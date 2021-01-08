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

import 'package:matrix_api_lite/matrix_api_lite.dart';
import 'package:test/test.dart';
import 'dart:convert';

void main() {
  group('Event Content tests', () {
    test('Room Encryption Content', () {
      var json = <String, dynamic>{
        'content': {
          'algorithm': 'm.megolm.v1.aes-sha2',
          'rotation_period_ms': 604800000,
          'rotation_period_msgs': 100
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '',
        'type': 'm.room.encryption',
        'unsigned': {'age': 1234}
      };
      json = jsonDecode(jsonEncode(json));
      expect(MatrixEvent.fromJson(json).parsedRoomEncryptionContent.toJson(),
          json['content']);
    });
    test('Room Encrypted Content', () {
      var json = <String, dynamic>{
        'content': {
          'algorithm': 'm.megolm.v1.aes-sha2',
          'ciphertext': 'AwgAEnACgAkLmt6qF84IK++J7UDH2Za1YVchHyprqTqsg...',
          'device_id': 'RJYKSTBOIE',
          'sender_key': 'IlRMeOPX2e0MurIyfWEucYBRVOEEUMrOHqn/8mLqMjA',
          'session_id': 'X3lUlvLELLYxeTx4yOVu6UDpasGEVO0Jbu+QFnm0cKQ'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.room.encrypted',
        'unsigned': {'age': 1234}
      };
      json = jsonDecode(jsonEncode(json));
      expect(MatrixEvent.fromJson(json).parsedRoomEncryptedContent.toJson(),
          json['content']);
      json = <String, dynamic>{
        'content': {
          'algorithm': 'm.olm.v1.curve25519-aes-sha2',
          'ciphertext': {
            '7qZcfnBmbEGzxxaWfBjElJuvn7BZx+lSz/SvFrDF/z8': {
              'body': 'AwogGJJzMhf/S3GQFXAOrCZ3iKyGU5ZScVtjI0KypTYrW...',
              'type': 0
            }
          },
          'sender_key': 'Szl29ksW/L8yZGWAX+8dY1XyFi+i5wm+DRhTGkbMiwU'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.room.encrypted',
        'unsigned': {'age': 1234}
      };
      json = jsonDecode(jsonEncode(json));
      expect(MatrixEvent.fromJson(json).parsedRoomEncryptedContent.toJson(),
          json['content']);
    });
    test('Room Key Content', () {
      var json = <String, dynamic>{
        'content': {
          'algorithm': 'm.megolm.v1.aes-sha2',
          'room_id': '!Cuyf34gef24t:localhost',
          'session_id': 'X3lUlvLELLYxeTx4yOVu6UDpasGEVO0Jbu+QFnm0cKQ',
          'session_key': 'AgAAAADxKHa9uFxcXzwYoNueL5Xqi69IkD4sni8LlfJL7qNBEY...'
        },
        'type': 'm.room_key'
      };
      json = jsonDecode(jsonEncode(json));
      expect(BasicEvent.fromJson(json).parsedRoomKeyContent.toJson(),
          json['content']);
    });
    test('Room Key Request Content', () {
      var json = <String, dynamic>{
        'content': {
          'action': 'request_cancellation',
          'request_id': '1495474790150.19',
          'requesting_device_id': 'RJYKSTBOIE'
        },
        'type': 'm.room_key_request'
      };
      json = jsonDecode(jsonEncode(json));
      expect(BasicEvent.fromJson(json).parsedRoomKeyRequestContent.toJson(),
          json['content']);
      json = <String, dynamic>{
        'content': {
          'action': 'request',
          'body': {
            'algorithm': 'm.megolm.v1.aes-sha2',
            'room_id': '!Cuyf34gef24t:localhost',
            'sender_key': 'RF3s+E7RkTQTGF2d8Deol0FkQvgII2aJDf3/Jp5mxVU',
            'session_id': 'X3lUlvLELLYxeTx4yOVu6UDpasGEVO0Jbu+QFnm0cKQ'
          },
          'request_id': '1495474790150.19',
          'requesting_device_id': 'RJYKSTBOIE'
        },
        'type': 'm.room_key_request'
      };
      json = jsonDecode(jsonEncode(json));
      expect(BasicEvent.fromJson(json).parsedRoomKeyRequestContent.toJson(),
          json['content']);
    });
    test('Forwarded Room Key Content', () {
      var json = <String, dynamic>{
        'content': {
          'algorithm': 'm.megolm.v1.aes-sha2',
          'forwarding_curve25519_key_chain': [
            'hPQNcabIABgGnx3/ACv/jmMmiQHoeFfuLB17tzWp6Hw'
          ],
          'room_id': '!Cuyf34gef24t:localhost',
          'sender_claimed_ed25519_key':
              'aj40p+aw64yPIdsxoog8jhPu9i7l7NcFRecuOQblE3Y',
          'sender_key': 'RF3s+E7RkTQTGF2d8Deol0FkQvgII2aJDf3/Jp5mxVU',
          'session_id': 'X3lUlvLELLYxeTx4yOVu6UDpasGEVO0Jbu+QFnm0cKQ',
          'session_key': 'AgAAAADxKHa9uFxcXzwYoNueL5Xqi69IkD4sni8Llf...'
        },
        'type': 'm.forwarded_room_key'
      };
      json = jsonDecode(jsonEncode(json));
      expect(BasicEvent.fromJson(json).parsedForwardedRoomKeyContent.toJson(),
          json['content']);
    });
    test('OLM Plaintext Payload', () {
      var json = <String, dynamic>{
        'type': '<type of the plaintext event>',
        'content': <String, dynamic>{
          'msgtype': 'm.text',
          'body': 'Hello world',
        },
        'sender': '<sender_user_id>',
        'recipient': '<recipient_user_id>',
        'recipient_keys': {'ed25519': '<our_ed25519_key>'},
        'keys': {'ed25519': '<sender_ed25519_key>'}
      };
      json = jsonDecode(jsonEncode(json));
      expect(OlmPlaintextPayload.fromJson(json).toJson(), json);
    });
  });
}
