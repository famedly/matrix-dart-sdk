// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import '../../matrix.dart';
import '../ssss.dart';
import 'bootstrap.dart';

extension CryptoSetupExtension on Client {
  /// Returns the current state of the crypto identity.
  ///
  /// [keyBackupEnabled] and [crossSigningEnabled] report each half
  /// independently. The crypto identity is `initialized` if both are set up.
  /// You can initialize a new account by using `Client.initCryptoIdentity()`.
  ///
  /// When [initialized] is false but the account already holds part of an
  /// identity (missing key backup or cross-signing, or incomplete cross-signing
  /// keys), heal it in place with `Client.initCryptoIdentity(
  /// reuseExistingStorageRecoveryKeyOrPassphrase: …)` and selective `setup*` /
  /// `wipe*` flags instead of wiping via a fresh `initCryptoIdentity()`.
  ///
  /// The crypto identity is `connected` if this device has all the secrets
  /// cached locally. This usually includes that this device has signed itself.
  /// You can use `Client.restoreCryptoIdentity()` to connect or
  /// `Client.initCryptoIdentity()` to wipe the current identity in case of
  /// that you lost your recovery key / passphrase and have no other way
  /// to restore.
  Future<
    ({
      bool keyBackupEnabled,
      bool crossSigningEnabled,
      bool initialized,
      bool connected,
    })
  >
  getCryptoIdentityState() async {
    await accountDataLoading;
    await firstSyncReceived;

    // Make sure we have the necessary account data types synced. Workaround for
    // https://github.com/element-hq/synapse/issues/15500
    for (final type in [
      EventTypes.MegolmBackup,
      EventTypes.CrossSigningSelfSigning,
      EventTypes.CrossSigningUserSigning,
      EventTypes.CrossSigningMasterKey,
    ]) {
      try {
        accountData[type] ??= BasicEvent(
          content: await getAccountData(userID!, type),
          type: type,
        );
      } on MatrixException catch (e) {
        if (e.error != MatrixError.M_NOT_FOUND) rethrow;
      }
    }

    final keyBackupEnabled = encryption?.keyManager.enabled ?? false;
    final crossSigningEnabled = encryption?.crossSigning.enabled ?? false;
    return (
      keyBackupEnabled: keyBackupEnabled,
      crossSigningEnabled: crossSigningEnabled,
      initialized: keyBackupEnabled && crossSigningEnabled,
      connected:
          ((await encryption?.keyManager.isCached()) ?? false) &&
          ((await encryption?.crossSigning.isCached()) ?? false),
    );
  }

  /// Reconnects to an already initialized crypto identity using the provided
  /// recovery key or passphrase. Throws if encryption is unavailable, the
  /// identity is not initialized, or it is already connected.
  ///
  /// [keyOrPassphrase] is the recovery key or passphrase that unlocks the
  /// secure secret storage. [keyIdentifier] can select a specific key when
  /// multiple exist.
  Future<void> restoreCryptoIdentity(
    String keyOrPassphrase, {
    String? keyIdentifier,
    bool selfSign = true,
  }) async {
    final encryption = this.encryption;
    if (encryption == null) {
      throw Exception('End to end encryption not available!');
    }
    final cryptoIdentityState = await getCryptoIdentityState();
    if (!cryptoIdentityState.initialized) {
      throw Exception(
        'Crypto identity is not initalized. Please check with `Client.getCryptoIdentityState()` first and run `Client.initCryptoIdentity()` once for this account.',
      );
    }
    if (cryptoIdentityState.connected) {
      throw Exception(
        'Crypto identity is already connected. Please check with `Client.getCryptoIdentityState()`.',
      );
    }

    final completer = Completer();
    encryption.bootstrap(
      onUpdate: (bootstrap) async {
        try {
          switch (bootstrap.state) {
            case BootstrapState.loading:
              break;
            case BootstrapState.askWipeSsss:
              bootstrap.wipeSsss(false);
              break;
            case BootstrapState.askUseExistingSsss:
              bootstrap.useExistingSsss(true, keyIdentifier: keyIdentifier);
              break;
            case BootstrapState.askUnlockSsss:
              bootstrap.unlockedSsss();
              break;
            case BootstrapState.askBadSsss:
              bootstrap.ignoreBadSecrets(false);
              break;
            case BootstrapState.openExistingSsss:
              await bootstrap.newSsssKey!.unlock(
                keyOrPassphrase: keyOrPassphrase,
              );
              await bootstrap.openExistingSsss();
              break;
            case BootstrapState.askWipeCrossSigning:
              await bootstrap.wipeCrossSigning(false);
              break;
            case BootstrapState.askWipeOnlineKeyBackup:
              bootstrap.wipeOnlineKeyBackup(false);
              break;
            // These states should not appear at all:
            case BootstrapState.askSetupOnlineKeyBackup:
            case BootstrapState.askSetupCrossSigning:
            case BootstrapState.askNewSsss:
              throw Exception(
                'Bootstrap state ${bootstrap.state} should not happen!',
              );
            case BootstrapState.error:
              throw bootstrap.errorResult ?? Exception('Bootstrap error!');
            case BootstrapState.done:
              completer.complete();
              break;
          }
        } catch (e, s) {
          if (completer.isCompleted) {
            return Logs().e('Bootstrap error after completed', e, s);
          }
          return completer.completeError(e, s);
        }
      },
    );

    await completer.future;

    if (selfSign) {
      await encryption.crossSigning.selfSign(keyOrPassphrase: keyOrPassphrase);
    }
  }

  /// Bootstraps a crypto identity for the client. Creates secret storage and
  /// cross-signing keys and optionally online key backup. Returns the recovery
  /// key for the secret storage key in use — newly generated, or the existing
  /// key when [reuseExistingStorageRecoveryKeyOrPassphrase] is set.
  ///
  /// [passphrase] lets users remember a human-readable phrase from which a
  /// **new** recovery key is derived using PBKDF2. It must not be combined with
  /// [reuseExistingStorageRecoveryKeyOrPassphrase].
  ///
  /// When [reuseExistingStorageRecoveryKeyOrPassphrase] is set, the existing
  /// secret storage key is kept and unlocked with that credential (secure
  /// storage is never wiped). Use this to heal a partially provisioned identity
  /// without invalidating the user's recovery key. [keyIdentifier] selects a
  /// specific key when several exist. [selfSign] then signs this device with
  /// the unlocked secrets when cross-signing is available.
  ///
  /// When [wipeSecureStorage] or [wipeKeyBackup] or [wipeCrossSigning] are true,
  /// existing data is wiped during setup. [wipeSecureStorage] is ignored when
  /// reusing an existing storage key. The `setup*` flags control which
  /// cross-signing keys and key backup are provisioned. [keyName] can label a
  /// newly generated secret storage key.
  ///
  /// Throws [BootstrapBadStateException] when reuse is requested but there is
  /// no usable existing secret storage key, or bootstrap would otherwise create
  /// a new key. Callers should fall back to a destructive
  /// `initCryptoIdentity()` without the reuse parameter.
  Future<String> initCryptoIdentity({
    String? passphrase,
    String? reuseExistingStorageRecoveryKeyOrPassphrase,
    String? keyIdentifier,
    bool selfSign = true,
    bool wipeSecureStorage = true,
    bool wipeKeyBackup = true,
    bool wipeCrossSigning = true,
    bool setupMasterKey = true,
    bool setupSelfSigningKey = true,
    bool setupUserSigningKey = true,
    bool setupOnlineKeyBackup = true,
    String? keyName,
  }) async {
    final encryption = this.encryption;
    if (encryption == null) {
      throw Exception('End to end encryption not available!');
    }

    final reuseCredential = reuseExistingStorageRecoveryKeyOrPassphrase;
    final reuseExisting = reuseCredential != null;
    if (reuseExisting && passphrase != null) {
      throw ArgumentError(
        'Cannot set both passphrase and reuseExistingStorageRecoveryKeyOrPassphrase.',
      );
    }

    if (reuseExisting) {
      final ssss = encryption.ssss;
      final keyToValidate = keyIdentifier ?? ssss.defaultKeyId;
      if (keyToValidate == null || !ssss.isKeyValid(keyToValidate)) {
        throw BootstrapBadStateException(
          'No usable existing secret storage key. Use `Client.initCryptoIdentity()` without reuse.',
        );
      }
      // Reuse mode never replaces the secret storage key or wipes existing components.
      wipeSecureStorage = false;
      wipeCrossSigning = false;
      wipeKeyBackup = false;
    }

    String? recoveryKey;
    OpenSSSS? openedSsss;
    final completer = Completer();
    encryption.bootstrap(
      onUpdate: (bootstrap) async {
        try {
          recoveryKey ??= bootstrap.newSsssKey?.recoveryKey;
          switch (bootstrap.state) {
            case BootstrapState.loading:
              break;
            case BootstrapState.askWipeSsss:
              bootstrap.wipeSsss(wipeSecureStorage);
              break;
            case BootstrapState.askUseExistingSsss:
              bootstrap.useExistingSsss(
                reuseExisting,
                keyIdentifier: keyIdentifier,
              );
              break;
            case BootstrapState.askUnlockSsss:
              if (reuseExisting) {
                throw BootstrapBadStateException(
                  'Cannot reuse existing storage from ${bootstrap.state}; use `Client.initCryptoIdentity()` without reuse.',
                );
              }
              bootstrap.unlockedSsss();
              break;
            case BootstrapState.askBadSsss:
              if (reuseExisting) {
                throw BootstrapBadStateException(
                  'Cannot reuse existing storage from ${bootstrap.state}; use `Client.initCryptoIdentity()` without reuse.',
                );
              }
              bootstrap.ignoreBadSecrets(true);
              break;
            case BootstrapState.askWipeCrossSigning:
              await bootstrap.wipeCrossSigning(wipeCrossSigning);
              break;
            case BootstrapState.askWipeOnlineKeyBackup:
              bootstrap.wipeOnlineKeyBackup(wipeKeyBackup);
              break;
            case BootstrapState.askSetupOnlineKeyBackup:
              await bootstrap.askSetupOnlineKeyBackup(setupOnlineKeyBackup);
              break;
            case BootstrapState.askSetupCrossSigning:
              await bootstrap.askSetupCrossSigning(
                setupMasterKey: setupMasterKey,
                setupSelfSigningKey: setupSelfSigningKey,
                setupUserSigningKey: setupUserSigningKey,
                selfSign: selfSign,
              );
              break;
            case BootstrapState.askNewSsss:
              if (reuseExisting) {
                throw BootstrapBadStateException(
                  'Cannot reuse existing storage from ${bootstrap.state}; use `Client.initCryptoIdentity()` without reuse.',
                );
              }
              await bootstrap.newSsss(passphrase, keyName);
              break;
            case BootstrapState.openExistingSsss:
              if (!reuseExisting) {
                throw Exception(
                  'Bootstrap state ${bootstrap.state} should not happen!',
                );
              }
              await bootstrap.newSsssKey!.unlock(
                keyOrPassphrase: reuseCredential,
              );
              recoveryKey ??= bootstrap.newSsssKey?.recoveryKey;
              openedSsss = bootstrap.newSsssKey;
              await bootstrap.openExistingSsss();
              break;
            case BootstrapState.error:
              throw bootstrap.errorResult ?? Exception('Bootstrap error!');
            case BootstrapState.done:
              completer.complete();
              break;
          }
        } catch (e, s) {
          if (completer.isCompleted) {
            return Logs().e('Bootstrap error after completed', e, s);
          }
          return completer.completeError(e, s);
        }
      },
    );

    await completer.future;

    if (reuseExisting && selfSign && (encryption.crossSigning.enabled)) {
      await encryption.crossSigning.selfSign(
        keyOrPassphrase: reuseCredential,
        openSsss: openedSsss,
      );
    }

    return recoveryKey!;
  }

  /// Empties encrypted SSSS account data so crypto identity reads as
  /// greenfield. Does not create a replacement key.
  Future<void> clearCryptoIdentity() async {
    final encryption = this.encryption;
    if (encryption == null) {
      throw Exception('End to end encryption not available!');
    }
    final ssss = encryption.ssss;
    Future<void> empty(String type) async {
      await setAccountData(userID!, type, {});
      while (accountData[type]?.content.isNotEmpty ?? true) {
        await oneShotSync();
      }
    }

    for (final type in ssss.analyzeEncryptedSecrets().keys.toList(
      growable: false,
    )) {
      await empty(type);
    }
    if (accountData.containsKey(EventTypes.SecretStorageDefaultKey)) {
      await empty(EventTypes.SecretStorageDefaultKey);
    }
    await ssss.clearCache();
  }
}
