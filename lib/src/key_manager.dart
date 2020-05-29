import 'client.dart';
import 'room.dart';
import 'utils/to_device_event.dart';
import 'utils/device_keys_list.dart';

class KeyManager {
  final Client client;
  final outgoingShareRequests = <String, KeyManagerKeyShareRequest>{};
  final incomingShareRequests = <String, KeyManagerKeyShareRequest>{};

  KeyManager(this.client);

  /// Request a certain key from another device
  Future<void> request(Room room, String sessionId, String senderKey) async {
    // while we just send the to-device event to '*', we still need to save the
    // devices themself to know where to send the cancel to after receiving a reply
    final devices = await room.getUserDeviceKeys();
    final requestId = client.generateUniqueTransactionId();
    final request = KeyManagerKeyShareRequest(
      requestId: requestId,
      devices: devices,
      room: room,
      sessionId: sessionId,
      senderKey: senderKey,
    );
    await client.sendToDevice(
        [],
        'm.room_key_request',
        {
          'action': 'request',
          'body': {
            'algorithm': 'm.megolm.v1.aes-sha2',
            'room_id': room.id,
            'sender_key': senderKey,
            'session_id': sessionId,
          },
          'request_id': requestId,
          'requesting_device_id': client.deviceID,
        },
        encrypted: false,
        toUsers: await room.requestParticipants());
    outgoingShareRequests[request.requestId] = request;
  }

  /// Handle an incoming to_device event that is related to key sharing
  Future<void> handleToDeviceEvent(ToDeviceEvent event) async {
    if (event.type == 'm.room_key_request') {
      if (!event.content.containsKey('request_id')) {
        return; // invalid event
      }
      if (event.content['action'] == 'request') {
        // we are *receiving* a request
        if (!event.content.containsKey('body')) {
          return; // no body
        }
        if (!client.userDeviceKeys.containsKey(event.sender) ||
            !client.userDeviceKeys[event.sender].deviceKeys
                .containsKey(event.content['requesting_device_id'])) {
          return; // device not found
        }
        final device = client.userDeviceKeys[event.sender]
            .deviceKeys[event.content['requesting_device_id']];
        if (device.userId == client.userID &&
            device.deviceId == client.deviceID) {
          return; // ignore requests by ourself
        }
        final room = client.getRoomById(event.content['body']['room_id']);
        if (room == null) {
          return; // unknown room
        }
        final sessionId = event.content['body']['session_id'];
        // okay, let's see if we have this session at all
        await room.loadInboundGroupSessionKey(sessionId);
        if (!room.inboundGroupSessions.containsKey(sessionId)) {
          return; // we don't have this session anyways
        }
        final request = KeyManagerKeyShareRequest(
          requestId: event.content['request_id'],
          devices: [device],
          room: room,
          sessionId: event.content['body']['session_id'],
          senderKey: event.content['body']['sender_key'],
        );
        if (incomingShareRequests.containsKey(request.requestId)) {
          return; // we don't want to process one and the same request multiple times
        }
        incomingShareRequests[request.requestId] = request;
        final roomKeyRequest =
            RoomKeyRequest.fromToDeviceEvent(event, this, request);
        if (device.userId == client.userID &&
            device.verified &&
            !device.blocked) {
          // alright, we can forward the key
          await roomKeyRequest.forwardKey();
        } else {
          client.onRoomKeyRequest
              .add(roomKeyRequest); // let the client handle this
        }
      } else if (event.content['action'] == 'request_cancellation') {
        // we got told to cancel an incoming request
        if (!incomingShareRequests.containsKey(event.content['request_id'])) {
          return; // we don't know this request anyways
        }
        // alright, let's just cancel this request
        final request = incomingShareRequests[event.content['request_id']];
        request.canceled = true;
        incomingShareRequests.remove(request.requestId);
      }
    } else if (event.type == 'm.forwarded_room_key') {
      // we *received* an incoming key request
      if (event.encryptedContent == null) {
        return; // event wasn't encrypted, this is a security risk
      }
      final request = outgoingShareRequests.values.firstWhere(
          (r) =>
              r.room.id == event.content['room_id'] &&
              r.sessionId == event.content['session_id'] &&
              r.senderKey == event.content['sender_key'],
          orElse: () => null);
      if (request == null || request.canceled) {
        return; // no associated request found or it got canceled
      }
      final device = request.devices.firstWhere(
          (d) =>
              d.userId == event.sender &&
              d.curve25519Key == event.encryptedContent['sender_key'],
          orElse: () => null);
      if (device == null) {
        return; // someone we didn't send our request to replied....better ignore this
      }
      // TODO: verify that the keys work to decrypt a message
      // alright, all checks out, let's go ahead and store this session
      request.room.setInboundGroupSession(request.sessionId, event.content,
          forwarded: true);
      request.devices.removeWhere(
          (k) => k.userId == device.userId && k.deviceId == device.deviceId);
      outgoingShareRequests.remove(request.requestId);
      // send cancel to all other devices
      if (request.devices.isEmpty) {
        return; // no need to send any cancellation
      }
      await client.sendToDevice(
          request.devices,
          'm.room_key_request',
          {
            'action': 'request_cancellation',
            'request_id': request.requestId,
            'requesting_device_id': client.deviceID,
          },
          encrypted: false);
    }
  }
}

class KeyManagerKeyShareRequest {
  final String requestId;
  final List<DeviceKeys> devices;
  final Room room;
  final String sessionId;
  final String senderKey;
  bool canceled;

  KeyManagerKeyShareRequest(
      {this.requestId,
      this.devices,
      this.room,
      this.sessionId,
      this.senderKey,
      this.canceled = false});
}

class RoomKeyRequest extends ToDeviceEvent {
  KeyManager keyManager;
  KeyManagerKeyShareRequest request;
  RoomKeyRequest.fromToDeviceEvent(ToDeviceEvent toDeviceEvent,
      KeyManager keyManager, KeyManagerKeyShareRequest request) {
    this.keyManager = keyManager;
    this.request = request;
    sender = toDeviceEvent.sender;
    content = toDeviceEvent.content;
    type = toDeviceEvent.type;
  }

  Room get room => request.room;

  DeviceKeys get requestingDevice => request.devices.first;

  Future<void> forwardKey() async {
    if (request.canceled) {
      keyManager.incomingShareRequests.remove(request.requestId);
      return; // request is canceled, don't send anything
    }
    var room = this.room;
    await room.loadInboundGroupSessionKey(request.sessionId);
    final session = room.inboundGroupSessions[request.sessionId];
    var forwardedKeys = <dynamic>[keyManager.client.identityKey];
    for (final key in session.forwardingCurve25519KeyChain) {
      forwardedKeys.add(key);
    }
    var message = session.content;
    message['forwarding_curve25519_key_chain'] = forwardedKeys;

    message['session_key'] = session.inboundGroupSession
        .export_session(session.inboundGroupSession.first_known_index());
    // send the actual reply of the key back to the requester
    await keyManager.client.sendToDevice(
      [requestingDevice],
      'm.forwarded_room_key',
      message,
    );
    keyManager.incomingShareRequests.remove(request.requestId);
  }
}
