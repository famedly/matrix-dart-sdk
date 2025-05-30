/*
 *   Famedly Matrix SDK
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

import 'package:olm/olm.dart' as olm;
import 'package:test/test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:matrix/matrix.dart';
import '../fake_client.dart';

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
  group('Key Request', tags: 'olm', () {
    Logs().level = Level.error;

    setUpAll(() async {
      await vod.init(
        wasmPath: './pkg/',
        libraryPath: './rust/target/debug/',
      );
      await olm.init();
      olm.get_library_version();
    });

    final validSessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
    final validSenderKey = 'JBG7ZaPn54OBC7TuIEiylW3BZ+7WcGQhFBPB9pogbAg';
    test('Create Request', () async {
      final matrix = await getClient();
      final requestRoom = matrix.getRoomById('!726s6s6q:example.com')!;
      await matrix.encryption!.keyManager.request(
        requestRoom,
        'sessionId',
        validSenderKey,
        tryOnlineBackup: false,
      );
      var foundEvent = false;
      for (final entry in FakeMatrixApi.calledEndpoints.entries) {
        final payload = jsonDecode(entry.value.first);
        if (entry.key
                .startsWith('/client/v3/sendToDevice/m.room_key_request') &&
            (payload['messages'] is Map) &&
            (payload['messages']['@alice:example.com'] is Map) &&
            (payload['messages']['@alice:example.com']['*'] is Map)) {
          final content = payload['messages']['@alice:example.com']['*'];
          if (content['action'] == 'request' &&
              content['body']['room_id'] == '!726s6s6q:example.com' &&
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
      final matrix = await getClient();
      await matrix.abortSync();

      matrix.setUserId('@alice:example.com'); // we need to pretend to be alice
      FakeMatrixApi.calledEndpoints.clear();
      await matrix
          .userDeviceKeys['@alice:example.com']!.deviceKeys['OTHERDEVICE']!
          .setBlocked(false);
      await matrix
          .userDeviceKeys['@alice:example.com']!.deviceKeys['OTHERDEVICE']!
          .setVerified(true);
      final session = await matrix.encryption!.keyManager
          .loadInboundGroupSession('!726s6s6q:example.com', validSessionId);
      // test a successful share
      var event = ToDeviceEvent(
        sender: '@alice:example.com',
        type: 'm.room_key_request',
        content: {
          'action': 'request',
          'body': {
            'algorithm': AlgorithmTypes.megolmV1AesSha2,
            'room_id': '!726s6s6q:example.com',
            'sender_key': validSenderKey,
            'session_id': validSessionId,
          },
          'request_id': 'request_1',
          'requesting_device_id': 'OTHERDEVICE',
        },
      );
      await matrix.encryption!.keyManager.handleToDeviceEvent(event);
      Logs().i(FakeMatrixApi.calledEndpoints.keys.toString());
      expect(
        FakeMatrixApi.calledEndpoints.keys.any(
          (k) => k.startsWith('/client/v3/sendToDevice/m.room.encrypted'),
        ),
        true,
      );

      // test a successful foreign share
      FakeMatrixApi.calledEndpoints.clear();
      session!.allowedAtIndex['@test:fakeServer.notExisting'] = <String, int>{
        matrix.userDeviceKeys['@test:fakeServer.notExisting']!
            .deviceKeys['OTHERDEVICE']!.curve25519Key!: 0,
      };
      event = ToDeviceEvent(
        sender: '@test:fakeServer.notExisting',
        type: 'm.room_key_request',
        content: {
          'action': 'request',
          'body': {
            'algorithm': AlgorithmTypes.megolmV1AesSha2,
            'room_id': '!726s6s6q:example.com',
            'sender_key': validSenderKey,
            'session_id': validSessionId,
          },
          'request_id': 'request_a1',
          'requesting_device_id': 'OTHERDEVICE',
        },
      );
      await matrix.encryption!.keyManager.handleToDeviceEvent(event);
      Logs().i(FakeMatrixApi.calledEndpoints.keys.toString());
      expect(
        FakeMatrixApi.calledEndpoints.keys.any(
          (k) => k.startsWith('/client/v3/sendToDevice/m.room.encrypted'),
        ),
        true,
      );
      session.allowedAtIndex.remove('@test:fakeServer.notExisting');

      // test various fail scenarios

      // unknown person
      FakeMatrixApi.calledEndpoints.clear();
      event = ToDeviceEvent(
        sender: '@test:fakeServer.notExisting',
        type: 'm.room_key_request',
        content: {
          'action': 'request',
          'body': {
            'algorithm': AlgorithmTypes.megolmV1AesSha2,
            'room_id': '!726s6s6q:example.com',
            'sender_key': validSenderKey,
            'session_id': validSessionId,
          },
          'request_id': 'request_a2',
          'requesting_device_id': 'OTHERDEVICE',
        },
      );
      await matrix.encryption!.keyManager.handleToDeviceEvent(event);
      Logs().i(FakeMatrixApi.calledEndpoints.keys.toString());
      expect(
        FakeMatrixApi.calledEndpoints.keys.any(
          (k) => k.startsWith('/client/v3/sendToDevice/m.room.encrypted'),
        ),
        false,
      );

      // no body
      FakeMatrixApi.calledEndpoints.clear();
      event = ToDeviceEvent(
        sender: '@alice:example.com',
        type: 'm.room_key_request',
        content: {
          'action': 'request',
          'request_id': 'request_2',
          'requesting_device_id': 'OTHERDEVICE',
        },
      );
      await matrix.encryption!.keyManager.handleToDeviceEvent(event);
      expect(
        FakeMatrixApi.calledEndpoints.keys.any(
          (k) => k.startsWith('/client/v3/sendToDevice/m.room.encrypted'),
        ),
        false,
      );

      // request by ourself
      FakeMatrixApi.calledEndpoints.clear();
      event = ToDeviceEvent(
        sender: '@alice:example.com',
        type: 'm.room_key_request',
        content: {
          'action': 'request',
          'body': {
            'algorithm': AlgorithmTypes.megolmV1AesSha2,
            'room_id': '!726s6s6q:example.com',
            'sender_key': validSenderKey,
            'session_id': validSessionId,
          },
          'request_id': 'request_3',
          'requesting_device_id': 'JLAFKJWSCS',
        },
      );
      await matrix.encryption!.keyManager.handleToDeviceEvent(event);
      expect(
        FakeMatrixApi.calledEndpoints.keys.any(
          (k) => k.startsWith('/client/v3/sendToDevice/m.room.encrypted'),
        ),
        false,
      );

      // device not found
      FakeMatrixApi.calledEndpoints.clear();
      event = ToDeviceEvent(
        sender: '@alice:example.com',
        type: 'm.room_key_request',
        content: {
          'action': 'request',
          'body': {
            'algorithm': AlgorithmTypes.megolmV1AesSha2,
            'room_id': '!726s6s6q:example.com',
            'sender_key': validSenderKey,
            'session_id': validSessionId,
          },
          'request_id': 'request_4',
          'requesting_device_id': 'blubb',
        },
      );
      await matrix.encryption!.keyManager.handleToDeviceEvent(event);
      expect(
        FakeMatrixApi.calledEndpoints.keys.any(
          (k) => k.startsWith('/client/v3/sendToDevice/m.room.encrypted'),
        ),
        false,
      );

      // unknown room
      FakeMatrixApi.calledEndpoints.clear();
      event = ToDeviceEvent(
        sender: '@alice:example.com',
        type: 'm.room_key_request',
        content: {
          'action': 'request',
          'body': {
            'algorithm': AlgorithmTypes.megolmV1AesSha2,
            'room_id': '!invalid:example.com',
            'sender_key': validSenderKey,
            'session_id': validSessionId,
          },
          'request_id': 'request_5',
          'requesting_device_id': 'OTHERDEVICE',
        },
      );
      await matrix.encryption!.keyManager.handleToDeviceEvent(event);
      expect(
        FakeMatrixApi.calledEndpoints.keys.any(
          (k) => k.startsWith('/client/v3/sendToDevice/m.room.encrypted'),
        ),
        false,
      );

      // unknwon session
      FakeMatrixApi.calledEndpoints.clear();
      event = ToDeviceEvent(
        sender: '@alice:example.com',
        type: 'm.room_key_request',
        content: {
          'action': 'request',
          'body': {
            'algorithm': AlgorithmTypes.megolmV1AesSha2,
            'room_id': '!726s6s6q:example.com',
            'sender_key': validSenderKey,
            'session_id': 'invalid',
          },
          'request_id': 'request_6',
          'requesting_device_id': 'OTHERDEVICE',
        },
      );
      await matrix.encryption!.keyManager.handleToDeviceEvent(event);
      expect(
        FakeMatrixApi.calledEndpoints.keys.any(
          (k) => k.startsWith('/client/v3/sendToDevice/m.room.encrypted'),
        ),
        false,
      );

      FakeMatrixApi.calledEndpoints.clear();
      await matrix.dispose(closeDatabase: true);
    });
    test('Receive shared keys', () async {
      final matrix = await getClient();
      final requestRoom = matrix.getRoomById('!726s6s6q:example.com')!;
      await matrix.encryption!.keyManager.request(
        requestRoom,
        validSessionId,
        validSenderKey,
        tryOnlineBackup: false,
      );

      final session = (await matrix.encryption!.keyManager
          .loadInboundGroupSession(requestRoom.id, validSessionId))!;
      final sessionKey = session.inboundGroupSession!.exportAtFirstKnownIndex();
      matrix.encryption!.keyManager.clearInboundGroupSessions();
      var event = ToDeviceEvent(
        sender: '@alice:example.com',
        type: 'm.forwarded_room_key',
        content: {
          'algorithm': AlgorithmTypes.megolmV1AesSha2,
          'room_id': '!726s6s6q:example.com',
          'session_id': validSessionId,
          'session_key': sessionKey,
          'sender_key': validSenderKey,
          'forwarding_curve25519_key_chain': [],
          'sender_claimed_ed25519_key':
              'L+4+JCl8MD63dgo8z5Ta+9QAHXiANyOVSfgbHA5d3H8',
        },
        encryptedContent: {
          'sender_key': 'L+4+JCl8MD63dgo8z5Ta+9QAHXiANyOVSfgbHA5d3H8',
        },
      );
      await matrix.encryption!.keyManager.handleToDeviceEvent(event);
      expect(
        matrix.encryption!.keyManager
                .getInboundGroupSession(requestRoom.id, validSessionId) !=
            null,
        true,
      );

      // test ToDeviceEvent without sender_key in content
      event = ToDeviceEvent(
        sender: '@alice:example.com',
        type: 'm.forwarded_room_key',
        content: {
          'algorithm': AlgorithmTypes.megolmV1AesSha2,
          'room_id': '!726s6s6q:example.com',
          'session_id': validSessionId,
          'session_key': sessionKey,
          'forwarding_curve25519_key_chain': [],
          'sender_claimed_ed25519_key':
              'L+4+JCl8MD63dgo8z5Ta+9QAHXiANyOVSfgbHA5d3H8',
        },
        encryptedContent: {
          'sender_key': 'L+4+JCl8MD63dgo8z5Ta+9QAHXiANyOVSfgbHA5d3H8',
        },
      );

      // now test a few invalid scenarios

      // request not found
      matrix.encryption!.keyManager.clearInboundGroupSessions();
      event = ToDeviceEvent(
        sender: '@alice:example.com',
        type: 'm.forwarded_room_key',
        content: {
          'algorithm': AlgorithmTypes.megolmV1AesSha2,
          'room_id': '!726s6s6q:example.com',
          'session_id': validSessionId,
          'session_key': sessionKey,
          'sender_key': validSenderKey,
          'forwarding_curve25519_key_chain': [],
          'sender_claimed_ed25519_key':
              'L+4+JCl8MD63dgo8z5Ta+9QAHXiANyOVSfgbHA5d3H8',
        },
        encryptedContent: {
          'sender_key': 'L+4+JCl8MD63dgo8z5Ta+9QAHXiANyOVSfgbHA5d3H8',
        },
      );
      await matrix.encryption!.keyManager.handleToDeviceEvent(event);
      expect(
        matrix.encryption!.keyManager
                .getInboundGroupSession(requestRoom.id, validSessionId) !=
            null,
        false,
      );

      // unknown device
      await matrix.encryption!.keyManager
          .request(requestRoom, validSessionId, null, tryOnlineBackup: false);
      matrix.encryption!.keyManager.clearInboundGroupSessions();
      event = ToDeviceEvent(
        sender: '@alice:example.com',
        type: 'm.forwarded_room_key',
        content: {
          'algorithm': AlgorithmTypes.megolmV1AesSha2,
          'room_id': '!726s6s6q:example.com',
          'session_id': validSessionId,
          'session_key': sessionKey,
          'sender_key': validSenderKey,
          'forwarding_curve25519_key_chain': [],
          'sender_claimed_ed25519_key':
              'L+4+JCl8MD63dgo8z5Ta+9QAHXiANyOVSfgbHA5d3H8',
        },
        encryptedContent: {
          'sender_key': 'invalid',
        },
      );
      await matrix.encryption!.keyManager.handleToDeviceEvent(event);
      expect(
        matrix.encryption!.keyManager
                .getInboundGroupSession(requestRoom.id, validSessionId) !=
            null,
        false,
      );

      // no encrypted content
      await matrix.encryption!.keyManager.request(
        requestRoom,
        validSessionId,
        validSenderKey,
        tryOnlineBackup: false,
      );
      matrix.encryption!.keyManager.clearInboundGroupSessions();
      event = ToDeviceEvent(
        sender: '@alice:example.com',
        type: 'm.forwarded_room_key',
        content: {
          'algorithm': AlgorithmTypes.megolmV1AesSha2,
          'room_id': '!726s6s6q:example.com',
          'session_id': validSessionId,
          'session_key': sessionKey,
          'sender_key': validSenderKey,
          'forwarding_curve25519_key_chain': [],
          'sender_claimed_ed25519_key':
              'L+4+JCl8MD63dgo8z5Ta+9QAHXiANyOVSfgbHA5d3H8',
        },
      );
      await matrix.encryption!.keyManager.handleToDeviceEvent(event);
      expect(
        matrix.encryption!.keyManager
                .getInboundGroupSession(requestRoom.id, validSessionId) !=
            null,
        false,
      );

      // There is a non awaiting setInboundGroupSession call on the database
      await Future.delayed(Duration(seconds: 1));

      await matrix.dispose(closeDatabase: true);
    });
  });
}
