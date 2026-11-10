// SPDX-FileCopyrightText: 2019-Present, 2020 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

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
      await vod.init(wasmPath: './pkg/', libraryPath: './rust/target/debug/');

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
      final decryptedEvent = await client.encryption!.decryptRoomEvent(
        encryptedEvent,
      );
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
      final decryptedEvent = await client.encryption!.decryptRoomEvent(
        encryptedEvent,
      );
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
      final decryptedEvent = await client.encryption!.decryptRoomEvent(
        encryptedEvent,
      );
      expect(decryptedEvent.type, 'm.room.message');
      expect(decryptedEvent.content['msgtype'], 'm.text');
      expect(decryptedEvent.content['text'], 'Hello foxies!');
      await client.encryption!.decryptRoomEvent(encryptedEvent, store: true);
    });

    test('getEventById decrypts events stored before the keys', () async {
      final session = vod.GroupSession();
      final sessionKey = session.sessionKey;
      final event = Event(
        type: EventTypes.Encrypted,
        content: {
          'algorithm': AlgorithmTypes.megolmV1AesSha2,
          'ciphertext': session.encrypt(
            json.encode({
              'type': EventTypes.Message,
              'content': {'msgtype': 'm.text', 'body': 'Late keys'},
              'room_id': roomId,
            }),
          ),
          'sender_key': client.identityKey,
          'session_id': session.sessionId,
        },
        room: room,
        originServerTs: now,
        eventId: '\$late_keys',
        senderId: '@alice:example.com',
      );
      await client.database.storeEventUpdate(
        roomId,
        event,
        EventUpdateType.timeline,
        client,
      );
      expect((await room.getEventById(event.eventId))?.type, event.type);

      await client.encryption!.keyManager.setInboundGroupSession(
        roomId,
        session.sessionId,
        client.identityKey,
        {
          'algorithm': AlgorithmTypes.megolmV1AesSha2,
          'room_id': roomId,
          'session_id': session.sessionId,
          'session_key': sessionKey,
        },
      );
      final decrypted = await room.getEventById(event.eventId);
      expect(decrypted?.type, EventTypes.Message);
      expect(decrypted?.body, 'Late keys');
    });

    test('getTimeline applies edits it decrypts', () async {
      final session = vod.GroupSession();
      final sessionKey = session.sessionKey;
      const senderId = '@alice:example.com';
      final original = Event(
        type: EventTypes.Message,
        content: {'msgtype': 'm.text', 'body': 'Original'},
        room: room,
        originServerTs: now,
        eventId: '\$edited',
        senderId: senderId,
      );
      // Stored as the sync stores it when the keys are missing.
      final edit = client.encryption!.decryptRoomEventSync(
        Event(
          type: EventTypes.Encrypted,
          content: {
            'algorithm': AlgorithmTypes.megolmV1AesSha2,
            'ciphertext': session.encrypt(
              json.encode({
                'type': EventTypes.Message,
                'content': {
                  'msgtype': 'm.text',
                  'body': '* Edited',
                  'm.new_content': {'msgtype': 'm.text', 'body': 'Edited'},
                },
                'room_id': roomId,
              }),
            ),
            'sender_key': client.identityKey,
            'session_id': session.sessionId,
            'm.relates_to': {
              'rel_type': RelationshipTypes.edit,
              'event_id': original.eventId,
            },
          },
          room: room,
          originServerTs: now,
          eventId: '\$edit',
          senderId: senderId,
        ),
      );
      expect(edit.content['can_request_session'], true);
      for (final event in [original, edit]) {
        await client.database.storeEventUpdate(
          roomId,
          event,
          EventUpdateType.timeline,
          client,
        );
      }

      await client.encryption!.keyManager.setInboundGroupSession(
        roomId,
        session.sessionId,
        client.identityKey,
        {
          'algorithm': AlgorithmTypes.megolmV1AesSha2,
          'room_id': roomId,
          'session_id': session.sessionId,
          'session_key': sessionKey,
        },
      );
      final timeline = await room.getTimeline();
      final edited = timeline.events.firstWhere(
        (event) => event.eventId == original.eventId,
      );
      expect(edited.getDisplayEvent(timeline).body, 'Edited');
      timeline.cancelSubscriptions();
    });

    test(
      'key backup retry keeps the original event as originalSource',
      () async {
        final encryptedEvent = Event(
          type: EventTypes.Encrypted,
          content: {
            'algorithm': AlgorithmTypes.megolmV1AesSha2,
            'ciphertext': 'not-a-real-ciphertext',
            'session_id': 'session-not-in-store',
            'sender_key': client.identityKey,
          },
          room: room,
          originServerTs: now,
          eventId: '\$retry_source',
          senderId: client.userID!,
        );
        final decrypted = await client.encryption!.decryptRoomEvent(
          encryptedEvent,
          waitForKeyBackupAndRetry: true,
        );
        expect(decrypted.originalSource, same(encryptedEvent));
      },
    );

    test('dispose client', () async {
      await client.dispose(closeDatabase: true);
    });
  });
}
