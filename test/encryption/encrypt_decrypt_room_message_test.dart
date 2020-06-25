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

import 'package:famedlysdk/famedlysdk.dart';
import 'package:test/test.dart';
import 'package:olm/olm.dart' as olm;

import '../fake_client.dart';

void main() {
  group('Encrypt/Decrypt room message', () {
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

    Client client;
    final roomId = '!726s6s6q:example.com';
    Room room;
    Map<String, dynamic> payload;
    final now = DateTime.now();

    test('setupClient', () async {
      client = await getClient();
      room = client.getRoomById(roomId);
    });

    test('encrypt payload', () async {
      payload = await client.encryption.encryptGroupMessagePayload(roomId, {
        'msgtype': 'm.text',
        'text': 'Hello foxies!',
      });
      expect(payload['algorithm'], 'm.megolm.v1.aes-sha2');
      expect(payload['ciphertext'] is String, true);
      expect(payload['device_id'], client.deviceID);
      expect(payload['sender_key'], client.identityKey);
      expect(payload['session_id'] is String, true);
    });

    test('decrypt payload', () async {
      final encryptedEvent = Event(
        type: EventTypes.Encrypted,
        content: payload,
        roomId: roomId,
        room: room,
        originServerTs: now,
        eventId: '\$event',
      );
      final decryptedEvent =
          await client.encryption.decryptRoomEvent(roomId, encryptedEvent);
      expect(decryptedEvent.type, 'm.room.message');
      expect(decryptedEvent.content['msgtype'], 'm.text');
      expect(decryptedEvent.content['text'], 'Hello foxies!');
    });

    test('decrypt payload nocache', () async {
      client.encryption.keyManager.clearInboundGroupSessions();
      final encryptedEvent = Event(
        type: EventTypes.Encrypted,
        content: payload,
        roomId: roomId,
        room: room,
        originServerTs: now,
        eventId: '\$event',
        senderId: '@alice:example.com',
      );
      final decryptedEvent =
          await client.encryption.decryptRoomEvent(roomId, encryptedEvent);
      expect(decryptedEvent.type, 'm.room.message');
      expect(decryptedEvent.content['msgtype'], 'm.text');
      expect(decryptedEvent.content['text'], 'Hello foxies!');
      await client.encryption
          .decryptRoomEvent(roomId, encryptedEvent, store: true);
    });

    test('dispose client', () async {
      await client.dispose(closeDatabase: true);
    });
  });
}
