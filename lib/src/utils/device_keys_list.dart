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

import 'package:canonical_json/canonical_json.dart';
import 'package:matrix/matrix.dart';
import 'package:olm/olm.dart' as olm;

import '../../encryption.dart';

import '../client.dart';
import '../event.dart';
import '../room.dart';
import '../user.dart';

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
    } else {
      for (final key in deviceKeys.values) {
        if (!key.verified) {
          return UserVerifiedStatus.unknown;
        }
      }
      return UserVerifiedStatus.verified;
    }
  }

  Future<KeyVerification> startVerification() async {
    if (userId != client.userID) {
      // in-room verification with someone else
      final roomId =
          await User(userId, room: Room(client: client)).startDirectChat();
      if (roomId == null) {
        throw Exception('Unable to start new room');
      }
      final room =
          client.getRoomById(roomId) ?? Room(id: roomId, client: client);
      final request = KeyVerification(
          encryption: client.encryption, room: room, userId: userId);
      await request.start();
      // no need to add to the request client object. As we are doing a room
      // verification request that'll happen automatically once we know the transaction id
      return request;
    } else {
      // broadcast self-verification
      final request = KeyVerification(
          encryption: client.encryption, userId: userId, deviceId: '*');
      await request.start();
      client.encryption.keyVerificationManager.addRequest(request);
      return request;
    }
  }

  DeviceKeysList.fromDbJson(
      Map<String, dynamic> dbEntry,
      List<Map<String, dynamic>> childEntries,
      List<Map<String, dynamic>> crossSigningEntries,
      Client cl) {
    client = cl;
    userId = dbEntry['user_id'];
    outdated = dbEntry['outdated'];
    deviceKeys = {};
    for (final childEntry in childEntries) {
      final entry = DeviceKeys.fromDb(childEntry, client);
      if (entry.isValid) {
        deviceKeys[childEntry['device_id']] = entry;
      } else {
        outdated = true;
      }
    }
    for (final crossSigningEntry in crossSigningEntries) {
      final entry = CrossSigningKey.fromDbJson(crossSigningEntry, client);
      if (entry.isValid) {
        crossSigningKeys[crossSigningEntry['public_key']] = entry;
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
  bool get encryptToDevice =>
      !blocked &&
      (client.userDeviceKeys[userId]?.masterKey?.verified ?? false
          ? verified
          : true);

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
    final newKey = MatrixSignableKey.fromJson(toJson().copy());
    newKey.identifier = identifier;
    newKey.signatures ??= <String, Map<String, String>>{};
    newKey.signatures.clear();
    return newKey;
  }

  String get signingContent {
    final data = super.toJson().copy();
    // some old data might have the custom verified and blocked keys
    data.remove('verified');
    data.remove('blocked');
    // remove the keys not needed for signing
    data.remove('unsigned');
    data.remove('signatures');
    return String.fromCharCodes(canonicalJson.encode(data));
  }

  bool _verifySignature(String pubKey, String signature,
      {bool isSignatureWithoutLibolmValid = false}) {
    olm.Utility olmutil;
    try {
      olmutil = olm.Utility();
    } catch (e) {
      // if no libolm is present we land in this catch block, and return the default
      // set if no libolm is there. Some signatures should be assumed-valid while others
      // should be assumed-invalid
      return isSignatureWithoutLibolmValid;
    }
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

  bool hasValidSignatureChain(
      {bool verifiedOnly = true,
      Set<String> visited,
      Set<String> onlyValidateUserIds}) {
    if (!client.encryptionEnabled) {
      return false;
    }
    visited ??= <String>{};
    onlyValidateUserIds ??= <String>{};
    final setKey = '$userId;$identifier';
    if (visited.contains(setKey) ||
        (onlyValidateUserIds.isNotEmpty &&
            !onlyValidateUserIds.contains(userId))) {
      return false; // prevent recursion & validate hasValidSignatureChain
    }
    visited.add(setKey);
    if (signatures == null) return false;
    for (final signatureEntries in signatures.entries) {
      final otherUserId = signatureEntries.key;
      if (!(signatureEntries.value is Map) ||
          !client.userDeviceKeys.containsKey(otherUserId)) {
        continue;
      }
      // we don't allow transitive trust unless it is for ourself
      if (otherUserId != userId && otherUserId != client.userID) {
        continue;
      }
      for (final signatureEntry in signatureEntries.value.entries) {
        final fullKeyId = signatureEntry.key;
        final signature = signatureEntry.value;
        if (!(fullKeyId is String) || !(signature is String)) {
          continue;
        }
        final keyId = fullKeyId.substring('ed25519:'.length);
        // we ignore self-signatures here
        if (otherUserId == userId && keyId == identifier) {
          continue;
        }
        SignableKey key;
        if (client.userDeviceKeys[otherUserId].deviceKeys.containsKey(keyId)) {
          key = client.userDeviceKeys[otherUserId].deviceKeys[keyId];
        } else if (client.userDeviceKeys[otherUserId].crossSigningKeys
            .containsKey(keyId)) {
          key = client.userDeviceKeys[otherUserId].crossSigningKeys[keyId];
        } else {
          continue;
        }

        if (onlyValidateUserIds.isNotEmpty &&
            !onlyValidateUserIds.contains(key.userId)) {
          // we don't want to verify keys from this user
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
            verifiedOnly: verifiedOnly,
            visited: visited,
            onlyValidateUserIds: onlyValidateUserIds);
        if (haveChain) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> setVerified(bool newVerified, [bool sign = true]) async {
    _verified = newVerified;
    if (newVerified &&
        sign &&
        client.encryptionEnabled &&
        client.encryption.crossSigning.signable([this])) {
      // sign the key!
      // ignore: unawaited_futures
      client.encryption.crossSigning.sign([this]);
    }
  }

  Future<void> setBlocked(bool newBlocked);

  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson().copy();
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
  Future<void> setVerified(bool newVerified, [bool sign = true]) async {
    await super.setVerified(newVerified, sign);
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
      : super.fromJson(k.toJson().copy(), cl) {
    final json = toJson();
    identifier = k.publicKey;
    usage = json['usage'].cast<String>();
  }

  CrossSigningKey.fromDbJson(Map<String, dynamic> dbEntry, Client cl)
      : super.fromJson(Event.getMapFromPayload(dbEntry['content']), cl) {
    final json = toJson();
    identifier = dbEntry['public_key'];
    usage = json['usage'].cast<String>();
    _verified = dbEntry['verified'];
    blocked = dbEntry['blocked'];
  }

  CrossSigningKey.fromJson(Map<String, dynamic> json, Client cl)
      : super.fromJson(json.copy(), cl) {
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
  DateTime lastActive;

  String get curve25519Key => keys['curve25519:$deviceId'];
  String get deviceDisplayName =>
      unsigned != null ? unsigned['device_display_name'] : null;

  bool _validSelfSignature;
  bool get selfSigned =>
      _validSelfSignature ??
      (_validSelfSignature = (signatures
                  ?.tryGet<Map<String, dynamic>>(userId)
                  ?.tryGet<String>('ed25519:$deviceId') ==
              null
          ? false
          // without libolm we still want to be able to add devices. In that case we ofc just can't
          // verify the signature
          : _verifySignature(
              ed25519Key, signatures[userId]['ed25519:$deviceId'],
              isSignatureWithoutLibolmValid: true)));

  @override
  bool get blocked => super.blocked || !selfSigned;

  bool get isValid =>
      userId != null &&
      deviceId != null &&
      keys != null &&
      curve25519Key != null &&
      ed25519Key != null &&
      selfSigned;

  @override
  Future<void> setVerified(bool newVerified, [bool sign = true]) async {
    await super.setVerified(newVerified, sign);
    return client?.database
        ?.setVerifiedUserDeviceKey(newVerified, client.id, userId, deviceId);
  }

  @override
  Future<void> setBlocked(bool newBlocked) {
    blocked = newBlocked;
    return client?.database
        ?.setBlockedUserDeviceKey(newBlocked, client.id, userId, deviceId);
  }

  DeviceKeys.fromMatrixDeviceKeys(MatrixDeviceKeys k, Client cl,
      [DateTime lastActiveTs])
      : super.fromJson(k.toJson().copy(), cl) {
    final json = toJson();
    identifier = k.deviceId;
    algorithms = json['algorithms'].cast<String>();
    lastActive = lastActiveTs ?? DateTime.now();
  }

  DeviceKeys.fromDb(Map<String, dynamic> dbEntry, Client cl)
      : super.fromJson(Event.getMapFromPayload(dbEntry['content']), cl) {
    final json = toJson();
    identifier = dbEntry['device_id'];
    algorithms = json['algorithms'].cast<String>();
    _verified = dbEntry['verified'];
    blocked = dbEntry['blocked'];
    lastActive =
        DateTime.fromMillisecondsSinceEpoch(dbEntry['last_active'] ?? 0);
  }

  DeviceKeys.fromJson(Map<String, dynamic> json, Client cl)
      : super.fromJson(json.copy(), cl) {
    final json = toJson();
    identifier = json['device_id'];
    algorithms = json['algorithms'].cast<String>();
    lastActive = DateTime.fromMillisecondsSinceEpoch(0);
  }

  KeyVerification startVerification() {
    final request = KeyVerification(
        encryption: client.encryption, userId: userId, deviceId: deviceId);

    request.start();
    client.encryption.keyVerificationManager.addRequest(request);
    return request;
  }
}
