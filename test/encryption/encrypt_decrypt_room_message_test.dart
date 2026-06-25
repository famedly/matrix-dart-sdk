// SPDX-FileCopyrightText: 2019-Present, 2020 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';
import 'package:test/test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import '../fake_client.dart';

void main() {
  group('Encrypt/Decrypt room message', tags: 'olm', () {
    Logs().level = Level.error;

    late Client client;
    const roomId = '!726s6s6q:example.com';
    late Room room;
    late Map<String, dynamic> payload;
    final now = DateTime.now();

    setUpAll(() async {
      await vod.init(
        wasmPath: './pkg/',
        libraryPath: './rust/target/debug/',
      );

      client = await getClient();
      room = client.getRoomById(roomId)!;
    });

    test('encrypt payload', () async {
      payload = await client.encryption!.encryptGroupMessagePayload(roomId, {
        'msgtype': 'm.text',
        'text': 'Hello foxies!',
      });
      expect(payload['algorithm'], AlgorithmTypes.megolmV1AesSha2);
      expect(payload['ciphertext'] is String, true);
      expect(payload['device_id'], client.deviceID);
      expect(payload['sender_key'], client.identityKey);
      expect(payload['session_id'] is String, true);
    });

    test('decrypt payload', () async {
      final encryptedEvent = Event(
        type: EventTypes.Encrypted,
        content: payload,
        room: room,
        originServerTs: now,
        eventId: '\$event',
        senderId: client.userID!,
      );
      final decryptedEvent =
          await client.encryption!.decryptRoomEvent(encryptedEvent);
      expect(decryptedEvent.type, 'm.room.message');
      expect(decryptedEvent.content['msgtype'], 'm.text');
      expect(decryptedEvent.content['text'], 'Hello foxies!');
      expect(decryptedEvent.originalSource?.toJson(), encryptedEvent.toJson());
    });

    test('decrypt payload without device_id', () async {
      payload.remove('device_id');
      payload.remove('sender_key');
      final encryptedEvent = Event(
        type: EventTypes.Encrypted,
        content: payload,
        room: room,
        originServerTs: now,
        eventId: '\$event',
        senderId: client.userID!,
      );
      final decryptedEvent =
          await client.encryption!.decryptRoomEvent(encryptedEvent);
      expect(decryptedEvent.type, 'm.room.message');
      expect(decryptedEvent.content['msgtype'], 'm.text');
      expect(decryptedEvent.content['text'], 'Hello foxies!');
      expect(decryptedEvent.originalSource?.toJson(), encryptedEvent.toJson());
    });

    test('decrypt payload nocache', () async {
      client.encryption!.keyManager.clearInboundGroupSessions();
      final encryptedEvent = Event(
        type: EventTypes.Encrypted,
        content: payload,
        room: room,
        originServerTs: now,
        eventId: '\$event',
        senderId: '@alice:example.com',
      );
      final decryptedEvent =
          await client.encryption!.decryptRoomEvent(encryptedEvent);
      expect(decryptedEvent.type, 'm.room.message');
      expect(decryptedEvent.content['msgtype'], 'm.text');
      expect(decryptedEvent.content['text'], 'Hello foxies!');
      await client.encryption!.decryptRoomEvent(encryptedEvent, store: true);
    });

    test('dispose client', () async {
      await client.dispose(closeDatabase: true);
    });
  });
}
