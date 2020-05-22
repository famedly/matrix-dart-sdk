import 'dart:convert';
import 'package:canonical_json/canonical_json.dart';
import 'package:olm/olm.dart' as olm;

import '../client.dart';
import '../database/database.dart'
    show DbUserDeviceKey, DbUserDeviceKeysKey, DbUserCrossSigningKey;
import '../event.dart';
import 'key_verification.dart';

class DeviceKeysList {
  Client client;
  String userId;
  bool outdated = true;
  Map<String, DeviceKeys> deviceKeys = {};
  Map<String, CrossSigningKey> crossSigningKeys = {};

  DeviceKeysList.fromDb(
      DbUserDeviceKey dbEntry,
      List<DbUserDeviceKeysKey> childEntries,
      List<DbUserCrossSigningKey> crossSigningEntries,
      Client cl) {
    client = cl;
    userId = dbEntry.userId;
    outdated = dbEntry.outdated;
    deviceKeys = {};
    for (final childEntry in childEntries) {
      final entry = DeviceKeys.fromDb(childEntry, client);
      if (entry.isValid) {
        deviceKeys[childEntry.deviceId] = entry;
      } else {
        outdated = true;
      }
    }
    for (final crossSigningEntry in crossSigningEntries) {
      final entry = CrossSigningKey.fromDb(crossSigningEntry, client);
      if (entry.isValid) {
        crossSigningKeys[crossSigningEntry.publicKey] = entry;
      } else {
        outdated = true;
      }
    }
  }

  DeviceKeysList.fromJson(Map<String, dynamic> json, Client cl) {
    client = cl;
    userId = json['user_id'];
    outdated = json['outdated'];
    deviceKeys = {};
    for (final rawDeviceKeyEntry in json['device_keys'].entries) {
      deviceKeys[rawDeviceKeyEntry.key] =
          DeviceKeys.fromJson(rawDeviceKeyEntry.value, client);
    }
  }

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
    final data = map;
    data['user_id'] = userId;
    data['outdated'] = outdated ?? true;

    var rawDeviceKeys = <String, dynamic>{};
    for (final deviceKeyEntry in deviceKeys.entries) {
      rawDeviceKeys[deviceKeyEntry.key] = deviceKeyEntry.value.toJson();
    }
    data['device_keys'] = rawDeviceKeys;
    return data;
  }

  @override
  String toString() => json.encode(toJson());

  DeviceKeysList(this.userId);
}

abstract class _SignedKey {
  Client client;
  String userId;
  String identifier;
  Map<String, dynamic> content;
  Map<String, String> keys;
  Map<String, dynamic> signatures;
  Map<String, dynamic> validSignatures;
  bool _verified;
  bool blocked;

  String get ed25519Key => keys['ed25519:$identifier'];

  bool get verified => (directVerified || crossVerified) && !blocked;

  void setDirectVerified(bool v) {
    _verified = v;
  }

  bool get directVerified => _verified;

  bool get crossVerified {
    try {
      return hasValidSignatureChain();
    } catch (err, stacktrace) {
      print(
          '[Cross Signing] Error during trying to determine signature chain: ' +
              err.toString());
      print(stacktrace);
      return false;
    }
  }

  String _getSigningContent() {
    final data = Map<String, dynamic>.from(content);
    // some old data might have the custom verified and blocked keys
    data.remove('verified');
    data.remove('blocked');
    // remove the keys not needed for signing
    data.remove('unsigned');
    data.remove('signatures');
    return String.fromCharCodes(canonicalJson.encode(data));
  }

  bool _verifySignature(String pubKey, String signature) {
    final olmutil = olm.Utility();
    var valid = false;
    try {
      olmutil.ed25519_verify(pubKey, _getSigningContent(), signature);
      valid = true;
    } catch (_) {
      // bad signature
      valid = false;
    } finally {
      olmutil.free();
    }
    return valid;
  }

  bool hasValidSignatureChain({Set<String> visited}) {
    visited ??= <String>{};
    final setKey = '${userId};${identifier}';
    if (visited.contains(setKey)) {
      return false; // prevent recursion
    }
    visited.add(setKey);
    for (final signatureEntries in signatures.entries) {
      final otherUserId = signatureEntries.key;
      if (!(signatureEntries.value is Map) ||
          !client.userDeviceKeys.containsKey(otherUserId)) {
        continue;
      }
      for (final signatureEntry in signatureEntries.value.entries) {
        final fullKeyId = signatureEntry.key;
        final signature = signatureEntry.value;
        if (!(fullKeyId is String) || !(signature is String)) {
          continue;
        }
        final keyId = fullKeyId.substring('ed25519:'.length);
        _SignedKey key;
        if (client.userDeviceKeys[otherUserId].deviceKeys.containsKey(keyId)) {
          key = client.userDeviceKeys[otherUserId].deviceKeys[keyId];
        } else if (client.userDeviceKeys[otherUserId].crossSigningKeys
            .containsKey(keyId)) {
          key = client.userDeviceKeys[otherUserId].crossSigningKeys[keyId];
        } else {
          continue;
        }
        if (key.blocked) {
          continue; // we can't be bothered about this keys signatures
        }
        var haveValidSignature = false;
        var gotSignatureFromCache = false;
        if (validSignatures != null &&
            validSignatures.containsKey(otherUserId) &&
            validSignatures[otherUserId].containsKey(fullKeyId)) {
          if (validSignatures[otherUserId][fullKeyId] == true) {
            haveValidSignature = true;
            gotSignatureFromCache = true;
          } else if (validSignatures[otherUserId][fullKeyId] == false) {
            haveValidSignature = false;
            gotSignatureFromCache = true;
          }
        }
        if (!gotSignatureFromCache) {
          // validate the signature manually
          haveValidSignature = _verifySignature(key.ed25519Key, signature);
          validSignatures ??= <String, dynamic>{};
          if (!validSignatures.containsKey(otherUserId)) {
            validSignatures[otherUserId] = <String, dynamic>{};
          }
          validSignatures[otherUserId][fullKeyId] = haveValidSignature;
        }
        if (!haveValidSignature) {
          // no valid signature, this key is useless
          continue;
        }

        if (key.directVerified) {
          return true; // we verified this key and it is valid...all checks out!
        }
        // or else we just recurse into that key and chack if it works out
        final haveChain = key.hasValidSignatureChain(visited: visited);
        if (haveChain) {
          return true;
        }
      }
    }
    return false;
  }

  Map<String, dynamic> toJson() {
    final data = Map<String, dynamic>.from(content);
    // some old data may have the verified and blocked keys which are unneeded now
    data.remove('verified');
    data.remove('blocked');
    return data;
  }

  @override
  String toString() => json.encode(toJson());
}

class CrossSigningKey extends _SignedKey {
  String get publicKey => identifier;
  List<String> usage;

  bool get isValid =>
      userId != null && publicKey != null && keys != null && ed25519Key != null;

  Future<void> setVerified(bool newVerified) {
    _verified = newVerified;
    return client.database?.setVerifiedUserCrossSigningKey(
        newVerified, client.id, userId, publicKey);
  }

  Future<void> setBlocked(bool newBlocked) {
    blocked = newBlocked;
    return client.database?.setBlockedUserCrossSigningKey(
        newBlocked, client.id, userId, publicKey);
  }

  CrossSigningKey.fromDb(DbUserCrossSigningKey dbEntry, Client cl) {
    client = cl;
    final json = Event.getMapFromPayload(dbEntry.content);
    content = Map<String, dynamic>.from(json);
    userId = dbEntry.userId;
    identifier = dbEntry.publicKey;
    usage = json['usage'].cast<String>();
    keys = json['keys'] != null ? Map<String, String>.from(json['keys']) : null;
    signatures = json['signatures'] != null
        ? Map<String, dynamic>.from(json['signatures'])
        : null;
    _verified = dbEntry.verified;
    blocked = dbEntry.blocked;
  }

  CrossSigningKey.fromJson(Map<String, dynamic> json, Client cl) {
    client = cl;
    content = Map<String, dynamic>.from(json);
    userId = json['user_id'];
    usage = json['usage'].cast<String>();
    keys = json['keys'] != null ? Map<String, String>.from(json['keys']) : null;
    signatures = json['signatures'] != null
        ? Map<String, dynamic>.from(json['signatures'])
        : null;
    _verified = json['verified'] ?? false;
    blocked = json['blocked'] ?? false;
    if (keys != null) {
      identifier = keys.values.first;
    }
  }
}

class DeviceKeys extends _SignedKey {
  String get deviceId => identifier;
  List<String> algorithms;
  Map<String, dynamic> unsigned;

  String get curve25519Key => keys['curve25519:$deviceId'];

  bool get isValid =>
      userId != null &&
      deviceId != null &&
      keys != null &&
      curve25519Key != null &&
      ed25519Key != null;

  Future<void> setVerified(bool newVerified, Client client) {
    _verified = newVerified;
    return client.database
        ?.setVerifiedUserDeviceKey(newVerified, client.id, userId, deviceId);
  }

  Future<void> setBlocked(bool newBlocked) {
    blocked = newBlocked;
    for (var room in client.rooms) {
      if (!room.encrypted) continue;
      if (room.getParticipants().indexWhere((u) => u.id == userId) != -1) {
        room.clearOutboundGroupSession();
      }
    }
    return client.database
        ?.setBlockedUserDeviceKey(newBlocked, client.id, userId, deviceId);
  }

  DeviceKeys.fromDb(DbUserDeviceKeysKey dbEntry, Client cl) {
    client = cl;
    final json = Event.getMapFromPayload(dbEntry.content);
    content = Map<String, dynamic>.from(json);
    userId = dbEntry.userId;
    identifier = dbEntry.deviceId;
    algorithms = content['algorithms'].cast<String>();
    keys = content['keys'] != null
        ? Map<String, String>.from(content['keys'])
        : null;
    signatures = content['signatures'] != null
        ? Map<String, dynamic>.from(content['signatures'])
        : null;
    unsigned = json['unsigned'] != null
        ? Map<String, dynamic>.from(json['unsigned'])
        : null;
    _verified = dbEntry.verified;
    blocked = dbEntry.blocked;
  }

  DeviceKeys.fromJson(Map<String, dynamic> json, Client cl) {
    client = cl;
    content = Map<String, dynamic>.from(json);
    userId = json['user_id'];
    identifier = json['device_id'];
    algorithms = json['algorithms'].cast<String>();
    keys = json['keys'] != null ? Map<String, String>.from(json['keys']) : null;
    signatures = json['signatures'] != null
        ? Map<String, dynamic>.from(json['signatures'])
        : null;
    unsigned = json['unsigned'] != null
        ? Map<String, dynamic>.from(json['unsigned'])
        : null;
    _verified = json['verified'] ?? false;
    blocked = json['blocked'] ?? false;
  }

  KeyVerification startVerification(Client client) {
    final request =
        KeyVerification(client: client, userId: userId, deviceId: deviceId);
    request.start();
    client.addKeyVerificationRequest(request);
    return request;
  }
}
