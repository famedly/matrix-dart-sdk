import 'dart:convert';

import '../client.dart';

class DeviceKeysList {
  String userId;
  bool outdated = true;
  Map<String, DeviceKeys> deviceKeys = {};

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
    final Map<String, dynamic> data = Map<String, dynamic>();
    data['user_id'] = this.userId;
    data['outdated'] = this.outdated;

    Map<String, dynamic> rawDeviceKeys = {};
    for (final deviceKeyEntry in this.deviceKeys.entries) {
      rawDeviceKeys[deviceKeyEntry.key] = deviceKeyEntry.value.toJson();
    }
    data['device_keys'] = rawDeviceKeys;
    return data;
  }

  String toString() => json.encode(toJson());

  DeviceKeysList(this.userId);
}

class DeviceKeys {
  String userId;
  String deviceId;
  List<String> algorithms;
  Map<String, String> keys;
  Map<String, dynamic> signatures;
  Map<String, dynamic> unsigned;
  bool verified;
  bool blocked;

  Future<void> setVerified(bool newVerified, Client client) {
    verified = newVerified;
    return client.storeAPI.storeUserDeviceKeys(client.userDeviceKeys);
  }

  Future<void> setBlocked(bool newBlocked, Client client) {
    blocked = newBlocked;
    return client.storeAPI.storeUserDeviceKeys(client.userDeviceKeys);
  }

  DeviceKeys({
    this.userId,
    this.deviceId,
    this.algorithms,
    this.keys,
    this.signatures,
    this.unsigned,
    this.verified,
    this.blocked,
  });

  DeviceKeys.fromJson(Map<String, dynamic> json) {
    userId = json['user_id'];
    deviceId = json['device_id'];
    algorithms = json['algorithms'].cast<String>();
    keys = json['keys'] != null ? Map<String, String>.from(json['keys']) : null;
    signatures = json['signatures'] != null
        ? Map<String, dynamic>.from(json['signatures'])
        : null;
    unsigned = json['unsigned'] != null
        ? Map<String, dynamic>.from(json['unsigned'])
        : null;
    verified = json['verified'] ?? false;
    blocked = json['blocked'] ?? false;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    data['user_id'] = this.userId;
    data['device_id'] = this.deviceId;
    data['algorithms'] = this.algorithms;
    if (this.keys != null) {
      data['keys'] = this.keys;
    }
    if (this.signatures != null) {
      data['signatures'] = this.signatures;
    }
    if (this.unsigned != null) {
      data['unsigned'] = this.unsigned;
    }
    data['verified'] = this.verified;
    data['blocked'] = this.blocked;
    return data;
  }
}
