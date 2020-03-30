import 'package:famedlysdk/famedlysdk.dart';

class RoomKeyRequest extends ToDeviceEvent {
  Client client;
  RoomKeyRequest.fromToDeviceEvent(ToDeviceEvent toDeviceEvent, Client client) {
    this.client = client;
    sender = toDeviceEvent.sender;
    content = toDeviceEvent.content;
    type = toDeviceEvent.type;
  }

  Room get room => client.getRoomById(content['body']['room_id']);

  DeviceKeys get requestingDevice =>
      client.userDeviceKeys[sender].deviceKeys[content['requesting_device_id']];

  Future<void> forwardKey() async {
    var room = this.room;
    final session = room.sessionKeys[content['body']['session_id']];
    var forwardedKeys = <dynamic>[client.identityKey];
    for (final key in session.forwardingCurve25519KeyChain) {
      forwardedKeys.add(key);
    }
    await requestingDevice.setVerified(true, client);
    var message = session.content;
    message['forwarding_curve25519_key_chain'] = forwardedKeys;
    message['session_key'] = session.inboundGroupSession.export_session(0);
    await client.sendToDevice(
      [requestingDevice],
      'm.forwarded_room_key',
      message,
    );
  }
}
