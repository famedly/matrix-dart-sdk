import 'dart:convert';
import 'package:canonical_json/canonical_json.dart';
import 'package:olm/olm.dart' as olm;

import 'package:famedlysdk/matrix_api.dart';
import 'package:famedlysdk/encryption.dart';

import '../client.dart';
import '../user.dart';
import '../room.dart';
import '../database/database.dart'
    show DbUserDeviceKey, DbUserDeviceKeysKey, DbUserCrossSigningKey;
import '../event.dart';

enum UserVerifiedStatus { verified, unknown, unknownDevice }

class DeviceKeysList {
  Client client;
  String userId;
  bool outdated = true;
  Map<String, DeviceKeys> deviceKeys = {};
  Map<String, CrossSigningKey> crossSigningKeys = {};

  SignableKey getKey(String id) {
    if (deviceKeys.containsKey(id)) {
      return deviceKeys[id];
    }
    if (crossSigningKeys.containsKey(id)) {
      return crossSigningKeys[id];
    }
    return null;
  }

  CrossSigningKey getCrossSigningKey(String type) => crossSigningKeys.values
      .firstWhere((k) => k.usage.contains(type), orElse: () => null);

  CrossSigningKey get masterKey => getCrossSigningKey('master');
  CrossSigningKey get selfSigningKey => getCrossSigningKey('self_signing');
  CrossSigningKey get userSigningKey => getCrossSigningKey('user_signing');

  UserVerifiedStatus get verified {
    if (masterKey == null) {
      return UserVerifiedStatus.unknown;
    }
    if (masterKey.verified) {
      for (final key in deviceKeys.values) {
        if (!key.verified) {
          return UserVerifiedStatus.unknownDevice;
        }
      }
      return UserVerifiedStatus.verified;
    }
    return UserVerifiedStatus.unknown;
  }

  Future<KeyVerification> startVerification() async {
    final roomId =
        await User(userId, room: Room(client: client)).startDirectChat();
    if (roomId == null) {
      throw 'Unable to start new room';
    }
    final room = client.getRoomById(roomId) ?? Room(id: roomId, client: client);
    final request = KeyVerification(
        encryption: client.encryption, room: room, userId: userId);
    await request.start();
    // no need to add to the request client object. As we are doing a room
    // verification request that'll happen automatically once we know the transaction id
    return request;
  }

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

  DeviceKeysList(this.userId, this.client);
}

abstract class SignableKey extends MatrixSignableKey {
  Client client;
  Map<String, dynamic> validSignatures;
  bool _verified;
  bool blocked;

  String get ed25519Key => keys['ed25519:$identifier'];
  bool get verified => (directVerified || crossVerified) && !blocked;

  void setDirectVerified(bool v) {
    _verified = v;
  }

  bool get directVerified => _verified;
  bool get crossVerified => hasValidSignatureChain();
  bool get signed => hasValidSignatureChain(verifiedOnly: false);

  SignableKey.fromJson(Map<String, dynamic> json, Client cl)
      : client = cl,
        super.fromJson(json) {
    _verified = false;
    blocked = false;
  }

  MatrixSignableKey cloneForSigning() {
    final newKey =
        MatrixSignableKey.fromJson(Map<String, dynamic>.from(toJson()));
    newKey.identifier = identifier;
    newKey.signatures ??= <String, Map<String, String>>{};
    newKey.signatures.clear();
    return newKey;
  }

  String get signingContent {
    final data = Map<String, dynamic>.from(super.toJson());
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
      olmutil.ed25519_verify(pubKey, signingContent, signature);
      valid = true;
    } catch (_) {
      // bad signature
      valid = false;
    } finally {
      olmutil.free();
    }
    return valid;
  }

  bool hasValidSignatureChain({bool verifiedOnly = true, Set<String> visited}) {
    if (!client.encryptionEnabled) {
      return false;
    }
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
        SignableKey key;
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

        if ((verifiedOnly && key.directVerified) ||
            (key is CrossSigningKey &&
                key.usage.contains('master') &&
                key.directVerified &&
                key.userId == client.userID)) {
          return true; // we verified this key and it is valid...all checks out!
        }
        // or else we just recurse into that key and chack if it works out
        final haveChain = key.hasValidSignatureChain(
            verifiedOnly: verifiedOnly, visited: visited);
        if (haveChain) {
          return true;
        }
      }
    }
    return false;
  }

  void setVerified(bool newVerified, [bool sign = true]) {
    _verified = newVerified;
    if (newVerified &&
        sign &&
        client.encryptionEnabled &&
        client.encryption.crossSigning.signable([this])) {
      // sign the key!
      client.encryption.crossSigning.sign([this]);
    }
  }

  Future<void> setBlocked(bool newBlocked);

  @override
  Map<String, dynamic> toJson() {
    final data = Map<String, dynamic>.from(super.toJson());
    // some old data may have the verified and blocked keys which are unneeded now
    data.remove('verified');
    data.remove('blocked');
    return data;
  }

  @override
  String toString() => json.encode(toJson());
}

class CrossSigningKey extends SignableKey {
  String get publicKey => identifier;
  List<String> usage;

  bool get isValid =>
      userId != null && publicKey != null && keys != null && ed25519Key != null;

  @override
  Future<void> setVerified(bool newVerified, [bool sign = true]) {
    super.setVerified(newVerified, sign);
    return client.database?.setVerifiedUserCrossSigningKey(
        newVerified, client.id, userId, publicKey);
  }

  @override
  Future<void> setBlocked(bool newBlocked) {
    blocked = newBlocked;
    return client.database?.setBlockedUserCrossSigningKey(
        newBlocked, client.id, userId, publicKey);
  }

  CrossSigningKey.fromMatrixCrossSigningKey(MatrixCrossSigningKey k, Client cl)
      : super.fromJson(Map<String, dynamic>.from(k.toJson()), cl) {
    final json = toJson();
    identifier = k.publicKey;
    usage = json['usage'].cast<String>();
  }

  CrossSigningKey.fromDb(DbUserCrossSigningKey dbEntry, Client cl)
      : super.fromJson(Event.getMapFromPayload(dbEntry.content), cl) {
    final json = toJson();
    identifier = dbEntry.publicKey;
    usage = json['usage'].cast<String>();
    _verified = dbEntry.verified;
    blocked = dbEntry.blocked;
  }

  CrossSigningKey.fromJson(Map<String, dynamic> json, Client cl)
      : super.fromJson(Map<String, dynamic>.from(json), cl) {
    final json = toJson();
    usage = json['usage'].cast<String>();
    if (keys != null && keys.isNotEmpty) {
      identifier = keys.values.first;
    }
  }
}

class DeviceKeys extends SignableKey {
  String get deviceId => identifier;
  List<String> algorithms;

  String get curve25519Key => keys['curve25519:$deviceId'];
  String get deviceDisplayName =>
      unsigned != null ? unsigned['device_display_name'] : null;

  bool get isValid =>
      userId != null &&
      deviceId != null &&
      keys != null &&
      curve25519Key != null &&
      ed25519Key != null;

  @override
  Future<void> setVerified(bool newVerified, [bool sign = true]) {
    super.setVerified(newVerified, sign);
    return client?.database
        ?.setVerifiedUserDeviceKey(newVerified, client.id, userId, deviceId);
  }

  @override
  Future<void> setBlocked(bool newBlocked) {
    blocked = newBlocked;
    return client?.database
        ?.setBlockedUserDeviceKey(newBlocked, client.id, userId, deviceId);
  }

  DeviceKeys.fromMatrixDeviceKeys(MatrixDeviceKeys k, Client cl)
      : super.fromJson(Map<String, dynamic>.from(k.toJson()), cl) {
    final json = toJson();
    identifier = k.deviceId;
    algorithms = json['algorithms'].cast<String>();
  }

  DeviceKeys.fromDb(DbUserDeviceKeysKey dbEntry, Client cl)
      : super.fromJson(Event.getMapFromPayload(dbEntry.content), cl) {
    final json = toJson();
    identifier = dbEntry.deviceId;
    algorithms = json['algorithms'].cast<String>();
    _verified = dbEntry.verified;
    blocked = dbEntry.blocked;
  }

  DeviceKeys.fromJson(Map<String, dynamic> json, Client cl)
      : super.fromJson(Map<String, dynamic>.from(json), cl) {
    final json = toJson();
    identifier = json['device_id'];
    algorithms = json['algorithms'].cast<String>();
  }

  KeyVerification startVerification() {
    final request = KeyVerification(
        encryption: client.encryption, userId: userId, deviceId: deviceId);

    request.start();
    client.encryption.keyVerificationManager.addRequest(request);
    return request;
  }
}
