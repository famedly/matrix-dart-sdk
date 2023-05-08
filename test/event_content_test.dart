/* MIT License
*
* Copyright (C) 2019, 2020, 2021 Famedly GmbH
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

import 'dart:convert';

import 'package:test/test.dart';

import 'package:matrix_api_lite/matrix_api_lite.dart';

void main() {
  group('Event Content tests', () {
    test('Room Encryption Content', () {
      Map<String, dynamic>? json = <String, dynamic>{
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
      json = jsonDecode(jsonEncode(json)) as Map<String, dynamic>?;
      expect(MatrixEvent.fromJson(json!).parsedRoomEncryptionContent.toJson(),
          json['content']);
    });
    test('Room Encrypted Content', () {
      Map<String, dynamic>? json = <String, dynamic>{
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
      json = jsonDecode(jsonEncode(json)) as Map<String, dynamic>?;
      expect(MatrixEvent.fromJson(json!).parsedRoomEncryptedContent.toJson(),
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
      json = jsonDecode(jsonEncode(json)) as Map<String, dynamic>?;
      expect(MatrixEvent.fromJson(json!).parsedRoomEncryptedContent.toJson(),
          json['content']);
    });
    test('Room Key Content', () {
      Map<String, dynamic>? json = <String, dynamic>{
        'content': {
          'algorithm': 'm.megolm.v1.aes-sha2',
          'room_id': '!Cuyf34gef24t:localhost',
          'session_id': 'X3lUlvLELLYxeTx4yOVu6UDpasGEVO0Jbu+QFnm0cKQ',
          'session_key': 'AgAAAADxKHa9uFxcXzwYoNueL5Xqi69IkD4sni8LlfJL7qNBEY...'
        },
        'type': 'm.room_key'
      };
      json = jsonDecode(jsonEncode(json)) as Map<String, dynamic>?;
      expect(BasicEvent.fromJson(json!).parsedRoomKeyContent.toJson(),
          json['content']);
    });
    test('Room Key Request Content', () {
      Map<String, dynamic>? json = <String, dynamic>{
        'content': {
          'action': 'request_cancellation',
          'request_id': '1495474790150.19',
          'requesting_device_id': 'RJYKSTBOIE'
        },
        'type': 'm.room_key_request'
      };
      json = jsonDecode(jsonEncode(json)) as Map<String, dynamic>?;
      expect(BasicEvent.fromJson(json!).parsedRoomKeyRequestContent.toJson(),
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
      json = jsonDecode(jsonEncode(json)) as Map<String, dynamic>?;
      expect(BasicEvent.fromJson(json!).parsedRoomKeyRequestContent.toJson(),
          json['content']);
    });
    test('Forwarded Room Key Content', () {
      Map<String, dynamic>? json = <String, dynamic>{
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
      json = jsonDecode(jsonEncode(json)) as Map<String, dynamic>?;
      expect(BasicEvent.fromJson(json!).parsedForwardedRoomKeyContent.toJson(),
          json['content']);
    });
    test('OLM Plaintext Payload', () {
      Map<String, dynamic>? json = <String, dynamic>{
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
      json = jsonDecode(jsonEncode(json)) as Map<String, dynamic>?;
      expect(OlmPlaintextPayload.fromJson(json!).toJson(), json);
    });
    test('Image Pack Content', () {
      // basic parse / unparse
      var json = <String, dynamic>{
        'type': 'some type',
        'content': {
          'images': {
            'emote': {
              'url': 'mxc://example.org/beep',
              'usage': ['emoticon'],
              'org.custom': 'beep',
            },
            'sticker': {
              'url': 'mxc://example.org/boop',
              'usage': ['org.custom', 'sticker', 'org.other.custom'],
            },
          },
          'pack': {
            'display_name': 'Awesome Pack',
            'org.custom': 'boop',
          },
          'org.custom': 'blah',
        },
      };
      json = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
      expect(BasicEvent.fromJson(json).parsedImagePackContent.toJson(),
          json['content']);

      // emoticons migration
      json = <String, dynamic>{
        'type': 'some type',
        'content': {
          'emoticons': {
            ':emote:': {
              'url': 'mxc://example.org/beep',
            },
          },
        },
      };
      json = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
      expect(
          BasicEvent.fromJson(json)
              .parsedImagePackContent
              .images['emote']
              ?.toJson(),
          {
            'url': 'mxc://example.org/beep',
          });

      json = <String, dynamic>{
        'type': 'some type',
        'content': {
          'short': {
            ':emote:': 'mxc://example.org/beep',
          },
        },
      };
      json = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
      expect(
          BasicEvent.fromJson(json)
              .parsedImagePackContent
              .images['emote']
              ?.toJson(),
          {
            'url': 'mxc://example.org/beep',
          });

      // invalid url for image
      json = <String, dynamic>{
        'type': 'some type',
        'content': {
          'images': {
            'emote': <String, dynamic>{},
          },
        },
      };
      json = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
      expect(BasicEvent.fromJson(json).parsedImagePackContent.images['emote'],
          null);
    });
  });
}
