// SPDX-FileCopyrightText: 2019-Present, 2022 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:matrix/matrix.dart';
import 'package:test/test.dart';

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

      expect(timeline.events.length, 6);
      expect(timeline.events[0].eventId, '1532735824654:example.org');
      expect(timeline.events[1].eventId, '1532735824650:example.org');
      expect(timeline.events[2].eventId, '1432735824656:example.org');
      expect(timeline.events[3].eventId, '1432735824655:example.org');
      expect(timeline.events[4].eventId, '1432735824654:example.org');
      expect(timeline.events[5].eventId, '1432735824653:example.org');
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

    test('includeLeave keeps left room in rooms and database', () async {
      await client.dispose().onError((e, s) {});
      client = await getClient(
        syncFilter: Filter(
          room: RoomFilter(
            state: StateFilter(lazyLoadMembers: true),
            includeLeave: true,
          ),
        ),
      );
      client.rooms.clear();
      await client.database.clearCache();

      const roomId = '!includeLeaveRoom:example.com';
      await client.handleSync(
        SyncUpdate(
          nextBatch: 't_join',
          rooms: RoomsUpdate(
            join: {
              roomId: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  prevBatch: 'join_batch',
                  events: [
                    MatrixEvent(
                      type: EventTypes.Message,
                      senderId: '@alice:example.com',
                      eventId: '\$include-leave-join',
                      originServerTs: DateTime.fromMillisecondsSinceEpoch(1),
                      content: {'msgtype': 'm.text', 'body': 'joined'},
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );

      await client.handleSync(
        SyncUpdate(
          nextBatch: 't_leave',
          rooms: RoomsUpdate(
            leave: {
              roomId: LeftRoomUpdate(
                timeline: TimelineUpdate(
                  prevBatch: 'leave_batch',
                  events: [
                    MatrixEvent(
                      type: EventTypes.Message,
                      senderId: '@alice:example.com',
                      eventId: '\$include-leave-left',
                      originServerTs: DateTime.fromMillisecondsSinceEpoch(2),
                      content: {'msgtype': 'm.text', 'body': 'left'},
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );

      final room = client.getRoomById(roomId);
      expect(room, isNotNull);
      expect(room!.membership, Membership.leave);
      expect(room.prev_batch, 'leave_batch');

      final storedRoom = await client.database.getSingleRoom(client, roomId);
      expect(storedRoom?.membership, Membership.leave);
      expect(storedRoom?.prev_batch, 'leave_batch');
      expect(storedRoom?.lastEvent?.eventId, '\$include-leave-left');

      final timeline = await room.getTimeline();
      expect(
        timeline.events.map((event) => event.eventId),
        contains('\$include-leave-left'),
      );
    });

    test('reinvite updates kept left room membership', () async {
      await client.dispose().onError((e, s) {});
      client = await getClient(
        syncFilter: Filter(
          room: RoomFilter(
            state: StateFilter(lazyLoadMembers: true),
            includeLeave: true,
          ),
        ),
      );
      client.rooms.clear();
      await client.database.clearCache();

      const roomId = '!reinviteLeftRoom:example.com';
      await client.handleSync(
        SyncUpdate(
          nextBatch: 't_join',
          rooms: RoomsUpdate(join: {roomId: JoinedRoomUpdate()}),
        ),
      );
      await client.handleSync(
        SyncUpdate(
          nextBatch: 't_leave',
          rooms: RoomsUpdate(leave: {roomId: LeftRoomUpdate()}),
        ),
      );

      await client.handleSync(
        SyncUpdate(
          nextBatch: 't_invite',
          rooms: RoomsUpdate(invite: {roomId: InvitedRoomUpdate()}),
        ),
      );

      expect(client.getRoomById(roomId)?.membership, Membership.invite);
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
