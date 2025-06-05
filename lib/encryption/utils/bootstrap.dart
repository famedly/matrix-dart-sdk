/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020, 2021 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:convert';
import 'dart:typed_data';

import 'package:canonical_json/canonical_json.dart';
import 'package:olm/olm.dart' as olm;

import 'package:matrix/encryption/encryption.dart';
import 'package:matrix/encryption/key_manager.dart';
import 'package:matrix/encryption/ssss.dart';
import 'package:matrix/encryption/utils/base64_unpadded.dart';
import 'package:matrix/matrix.dart';

enum BootstrapState {
  /// Is loading.
  loading,

  /// Existing SSSS found, should we wipe it?
  askWipeSsss,

  /// Ask if an existing SSSS should be userDeviceKeys
  askUseExistingSsss,

  /// Ask to unlock all the SSSS keys
  askUnlockSsss,

  /// SSSS is in a bad state, continue with potential dataloss?
  askBadSsss,

  /// Ask for new SSSS key / passphrase
  askNewSsss,

  /// Open an existing SSSS key
  openExistingSsss,

  /// Ask if cross signing should be wiped
  askWipeCrossSigning,

  /// Ask if cross signing should be set up
  askSetupCrossSigning,

  /// Ask if online key backup should be wiped
  askWipeOnlineKeyBackup,

  /// Ask if the online key backup should be set up
  askSetupOnlineKeyBackup,

  /// An error has been occured.
  error,

  /// done
  done,
}

/// Bootstrapping SSSS and cross-signing
class Bootstrap {
  final Encryption encryption;
  Client get client => encryption.client;
  void Function(Bootstrap)? onUpdate;
  BootstrapState get state => _state;
  BootstrapState _state = BootstrapState.loading;
  Map<String, OpenSSSS>? oldSsssKeys;
  OpenSSSS? newSsssKey;
  Map<String, String>? secretMap;

  Bootstrap({required this.encryption, this.onUpdate}) {
    if (analyzeSecrets().isNotEmpty) {
      state = BootstrapState.askWipeSsss;
    } else {
      state = BootstrapState.askNewSsss;
    }
  }

  // cache the secret analyzing so that we don't drop stuff a different client sets during bootstrapping
  Map<String, Set<String>>? _secretsCache;

  /// returns ssss from accountdata, eg: m.megolm_backup.v1, or your m.cross_signing stuff
  Map<String, Set<String>> analyzeSecrets() {
    final secretsCache = _secretsCache;
    if (secretsCache != null) {
      // deep-copy so that we can do modifications
      final newSecrets = <String, Set<String>>{};
      for (final s in secretsCache.entries) {
        newSecrets[s.key] = Set<String>.from(s.value);
      }
      return newSecrets;
    }
    final secrets = <String, Set<String>>{};
    for (final entry in client.accountData.entries) {
      final type = entry.key;
      final event = entry.value;
      final encryptedContent =
          event.content.tryGetMap<String, Object?>('encrypted');
      if (encryptedContent == null) {
        continue;
      }
      final validKeys = <String>{};
      final invalidKeys = <String>{};
      for (final keyEntry in encryptedContent.entries) {
        final key = keyEntry.key;
        final value = keyEntry.value;
        if (value is! Map) {
          // we don't add the key to invalidKeys as this was not a proper secret anyways!
          continue;
        }
        if (value['iv'] is! String ||
            value['ciphertext'] is! String ||
            value['mac'] is! String) {
          invalidKeys.add(key);
          continue;
        }
        if (!encryption.ssss.isKeyValid(key)) {
          invalidKeys.add(key);
          continue;
        }
        validKeys.add(key);
      }
      if (validKeys.isEmpty && invalidKeys.isEmpty) {
        continue; // this didn't contain any keys anyways!
      }
      // if there are no valid keys and only invalid keys then the validKeys set will be empty
      // from that we know that there were errors with this secret and that we won't be able to migrate it
      secrets[type] = validKeys;
    }
    _secretsCache = secrets;
    return analyzeSecrets();
  }

  Set<String> badSecrets() {
    final secrets = analyzeSecrets();
    secrets.removeWhere((k, v) => v.isNotEmpty);
    return Set<String>.from(secrets.keys);
  }

  String mostUsedKey(Map<String, Set<String>> secrets) {
    final usage = <String, int>{};
    for (final keys in secrets.values) {
      for (final key in keys) {
        usage.update(key, (i) => i + 1, ifAbsent: () => 1);
      }
    }
    final entriesList = usage.entries.toList();
    entriesList.sort((a, b) => a.value.compareTo(b.value));
    return entriesList.first.key;
  }

  Set<String> allNeededKeys() {
    final secrets = analyzeSecrets();
    secrets.removeWhere(
      (k, v) => v.isEmpty,
    ); // we don't care about the failed secrets here
    final keys = <String>{};
    final defaultKeyId = encryption.ssss.defaultKeyId;
    int removeKey(String key) {
      final sizeBefore = secrets.length;
      secrets.removeWhere((k, v) => v.contains(key));
      return sizeBefore - secrets.length;
    }

    // first we want to try the default key id
    if (defaultKeyId != null) {
      if (removeKey(defaultKeyId) > 0) {
        keys.add(defaultKeyId);
      }
    }
    // now we re-try as long as we have keys for all secrets
    while (secrets.isNotEmpty) {
      final key = mostUsedKey(secrets);
      removeKey(key);
      keys.add(key);
    }
    return keys;
  }

  void wipeSsss(bool wipe) {
    if (state != BootstrapState.askWipeSsss) {
      throw BootstrapBadStateException('Wrong State');
    }
    if (wipe) {
      state = BootstrapState.askNewSsss;
    } else if (encryption.ssss.defaultKeyId != null &&
        encryption.ssss.isKeyValid(encryption.ssss.defaultKeyId!)) {
      state = BootstrapState.askUseExistingSsss;
    } else if (badSecrets().isNotEmpty) {
      state = BootstrapState.askBadSsss;
    } else {
      migrateOldSsss();
    }
  }

  void useExistingSsss(bool use) {
    if (state != BootstrapState.askUseExistingSsss) {
      throw BootstrapBadStateException('Wrong State');
    }
    if (use) {
      try {
        newSsssKey = encryption.ssss.open(encryption.ssss.defaultKeyId);
        state = BootstrapState.openExistingSsss;
      } catch (e, s) {
        Logs().e('[Bootstrapping] Error open SSSS', e, s);
        state = BootstrapState.error;
        return;
      }
    } else if (badSecrets().isNotEmpty) {
      state = BootstrapState.askBadSsss;
    } else {
      migrateOldSsss();
    }
  }

  void ignoreBadSecrets(bool ignore) {
    if (state != BootstrapState.askBadSsss) {
      throw BootstrapBadStateException('Wrong State');
    }
    if (ignore) {
      migrateOldSsss();
    } else {
      // that's it, folks. We can't do anything here
      state = BootstrapState.error;
    }
  }

  void migrateOldSsss() {
    final keys = allNeededKeys();
    final oldSsssKeys = this.oldSsssKeys = {};
    try {
      for (final key in keys) {
        oldSsssKeys[key] = encryption.ssss.open(key);
      }
    } catch (e, s) {
      Logs().e('[Bootstrapping] Error construction ssss key', e, s);
      state = BootstrapState.error;
      return;
    }
    state = BootstrapState.askUnlockSsss;
  }

  void unlockedSsss() {
    if (state != BootstrapState.askUnlockSsss) {
      throw BootstrapBadStateException('Wrong State');
    }
    state = BootstrapState.askNewSsss;
  }

  Future<void> newSsss([String? passphrase]) async {
    if (state != BootstrapState.askNewSsss) {
      throw BootstrapBadStateException('Wrong State');
    }
    state = BootstrapState.loading;
    try {
      Logs().v('Create key...');
      newSsssKey = await encryption.ssss.createKey(passphrase);
      if (oldSsssKeys != null) {
        // alright, we have to re-encrypt old secrets with the new key
        final secrets = analyzeSecrets();
        Set<String> removeKey(String key) {
          final s = secrets.entries
              .where((e) => e.value.contains(key))
              .map((e) => e.key)
              .toSet();
          secrets.removeWhere((k, v) => v.contains(key));
          return s;
        }

        secretMap = <String, String>{};
        for (final entry in oldSsssKeys!.entries) {
          final key = entry.value;
          final keyId = entry.key;
          if (!key.isUnlocked) {
            continue;
          }
          for (final s in removeKey(keyId)) {
            Logs().v('Get stored key of type $s...');
            secretMap![s] = await key.getStored(s);
            Logs().v('Store new secret with this key...');
            await newSsssKey!.store(s, secretMap![s]!, add: true);
          }
        }
        // alright, we re-encrypted all the secrets. We delete the dead weight only *after* we set our key to the default key
      }
      await encryption.ssss.setDefaultKeyId(newSsssKey!.keyId);
      while (encryption.ssss.defaultKeyId != newSsssKey!.keyId) {
        Logs().v(
          'Waiting accountData to have the correct m.secret_storage.default_key',
        );
        await client.oneShotSync();
      }
      if (oldSsssKeys != null) {
        for (final entry in secretMap!.entries) {
          Logs().v('Validate and stripe other keys ${entry.key}...');
          await newSsssKey!.validateAndStripOtherKeys(entry.key, entry.value);
        }
        Logs().v('And make super sure we have everything cached...');
        await newSsssKey!.maybeCacheAll();
      }
    } catch (e, s) {
      Logs().e('[Bootstrapping] Error trying to migrate old secrets', e, s);
      state = BootstrapState.error;
      return;
    }
    // alright, we successfully migrated all secrets, if needed

    checkCrossSigning();
  }

  Future<void> openExistingSsss() async {
    final newSsssKey = this.newSsssKey;
    if (state != BootstrapState.openExistingSsss || newSsssKey == null) {
      throw BootstrapBadStateException();
    }
    if (!newSsssKey.isUnlocked) {
      throw BootstrapBadStateException('Key not unlocked');
    }
    Logs().v('Maybe cache all...');
    await newSsssKey.maybeCacheAll();
    checkCrossSigning();
  }

  void checkCrossSigning() {
    // so, let's see if we have cross signing set up
    if (encryption.crossSigning.enabled) {
      // cross signing present, ask for wipe
      state = BootstrapState.askWipeCrossSigning;
      return;
    }
    // no cross signing present
    state = BootstrapState.askSetupCrossSigning;
  }

  Future<void> wipeCrossSigning(bool wipe) async {
    if (state != BootstrapState.askWipeCrossSigning) {
      throw BootstrapBadStateException();
    }
    if (wipe) {
      state = BootstrapState.askSetupCrossSigning;
    } else {
      await client.dehydratedDeviceSetup(newSsssKey!);
      checkOnlineKeyBackup();
    }
  }

  Future<void> askSetupCrossSigning({
    bool setupMasterKey = false,
    bool setupSelfSigningKey = false,
    bool setupUserSigningKey = false,
  }) async {
    if (state != BootstrapState.askSetupCrossSigning) {
      throw BootstrapBadStateException();
    }
    if (!setupMasterKey && !setupSelfSigningKey && !setupUserSigningKey) {
      await client.dehydratedDeviceSetup(newSsssKey!);
      checkOnlineKeyBackup();
      return;
    }
    final userID = client.userID!;
    try {
      Uint8List masterSigningKey;
      final secretsToStore = <String, String>{};
      MatrixCrossSigningKey? masterKey;
      MatrixCrossSigningKey? selfSigningKey;
      MatrixCrossSigningKey? userSigningKey;
      String? masterPub;
      if (setupMasterKey) {
        final master = olm.PkSigning();
        try {
          masterSigningKey = master.generate_seed();
          masterPub = master.init_with_seed(masterSigningKey);
          final json = <String, dynamic>{
            'user_id': userID,
            'usage': ['master'],
            'keys': <String, dynamic>{
              'ed25519:$masterPub': masterPub,
            },
          };
          masterKey = MatrixCrossSigningKey.fromJson(json);
          secretsToStore[EventTypes.CrossSigningMasterKey] =
              base64.encode(masterSigningKey);
        } finally {
          master.free();
        }
      } else {
        Logs().v('Get stored key...');
        masterSigningKey = base64decodeUnpadded(
          await newSsssKey?.getStored(EventTypes.CrossSigningMasterKey) ?? '',
        );
        if (masterSigningKey.isEmpty) {
          // no master signing key :(
          throw BootstrapBadStateException('No master key');
        }
        final master = olm.PkSigning();
        try {
          masterPub = master.init_with_seed(masterSigningKey);
        } finally {
          master.free();
        }
      }
      String? sign(Map<String, dynamic> object) {
        final keyObj = olm.PkSigning();
        try {
          keyObj.init_with_seed(masterSigningKey);
          return keyObj
              .sign(String.fromCharCodes(canonicalJson.encode(object)));
        } finally {
          keyObj.free();
        }
      }

      if (setupSelfSigningKey) {
        final selfSigning = olm.PkSigning();
        try {
          final selfSigningPriv = selfSigning.generate_seed();
          final selfSigningPub = selfSigning.init_with_seed(selfSigningPriv);
          final json = <String, dynamic>{
            'user_id': userID,
            'usage': ['self_signing'],
            'keys': <String, dynamic>{
              'ed25519:$selfSigningPub': selfSigningPub,
            },
          };
          final signature = sign(json);
          json['signatures'] = <String, dynamic>{
            userID: <String, dynamic>{
              'ed25519:$masterPub': signature,
            },
          };
          selfSigningKey = MatrixCrossSigningKey.fromJson(json);
          secretsToStore[EventTypes.CrossSigningSelfSigning] =
              base64.encode(selfSigningPriv);
        } finally {
          selfSigning.free();
        }
      }
      if (setupUserSigningKey) {
        final userSigning = olm.PkSigning();
        try {
          final userSigningPriv = userSigning.generate_seed();
          final userSigningPub = userSigning.init_with_seed(userSigningPriv);
          final json = <String, dynamic>{
            'user_id': userID,
            'usage': ['user_signing'],
            'keys': <String, dynamic>{
              'ed25519:$userSigningPub': userSigningPub,
            },
          };
          final signature = sign(json);
          json['signatures'] = <String, dynamic>{
            userID: <String, dynamic>{
              'ed25519:$masterPub': signature,
            },
          };
          userSigningKey = MatrixCrossSigningKey.fromJson(json);
          secretsToStore[EventTypes.CrossSigningUserSigning] =
              base64.encode(userSigningPriv);
        } finally {
          userSigning.free();
        }
      }
      // upload the keys!
      state = BootstrapState.loading;
      Logs().v('Upload device signing keys.');
      await client.uiaRequestBackground(
        (AuthenticationData? auth) => client.uploadCrossSigningKeys(
          masterKey: masterKey,
          selfSigningKey: selfSigningKey,
          userSigningKey: userSigningKey,
          auth: auth,
        ),
      );
      Logs().v('Device signing keys have been uploaded.');
      // aaaand set the SSSS secrets
      if (masterKey != null) {
        while (!(masterKey.publicKey != null &&
            client.userDeviceKeys[client.userID]?.masterKey?.ed25519Key ==
                masterKey.publicKey)) {
          Logs().v('Waiting for master to be created');
          await client.oneShotSync();
        }
      }
      if (newSsssKey != null) {
        final storeFutures = <Future<void>>[];
        for (final entry in secretsToStore.entries) {
          storeFutures.add(newSsssKey!.store(entry.key, entry.value));
        }
        Logs().v('Store new SSSS key entries...');
        await Future.wait(storeFutures);
      }

      final keysToSign = <SignableKey>[];
      if (masterKey != null) {
        if (client.userDeviceKeys[client.userID]?.masterKey?.ed25519Key !=
            masterKey.publicKey) {
          throw BootstrapBadStateException(
            'ERROR: New master key does not match up!',
          );
        }
        Logs().v('Set own master key to verified...');
        await client.userDeviceKeys[client.userID]!.masterKey!
            .setVerified(true, false);
        keysToSign.add(client.userDeviceKeys[client.userID]!.masterKey!);
      }
      if (selfSigningKey != null) {
        keysToSign.add(
          client.userDeviceKeys[client.userID]!.deviceKeys[client.deviceID]!,
        );
      }
      Logs().v('Sign ourself...');
      await encryption.crossSigning.sign(keysToSign);
    } catch (e, s) {
      Logs().e('[Bootstrapping] Error setting up cross signing', e, s);
      state = BootstrapState.error;
      return;
    }

    await client.dehydratedDeviceSetup(newSsssKey!);
    checkOnlineKeyBackup();
  }

  void checkOnlineKeyBackup() {
    // check if we have online key backup set up
    if (encryption.keyManager.enabled) {
      state = BootstrapState.askWipeOnlineKeyBackup;
      return;
    }
    state = BootstrapState.askSetupOnlineKeyBackup;
  }

  void wipeOnlineKeyBackup(bool wipe) {
    if (state != BootstrapState.askWipeOnlineKeyBackup) {
      throw BootstrapBadStateException();
    }
    if (wipe) {
      state = BootstrapState.askSetupOnlineKeyBackup;
    } else {
      state = BootstrapState.done;
    }
  }

  Future<void> askSetupOnlineKeyBackup(bool setup) async {
    if (state != BootstrapState.askSetupOnlineKeyBackup) {
      throw BootstrapBadStateException();
    }
    if (!setup) {
      state = BootstrapState.done;
      return;
    }
    try {
      final keyObj = olm.PkDecryption();
      String pubKey;
      Uint8List privKey;
      try {
        pubKey = keyObj.generate_key();
        privKey = keyObj.get_private_key();
      } finally {
        keyObj.free();
      }
      Logs().v('Create the new backup version...');
      await client.postRoomKeysVersion(
        BackupAlgorithm.mMegolmBackupV1Curve25519AesSha2,
        <String, dynamic>{
          'public_key': pubKey,
        },
      );
      Logs().v('Store the secret...');
      await newSsssKey?.store(megolmKey, base64.encode(privKey));

      Logs().v(
        'And finally set all megolm keys as needing to be uploaded again...',
      );
      await client.database?.markInboundGroupSessionsAsNeedingUpload();
      Logs().v('And uploading keys...');
      await client.encryption?.keyManager.uploadInboundGroupSessions();
    } catch (e, s) {
      Logs().e('[Bootstrapping] Error setting up online key backup', e, s);
      state = BootstrapState.error;
      encryption.client.onEncryptionError.add(
        SdkError(exception: e, stackTrace: s),
      );
      return;
    }
    state = BootstrapState.done;
  }

  set state(BootstrapState newState) {
    Logs().v('BootstrapState: $newState');
    if (state != BootstrapState.error) {
      _state = newState;
    }

    onUpdate?.call(this);
  }
}

class BootstrapBadStateException implements Exception {
  String cause;
  BootstrapBadStateException([this.cause = 'Bad state']);

  @override
  String toString() => 'BootstrapBadStateException: $cause';
}
