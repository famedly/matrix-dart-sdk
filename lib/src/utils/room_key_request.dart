import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/src/utils/session_key.dart';

class RoomKeyRequest extends ToDeviceEvent {
  Client client;
  RoomKeyRequest.fromToDeviceEvent(ToDeviceEvent toDeviceEvent, Client client) {
    this.client = client;
    this.sender = toDeviceEvent.sender;
    this.content = toDeviceEvent.content;
    this.type = toDeviceEvent.type;
  }

  Room get room => client.getRoomById(this.content["body"]["room_id"]);

  DeviceKeys get requestingDevice =>
      client.userDeviceKeys[sender].deviceKeys[content["requesting_device_id"]];

  Future<void> forwardKey() async {
    Room room = this.room;
    final SessionKey session =
        room.sessionKeys[this.content["body"]["session_id"]];
    List<dynamic> forwardedKeys = [client.identityKey];
    for (final key in session.forwardingCurve25519KeyChain) {
      forwardedKeys.add(key);
    }
    await requestingDevice.setVerified(true, client);
    Map<String, dynamic> message = session.content;
    message["forwarding_curve25519_key_chain"] = forwardedKeys;
    message["session_key"] = session.inboundGroupSession.export_session(0);
    await client.sendToDevice(
      [requestingDevice],
      "m.forwarded_room_key",
      message,
    );
  }
}
