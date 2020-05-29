/*
 * Copyright (c) 2019 Zender & Kurtz GbR.
 *
 * Authors:
 *   Christian Pauly <krille@famedly.com>
 *   Marcel Radzio <mtrnord@famedly.com>
 *
 * This file is part of famedlysdk.
 *
 * famedlysdk is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * famedlysdk is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with famedlysdk.  If not, see <http://www.gnu.org/licenses/>.
 */

import 'dart:convert';
import 'package:famedlysdk/famedlysdk.dart';
import 'package:test/test.dart';

import 'fake_matrix_api.dart';
import 'fake_database.dart';

Map<String, dynamic> jsonDecode(dynamic payload) {
  if (payload is String) {
    try {
      return json.decode(payload);
    } catch (e) {
      return {};
    }
  }
  if (payload is Map<String, dynamic>) return payload;
  return {};
}

void main() {
  /// All Tests related to device keys
  test('fromJson', () async {
    var rawJson = <String, dynamic>{
      'content': {
        'action': 'request',
        'body': {
          'algorithm': 'm.megolm.v1.aes-sha2',
          'room_id': '!726s6s6q:example.com',
          'sender_key': 'RF3s+E7RkTQTGF2d8Deol0FkQvgII2aJDf3/Jp5mxVU',
          'session_id': 'X3lUlvLELLYxeTx4yOVu6UDpasGEVO0Jbu+QFnm0cKQ'
        },
        'request_id': '1495474790150.19',
        'requesting_device_id': 'JLAFKJWSCS'
      },
      'type': 'm.room_key_request',
      'sender': '@alice:example.com'
    };
    var toDeviceEvent = ToDeviceEvent.fromJson(rawJson);
    expect(toDeviceEvent.content, rawJson['content']);
    expect(toDeviceEvent.sender, rawJson['sender']);
    expect(toDeviceEvent.type, rawJson['type']);

    var matrix = Client('testclient', debug: true);
    matrix.httpClient = FakeMatrixApi();
    matrix.database = getDatabase();
    await matrix.checkServer('https://fakeServer.notExisting');
    await matrix.login('test', '1234');
    var room = matrix.getRoomById('!726s6s6q:example.com');
    if (matrix.encryptionEnabled) {
      await room.createOutboundGroupSession();
      rawJson['content']['body']['session_id'] =
          room.inboundGroupSessions.keys.first;

      var roomKeyRequest = RoomKeyRequest.fromToDeviceEvent(
          ToDeviceEvent.fromJson(rawJson),
          matrix.keyManager,
          KeyManagerKeyShareRequest(
            room: room,
            sessionId: rawJson['content']['body']['session_id'],
            senderKey: rawJson['content']['body']['sender_key'],
            devices: [
              matrix.userDeviceKeys[rawJson['sender']]
                  .deviceKeys[rawJson['content']['requesting_device_id']]
            ],
          ));
      await roomKeyRequest.forwardKey();
    }
    await matrix.dispose(closeDatabase: true);
  });
  test('Create Request', () async {
    var matrix = Client('testclient', debug: true);
    matrix.httpClient = FakeMatrixApi();
    matrix.database = getDatabase();
    await matrix.checkServer('https://fakeServer.notExisting');
    await matrix.login('test', '1234');
    if (!matrix.encryptionEnabled) {
      await matrix.dispose(closeDatabase: true);
      return;
    }
    final requestRoom = matrix.getRoomById('!726s6s6q:example.com');
    await matrix.keyManager.request(requestRoom, 'sessionId', 'senderKey');
    var foundEvent = false;
    for (var entry in FakeMatrixApi.calledEndpoints.entries) {
      final payload = jsonDecode(entry.value.first);
      if (entry.key.startsWith('/client/r0/sendToDevice/m.room_key_request') &&
          (payload['messages'] is Map) &&
          (payload['messages']['@alice:example.com'] is Map) &&
          (payload['messages']['@alice:example.com']['*'] is Map)) {
        final content = payload['messages']['@alice:example.com']['*'];
        if (content['action'] == 'request' &&
            content['body']['room_id'] == '!726s6s6q:example.com' &&
            content['body']['sender_key'] == 'senderKey' &&
            content['body']['session_id'] == 'sessionId') {
          foundEvent = true;
          break;
        }
      }
    }
    expect(foundEvent, true);
    await matrix.dispose(closeDatabase: true);
  });
  final validSessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
  test('Reply To Request', () async {
    var matrix = Client('testclient', debug: true);
    matrix.httpClient = FakeMatrixApi();
    matrix.database = getDatabase();
    await matrix.checkServer('https://fakeServer.notExisting');
    await matrix.login('test', '1234');
    if (!matrix.encryptionEnabled) {
      await matrix.dispose(closeDatabase: true);
      return;
    }
    matrix.setUserId('@alice:example.com'); // we need to pretend to be alice
    FakeMatrixApi.calledEndpoints.clear();
    await matrix.userDeviceKeys['@alice:example.com'].deviceKeys['OTHERDEVICE']
        .setVerified(true);
    // test a successful share
    var event = ToDeviceEvent(
        sender: '@alice:example.com',
        type: 'm.room_key_request',
        content: {
          'action': 'request',
          'body': {
            'algorithm': 'm.megolm.v1.aes-sha2',
            'room_id': '!726s6s6q:example.com',
            'sender_key': 'senderKey',
            'session_id': validSessionId,
          },
          'request_id': 'request_1',
          'requesting_device_id': 'OTHERDEVICE',
        });
    await matrix.keyManager.handleToDeviceEvent(event);
    expect(
        FakeMatrixApi.calledEndpoints.keys.any(
            (k) => k.startsWith('/client/r0/sendToDevice/m.room.encrypted')),
        true);

    // test various fail scenarios

    // no body
    FakeMatrixApi.calledEndpoints.clear();
    event = ToDeviceEvent(
        sender: '@alice:example.com',
        type: 'm.room_key_request',
        content: {
          'action': 'request',
          'request_id': 'request_2',
          'requesting_device_id': 'OTHERDEVICE',
        });
    await matrix.keyManager.handleToDeviceEvent(event);
    expect(
        FakeMatrixApi.calledEndpoints.keys.any(
            (k) => k.startsWith('/client/r0/sendToDevice/m.room.encrypted')),
        false);

    // request by ourself
    FakeMatrixApi.calledEndpoints.clear();
    event = ToDeviceEvent(
        sender: '@alice:example.com',
        type: 'm.room_key_request',
        content: {
          'action': 'request',
          'body': {
            'algorithm': 'm.megolm.v1.aes-sha2',
            'room_id': '!726s6s6q:example.com',
            'sender_key': 'senderKey',
            'session_id': validSessionId,
          },
          'request_id': 'request_3',
          'requesting_device_id': 'JLAFKJWSCS',
        });
    await matrix.keyManager.handleToDeviceEvent(event);
    expect(
        FakeMatrixApi.calledEndpoints.keys.any(
            (k) => k.startsWith('/client/r0/sendToDevice/m.room.encrypted')),
        false);

    // device not found
    FakeMatrixApi.calledEndpoints.clear();
    event = ToDeviceEvent(
        sender: '@alice:example.com',
        type: 'm.room_key_request',
        content: {
          'action': 'request',
          'body': {
            'algorithm': 'm.megolm.v1.aes-sha2',
            'room_id': '!726s6s6q:example.com',
            'sender_key': 'senderKey',
            'session_id': validSessionId,
          },
          'request_id': 'request_4',
          'requesting_device_id': 'blubb',
        });
    await matrix.keyManager.handleToDeviceEvent(event);
    expect(
        FakeMatrixApi.calledEndpoints.keys.any(
            (k) => k.startsWith('/client/r0/sendToDevice/m.room.encrypted')),
        false);

    // unknown room
    FakeMatrixApi.calledEndpoints.clear();
    event = ToDeviceEvent(
        sender: '@alice:example.com',
        type: 'm.room_key_request',
        content: {
          'action': 'request',
          'body': {
            'algorithm': 'm.megolm.v1.aes-sha2',
            'room_id': '!invalid:example.com',
            'sender_key': 'senderKey',
            'session_id': validSessionId,
          },
          'request_id': 'request_5',
          'requesting_device_id': 'OTHERDEVICE',
        });
    await matrix.keyManager.handleToDeviceEvent(event);
    expect(
        FakeMatrixApi.calledEndpoints.keys.any(
            (k) => k.startsWith('/client/r0/sendToDevice/m.room.encrypted')),
        false);

    // unknwon session
    FakeMatrixApi.calledEndpoints.clear();
    event = ToDeviceEvent(
        sender: '@alice:example.com',
        type: 'm.room_key_request',
        content: {
          'action': 'request',
          'body': {
            'algorithm': 'm.megolm.v1.aes-sha2',
            'room_id': '!726s6s6q:example.com',
            'sender_key': 'senderKey',
            'session_id': 'invalid',
          },
          'request_id': 'request_6',
          'requesting_device_id': 'OTHERDEVICE',
        });
    await matrix.keyManager.handleToDeviceEvent(event);
    expect(
        FakeMatrixApi.calledEndpoints.keys.any(
            (k) => k.startsWith('/client/r0/sendToDevice/m.room.encrypted')),
        false);

    FakeMatrixApi.calledEndpoints.clear();
    await matrix.dispose(closeDatabase: true);
  });
  test('Receive shared keys', () async {
    var matrix = Client('testclient', debug: true);
    matrix.httpClient = FakeMatrixApi();
    matrix.database = getDatabase();
    await matrix.checkServer('https://fakeServer.notExisting');
    await matrix.login('test', '1234');
    if (!matrix.encryptionEnabled) {
      await matrix.dispose(closeDatabase: true);
      return;
    }
    final requestRoom = matrix.getRoomById('!726s6s6q:example.com');
    await matrix.keyManager.request(requestRoom, validSessionId, 'senderKey');

    final session = requestRoom.inboundGroupSessions[validSessionId];
    final sessionKey = session.inboundGroupSession
        .export_session(session.inboundGroupSession.first_known_index());
    requestRoom.inboundGroupSessions.clear();
    var event = ToDeviceEvent(
        sender: '@alice:example.com',
        type: 'm.forwarded_room_key',
        content: {
          'algorithm': 'm.megolm.v1.aes-sha2',
          'room_id': '!726s6s6q:example.com',
          'session_id': validSessionId,
          'session_key': sessionKey,
          'sender_key': 'senderKey',
          'forwarding_curve25519_key_chain': [],
        },
        encryptedContent: {
          'sender_key': '3C5BFWi2Y8MaVvjM8M22DBmh24PmgR0nPvJOIArzgyI',
        });
    await matrix.keyManager.handleToDeviceEvent(event);
    expect(requestRoom.inboundGroupSessions.containsKey(validSessionId), true);

    // now test a few invalid scenarios

    // request not found
    requestRoom.inboundGroupSessions.clear();
    event = ToDeviceEvent(
        sender: '@alice:example.com',
        type: 'm.forwarded_room_key',
        content: {
          'algorithm': 'm.megolm.v1.aes-sha2',
          'room_id': '!726s6s6q:example.com',
          'session_id': validSessionId,
          'session_key': sessionKey,
          'sender_key': 'senderKey',
          'forwarding_curve25519_key_chain': [],
        },
        encryptedContent: {
          'sender_key': '3C5BFWi2Y8MaVvjM8M22DBmh24PmgR0nPvJOIArzgyI',
        });
    await matrix.keyManager.handleToDeviceEvent(event);
    expect(requestRoom.inboundGroupSessions.containsKey(validSessionId), false);

    // unknown device
    await matrix.keyManager.request(requestRoom, validSessionId, 'senderKey');
    requestRoom.inboundGroupSessions.clear();
    event = ToDeviceEvent(
        sender: '@alice:example.com',
        type: 'm.forwarded_room_key',
        content: {
          'algorithm': 'm.megolm.v1.aes-sha2',
          'room_id': '!726s6s6q:example.com',
          'session_id': validSessionId,
          'session_key': sessionKey,
          'sender_key': 'senderKey',
          'forwarding_curve25519_key_chain': [],
        },
        encryptedContent: {
          'sender_key': 'invalid',
        });
    await matrix.keyManager.handleToDeviceEvent(event);
    expect(requestRoom.inboundGroupSessions.containsKey(validSessionId), false);

    // no encrypted content
    await matrix.keyManager.request(requestRoom, validSessionId, 'senderKey');
    requestRoom.inboundGroupSessions.clear();
    event = ToDeviceEvent(
        sender: '@alice:example.com',
        type: 'm.forwarded_room_key',
        content: {
          'algorithm': 'm.megolm.v1.aes-sha2',
          'room_id': '!726s6s6q:example.com',
          'session_id': validSessionId,
          'session_key': sessionKey,
          'sender_key': 'senderKey',
          'forwarding_curve25519_key_chain': [],
        });
    await matrix.keyManager.handleToDeviceEvent(event);
    expect(requestRoom.inboundGroupSessions.containsKey(validSessionId), false);

    await matrix.dispose(closeDatabase: true);
  });
}
