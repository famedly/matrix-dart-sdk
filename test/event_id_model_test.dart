// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';
import 'package:test/test.dart';

import 'fake_database.dart';

void main() {
  final alice = UserId('@alice:example.com');
  final roomId = RoomId('!testroom:example.com');
  final eventId = EventId(r'$event1:example.com');
  final targetEventId = EventId(r'$target:example.com');
  final replyEventId = EventId(r'$reply_to:example.com');

  group('MatrixEvent EventId API', () {
    test(
      'MatrixEvent.typed constructs with EventId and exposes getters/setters',
      () {
        final event = MatrixEvent.typed(
          type: 'm.room.message',
          content: {'body': 'hello'},
          senderUserId: alice,
          eventIdentifier: eventId,
          room: roomId,
          originServerTs: DateTime.now(),
          redacts: targetEventId,
        );

        expect(event.eventIdentifier, equals(eventId));
        expect(event.eventId, equals(eventId.value));
        expect(event.redactsEventId, equals(targetEventId));
        expect(event.redacts, equals(targetEventId.value));

        final newEventId = EventId(r'$newevent:example.com');
        event.eventIdentifier = newEventId;
        expect(event.eventIdentifier, equals(newEventId));
        expect(event.eventId, equals(newEventId.value));

        event.redactsEventId = null;
        expect(event.redactsEventId, isNull);
        expect(event.redacts, isNull);
      },
    );

    test(
      'MatrixEvent parses modern room v3 opaque event ID without domain',
      () {
        final opaqueEventId = EventId(r'$0123456789abcdefghijklmnopqrstuvwxyz');
        final event = MatrixEvent.fromJson(<String, Object?>{
          'type': 'm.room.message',
          'content': <String, Object?>{'body': 'opaque'},
          'sender': alice.value,
          'event_id': opaqueEventId.value,
          'origin_server_ts': 1700000000000,
        });

        expect(event.eventIdentifier, equals(opaqueEventId));
        expect(event.eventId, equals(opaqueEventId.value));
      },
    );

    test(
      'MatrixEvent returns null eventIdentifier for empty or malformed eventId',
      () {
        final invalidEvent = MatrixEvent.fromJson(<String, Object?>{
          'type': 'm.room.message',
          'content': <String, Object?>{},
          'sender': alice.value,
          'event_id': 'not-an-event-id',
          'origin_server_ts': 1700000000000,
        });

        expect(invalidEvent.eventIdentifier, isNull);
        expect(invalidEvent.eventId, equals('not-an-event-id'));
      },
    );
  });

  group('Event EventId typed relations and constructors', () {
    late Client client;
    late Room room;

    setUp(() async {
      client = Client('test-event-id-client', database: await getDatabase());
      addTearDown(client.dispose);
      room = Room.typed(roomId: roomId, client: client);
    });

    test('Event.typed constructs correctly and exposes eventIdentifier', () {
      final event = Event.typed(
        type: 'm.room.message',
        content: {'body': 'test message'},
        senderUserId: alice,
        eventIdentifier: eventId,
        originServerTs: DateTime.now(),
        room: room,
      );

      expect(event.eventIdentifier, equals(eventId));
      expect(event.eventId, equals(eventId.value));
      expect(event.senderUserId, equals(alice));
      expect(event.room, equals(room));
    });

    test(
      'relationshipTargetEventId and inReplyToEventIdentifier parse typed IDs',
      () {
        final replyEvent = Event(
          eventId: eventId.value,
          senderId: alice.value,
          type: 'm.room.message',
          originServerTs: DateTime.now(),
          room: room,
          content: {
            'body': 'in reply',
            'm.relates_to': {
              'event_id': targetEventId.value,
              'm.in_reply_to': {'event_id': replyEventId.value},
            },
          },
        );

        expect(replyEvent.relationshipTargetEventId, equals(targetEventId));
        expect(replyEvent.relationshipEventId, equals(targetEventId.value));
        expect(replyEvent.inReplyToEventIdentifier(), equals(replyEventId));
        expect(replyEvent.inReplyToEventId(), equals(replyEventId.value));
      },
    );

    test('relationshipTargetEventId is null when relates_to is missing or malformed', () {
      final plainEvent = Event(
        eventId: eventId.value,
        senderId: alice.value,
        type: 'm.room.message',
        originServerTs: DateTime.now(),
        room: room,
        content: {'body': 'plain'},
      );

      expect(plainEvent.relationshipTargetEventId, isNull);
      expect(plainEvent.inReplyToEventIdentifier(), isNull);

      final malformedRelEvent = Event(
        eventId: eventId.value,
        senderId: alice.value,
        type: 'm.room.message',
        originServerTs: DateTime.now(),
        room: room,
        content: {
          'body': 'malformed',
          'm.relates_to': {'event_id': 'malformed-event-id'},
        },
      );

      expect(malformedRelEvent.relationshipTargetEventId, isNull);
    });
  });

  group('Room EventId helpers', () {
    late Client client;
    late Room room;

    setUp(() async {
      client = Client('test-room-event-helpers', database: await getDatabase());
      addTearDown(client.dispose);
      room = Room.typed(roomId: roomId, client: client);
    });

    test('fullyReadEventId reflects m.fully_read account data', () {
      expect(room.fullyReadEventId, isNull);
      expect(room.fullyRead, isEmpty);

      room.roomAccountData['m.fully_read'] = BasicEvent(
        type: 'm.fully_read',
        content: {'event_id': eventId.value},
      );

      expect(room.fullyReadEventId, equals(eventId));
      expect(room.fullyRead, equals(eventId.value));
    });

    test('lastEventId returns eventIdentifier of lastEvent', () {
      expect(room.lastEventId, isNull);

      room.lastEvent = Event.typed(
        type: 'm.room.message',
        content: {'body': 'latest'},
        senderUserId: alice,
        eventIdentifier: eventId,
        originServerTs: DateTime.now(),
        room: room,
      );

      expect(room.lastEventId, equals(eventId));
    });

    test(
      'getEventByEventId delegates to getEventById and finds database event',
      () async {
        final event = Event.typed(
          type: 'm.room.message',
          content: {'body': 'hello world'},
          senderUserId: alice,
          eventIdentifier: eventId,
          originServerTs: DateTime.now(),
          room: room,
        );
        await client.database.storeEventUpdate(
          room.id,
          event,
          EventUpdateType.timeline,
          client,
        );

        final found = await room.getEventByEventId(eventId);
        expect(found, isNotNull);
        expect(found!.eventIdentifier, equals(eventId));
        expect(found.body, equals('hello world'));
      },
    );
  });
}
