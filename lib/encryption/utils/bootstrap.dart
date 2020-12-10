/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020 Famedly GmbH
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

import '../encryption.dart';
import '../ssss.dart';
import '../key_manager.dart';
import '../../famedlysdk.dart';
import '../../matrix_api/utils/logs.dart';

enum BootstrapState {
  loading, // loading
  askWipeSsss, // existing SSSS found, should we wipe it?
  askUseExistingSsss, // ask if an existing SSSS should be userDeviceKeys
  askBadSsss, // SSSS is in a bad state, continue with potential dataloss?
  askUnlockSsss, // Ask to unlock all the SSSS keys
  askNewSsss, // Ask for new SSSS key / passphrase
  openExistingSsss, // Open an existing SSSS key
  askWipeCrossSigning, // Ask if cross signing should be wiped
  askSetupCrossSigning, // Ask if cross signing should be set up
  askWipeOnlineKeyBackup, // Ask if online key backup should be wiped
  askSetupOnlineKeyBackup, // Ask if the online key backup should be set up
  error, // error
  done, // done
}

/// Bootstrapping SSSS and cross-signing
class Bootstrap {
  final Encryption encryption;
  Client get client => encryption.client;
  void Function() onUpdate;
  BootstrapState get state => _state;
  BootstrapState _state = BootstrapState.loading;
  Map<String, OpenSSSS> oldSsssKeys;
  OpenSSSS newSsssKey;
  Map<String, String> secretMap;

  Bootstrap({this.encryption, this.onUpdate}) {
    if (analyzeSecrets().isNotEmpty) {
      state = BootstrapState.askWipeSsss;
    } else {
      state = BootstrapState.askNewSsss;
    }
  }

  // cache the secret analyzing so that we don't drop stuff a different client sets during bootstrapping
  Map<String, Set<String>> _secretsCache;
  Map<String, Set<String>> analyzeSecrets() {
    if (_secretsCache != null) {
      // deep-copy so that we can do modifications
      final newSecrets = <String, Set<String>>{};
      for (final s in _secretsCache.entries) {
        newSecrets[s.key] = Set<String>.from(s.value);
      }
      return newSecrets;
    }
    final secrets = <String, Set<String>>{};
    for (final entry in client.accountData.entries) {
      final type = entry.key;
      final event = entry.value;
      if (!(event.content['encrypted'] is Map)) {
        continue;
      }
      final validKeys = <String>{};
      final invalidKeys = <String>{};
      for (final keyEntry in event.content['encrypted'].entries) {
        final key = keyEntry.key;
        final value = keyEntry.value;
        if (!(value is Map)) {
          // we don't add the key to invalidKeys as this was not a proper secret anyways!
          continue;
        }
        if (!(value['iv'] is String) ||
            !(value['ciphertext'] is String) ||
            !(value['mac'] is String)) {
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
        if (!usage.containsKey(key)) {
          usage[key] = 0;
        }
        usage[key]++;
      }
    }
    final entriesList = usage.entries.toList();
    entriesList.sort((a, b) => a.value.compareTo(b.value));
    return entriesList.first.key;
  }

  Set<String> allNeededKeys() {
    final secrets = analyzeSecrets();
    secrets.removeWhere(
        (k, v) => v.isEmpty); // we don't care about the failed secrets here
    final keys = <String>{};
    final defaultKeyId = encryption.ssss.defaultKeyId;
    final removeKey = (String key) {
      final sizeBefore = secrets.length;
      secrets.removeWhere((k, v) => v.contains(key));
      return sizeBefore - secrets.length;
    };
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
        encryption.ssss.isKeyValid(encryption.ssss.defaultKeyId)) {
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
      newSsssKey = encryption.ssss.open(encryption.ssss.defaultKeyId);
      state = BootstrapState.openExistingSsss;
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
    oldSsssKeys = <String, OpenSSSS>{};
    try {
      for (final key in keys) {
        oldSsssKeys[key] = encryption.ssss.open(key);
      }
    } catch (e) {
      // very bad
      Logs.error(
          '[Bootstrapping] Error construction ssss key: ' + e.toString());
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

  Future<void> newSsss([String passphrase]) async {
    if (state != BootstrapState.askNewSsss) {
      throw BootstrapBadStateException('Wrong State');
    }
    state = BootstrapState.loading;
    try {
      newSsssKey = await encryption.ssss.createKey(passphrase);
      if (oldSsssKeys != null) {
        // alright, we have to re-encrypt old secrets with the new key
        final secrets = analyzeSecrets();
        final removeKey = (String key) {
          final s = secrets.entries
              .where((e) => e.value.contains(key))
              .map((e) => e.key)
              .toSet();
          secrets.removeWhere((k, v) => v.contains(key));
          return s;
        };
        secretMap = <String, String>{};
        for (final entry in oldSsssKeys.entries) {
          final key = entry.value;
          final keyId = entry.key;
          if (!key.isUnlocked) {
            continue;
          }
          for (final s in removeKey(keyId)) {
            secretMap[s] = await key.getStored(s);
            await newSsssKey.store(s, secretMap[s], add: true);
          }
        }
        // alright, we re-encrypted all the secrets. We delete the dead weight only *after* we set our key to the default key
      }
      final updatedAccountData = client.onSync.stream.firstWhere((syncUpdate) =>
          syncUpdate.accountData.any((accountData) =>
              accountData.type == EventTypes.SecretStorageDefaultKey));
      await encryption.ssss.setDefaultKeyId(newSsssKey.keyId);
      await updatedAccountData;
      if (oldSsssKeys != null) {
        for (final entry in secretMap.entries) {
          await newSsssKey.validateAndStripOtherKeys(entry.key, entry.value);
        }
        // and make super sure we have everything cached
        await newSsssKey.maybeCacheAll();
      }
    } catch (e, s) {
      Logs.error(
          '[Bootstrapping] Error trying to migrate old secrets: ' +
              e.toString(),
          s);
      state = BootstrapState.error;
      return;
    }
    // alright, we successfully migrated all secrets, if needed

    checkCrossSigning();
  }

  void openExistingSsss() {
    if (state != BootstrapState.openExistingSsss) {
      throw BootstrapBadStateException();
    }
    if (!newSsssKey.isUnlocked) {
      throw BootstrapBadStateException('Key not unlocked');
    }
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

  void wipeCrossSigning(bool wipe) {
    if (state != BootstrapState.askWipeCrossSigning) {
      throw BootstrapBadStateException();
    }
    if (wipe) {
      state = BootstrapState.askSetupCrossSigning;
    } else {
      checkOnlineKeyBackup();
    }
  }

  Future<void> askSetupCrossSigning(
      {bool setupMasterKey = false,
      bool setupSelfSigningKey = false,
      bool setupUserSigningKey = false}) async {
    if (state != BootstrapState.askSetupCrossSigning) {
      throw BootstrapBadStateException();
    }
    if (!setupMasterKey && !setupSelfSigningKey && !setupUserSigningKey) {
      checkOnlineKeyBackup();
      return;
    }
    Uint8List masterSigningKey;
    final secretsToStore = <String, String>{};
    MatrixCrossSigningKey masterKey;
    MatrixCrossSigningKey selfSigningKey;
    MatrixCrossSigningKey userSigningKey;
    String masterPub;
    if (setupMasterKey) {
      final master = olm.PkSigning();
      try {
        masterSigningKey = master.generate_seed();
        masterPub = master.init_with_seed(masterSigningKey);
        final json = <String, dynamic>{
          'user_id': client.userID,
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
      masterSigningKey = base64.decode(
          await newSsssKey.getStored(EventTypes.CrossSigningMasterKey) ?? '');
      if (masterSigningKey == null || masterSigningKey.isEmpty) {
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
    final _sign = (Map<String, dynamic> object) {
      final keyObj = olm.PkSigning();
      try {
        keyObj.init_with_seed(masterSigningKey);
        return keyObj.sign(String.fromCharCodes(canonicalJson.encode(object)));
      } finally {
        keyObj.free();
      }
    };
    if (setupSelfSigningKey) {
      final selfSigning = olm.PkSigning();
      try {
        final selfSigningPriv = selfSigning.generate_seed();
        final selfSigningPub = selfSigning.init_with_seed(selfSigningPriv);
        final json = <String, dynamic>{
          'user_id': client.userID,
          'usage': ['self_signing'],
          'keys': <String, dynamic>{
            'ed25519:$selfSigningPub': selfSigningPub,
          },
        };
        final signature = _sign(json);
        json['signatures'] = <String, dynamic>{
          client.userID: <String, dynamic>{
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
          'user_id': client.userID,
          'usage': ['user_signing'],
          'keys': <String, dynamic>{
            'ed25519:$userSigningPub': userSigningPub,
          },
        };
        final signature = _sign(json);
        json['signatures'] = <String, dynamic>{
          client.userID: <String, dynamic>{
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
    try {
      // upload the keys!
      await client.uiaRequestBackground(
          (Map<String, dynamic> auth) => client.uploadDeviceSigningKeys(
                masterKey: masterKey,
                selfSigningKey: selfSigningKey,
                userSigningKey: userSigningKey,
                auth: auth,
              ));
      // aaaand set the SSSS secrets
      final futures = <Future<void>>[];
      if (masterKey != null) {
        futures.add(client.onSync.stream.firstWhere((syncUpdate) =>
            client.userDeviceKeys.containsKey(client.userID) &&
            client.userDeviceKeys[client.userID].masterKey != null &&
            client.userDeviceKeys[client.userID].masterKey.ed25519Key ==
                masterKey.publicKey));
      }
      for (final entry in secretsToStore.entries) {
        futures.add(client.onSync.stream.firstWhere((syncUpdate) => syncUpdate
            .accountData
            .any((accountData) => accountData.type == entry.key)));
        await newSsssKey.store(entry.key, entry.value);
      }
      for (final f in futures) {
        await f;
      }
      final keysToSign = <SignableKey>[];
      if (masterKey != null) {
        if (client.userDeviceKeys[client.userID].masterKey.ed25519Key !=
            masterKey.publicKey) {
          throw BootstrapBadStateException(
              'ERROR: New master key does not match up!');
        }
        await client.userDeviceKeys[client.userID].masterKey
            .setVerified(true, false);
        keysToSign.add(client.userDeviceKeys[client.userID].masterKey);
      }
      // and sign ourself!
      if (selfSigningKey != null) {
        keysToSign.add(
            client.userDeviceKeys[client.userID].deviceKeys[client.deviceID]);
      }
      await encryption.crossSigning.sign(keysToSign);
    } catch (e, s) {
      Logs.error(
          '[Bootstrapping] Error setting up cross signing: ' + e.toString(), s);
      state = BootstrapState.error;
      return;
    }

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
    final keyObj = olm.PkDecryption();
    String pubKey;
    Uint8List privKey;
    try {
      pubKey = keyObj.generate_key();
      privKey = keyObj.get_private_key();
    } finally {
      keyObj.free();
    }
    try {
      // create the new backup version
      await client.createRoomKeysBackup(
        RoomKeysAlgorithmType.v1Curve25519AesSha2,
        <String, dynamic>{
          'public_key': pubKey,
        },
      );
      // store the secret
      await newSsssKey.store(MEGOLM_KEY, base64.encode(privKey));
      // and finally set all megolm keys as needing to be uploaded again
      await client.database?.markInboundGroupSessionsAsNeedingUpload(client.id);
    } catch (e, s) {
      Logs.error(
          '[Bootstrapping] Error setting up online key backup: ' + e.toString(),
          s);
      state = BootstrapState.error;
      encryption.onError.add(SdkError(exception: e, stackTrace: s));
      return;
    }
    state = BootstrapState.done;
  }

  set state(BootstrapState newState) {
    if (state != BootstrapState.error) {
      _state = newState;
    }
    if (onUpdate != null) {
      onUpdate();
    }
  }
}

class BootstrapBadStateException implements Exception {
  String cause;
  BootstrapBadStateException([this.cause = 'Bad state']);

  @override
  String toString() => 'BootstrapBadStateException: $cause';
}
