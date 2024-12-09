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
import 'package:collection/collection.dart' show IterableExtension;
import 'package:olm/olm.dart' as olm;

import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';

enum UserVerifiedStatus { verified, unknown, unknownDevice }

class DeviceKeysList {
  Client client;
  String userId;
  bool outdated = true;
  Map<String, DeviceKeys> deviceKeys = {};
  Map<String, CrossSigningKey> crossSigningKeys = {};

  SignableKey? getKey(String id) => deviceKeys[id] ?? crossSigningKeys[id];

  CrossSigningKey? getCrossSigningKey(String type) => crossSigningKeys.values
      .firstWhereOrNull((key) => key.usage.contains(type));

  CrossSigningKey? get masterKey => getCrossSigningKey('master');
  CrossSigningKey? get selfSigningKey => getCrossSigningKey('self_signing');
  CrossSigningKey? get userSigningKey => getCrossSigningKey('user_signing');

  UserVerifiedStatus get verified {
    if (masterKey == null) {
      return UserVerifiedStatus.unknown;
    }
    if (masterKey!.verified) {
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

  /// Starts a verification with this device. This might need to create a new
  /// direct chat to send the verification request over this room. For this you
  /// can set parameters here.
  Future<KeyVerification> startVerification({
    bool? newDirectChatEnableEncryption,
    List<StateEvent>? newDirectChatInitialState,
  }) async {
    final encryption = client.encryption;
    if (encryption == null) {
      throw Exception('Encryption not enabled');
    }
    if (userId != client.userID) {
      // in-room verification with someone else
      final roomId = await client.startDirectChat(
        userId,
        enableEncryption: newDirectChatEnableEncryption,
        initialState: newDirectChatInitialState,
        waitForSync: false,
      );

      final room =
          client.getRoomById(roomId) ?? Room(id: roomId, client: client);
      final request =
          KeyVerification(encryption: encryption, room: room, userId: userId);
      await request.start();
      // no need to add to the request client object. As we are doing a room
      // verification request that'll happen automatically once we know the transaction id
      return request;
    } else {
      // start verification with verified devices
      final request = KeyVerification(
        encryption: encryption,
        userId: userId,
        deviceId: '*',
      );
      await request.start();
      encryption.keyVerificationManager.addRequest(request);
      return request;
    }
  }

  DeviceKeysList.fromDbJson(
    Map<String, dynamic> dbEntry,
    List<Map<String, dynamic>> childEntries,
    List<Map<String, dynamic>> crossSigningEntries,
    this.client,
  ) : userId = dbEntry['user_id'] ?? '' {
    outdated = dbEntry['outdated'];
    deviceKeys = {};
    for (final childEntry in childEntries) {
      try {
        final entry = DeviceKeys.fromDb(childEntry, client);
        if (!entry.isValid) throw Exception('Invalid device keys');
        deviceKeys[childEntry['device_id']] = entry;
      } catch (e, s) {
        Logs().w('Skipping invalid user device key', e, s);
        outdated = true;
      }
    }
    for (final crossSigningEntry in crossSigningEntries) {
      try {
        final entry = CrossSigningKey.fromDbJson(crossSigningEntry, client);
        if (!entry.isValid) throw Exception('Invalid device keys');
        crossSigningKeys[crossSigningEntry['public_key']] = entry;
      } catch (e, s) {
        Logs().w('Skipping invalid cross siging key', e, s);
        outdated = true;
      }
    }
  }

  DeviceKeysList(this.userId, this.client);
}

class SimpleSignableKey extends MatrixSignableKey {
  @override
  String? identifier;

  SimpleSignableKey.fromJson(Map<String, dynamic> super.json)
      : super.fromJson();
}

abstract class SignableKey extends MatrixSignableKey {
  Client client;
  Map<String, dynamic>? validSignatures;
  bool? _verified;
  bool? _blocked;

  String? get ed25519Key => keys['ed25519:$identifier'];
  bool get verified =>
      identifier != null && (directVerified || crossVerified) && !(blocked);
  bool get blocked => _blocked ?? false;
  set blocked(bool isBlocked) => _blocked = isBlocked;

  bool get encryptToDevice {
    if (blocked) return false;

    if (identifier == null || ed25519Key == null) return false;

    return client.shareKeysWithUnverifiedDevices || verified;
  }

  void setDirectVerified(bool isVerified) {
    _verified = isVerified;
  }

  bool get directVerified => _verified ?? false;
  bool get crossVerified => hasValidSignatureChain();
  bool get signed => hasValidSignatureChain(verifiedOnly: false);

  SignableKey.fromJson(Map<String, dynamic> super.json, this.client)
      : super.fromJson() {
    _verified = false;
    _blocked = false;
  }

  SimpleSignableKey cloneForSigning() {
    final newKey = SimpleSignableKey.fromJson(toJson().copy());
    newKey.identifier = identifier;
    (newKey.signatures ??= {}).clear();
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

  bool _verifySignature(
    String pubKey,
    String signature, {
    bool isSignatureWithoutLibolmValid = false,
  }) {
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

  bool hasValidSignatureChain({
    bool verifiedOnly = true,
    Set<String>? visited,
    Set<String>? onlyValidateUserIds,

    /// Only check if this key is verified by their Master key.
    bool verifiedByTheirMasterKey = false,
  }) {
    if (!client.encryptionEnabled) {
      return false;
    }

    final visited_ = visited ?? <String>{};
    final onlyValidateUserIds_ = onlyValidateUserIds ?? <String>{};

    final setKey = '$userId;$identifier';
    if (visited_.contains(setKey) ||
        (onlyValidateUserIds_.isNotEmpty &&
            !onlyValidateUserIds_.contains(userId))) {
      return false; // prevent recursion & validate hasValidSignatureChain
    }
    visited_.add(setKey);

    if (signatures == null) return false;

    for (final signatureEntries in signatures!.entries) {
      final otherUserId = signatureEntries.key;
      if (!client.userDeviceKeys.containsKey(otherUserId)) {
        continue;
      }
      // we don't allow transitive trust unless it is for ourself
      if (otherUserId != userId && otherUserId != client.userID) {
        continue;
      }
      for (final signatureEntry in signatureEntries.value.entries) {
        final fullKeyId = signatureEntry.key;
        final signature = signatureEntry.value;
        final keyId = fullKeyId.substring('ed25519:'.length);
        // we ignore self-signatures here
        if (otherUserId == userId && keyId == identifier) {
          continue;
        }

        final key = client.userDeviceKeys[otherUserId]?.deviceKeys[keyId] ??
            client.userDeviceKeys[otherUserId]?.crossSigningKeys[keyId];
        if (key == null) {
          continue;
        }

        if (onlyValidateUserIds_.isNotEmpty &&
            !onlyValidateUserIds_.contains(key.userId)) {
          // we don't want to verify keys from this user
          continue;
        }

        if (key.blocked) {
          continue; // we can't be bothered about this keys signatures
        }
        var haveValidSignature = false;
        var gotSignatureFromCache = false;
        final fullKeyIdBool = validSignatures
            ?.tryGetMap<String, Object?>(otherUserId)
            ?.tryGet<bool>(fullKeyId);
        if (fullKeyIdBool == true) {
          haveValidSignature = true;
          gotSignatureFromCache = true;
        } else if (fullKeyIdBool == false) {
          haveValidSignature = false;
          gotSignatureFromCache = true;
        }

        if (!gotSignatureFromCache && key.ed25519Key != null) {
          // validate the signature manually
          haveValidSignature = _verifySignature(key.ed25519Key!, signature);
          final validSignatures = this.validSignatures ??= <String, dynamic>{};
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
                (verifiedByTheirMasterKey ||
                    (key.directVerified && key.userId == client.userID)))) {
          return true; // we verified this key and it is valid...all checks out!
        }
        // or else we just recurse into that key and check if it works out
        final haveChain = key.hasValidSignatureChain(
          verifiedOnly: verifiedOnly,
          visited: visited_,
          onlyValidateUserIds: onlyValidateUserIds,
          verifiedByTheirMasterKey: verifiedByTheirMasterKey,
        );
        if (haveChain) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> setVerified(bool newVerified, [bool sign = true]) async {
    _verified = newVerified;
    final encryption = client.encryption;
    if (newVerified &&
        sign &&
        encryption != null &&
        client.encryptionEnabled &&
        encryption.crossSigning.signable([this])) {
      // sign the key!
      // ignore: unawaited_futures
      encryption.crossSigning.sign([this]);
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

  @override
  bool operator ==(Object other) => (other is SignableKey &&
      other.userId == userId &&
      other.identifier == identifier);

  @override
  int get hashCode => Object.hash(userId, identifier);
}

class CrossSigningKey extends SignableKey {
  @override
  String? identifier;

  String? get publicKey => identifier;
  late List<String> usage;

  bool get isValid =>
      userId.isNotEmpty &&
      publicKey != null &&
      keys.isNotEmpty &&
      ed25519Key != null;

  @override
  Future<void> setVerified(bool newVerified, [bool sign = true]) async {
    if (!isValid) {
      throw Exception('setVerified called on invalid key');
    }
    await super.setVerified(newVerified, sign);
    await client.database
        ?.setVerifiedUserCrossSigningKey(newVerified, userId, publicKey!);
  }

  @override
  Future<void> setBlocked(bool newBlocked) async {
    if (!isValid) {
      throw Exception('setBlocked called on invalid key');
    }
    _blocked = newBlocked;
    await client.database
        ?.setBlockedUserCrossSigningKey(newBlocked, userId, publicKey!);
  }

  CrossSigningKey.fromMatrixCrossSigningKey(
    MatrixCrossSigningKey key,
    Client client,
  ) : super.fromJson(key.toJson().copy(), client) {
    final json = toJson();
    identifier = key.publicKey;
    usage = json['usage'].cast<String>();
  }

  CrossSigningKey.fromDbJson(Map<String, dynamic> dbEntry, Client client)
      : super.fromJson(Event.getMapFromPayload(dbEntry['content']), client) {
    final json = toJson();
    identifier = dbEntry['public_key'];
    usage = json['usage'].cast<String>();
    _verified = dbEntry['verified'];
    _blocked = dbEntry['blocked'];
  }

  CrossSigningKey.fromJson(Map<String, dynamic> json, Client client)
      : super.fromJson(json.copy(), client) {
    final json = toJson();
    usage = json['usage'].cast<String>();
    if (keys.isNotEmpty) {
      identifier = keys.values.first;
    }
  }
}

class DeviceKeys extends SignableKey {
  @override
  String? identifier;

  String? get deviceId => identifier;
  late List<String> algorithms;
  late DateTime lastActive;

  String? get curve25519Key => keys['curve25519:$deviceId'];
  String? get deviceDisplayName =>
      unsigned?.tryGet<String>('device_display_name');

  bool? _validSelfSignature;
  bool get selfSigned =>
      _validSelfSignature ??
      (_validSelfSignature = deviceId != null &&
          signatures
                  ?.tryGetMap<String, Object?>(userId)
                  ?.tryGet<String>('ed25519:$deviceId') !=
              null &&
          // without libolm we still want to be able to add devices. In that case we ofc just can't
          // verify the signature
          _verifySignature(
            ed25519Key!,
            signatures![userId]!['ed25519:$deviceId']!,
            isSignatureWithoutLibolmValid: true,
          ));

  @override
  bool get blocked => super.blocked || !selfSigned;

  bool get isValid =>
      deviceId != null &&
      keys.isNotEmpty &&
      curve25519Key != null &&
      ed25519Key != null &&
      selfSigned;

  @override
  Future<void> setVerified(bool newVerified, [bool sign = true]) async {
    if (!isValid) {
      //throw Exception('setVerified called on invalid key');
      return;
    }
    await super.setVerified(newVerified, sign);
    await client.database
        ?.setVerifiedUserDeviceKey(newVerified, userId, deviceId!);
  }

  @override
  Future<void> setBlocked(bool newBlocked) async {
    if (!isValid) {
      //throw Exception('setBlocked called on invalid key');
      return;
    }
    _blocked = newBlocked;
    await client.database
        ?.setBlockedUserDeviceKey(newBlocked, userId, deviceId!);
  }

  DeviceKeys.fromMatrixDeviceKeys(
    MatrixDeviceKeys keys,
    Client client, [
    DateTime? lastActiveTs,
  ]) : super.fromJson(keys.toJson().copy(), client) {
    final json = toJson();
    identifier = keys.deviceId;
    algorithms = json['algorithms'].cast<String>();
    lastActive = lastActiveTs ?? DateTime.now();
  }

  DeviceKeys.fromDb(Map<String, dynamic> dbEntry, Client client)
      : super.fromJson(Event.getMapFromPayload(dbEntry['content']), client) {
    final json = toJson();
    identifier = dbEntry['device_id'];
    algorithms = json['algorithms'].cast<String>();
    _verified = dbEntry['verified'];
    _blocked = dbEntry['blocked'];
    lastActive =
        DateTime.fromMillisecondsSinceEpoch(dbEntry['last_active'] ?? 0);
  }

  DeviceKeys.fromJson(Map<String, dynamic> json, Client client)
      : super.fromJson(json.copy(), client) {
    final json = toJson();
    identifier = json['device_id'];
    algorithms = json['algorithms'].cast<String>();
    lastActive = DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<KeyVerification> startVerification() async {
    if (!isValid) {
      throw Exception('setVerification called on invalid key');
    }
    final encryption = client.encryption;
    if (encryption == null) {
      throw Exception('setVerification called with disabled encryption');
    }

    final request = KeyVerification(
      encryption: encryption,
      userId: userId,
      deviceId: deviceId!,
    );

    await request.start();
    encryption.keyVerificationManager.addRequest(request);
    return request;
  }
}
