import 'dart:async';

import 'package:matrix/encryption/utils/bootstrap.dart';
import 'package:matrix/matrix.dart';

extension CryptoSetupExtension on Client {
  /// Returns the current state of the crypto identity.
  Future<({bool initialized, bool connected})> getCryptoIdentityState() async =>
      (
        initialized: (encryption?.keyManager.enabled ?? false) &&
            (encryption?.crossSigning.enabled ?? false),
        connected: ((await encryption?.keyManager.isCached()) ?? false) &&
            ((await encryption?.crossSigning.isCached()) ?? false),
      );

  Future<void> restoreCryptoIdentity(
    String keyOrPassphrase, {
    String? keyIdentifier,
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
              await bootstrap.newSsssKey!
                  .unlock(keyOrPassphrase: keyOrPassphrase);
              await bootstrap.openExistingSsss();
              await bootstrap.client.encryption!.crossSigning
                  .selfSign(keyOrPassphrase: keyOrPassphrase);
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
              throw Exception('Bootstrap error!');
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
  }

  Future<String> initCryptoIdentity({
    String? passphrase,
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

    String? newSsssKey;
    final completer = Completer();
    encryption.bootstrap(
      onUpdate: (bootstrap) async {
        try {
          newSsssKey ??= bootstrap.newSsssKey?.recoveryKey;
          switch (bootstrap.state) {
            case BootstrapState.loading:
              break;
            case BootstrapState.askWipeSsss:
              bootstrap.wipeSsss(wipeSecureStorage);
              break;
            case BootstrapState.askUseExistingSsss:
              bootstrap.useExistingSsss(false);
              break;
            case BootstrapState.askUnlockSsss:
              bootstrap.unlockedSsss();
              break;
            case BootstrapState.askBadSsss:
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
              );
              break;
            case BootstrapState.askNewSsss:
              await bootstrap.newSsss(passphrase, keyName);
              break;
            case BootstrapState.openExistingSsss:
              throw Exception(
                'Bootstrap state ${bootstrap.state} should not happen!',
              );
            case BootstrapState.error:
              throw Exception('Bootstrap error!');
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
    return newSsssKey!;
  }
}
