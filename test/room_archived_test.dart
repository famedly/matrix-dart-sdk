/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2022 Famedly GmbH
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

import 'dart:async';

import 'package:test/test.dart';

import 'package:matrix/matrix.dart';
import 'fake_client.dart';

void main() {
  group('Timeline', () {
    Logs().level = Level.error;

    final insertList = <int>[];

    late Client client;

    setUp(() async {
      client = await getClient(
        sendTimelineEventTimeout: const Duration(seconds: 5),
      );

      await client.abortSync();
      insertList.clear();
    });

    tearDown(() async => client.dispose().onError((e, s) {}));

    test('archive room not loaded', () async {
      final archiveRoom =
          client.getArchiveRoomFromCache('!5345234234:example.com');
      expect(archiveRoom, null);
    });

    test('get archive', () async {
      final archive = await client.loadArchiveWithTimeline();

      expect(archive.length, 2);
      expect(client.rooms.length, 3);
      expect(archive[0].room.id, '!5345234234:example.com');
      expect(archive[0].room.membership, Membership.leave);
      expect(archive[0].room.name, 'The room name');
      expect(archive[0].room.lastEvent?.body,
          'This is a second text example message');
      expect(archive[0].room.roomAccountData.length, 1);
      expect(archive[1].room.id, '!5345234235:example.com');
      expect(archive[1].room.membership, Membership.leave);
      expect(archive[1].room.name, 'The room name 2');

      final archiveRoom =
          client.getArchiveRoomFromCache('!5345234234:example.com');
      expect(archiveRoom != null, true);
      expect(archiveRoom!.timeline.events.length, 2);
    });

    test('request history', () async {
      await client.loadArchiveWithTimeline();
      final archiveRoom = client.getRoomById('!5345234234:example.com');
      expect(archiveRoom != null, true);

      final timeline = await archiveRoom!.getTimeline(onInsert: insertList.add);

      expect(timeline.events.length, 2);
      expect(timeline.events[0].eventId, '143274597443PhrSn:example.org');
      expect(timeline.events[1].eventId, '143274597446PhrSn:example.org');

      await timeline.requestHistory();

      expect(timeline.events.length, 5);
      expect(timeline.events[0].eventId, '143274597443PhrSn:example.org');
      expect(timeline.events[1].eventId, '143274597446PhrSn:example.org');
      expect(timeline.events[2].eventId, '3143273582443PhrSn:example.org');
      expect(timeline.events[3].eventId, '2143273582443PhrSn:example.org');
      expect(timeline.events[4].eventId, '1143273582466PhrSn:example.org');
      expect(insertList.length, 3);
    });

    test('expect database to be empty', () async {
      await client.loadArchiveWithTimeline();
      final archiveRoom = client.getRoomById('!5345234234:example.com');
      expect(archiveRoom != null, true);

      final eventsFromStore = await client.database?.getEventList(
        archiveRoom!,
        start: 0,
        limit: Room.defaultHistoryCount,
      );
      expect(eventsFromStore?.isEmpty, true);
    });

    test('discard room from archives when membership change', () async {
      await client.loadArchiveWithTimeline();
      expect(client.getArchiveRoomFromCache('!5345234235:example.com') != null,
          true);
      await client.handleSync(SyncUpdate(
          nextBatch: 't_456',
          rooms: RoomsUpdate(
              invite: {'!5345234235:example.com': InvitedRoomUpdate()})));
      expect(client.getArchiveRoomFromCache('!5345234235:example.com'), null);
    });

    test('clear archive', () async {
      await client.loadArchiveWithTimeline();
      client.clearArchivesFromCache();
      expect(client.getArchiveRoomFromCache('!5345234234:example.com'), null);
    });

    test('logout', () async {
      await client.logout();
    });
  });
}
