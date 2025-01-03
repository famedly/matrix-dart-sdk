/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020 Famedly GmbH
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
import 'package:matrix/src/models/timeline_chunk.dart';
import 'fake_client.dart';

void main() {
  group('Timeline context', tags: 'olm', () {
    Logs().level = Level.error;
    final roomID = '!1234:example.com';
    var testTimeStamp = 0;
    var updateCount = 0;
    final insertList = <int>[];
    final changeList = <int>[];
    final removeList = <int>[];

    final countStream = StreamController<int>.broadcast();
    Future<int> waitForCount(int count) async {
      if (updateCount == count) {
        return Future.value(updateCount);
      }

      final completer = Completer<int>();

      StreamSubscription<int>? sub;
      sub = countStream.stream.listen((newCount) async {
        if (newCount == count) {
          await sub?.cancel();
          completer.complete(count);
        }
      });

      return completer.future.timeout(
        Duration(seconds: 1),
        onTimeout: () async {
          throw TimeoutException(
            'Failed to wait for updateCount == $count, current == $updateCount',
            Duration(seconds: 1),
          );
        },
      );
    }

    late Client client;
    late Room room;
    late Timeline timeline;
    setUp(() async {
      client = await getClient(
        sendTimelineEventTimeout: const Duration(seconds: 5),
      );

      room = Room(
        id: roomID,
        client: client,
        prev_batch: 't123',
        roomAccountData: {},
      );
      timeline = Timeline(
        room: room,
        chunk: TimelineChunk(events: [], nextBatch: 't456', prevBatch: 't123'),
        onUpdate: () {
          updateCount++;
          countStream.add(updateCount);
        },
        onInsert: insertList.add,
        onChange: changeList.add,
        onRemove: removeList.add,
      );
      expect(timeline.isFragmentedTimeline, true);
      expect(timeline.allowNewEvent, false);
      updateCount = 0;
      insertList.clear();
      changeList.clear();
      removeList.clear();

      await client.abortSync();
      testTimeStamp = DateTime.now().millisecondsSinceEpoch;
    });

    tearDown(
      () async => client.dispose(closeDatabase: true).onError((e, s) {}),
    );

    test('Request future', () async {
      timeline.events.clear();
      FakeMatrixApi.calledEndpoints.clear();

      await timeline.requestFuture();

      await FakeMatrixApi.firstWhere(
        (a) => a.startsWith(
          '/client/v3/rooms/!1234%3Aexample.com/messages?from=t456&dir=f',
        ),
      );

      expect(updateCount, 3);
      expect(insertList, [0, 1, 2]);
      expect(timeline.events.length, 3);
      expect(timeline.events[0].eventId, '3143273582443PhrSn:example.org');
      expect(timeline.events[1].eventId, '2143273582443PhrSn:example.org');
      expect(timeline.events[2].eventId, '1143273582443PhrSn:example.org');
      expect(timeline.chunk.nextBatch, 't789');

      expect(timeline.isFragmentedTimeline, true);
      expect(timeline.allowNewEvent, false);
    });

    /// We send a message in a fragmented timeline, it didn't reached the end so we shouldn't be displayed.
    test('Send message not displayed', () async {
      await room.sendTextEvent('test', txid: '1234');
      await FakeMatrixApi.firstWhere(
        (a) => a.startsWith(
          '/client/v3/rooms/!1234%3Aexample.com/send/m.room.message/1234',
        ),
      );

      expect(updateCount, 0);
      expect(insertList, []);
      expect(
        insertList.length,
        timeline.events.length,
      ); // expect no new events to have been added

      final eventId = '1844295642248BcDkn:example.org';
      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.message',
            'content': {'msgtype': 'm.text', 'body': 'test'},
            'sender': '@alice:example.com',
            'status': EventStatus.synced.intValue,
            'event_id': eventId,
            'unsigned': {'transaction_id': '1234'},
            'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
          },
          room,
        ),
      ); // just assume that it was on the server for this call but not for the following.

      expect(updateCount, 0);
      expect(insertList, []);
      expect(
        timeline.events.length,
        0,
      ); // we still expect the timeline to contain the same numbre of elements
    });

    test('Request future end of timeline', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await timeline.requestFuture();
      await timeline.requestFuture();

      await FakeMatrixApi.firstWhere(
        (a) => a.startsWith(
          '/client/v3/rooms/!1234%3Aexample.com/messages?from=t789&dir=f',
        ),
      );

      expect(updateCount, 6);
      expect(insertList, [0, 1, 2]);
      expect(insertList.length, timeline.events.length);
      expect(timeline.events[0].eventId, '3143273582443PhrSn:example.org');
      expect(timeline.events[1].eventId, '2143273582443PhrSn:example.org');
      expect(timeline.events[2].eventId, '1143273582443PhrSn:example.org');
      expect(timeline.chunk.nextBatch, '');

      expect(timeline.isFragmentedTimeline, true);
      expect(timeline.allowNewEvent, true);
    });

    test('Send message', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await timeline.requestFuture();
      await timeline.requestFuture();
      await room.sendTextEvent('test', txid: '1234');

      await FakeMatrixApi.firstWhere(
        (a) => a.startsWith(
          '/client/v3/rooms/!1234%3Aexample.com/send/m.room.message/1234',
        ),
      );

      expect(updateCount, 8);
      expect(insertList, [0, 1, 2, 0]);
      expect(insertList.length, timeline.events.length);
      final eventId = timeline.events[0].eventId;
      expect(eventId.startsWith('\$event'), true);
      expect(timeline.events[0].status, EventStatus.sent);

      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.message',
            'content': {'msgtype': 'm.text', 'body': 'test'},
            'sender': '@alice:example.com',
            'status': EventStatus.synced.intValue,
            'event_id': eventId,
            'unsigned': {'transaction_id': '1234'},
            'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
          },
          room,
        ),
      );

      await waitForCount(9);

      expect(updateCount, 9);
      expect(insertList, [0, 1, 2, 0]);
      expect(insertList.length, timeline.events.length);
      expect(timeline.events[0].eventId, eventId);
      expect(timeline.events[0].status, EventStatus.synced);
    });

    test('Send message with error', () async {
      await timeline.requestFuture();
      await timeline.requestFuture();
      await waitForCount(6);

      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.message',
            'content': {'msgtype': 'm.text', 'body': 'Testcase'},
            'sender': '@alice:example.com',
            'status': EventStatus.sending.intValue,
            'event_id': 'abc',
            'origin_server_ts': testTimeStamp,
          },
          room,
        ),
      );

      await waitForCount(7);

      expect(updateCount, 7);

      FakeMatrixApi.calledEndpoints.clear();

      await room.sendTextEvent('test', txid: 'errortxid');

      await FakeMatrixApi.firstWhere(
        (a) => a.startsWith(
          '/client/v3/rooms/!1234%3Aexample.com/send/m.room.message/errortxid',
        ),
      );

      await waitForCount(9);
      expect(updateCount, 9);
      await room.sendTextEvent('test', txid: 'errortxid2');
      await FakeMatrixApi.firstWhere(
        (a) => a.startsWith(
          '/client/v3/rooms/!1234%3Aexample.com/send/m.room.message/errortxid2',
        ),
      );
      await room.sendTextEvent('test', txid: 'errortxid3');
      await FakeMatrixApi.firstWhere(
        (a) => a.startsWith(
          '/client/v3/rooms/!1234%3Aexample.com/send/m.room.message/errortxid3',
        ),
      );

      expect(updateCount, 13);
      expect(insertList, [0, 1, 2, 0, 0, 1, 2]);
      expect(insertList.length, timeline.events.length);
      expect(changeList, [0, 1, 2]);
      expect(removeList, []);
      expect(timeline.events[0].status, EventStatus.error);
      expect(timeline.events[1].status, EventStatus.error);
      expect(timeline.events[2].status, EventStatus.error);
    });

    test('Remove message', () async {
      await timeline.requestFuture();
      await timeline.requestFuture();
      // send a failed message
      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.message',
            'content': {'msgtype': 'm.text', 'body': 'Testcase'},
            'sender': '@alice:example.com',
            'status': EventStatus.sending.intValue,
            'event_id': 'abc',
            'origin_server_ts': testTimeStamp,
          },
          room,
        ),
      );
      await waitForCount(7);

      await timeline.events[0].cancelSend();

      await waitForCount(8);
      expect(updateCount, 8);

      expect(insertList, [0, 1, 2, 0]);
      expect(changeList, []);
      expect(removeList, [0]);
      expect(timeline.events.length, 3);
      expect(timeline.events[0].status, EventStatus.synced);
    });

    test('getEventById', () async {
      await timeline.requestFuture();
      await timeline.requestFuture();
      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.message',
            'content': {'msgtype': 'm.text', 'body': 'Testcase'},
            'sender': '@alice:example.com',
            'status': EventStatus.sending.intValue,
            'event_id': 'abc',
            'origin_server_ts': testTimeStamp,
          },
          room,
        ),
      );
      await waitForCount(7);
      var event = await timeline.getEventById('abc');
      expect(event?.content, {'msgtype': 'm.text', 'body': 'Testcase'});

      event = await timeline.getEventById('not_found');
      expect(event, null);

      event = await timeline.getEventById('unencrypted_event');
      expect(event?.body, 'This is an example text message');

      event = await timeline.getEventById('encrypted_event');
      // the event is invalid but should have traces of attempting to decrypt
      expect(event?.messageType, MessageTypes.BadEncrypted);
    });

    test('Resend message', () async {
      timeline.events.clear();
      await timeline.requestFuture();
      await timeline.requestFuture();
      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.message',
            'content': {'msgtype': 'm.text', 'body': 'Testcase'},
            'sender': '@alice:example.com',
            'status': EventStatus.error.intValue,
            'event_id': 'new-test-event',
            'origin_server_ts': testTimeStamp,
            'unsigned': {'transaction_id': 'newresend'},
          },
          room,
        ),
      );
      await waitForCount(7);
      expect(timeline.events[0].status, EventStatus.error);

      FakeMatrixApi.calledEndpoints.clear();

      await timeline.events[0].sendAgain();

      await FakeMatrixApi.firstWhere(
        (a) => a.startsWith(
          '/client/v3/rooms/!1234%3Aexample.com/send/m.room.message/newresend',
        ),
      );

      expect(updateCount, 9);

      expect(insertList, [0, 1, 2, 0]);
      expect(changeList, [0, 0]);
      expect(removeList, []);
      expect(timeline.events.length, 4);
      expect(timeline.events[0].status, EventStatus.sent);
    });

    test('Clear cache on limited timeline', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await timeline.requestFuture();
      await timeline.requestFuture();
      await client.handleSync(
        SyncUpdate(
          nextBatch: '1234',
          rooms: RoomsUpdate(
            join: {
              roomID: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  limited: true,
                  prevBatch: 'blah',
                  events: [
                    MatrixEvent(
                      eventId: '\$somerandomfox',
                      type: 'm.room.message',
                      content: {'msgtype': 'm.text', 'body': 'Testcase'},
                      senderId: '@alice:example.com',
                      originServerTs:
                          DateTime.fromMillisecondsSinceEpoch(testTimeStamp),
                    ),
                  ],
                ),
                unreadNotifications: UnreadNotificationCounts(
                  highlightCount: 0,
                  notificationCount: 0,
                ),
              ),
            },
          ),
        ),
      );
      await waitForCount(7);
      expect(timeline.events.length, 1);
    });

    test('sort errors on top', () async {
      timeline.events.clear();
      await timeline.requestFuture();
      await timeline.requestFuture();
      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.message',
            'content': {'msgtype': 'm.text', 'body': 'Testcase'},
            'sender': '@alice:example.com',
            'status': EventStatus.error.intValue,
            'event_id': 'abc',
            'origin_server_ts': testTimeStamp,
          },
          room,
        ),
      );
      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.message',
            'content': {'msgtype': 'm.text', 'body': 'Testcase'},
            'sender': '@alice:example.com',
            'status': EventStatus.synced.intValue,
            'event_id': 'def',
            'origin_server_ts': testTimeStamp + 5,
          },
          room,
        ),
      );
      await waitForCount(8);
      expect(timeline.events[0].status, EventStatus.error);
      expect(timeline.events[1].status, EventStatus.synced);
    });

    test('sending event to failed update', () async {
      timeline.events.clear();
      await timeline.requestFuture();
      await timeline.requestFuture();
      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.message',
            'content': {'msgtype': 'm.text', 'body': 'Testcase'},
            'sender': '@alice:example.com',
            'status': EventStatus.sending.intValue,
            'event_id': 'will-fail',
            'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
          },
          room,
        ),
      );
      await waitForCount(7);
      expect(timeline.events[0].status, EventStatus.sending);
      expect(timeline.events.length, 4);
      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.message',
            'content': {'msgtype': 'm.text', 'body': 'Testcase'},
            'sender': '@alice:example.com',
            'status': EventStatus.error.intValue,
            'event_id': 'will-fail',
            'origin_server_ts': testTimeStamp,
          },
          room,
        ),
      );
      await waitForCount(8);
      expect(timeline.events[0].status, EventStatus.error);
      expect(timeline.events.length, 4);
    });
    test('setReadMarker', () async {
      await timeline.requestFuture();
      await timeline.requestFuture();
      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.message',
            'content': {'msgtype': 'm.text', 'body': 'Testcase'},
            'sender': '@alice:example.com',
            'status': EventStatus.synced.intValue,
            'event_id': 'will-work',
            'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
          },
          room,
        ),
      );
      await waitForCount(7);

      room.notificationCount = 1;
      await timeline.setReadMarker();
      //expect(room.notificationCount, 0);
    });
    test('sending an event and the http request finishes first, 0 -> 1 -> 2',
        () async {
      timeline.events.clear();
      await timeline.requestFuture();
      await timeline.requestFuture();

      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.message',
            'content': {'msgtype': 'm.text', 'body': 'Testcase'},
            'sender': '@alice:example.com',
            'status': EventStatus.sending.intValue,
            'event_id': 'transaction',
            'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
          },
          room,
        ),
      );
      await waitForCount(7);
      expect(timeline.events[0].status, EventStatus.sending);
      expect(timeline.events.length, 4);
      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.message',
            'content': {'msgtype': 'm.text', 'body': 'Testcase'},
            'sender': '@alice:example.com',
            'status': EventStatus.sent.intValue,
            'event_id': '\$event',
            'origin_server_ts': testTimeStamp,
            'unsigned': {'transaction_id': 'transaction'},
          },
          room,
        ),
      );
      await waitForCount(8);
      expect(timeline.events[0].status, EventStatus.sent);
      expect(timeline.events.length, 4);
      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.message',
            'content': {'msgtype': 'm.text', 'body': 'Testcase'},
            'sender': '@alice:example.com',
            'status': EventStatus.synced.intValue,
            'event_id': '\$event',
            'origin_server_ts': testTimeStamp,
            'unsigned': {'transaction_id': 'transaction'},
          },
          room,
        ),
      );
      await waitForCount(9);
      expect(timeline.events[0].status, EventStatus.synced);
      expect(timeline.events.length, 4);
    });
    test('sending an event where the sync reply arrives first, 0 -> 2 -> 1',
        () async {
      timeline.events.clear();
      await timeline.requestFuture();
      await timeline.requestFuture();

      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.message',
            'content': {'msgtype': 'm.text', 'body': 'Testcase'},
            'sender': '@alice:example.com',
            'event_id': 'transaction',
            'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
            'unsigned': {
              messageSendingStatusKey: EventStatus.sending.intValue,
              'transaction_id': 'transaction',
            },
          },
          room,
        ),
      );
      await waitForCount(7);
      expect(timeline.events[0].status, EventStatus.sending);
      expect(timeline.events.length, 4);
      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.message',
            'content': {'msgtype': 'm.text', 'body': 'Testcase'},
            'sender': '@alice:example.com',
            'event_id': '\$event',
            'origin_server_ts': testTimeStamp,
            'unsigned': {
              'transaction_id': 'transaction',
              messageSendingStatusKey: EventStatus.synced.intValue,
            },
          },
          room,
        ),
      );
      await waitForCount(8);
      expect(timeline.events[0].status, EventStatus.synced);
      expect(timeline.events.length, 4);
      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.message',
            'content': {'msgtype': 'm.text', 'body': 'Testcase'},
            'sender': '@alice:example.com',
            'event_id': '\$event',
            'origin_server_ts': testTimeStamp,
            'unsigned': {
              'transaction_id': 'transaction',
              messageSendingStatusKey: EventStatus.sent.intValue,
            },
          },
          room,
        ),
      );
      await waitForCount(9);
      expect(timeline.events[0].status, EventStatus.synced);
      expect(timeline.events.length, 4);
    });
    test('sending an event 0 -> -1 -> 2', () async {
      timeline.events.clear();
      await timeline.requestFuture();
      await timeline.requestFuture();

      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.message',
            'content': {'msgtype': 'm.text', 'body': 'Testcase'},
            'sender': '@alice:example.com',
            'status': EventStatus.sending.intValue,
            'event_id': 'transaction',
            'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
          },
          room,
        ),
      );
      await waitForCount(7);
      expect(timeline.events[0].status, EventStatus.sending);
      expect(timeline.events.length, 4);
      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.message',
            'content': {'msgtype': 'm.text', 'body': 'Testcase'},
            'sender': '@alice:example.com',
            'status': EventStatus.error.intValue,
            'origin_server_ts': testTimeStamp,
            'unsigned': {'transaction_id': 'transaction'},
          },
          room,
        ),
      );
      await waitForCount(8);
      expect(timeline.events[0].status, EventStatus.error);
      expect(timeline.events.length, 4);
      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.message',
            'content': {'msgtype': 'm.text', 'body': 'Testcase'},
            'sender': '@alice:example.com',
            'status': EventStatus.synced.intValue,
            'event_id': '\$event',
            'origin_server_ts': testTimeStamp,
            'unsigned': {'transaction_id': 'transaction'},
          },
          room,
        ),
      );
      await waitForCount(9);
      expect(timeline.events[0].status, EventStatus.synced);
      expect(timeline.events.length, 4);
    });
    test('sending an event 0 -> 2 -> -1', () async {
      timeline.events.clear();
      await timeline.requestFuture();
      await timeline.requestFuture();

      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.message',
            'content': {'msgtype': 'm.text', 'body': 'Testcase'},
            'sender': '@alice:example.com',
            'status': EventStatus.sending.intValue,
            'event_id': 'transaction',
            'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
          },
          room,
        ),
      );
      await waitForCount(7);
      expect(timeline.events[0].status, EventStatus.sending);
      expect(timeline.events.length, 4);
      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.message',
            'content': {'msgtype': 'm.text', 'body': 'Testcase'},
            'sender': '@alice:example.com',
            'status': EventStatus.synced.intValue,
            'event_id': '\$event',
            'origin_server_ts': testTimeStamp,
            'unsigned': {'transaction_id': 'transaction'},
          },
          room,
        ),
      );
      await waitForCount(8);
      expect(timeline.events[0].status, EventStatus.synced);
      expect(timeline.events.length, 4);
      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.message',
            'content': {'msgtype': 'm.text', 'body': 'Testcase'},
            'sender': '@alice:example.com',
            'status': EventStatus.error.intValue,
            'origin_server_ts': testTimeStamp,
            'unsigned': {'transaction_id': 'transaction'},
          },
          room,
        ),
      );
      await waitForCount(9);
      expect(timeline.events[0].status, EventStatus.synced);
      expect(timeline.events.length, 4);
    });
    test('logout', () async {
      await client.logout();
    });
  });
}
