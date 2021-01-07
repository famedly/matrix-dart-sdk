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
      expect(MatrixEvent.fromJson(json).parsedRoomEncryptedContent.toJson(),
          json['content']);
    });
  });
}
