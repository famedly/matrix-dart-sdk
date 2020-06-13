/*
 *   Ansible inventory script used at Famedly GmbH for managing many hosts
 *   Copyright (C) 2020 Famedly GmbH
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
import 'package:famedlysdk/famedlysdk.dart';
import 'package:test/test.dart';
import 'package:olm/olm.dart' as olm;

import '../fake_client.dart';
import '../fake_matrix_api.dart';

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
  group('Key Request', () {
    var olmEnabled = true;
    try {
      olm.init();
      olm.Account();
    } catch (_) {
      olmEnabled = false;
      print('[LibOlm] Failed to load LibOlm: ' + _.toString());
    }
    print('[LibOlm] Enabled: $olmEnabled');

    if (!olmEnabled) return;

    final validSessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
    final validSenderKey = '3C5BFWi2Y8MaVvjM8M22DBmh24PmgR0nPvJOIArzgyI';
    test('Create Request', () async {
      var matrix = await getClient();
      final requestRoom = matrix.getRoomById('!726s6s6q:example.com');
      await matrix.encryption.keyManager.request(
          requestRoom, 'sessionId', validSenderKey,
          tryOnlineBackup: false);
      var foundEvent = false;
      for (var entry in FakeMatrixApi.calledEndpoints.entries) {
        final payload = jsonDecode(entry.value.first);
        if (entry.key
                .startsWith('/client/r0/sendToDevice/m.room_key_request') &&
            (payload['messages'] is Map) &&
            (payload['messages']['@alice:example.com'] is Map) &&
            (payload['messages']['@alice:example.com']['*'] is Map)) {
          final content = payload['messages']['@alice:example.com']['*'];
          if (content['action'] == 'request' &&
              content['body']['room_id'] == '!726s6s6q:example.com' &&
              content['body']['sender_key'] == validSenderKey &&
              content['body']['session_id'] == 'sessionId') {
            foundEvent = true;
            break;
          }
        }
      }
      expect(foundEvent, true);
      await matrix.dispose(closeDatabase: true);
    });
    test('Reply To Request', () async {
      var matrix = await getClient();
      matrix.setUserId('@alice:example.com'); // we need to pretend to be alice
      FakeMatrixApi.calledEndpoints.clear();
      await matrix
          .userDeviceKeys['@alice:example.com'].deviceKeys['OTHERDEVICE']
          .setBlocked(false);
      await matrix
          .userDeviceKeys['@alice:example.com'].deviceKeys['OTHERDEVICE']
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
              'sender_key': validSenderKey,
              'session_id': validSessionId,
            },
            'request_id': 'request_1',
            'requesting_device_id': 'OTHERDEVICE',
          });
      await matrix.encryption.keyManager.handleToDeviceEvent(event);
      print(FakeMatrixApi.calledEndpoints.keys.toString());
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
      await matrix.encryption.keyManager.handleToDeviceEvent(event);
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
              'sender_key': validSenderKey,
              'session_id': validSessionId,
            },
            'request_id': 'request_3',
            'requesting_device_id': 'JLAFKJWSCS',
          });
      await matrix.encryption.keyManager.handleToDeviceEvent(event);
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
              'sender_key': validSenderKey,
              'session_id': validSessionId,
            },
            'request_id': 'request_4',
            'requesting_device_id': 'blubb',
          });
      await matrix.encryption.keyManager.handleToDeviceEvent(event);
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
              'sender_key': validSenderKey,
              'session_id': validSessionId,
            },
            'request_id': 'request_5',
            'requesting_device_id': 'OTHERDEVICE',
          });
      await matrix.encryption.keyManager.handleToDeviceEvent(event);
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
              'sender_key': validSenderKey,
              'session_id': 'invalid',
            },
            'request_id': 'request_6',
            'requesting_device_id': 'OTHERDEVICE',
          });
      await matrix.encryption.keyManager.handleToDeviceEvent(event);
      expect(
          FakeMatrixApi.calledEndpoints.keys.any(
              (k) => k.startsWith('/client/r0/sendToDevice/m.room.encrypted')),
          false);

      FakeMatrixApi.calledEndpoints.clear();
      await matrix.dispose(closeDatabase: true);
    });
    test('Receive shared keys', () async {
      var matrix = await getClient();
      final requestRoom = matrix.getRoomById('!726s6s6q:example.com');
      await matrix.encryption.keyManager.request(
          requestRoom, validSessionId, validSenderKey,
          tryOnlineBackup: false);

      final session = await matrix.encryption.keyManager
          .loadInboundGroupSession(
              requestRoom.id, validSessionId, validSenderKey);
      final sessionKey = session.inboundGroupSession
          .export_session(session.inboundGroupSession.first_known_index());
      matrix.encryption.keyManager.clearInboundGroupSessions();
      var event = ToDeviceEvent(
          sender: '@alice:example.com',
          type: 'm.forwarded_room_key',
          content: {
            'algorithm': 'm.megolm.v1.aes-sha2',
            'room_id': '!726s6s6q:example.com',
            'session_id': validSessionId,
            'session_key': sessionKey,
            'sender_key': validSenderKey,
            'forwarding_curve25519_key_chain': [],
          },
          encryptedContent: {
            'sender_key': '3C5BFWi2Y8MaVvjM8M22DBmh24PmgR0nPvJOIArzgyI',
          });
      await matrix.encryption.keyManager.handleToDeviceEvent(event);
      expect(
          matrix.encryption.keyManager.getInboundGroupSession(
                  requestRoom.id, validSessionId, validSenderKey) !=
              null,
          true);

      // now test a few invalid scenarios

      // request not found
      matrix.encryption.keyManager.clearInboundGroupSessions();
      event = ToDeviceEvent(
          sender: '@alice:example.com',
          type: 'm.forwarded_room_key',
          content: {
            'algorithm': 'm.megolm.v1.aes-sha2',
            'room_id': '!726s6s6q:example.com',
            'session_id': validSessionId,
            'session_key': sessionKey,
            'sender_key': validSenderKey,
            'forwarding_curve25519_key_chain': [],
          },
          encryptedContent: {
            'sender_key': '3C5BFWi2Y8MaVvjM8M22DBmh24PmgR0nPvJOIArzgyI',
          });
      await matrix.encryption.keyManager.handleToDeviceEvent(event);
      expect(
          matrix.encryption.keyManager.getInboundGroupSession(
                  requestRoom.id, validSessionId, validSenderKey) !=
              null,
          false);

      // unknown device
      await matrix.encryption.keyManager.request(
          requestRoom, validSessionId, validSenderKey,
          tryOnlineBackup: false);
      matrix.encryption.keyManager.clearInboundGroupSessions();
      event = ToDeviceEvent(
          sender: '@alice:example.com',
          type: 'm.forwarded_room_key',
          content: {
            'algorithm': 'm.megolm.v1.aes-sha2',
            'room_id': '!726s6s6q:example.com',
            'session_id': validSessionId,
            'session_key': sessionKey,
            'sender_key': validSenderKey,
            'forwarding_curve25519_key_chain': [],
          },
          encryptedContent: {
            'sender_key': 'invalid',
          });
      await matrix.encryption.keyManager.handleToDeviceEvent(event);
      expect(
          matrix.encryption.keyManager.getInboundGroupSession(
                  requestRoom.id, validSessionId, validSenderKey) !=
              null,
          false);

      // no encrypted content
      await matrix.encryption.keyManager.request(
          requestRoom, validSessionId, validSenderKey,
          tryOnlineBackup: false);
      matrix.encryption.keyManager.clearInboundGroupSessions();
      event = ToDeviceEvent(
          sender: '@alice:example.com',
          type: 'm.forwarded_room_key',
          content: {
            'algorithm': 'm.megolm.v1.aes-sha2',
            'room_id': '!726s6s6q:example.com',
            'session_id': validSessionId,
            'session_key': sessionKey,
            'sender_key': validSenderKey,
            'forwarding_curve25519_key_chain': [],
          });
      await matrix.encryption.keyManager.handleToDeviceEvent(event);
      expect(
          matrix.encryption.keyManager.getInboundGroupSession(
                  requestRoom.id, validSessionId, validSenderKey) !=
              null,
          false);

      await matrix.dispose(closeDatabase: true);
    });
  });
}
