import 'dart:convert';

import 'package:famedlysdk/matrix_api.dart';
import 'package:famedlysdk/encryption.dart';

import '../client.dart';
import '../database/database.dart' show DbUserDeviceKey, DbUserDeviceKeysKey;
import '../event.dart';

class DeviceKeysList {
  String userId;
  bool outdated = true;
  Map<String, DeviceKeys> deviceKeys = {};

  DeviceKeysList.fromDb(
      DbUserDeviceKey dbEntry, List<DbUserDeviceKeysKey> childEntries) {
    userId = dbEntry.userId;
    outdated = dbEntry.outdated;
    deviceKeys = {};
    for (final childEntry in childEntries) {
      final entry = DeviceKeys.fromDb(childEntry);
      if (entry.isValid) {
        deviceKeys[childEntry.deviceId] = entry;
      } else {
        outdated = true;
      }
    }
  }

  DeviceKeysList.fromJson(Map<String, dynamic> json) {
    userId = json['user_id'];
    outdated = json['outdated'];
    deviceKeys = {};
    for (final rawDeviceKeyEntry in json['device_keys'].entries) {
      deviceKeys[rawDeviceKeyEntry.key] =
          DeviceKeys.fromJson(rawDeviceKeyEntry.value);
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

class DeviceKeys extends MatrixDeviceKeys {
  bool verified;
  bool blocked;

  String get curve25519Key => keys['curve25519:$deviceId'];
  String get ed25519Key => keys['ed25519:$deviceId'];

  bool get isValid =>
      userId != null &&
      deviceId != null &&
      curve25519Key != null &&
      ed25519Key != null;

  Future<void> setVerified(bool newVerified, Client client) {
    verified = newVerified;
    return client.database
        ?.setVerifiedUserDeviceKey(newVerified, client.id, userId, deviceId);
  }

  Future<void> setBlocked(bool newBlocked, Client client) {
    blocked = newBlocked;
    return client.database
        ?.setBlockedUserDeviceKey(newBlocked, client.id, userId, deviceId);
  }

  DeviceKeys({
    String userId,
    String deviceId,
    List<String> algorithms,
    Map<String, String> keys,
    Map<String, Map<String, String>> signatures,
    Map<String, dynamic> unsigned,
    this.verified,
    this.blocked,
  }) : super(userId, deviceId, algorithms, keys, signatures,
            unsigned: unsigned);

  factory DeviceKeys.fromMatrixDeviceKeys(MatrixDeviceKeys matrixDeviceKeys) =>
      DeviceKeys(
        userId: matrixDeviceKeys.userId,
        deviceId: matrixDeviceKeys.deviceId,
        algorithms: matrixDeviceKeys.algorithms,
        keys: matrixDeviceKeys.keys,
        signatures: matrixDeviceKeys.signatures,
        unsigned: matrixDeviceKeys.unsigned,
        verified: false,
        blocked: false,
      );

  static DeviceKeys fromDb(DbUserDeviceKeysKey dbEntry) {
    var deviceKeys = DeviceKeys();
    final content = Event.getMapFromPayload(dbEntry.content);
    deviceKeys.userId = dbEntry.userId;
    deviceKeys.deviceId = dbEntry.deviceId;
    deviceKeys.algorithms = content['algorithms'].cast<String>();
    deviceKeys.keys = content['keys'] != null
        ? Map<String, String>.from(content['keys'])
        : null;
    deviceKeys.signatures = content['signatures'] != null
        ? Map<String, Map<String, String>>.from((content['signatures'] as Map)
            .map((k, v) => MapEntry(k, Map<String, String>.from(v))))
        : null;
    deviceKeys.unsigned = content['unsigned'] != null
        ? Map<String, dynamic>.from(content['unsigned'])
        : null;
    deviceKeys.verified = dbEntry.verified;
    deviceKeys.blocked = dbEntry.blocked;
    return deviceKeys;
  }

  static DeviceKeys fromJson(Map<String, dynamic> json) {
    var matrixDeviceKeys = MatrixDeviceKeys.fromJson(json);
    var deviceKeys = DeviceKeys(
      userId: matrixDeviceKeys.userId,
      deviceId: matrixDeviceKeys.deviceId,
      algorithms: matrixDeviceKeys.algorithms,
      keys: matrixDeviceKeys.keys,
      signatures: matrixDeviceKeys.signatures,
      unsigned: matrixDeviceKeys.unsigned,
    );
    deviceKeys.verified = json['verified'] ?? false;
    deviceKeys.blocked = json['blocked'] ?? false;
    return deviceKeys;
  }

  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson();
    data['verified'] = verified;
    data['blocked'] = blocked;
    return data;
  }

  KeyVerification startVerification(Client client) {
    final request = KeyVerification(
        encryption: client.encryption, userId: userId, deviceId: deviceId);
    request.start();
    client.encryption.keyVerificationManager.addRequest(request);
    return request;
  }
}
