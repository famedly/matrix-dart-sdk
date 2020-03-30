import 'dart:convert';

import 'package:famedlysdk/famedlysdk.dart';

class FakeStore implements StoreAPI {
  /// Whether this is a simple store which only stores the client credentials and
  /// end to end encryption stuff or the whole sync payloads.
  @override
  final bool extended = false;

  Map<String, dynamic> storeMap = {};

  /// Link back to the client.
  @override
  Client client;

  FakeStore(this.client, this.storeMap) {
    _init();
  }

  Future<void> _init() async {
    final credentialsStr = await getItem(client.clientName);

    if (credentialsStr == null || credentialsStr.isEmpty) {
      client.onLoginStateChanged.add(LoginState.loggedOut);
      return;
    }
    print('[Matrix] Restoring account credentials');
    final Map<String, dynamic> credentials = json.decode(credentialsStr);
    client.connect(
      newDeviceID: credentials['deviceID'],
      newDeviceName: credentials['deviceName'],
      newHomeserver: credentials['homeserver'],
      newLazyLoadMembers: credentials['lazyLoadMembers'],
      newMatrixVersions: List<String>.from(credentials['matrixVersions']),
      newToken: credentials['token'],
      newUserID: credentials['userID'],
      newPrevBatch: credentials['prev_batch'],
      newOlmAccount: credentials['olmAccount'],
    );
  }

  /// Will be automatically called when the client is logged in successfully.
  @override
  Future<void> storeClient() async {
    final credentials = {
      'deviceID': client.deviceID,
      'deviceName': client.deviceName,
      'homeserver': client.homeserver,
      'lazyLoadMembers': client.lazyLoadMembers,
      'matrixVersions': client.matrixVersions,
      'token': client.accessToken,
      'userID': client.userID,
      'olmAccount': client.pickledOlmAccount,
    };
    await setItem(client.clientName, json.encode(credentials));
    return;
  }

  /// Clears all tables from the database.
  @override
  Future<void> clear() async {
    storeMap = {};
    return;
  }

  @override
  Future<dynamic> getItem(String key) async {
    return storeMap[key];
  }

  @override
  Future<void> setItem(String key, String value) async {
    storeMap[key] = value;
    return;
  }

  String get _UserDeviceKeysKey => '${client.clientName}.user_device_keys';

  @override
  Future<Map<String, DeviceKeysList>> getUserDeviceKeys() async {
    final deviceKeysListString = await getItem(_UserDeviceKeysKey);
    if (deviceKeysListString == null) return {};
    Map<String, dynamic> rawUserDeviceKeys = json.decode(deviceKeysListString);
    var userDeviceKeys = <String, DeviceKeysList>{};
    for (final entry in rawUserDeviceKeys.entries) {
      userDeviceKeys[entry.key] = DeviceKeysList.fromJson(entry.value);
    }
    return userDeviceKeys;
  }

  @override
  Future<void> storeUserDeviceKeys(
      Map<String, DeviceKeysList> userDeviceKeys) async {
    await setItem(_UserDeviceKeysKey, json.encode(userDeviceKeys));
  }
}
