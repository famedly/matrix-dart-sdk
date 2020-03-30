import '../client.dart';

///  Registered device for this user.
class UserDevice {
  /// Identifier of this device.
  final String deviceId;

  /// Display name set by the user for this device. Absent if no name has been set.
  final String displayName;

  /// The IP address where this device was last seen. (May be a few minutes out of date, for efficiency reasons).
  final String lastSeenIp;

  ///  	The time when this devices was last seen. (May be a few minutes out of date, for efficiency reasons).
  final DateTime lastSeenTs;

  final Client _client;

  /// Updates the metadata on the given device.
  Future<void> updateMetaData(String newName) async {
    await _client.jsonRequest(
      type: HTTPType.PUT,
      action: '/client/r0/devices/$deviceId',
      data: {'display_name': newName},
    );
    return;
  }

  /// Deletes the given device, and invalidates any access token associated with it.
  Future<void> deleteDevice(Map<String, dynamic> auth) async {
    await _client.jsonRequest(
      type: HTTPType.DELETE,
      action: '/client/r0/devices/$deviceId',
      data: auth != null ? {'auth': auth} : null,
    );
    return;
  }

  UserDevice(
    this._client, {
    this.deviceId,
    this.displayName,
    this.lastSeenIp,
    this.lastSeenTs,
  });

  UserDevice.fromJson(Map<String, dynamic> json, Client client)
      : deviceId = json['device_id'],
        displayName = json['display_name'],
        lastSeenIp = json['last_seen_ip'],
        lastSeenTs =
            DateTime.fromMillisecondsSinceEpoch(json['last_seen_ts'] ?? 0),
        _client = client;
}
