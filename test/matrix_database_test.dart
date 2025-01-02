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
 *
 */

import 'package:test/test.dart';

import 'package:matrix/matrix.dart';
import 'fake_database.dart';

void main() {
  group('Databse', () {
    Logs().level = Level.error;
    final room = Room(id: '!room:blubb', client: Client('testclient'));
    test('setupDatabase', () async {
      final database = await getDatabase(null);
      await database.insertClient(
        'testclient',
        'https://example.org',
        'blubb',
        null,
        null,
        '@test:example.org',
        null,
        null,
        null,
        null,
      );
    });

    test('storeEventUpdate', () async {
      final client = Client('testclient');
      final database = await getDatabase(client);
      // store a simple update
      await database.storeEventUpdate(
        room.id,
        MatrixEvent.fromJson(
          {
            'type': 'm.room.message',
            'origin_server_ts': 100,
            'content': <String, dynamic>{'blah': 'blubb'},
            'event_id': '\$event-1',
            'sender': '@blah:blubb',
          },
        ),
        EventUpdateType.timeline,
        client,
      );
      var event = await database.getEventById('\$event-1', room);
      expect(event?.eventId, '\$event-1');

      // insert a transaction id
      await database.storeEventUpdate(
        room.id,
        Event.fromJson(
          {
            'type': 'm.room.message',
            'origin_server_ts': 100,
            'content': <String, dynamic>{'blah': 'blubb'},
            'event_id': 'transaction-1',
            'sender': '@blah:blubb',
            'status': EventStatus.sending.intValue,
          },
          room,
        ),
        EventUpdateType.timeline,
        client,
      );
      event = await database.getEventById('transaction-1', room);
      expect(event?.eventId, 'transaction-1');

      await database.storeEventUpdate(
        room.id,
        Event.fromJson(
          {
            'type': 'm.room.message',
            'origin_server_ts': 100,
            'content': <String, dynamic>{'blah': 'blubb'},
            'event_id': '\$event-2',
            'sender': '@blah:blubb',
            'unsigned': <String, dynamic>{
              'transaction_id': 'transaction-1',
            },
            'status': EventStatus.sent.intValue,
          },
          room,
        ),
        EventUpdateType.timeline,
        client,
      );
      event = await database.getEventById('transaction-1', room);
      expect(event, null);
      event = await database.getEventById('\$event-2', room);

      // insert a transaction id if the event id for it already exists
      await database.storeEventUpdate(
        room.id,
        Event.fromJson(
          {
            'type': 'm.room.message',
            'origin_server_ts': 100,
            'content': {'blah': 'blubb'},
            'event_id': '\$event-3',
            'sender': '@blah:blubb',
            'status': EventStatus.sending.intValue,
          },
          room,
        ),
        EventUpdateType.timeline,
        client,
      );
      event = await database.getEventById('\$event-3', room);
      expect(event?.eventId, '\$event-3');

      await database.storeEventUpdate(
        room.id,
        Event.fromJson(
          {
            'type': 'm.room.message',
            'origin_server_ts': 100,
            'content': {'blah': 'blubb'},
            'event_id': '\$event-3',
            'sender': '@blah:blubb',
            'status': EventStatus.sent.intValue,
            'unsigned': <String, dynamic>{
              'transaction_id': 'transaction-2',
            },
          },
          room,
        ),
        EventUpdateType.timeline,
        client,
      );
      event = await database.getEventById('\$event-3', room);
      expect(event?.eventId, '\$event-3');
      expect(event?.status, EventStatus.sent);
      event = await database.getEventById('transaction-2', room);
      expect(event, null);

      // insert transaction id and not update status
      await database.storeEventUpdate(
        room.id,
        Event.fromJson(
          {
            'type': 'm.room.message',
            'origin_server_ts': 100,
            'content': {'blah': 'blubb'},
            'event_id': '\$event-4',
            'sender': '@blah:blubb',
            'status': EventStatus.synced.intValue,
          },
          room,
        ),
        EventUpdateType.timeline,
        client,
      );
      event = await database.getEventById('\$event-4', room);
      expect(event?.eventId, '\$event-4');

      await database.storeEventUpdate(
        room.id,
        Event.fromJson(
          {
            'type': 'm.room.message',
            'origin_server_ts': 100,
            'content': {'blah': 'blubb'},
            'event_id': '\$event-4',
            'sender': '@blah:blubb',
            'status': EventStatus.sent.intValue,
            'unsigned': <String, dynamic>{
              'transaction_id': 'transaction-3',
            },
          },
          room,
        ),
        EventUpdateType.timeline,
        client,
      );
      event = await database.getEventById('\$event-4', room);
      expect(event?.eventId, '\$event-4');
      expect(event?.status, EventStatus.synced);
      event = await database.getEventById('transaction-3', room);
      expect(event, null);
    });
  });
}
