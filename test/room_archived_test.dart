// SPDX-FileCopyrightText: 2019-Present, 2022 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:test/test.dart';

import 'package:matrix/matrix.dart';
import 'fake_client.dart';

void main() async {
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

    test('get archive', () async {
      final archive = await client.loadArchiveWithTimeline();

      expect(archive.length, 2);
      expect(archive[0].room.id, '!5345234234:example.com');
      expect(archive[0].room.membership, Membership.leave);
      expect(archive[0].room.name, 'The room name');
      expect(archive[0].room.roomAccountData.length, 1);
      expect(archive[1].room.id, '!5345234235:example.com');
      expect(archive[1].room.membership, Membership.leave);
      expect(archive[1].room.name, 'The room name 2');
    });

    test('request history', () async {
      final archive = await client.loadArchiveWithTimeline();

      final timeline = archive.first.timeline;

      expect(timeline.events.length, 2);
      expect(timeline.events[0].eventId, '1532735824654:example.org');
      expect(timeline.events[1].eventId, '1532735824650:example.org');

      await timeline.requestHistory();

      expect(timeline.events.length, 5);
      expect(timeline.events[0].eventId, '143274597443PhrSn:example.org');
      expect(timeline.events[1].eventId, '143274597446PhrSn:example.org');
      expect(timeline.events[2].eventId, '3143273582443PhrSn:example.org');
      expect(timeline.events[3].eventId, '2143273582443PhrSn:example.org');
      expect(timeline.events[4].eventId, '1143273582466PhrSn:example.org');
    });

    test('expect database to be empty', () async {
      final archive = await client.loadArchiveWithTimeline();
      final archiveRoom = archive.first;

      final eventsFromStore = await client.database.getEventList(
        archiveRoom.room,
        start: 0,
        limit: Room.defaultHistoryCount,
      );
      expect(eventsFromStore.isEmpty, true);
    });

    test('discard room from archives when membership change', () async {
      await client.loadArchiveWithTimeline();
      await client.handleSync(
        SyncUpdate(
          nextBatch: 't_456',
          rooms: RoomsUpdate(
            invite: {'!5345234235:example.com': InvitedRoomUpdate()},
          ),
        ),
      );
    });

    test('logout', () async {
      await client.logout();
    });
  });
}
