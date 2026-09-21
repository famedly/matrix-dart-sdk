// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';
import 'package:test/test.dart';

import 'fake_database.dart';

void main() {
  final roomId = RoomId('!testroom:example.com');
  final alice = UserId('@alice:example.com');

  group('Room typed RoomId API', () {
    late Client client;

    setUp(() async {
      client = Client('test-room-id-client', database: await getDatabase());
      addTearDown(client.dispose);
    });

    test(
      'Room.typed constructs with typed RoomId and exposes roomId and id',
      () {
        final room = Room.typed(
          roomId: roomId,
          client: client,
          notificationCount: 3,
        );

        expect(room.roomId, equals(roomId));
        expect(room.id, equals(roomId.value));
        expect(room.notificationCount, equals(3));
      },
    );

    test(
      'Room default constructor exposes parsed roomId and null for invalid id',
      () {
        final validRoom = Room(id: roomId.value, client: client);
        expect(validRoom.roomId, equals(roomId));

        final invalidRoom = Room(id: 'invalid-room-id', client: client);
        expect(invalidRoom.roomId, isNull);
        expect(invalidRoom.id, equals('invalid-room-id'));
      },
    );
  });

  group('Client RoomId query API', () {
    late Client client;
    late Room room;

    setUp(() async {
      client = Client('test-client-room-lookup', database: await getDatabase());
      addTearDown(client.dispose);
      room = Room.typed(roomId: roomId, client: client);
      client.rooms.add(room);
    });

    test('getRoomByRoomId finds room matching typed RoomId', () {
      expect(client.getRoomByRoomId(roomId), equals(room));

      final otherRoomId = RoomId('!other:example.com');
      expect(client.getRoomByRoomId(otherRoomId), isNull);
    });
  });

  group('MatrixEvent RoomId API', () {
    test('MatrixEvent.typed constructs with typed sender and room', () {
      final event = MatrixEvent.typed(
        type: 'm.room.message',
        content: {'body': 'hello'},
        senderUserId: alice,
        eventIdentifier: EventId(r'$123456:example.com'),
        room: roomId,
        originServerTs: DateTime.now(),
      );

      expect(event.parsedRoomId, equals(roomId));
      expect(event.roomId, equals(roomId.value));
      expect(event.senderUserId, equals(alice));
      expect(event.senderId, equals(alice.value));

      final otherRoom = RoomId('!newroom:example.com');
      event.parsedRoomId = otherRoom;
      expect(event.parsedRoomId, equals(otherRoom));
      expect(event.roomId, equals(otherRoom.value));

      event.parsedRoomId = null;
      expect(event.parsedRoomId, isNull);
      expect(event.roomId, isNull);
    });

    test('MatrixEvent exposes parsedRoomId from json', () {
      final event = MatrixEvent.fromJson(<String, Object?>{
        'type': 'm.room.message',
        'content': <String, Object?>{'body': 'hello'},
        'sender': alice.value,
        'event_id': r'$event123:example.com',
        'room_id': roomId.value,
        'origin_server_ts': 1700000000000,
      });

      expect(event.parsedRoomId, equals(roomId));
      expect(event.roomId, equals(roomId.value));

      final invalidRoomEvent = MatrixEvent.fromJson(<String, Object?>{
        'type': 'm.room.message',
        'content': <String, Object?>{},
        'sender': alice.value,
        'event_id': r'$event123:example.com',
        'room_id': 'malformed-room-id',
        'origin_server_ts': 1700000000000,
      });

      expect(invalidRoomEvent.parsedRoomId, isNull);
      expect(invalidRoomEvent.roomId, equals('malformed-room-id'));
    });
  });

  group('GetRoomIdByAliasResponseExtension', () {
    test('parsedRoomId parses valid and invalid room IDs', () {
      final response = GetRoomIdByAliasResponse(
        roomId: roomId.value,
        servers: ['example.com'],
      );
      expect(response.parsedRoomId, equals(roomId));

      final invalidResponse = GetRoomIdByAliasResponse(
        roomId: 'invalid',
        servers: ['example.com'],
      );
      expect(invalidResponse.parsedRoomId, isNull);

      final emptyResponse = GetRoomIdByAliasResponse();
      expect(emptyResponse.parsedRoomId, isNull);
    });
  });
}
