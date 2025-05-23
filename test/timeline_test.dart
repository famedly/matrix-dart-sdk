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
import 'dart:math';

import 'package:test/test.dart';

import 'package:matrix/matrix.dart';
import 'package:matrix/src/models/timeline_chunk.dart';
import 'fake_client.dart';

void main() {
  group('Timeline', tags: 'olm', () {
    Logs().level = Level.error;
    final roomID = '!1234:example.com';
    var testTimeStamp = 0;
    var updateCount = 0;
    final insertList = <int>[];
    final changeList = <int>[];
    final removeList = <int>[];
    var currentPoison = 0;

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
      await client.abortSync();

      final poison = Random().nextInt(2 ^ 32);
      currentPoison = poison;

      room = Room(
        id: roomID,
        client: client,
        roomAccountData: {},
        prev_batch: 'room_preset_1234',
      );
      timeline = Timeline(
        room: room,
        chunk: TimelineChunk(events: []),
        onUpdate: () {
          if (poison != currentPoison) return;
          updateCount++;
          countStream.add(updateCount);
        },
        onInsert: insertList.add,
        onChange: changeList.add,
        onRemove: removeList.add,
      );
      client.rooms.add(room);

      await client.checkHomeserver(
        Uri.parse('https://fakeserver.notexisting'),
        checkWellKnown: false,
      );
      await client.abortSync();

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

    test('Create', () async {
      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.message',
            'content': {'msgtype': 'm.text', 'body': 'Testcase'},
            'sender': '@alice:example.com',
            'status': EventStatus.synced.intValue,
            'event_id': '2',
            'origin_server_ts': testTimeStamp - 1000,
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
            'event_id': '\$1',
            'origin_server_ts': testTimeStamp,
          },
          room,
        ),
      );

      expect(timeline.timelineSub != null, true);
      expect(timeline.historySub != null, true);

      await waitForCount(2);

      expect(updateCount, 2);
      expect(insertList, [0, 0]);
      expect(insertList.length, timeline.events.length);
      expect(changeList, []);
      expect(removeList, []);
      expect(timeline.events.length, 2);
      expect(timeline.events[0].eventId, '\$1');
      expect(
        timeline.events[0].senderFromMemoryOrFallback.id,
        '@alice:example.com',
      );
      expect(
        timeline.events[0].originServerTs.millisecondsSinceEpoch,
        testTimeStamp,
      );
      expect(timeline.events[0].body, 'Testcase');
      expect(
        timeline.events[0].originServerTs.millisecondsSinceEpoch >
            timeline.events[1].originServerTs.millisecondsSinceEpoch,
        true,
      );
      expect(timeline.events[0].receipts, []);

      await client.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              timeline.room.id: JoinedRoomUpdate(
                ephemeral: [
                  BasicEvent.fromJson({
                    'type': 'm.receipt',
                    'content': {
                      timeline.events.first.eventId: {
                        'm.read': {
                          '@alice:example.com': {
                            'ts': 1436451550453,
                          },
                        },
                      },
                    },
                  }),
                ],
              ),
            },
          ),
        ),
      );

      await Future.delayed(Duration(milliseconds: 50));

      expect(timeline.events[0].receipts.length, 1);
      expect(timeline.events[0].receipts[0].user.id, '@alice:example.com');

      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.redaction',
            'content': {'reason': 'spamming'},
            'sender': '@alice:example.com',
            'redacts': '2',
            'event_id': '3',
            'origin_server_ts': testTimeStamp + 1000,
          },
          room,
        ),
      );

      await waitForCount(3);

      expect(updateCount, 3);
      expect(insertList, [0, 0, 0]);
      expect(insertList.length, timeline.events.length);
      expect(changeList, [2]);
      expect(removeList, []);
      expect(timeline.events.length, 3);
      expect(timeline.events[2].redacted, true);
    });

    test('Receipt updates', () async {
      await client.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              timeline.room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent.fromJson({
                      'type': 'm.room.message',
                      'content': {'msgtype': 'm.text', 'body': 'Testcase'},
                      'sender': '@alice:example.com',
                      'status': EventStatus.synced.intValue,
                      'event_id': '\$2',
                      'origin_server_ts': testTimeStamp - 1000,
                    }),
                    MatrixEvent.fromJson({
                      'type': 'm.room.message',
                      'content': {'msgtype': 'm.text', 'body': 'Testcase'},
                      'sender': '@alice:example.com',
                      'status': EventStatus.synced.intValue,
                      'event_id': '\$1',
                      'origin_server_ts': testTimeStamp,
                    }),
                    MatrixEvent.fromJson({
                      'type': 'm.room.message',
                      'content': {'msgtype': 'm.text', 'body': 'Testcase'},
                      'sender': '@bob:example.com',
                      'status': EventStatus.synced.intValue,
                      'event_id': '\$0',
                      'origin_server_ts': testTimeStamp + 50,
                    }),
                  ],
                ),
              ),
            },
          ),
        ),
      );

      expect(timeline.timelineSub != null, true);
      expect(timeline.historySub != null, true);

      await waitForCount(3);

      expect(updateCount, 3);
      expect(insertList, [0, 0, 0]);
      expect(insertList.length, timeline.events.length);
      expect(
        timeline.events[1].senderFromMemoryOrFallback.id,
        '@alice:example.com',
      );
      expect(
        timeline.events[0].senderFromMemoryOrFallback.id,
        '@bob:example.com',
      );
      expect(timeline.events[0].receipts, []);
      expect(timeline.events[1].receipts, []);
      expect(timeline.events[2].receipts, []);

      await client.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              timeline.room.id: JoinedRoomUpdate(
                ephemeral: [
                  BasicEvent.fromJson({
                    'type': 'm.receipt',
                    'content': {
                      '\$2': {
                        'm.read': {
                          '@alice:example.com': {
                            'ts': 1436451550453,
                          },
                        },
                      },
                    },
                  }),
                ],
              ),
            },
          ),
        ),
      );

      expect(room.receiptState.global.latestOwnReceipt?.eventId, null);
      expect(
        room.receiptState.global.otherUsers['@alice:example.com']?.eventId,
        '\$2',
      );
      expect(timeline.events[2].receipts.length, 1);
      expect(timeline.events[2].receipts[0].user.id, '@alice:example.com');

      await client.handleSync(
        SyncUpdate(
          nextBatch: 'something2',
          rooms: RoomsUpdate(
            join: {
              timeline.room.id: JoinedRoomUpdate(
                ephemeral: [
                  BasicEvent.fromJson({
                    'type': 'm.receipt',
                    'content': {
                      '\$2': {
                        'm.read': {
                          client.userID: {
                            'ts': 1436451550453,
                          },
                          '@bob:example.com': {
                            'ts': 1436451550453,
                          },
                        },
                      },
                    },
                  }),
                ],
              ),
            },
          ),
        ),
      );

      expect(room.receiptState.global.latestOwnReceipt?.eventId, '\$2');
      expect(room.receiptState.global.ownPublic?.eventId, '\$2');
      expect(room.receiptState.global.ownPrivate?.eventId, null);
      expect(
        room.receiptState.global.otherUsers['@alice:example.com']?.eventId,
        '\$2',
      );
      expect(
        room.receiptState.global.otherUsers['@bob:example.com']?.eventId,
        '\$2',
      );
      expect(timeline.events[2].receipts.length, 3);
      expect(timeline.events[2].receipts[0].user.id, '@alice:example.com');

      await client.handleSync(
        SyncUpdate(
          nextBatch: 'something3',
          rooms: RoomsUpdate(
            join: {
              timeline.room.id: JoinedRoomUpdate(
                ephemeral: [
                  BasicEvent.fromJson({
                    'type': 'm.receipt',
                    'content': {
                      '\$2': {
                        'm.read.private': {
                          client.userID: {
                            'ts': 1436451550453,
                          },
                          '@alice:example.com': {
                            'ts': 1436451550453,
                          },
                        },
                        'm.read': {
                          '@bob:example.com': {
                            'ts': 1436451550453,
                            'thread_id': '\$734',
                          },
                        },
                      },
                    },
                  }),
                ],
              ),
            },
          ),
        ),
      );

      expect(room.receiptState.global.latestOwnReceipt?.eventId, '\$2');
      expect(room.receiptState.global.ownPublic?.eventId, '\$2');
      expect(room.receiptState.global.ownPrivate?.eventId, '\$2');
      expect(
        room.receiptState.global.otherUsers['@alice:example.com']?.eventId,
        '\$2',
      );
      expect(
        room.receiptState.global.otherUsers['@bob:example.com']?.eventId,
        '\$2',
      );
      expect(room.receiptState.byThread.length, 1);
      expect(timeline.events[2].receipts.length, 3);
      expect(timeline.events[2].receipts[0].user.id, '@alice:example.com');

      await client.handleSync(
        SyncUpdate(
          nextBatch: 'something4',
          rooms: RoomsUpdate(
            join: {
              timeline.room.id: JoinedRoomUpdate(
                ephemeral: [
                  BasicEvent.fromJson({
                    'type': 'm.receipt',
                    'content': {
                      '\$1': {
                        'm.read.private': {
                          client.userID: {
                            'ts': 1436451550453,
                          },
                          '@bob:example.com': {
                            'ts': 1436451550453,
                          },
                        },
                      },
                    },
                  }),
                ],
              ),
            },
          ),
        ),
      );

      expect(room.receiptState.global.latestOwnReceipt?.eventId, '\$1');
      expect(room.receiptState.global.ownPublic?.eventId, '\$2');
      expect(room.receiptState.global.ownPrivate?.eventId, '\$1');
      expect(
        room.receiptState.global.otherUsers['@alice:example.com']?.eventId,
        '\$2',
      );
      expect(
        room.receiptState.global.otherUsers['@bob:example.com']?.eventId,
        '\$1',
      );
      expect(room.receiptState.byThread.length, 1);
      expect(timeline.events[1].receipts.length, 2);
      expect(timeline.events[1].receipts[0].user.id, '@bob:example.com');

      // test receipt only on main thread
      expect(timeline.events[2].receipts.length, 1);
      await client.handleSync(
        SyncUpdate(
          nextBatch: 'something5',
          rooms: RoomsUpdate(
            join: {
              timeline.room.id: JoinedRoomUpdate(
                ephemeral: [
                  BasicEvent.fromJson({
                    'type': 'm.receipt',
                    'content': {
                      '\$2': {
                        'm.read': {
                          '@eve:example.com': {
                            'ts': 1436451550453,
                            'thread_id': 'main',
                          },
                          '@john:example.com': {
                            'ts': 1436451550453,
                            'thread_id': 'main',
                          },
                        },
                      },
                    },
                  }),
                ],
              ),
            },
          ),
        ),
      );

      expect(
        room.receiptState.global.otherUsers['@eve:example.com']?.eventId,
        null,
      );
      expect(
        room.receiptState.mainThread?.otherUsers['@eve:example.com']?.eventId,
        '\$2',
      );
      expect(timeline.events[1].receipts.length, 2);
      expect(timeline.events[2].receipts.length, 3);

      // test own receipt on main thread

      await client.handleSync(
        SyncUpdate(
          nextBatch: 'something6',
          rooms: RoomsUpdate(
            join: {
              timeline.room.id: JoinedRoomUpdate(
                ephemeral: [
                  BasicEvent.fromJson({
                    'type': 'm.receipt',
                    'content': {
                      '\$2': {
                        'm.read': {
                          client.userID: {
                            'ts': 1436451550453,
                            'thread_id': 'main',
                          },
                        },
                      },
                    },
                  }),
                ],
              ),
            },
          ),
        ),
      );
      expect(room.receiptState.global.latestOwnReceipt?.eventId, '\$1');
      expect(room.receiptState.mainThread?.latestOwnReceipt?.eventId, '\$2');
      expect(room.receiptState.global.ownPublic?.eventId, '\$2');
      expect(room.receiptState.mainThread?.ownPublic?.eventId, '\$2');
      expect(room.receiptState.global.ownPrivate?.eventId, '\$1');
      expect(timeline.events[2].receipts.length, 3);
    });

    test('Sending both receipts at the same time sets the latest receipt',
        () async {
      await client.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              timeline.room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent.fromJson({
                      'type': 'm.room.message',
                      'content': {'msgtype': 'm.text', 'body': 'Testcase'},
                      'sender': '@alice:example.com',
                      'status': EventStatus.synced.intValue,
                      'event_id': '\$2',
                      'origin_server_ts': testTimeStamp - 1000,
                    }),
                  ],
                ),
                ephemeral: [
                  BasicEvent.fromJson({
                    'type': 'm.receipt',
                    'content': {
                      '\$2': {
                        'm.read': {
                          client.userID: {
                            'ts': 1436451550453,
                          },
                        },
                        'm.read.private': {
                          client.userID: {
                            'ts': 1436451550453,
                          },
                        },
                      },
                    },
                  }),
                ],
              ),
            },
          ),
        ),
      );

      expect(timeline.timelineSub != null, true);
      expect(timeline.historySub != null, true);

      await waitForCount(1);

      expect(room.receiptState.global.latestOwnReceipt?.eventId, '\$2');
      expect(room.receiptState.global.ownPublic?.eventId, '\$2');
      expect(room.receiptState.global.ownPrivate?.eventId, '\$2');
    });

    test('Send message', () async {
      await room.sendTextEvent('test', txid: '1234');

      await waitForCount(2);
      expect(updateCount, 2);
      expect(insertList, [0]);
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

      await waitForCount(3);
      expect(updateCount, 3);
      expect(insertList, [0]);
      expect(insertList.length, timeline.events.length);
      expect(timeline.events[0].eventId, eventId);
      expect(timeline.events[0].status, EventStatus.synced);
    });

    test('Send message with error', () async {
      client.onTimelineEvent.add(
        Event.fromJson(
          {
            'type': 'm.room.message',
            'content': {
              'msgtype': 'm.text',
              'body': 'Testcase should not show up in Sync',
            },
            'sender': '@alice:example.com',
            'status': EventStatus.sending.intValue,
            'event_id': 'abc',
            'origin_server_ts': testTimeStamp,
          },
          room,
        ),
      );
      await waitForCount(1);

      await room.sendTextEvent('test', txid: 'errortxid');
      await waitForCount(3);

      await room.sendTextEvent('test', txid: 'errortxid2');
      await waitForCount(5);
      await room.sendTextEvent('test', txid: 'errortxid3');
      await waitForCount(7);

      expect(updateCount, 7);
      expect(insertList, [0, 0, 1, 2]);
      expect(insertList.length, timeline.events.length);
      expect(changeList, [0, 1, 2]);
      expect(removeList, []);
      expect(timeline.events[0].status, EventStatus.error);
      expect(timeline.events[1].status, EventStatus.error);
      expect(timeline.events[2].status, EventStatus.error);
    });

    test('Remove message', () async {
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
      await waitForCount(1);

      await timeline.events[0].cancelSend();

      await waitForCount(2);

      expect(insertList, [0]);
      expect(changeList, []);
      expect(removeList, [0]);
      expect(timeline.events.length, 0);
    });

    test('getEventById', () async {
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
      await waitForCount(1);
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
      await waitForCount(1);
      expect(timeline.events[0].status, EventStatus.error);
      await timeline.events[0].sendAgain();

      await waitForCount(3);

      expect(updateCount, 3);

      expect(insertList, [0]);
      expect(changeList, [0, 0]);
      expect(removeList, []);
      expect(timeline.events.length, 1);
      expect(timeline.events[0].status, EventStatus.sent);
    });

    test('Request history', () async {
      timeline.events.clear();
      expect(timeline.canRequestHistory, true);
      await room.requestHistory();

      await waitForCount(3);

      expect(updateCount, 3);
      expect(insertList, [0, 1, 2]);
      expect(timeline.events.length, 3);
      expect(timeline.events[0].eventId, '3143273582443PhrSn:example.org');
      expect(timeline.events[1].eventId, '2143273582443PhrSn:example.org');
      expect(timeline.events[2].eventId, '1143273582443PhrSn:example.org');
      expect(room.prev_batch, 't47409-4357353_219380_26003_2265');
      await timeline.events[2].redactEvent(reason: 'test', txid: '1234');
    });

    test('Clear cache on limited timeline', () async {
      client.onSync.add(
        SyncUpdate(
          nextBatch: '1234',
          rooms: RoomsUpdate(
            join: {
              roomID: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  limited: true,
                  prevBatch: 'blah',
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
      await Future.delayed(Duration(milliseconds: 50));
      expect(timeline.events.isEmpty, true);
    });

    test('sort errors on top', () async {
      timeline.events.clear();
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
      await Future.delayed(Duration(milliseconds: 50));
      expect(timeline.events[0].status, EventStatus.error);
      expect(timeline.events[1].status, EventStatus.synced);
    });

    test('sending event to failed update', () async {
      timeline.events.clear();
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
      await Future.delayed(Duration(milliseconds: 50));
      expect(timeline.events[0].status, EventStatus.sending);
      expect(timeline.events.length, 1);
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
      await Future.delayed(Duration(milliseconds: 50));
      expect(timeline.events[0].status, EventStatus.error);
      expect(timeline.events.length, 1);
    });
    test('setReadMarker', () async {
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
      await Future.delayed(Duration(milliseconds: 50));
      room.notificationCount = 1;
      await timeline.setReadMarker();
      //expect(room.notificationCount, 0);
    });
    test('sending an event and the http request finishes first, 0 -> 1 -> 2',
        () async {
      timeline.events.clear();
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
      await Future.delayed(Duration(milliseconds: 50));
      expect(timeline.events[0].status, EventStatus.sending);
      expect(timeline.events.length, 1);
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
      await Future.delayed(Duration(milliseconds: 50));
      expect(timeline.events[0].status, EventStatus.sent);
      expect(timeline.events.length, 1);
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
      await Future.delayed(Duration(milliseconds: 50));
      expect(timeline.events[0].status, EventStatus.synced);
      expect(timeline.events.length, 1);
    });
    test('sending an event where the sync reply arrives first, 0 -> 2 -> 1',
        () async {
      timeline.events.clear();
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
      await Future.delayed(Duration(milliseconds: 50));
      expect(timeline.events[0].status, EventStatus.sending);
      expect(timeline.events.length, 1);
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
      await Future.delayed(Duration(milliseconds: 50));
      expect(timeline.events[0].status, EventStatus.synced);
      expect(timeline.events.length, 1);
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
      await Future.delayed(Duration(milliseconds: 50));
      expect(timeline.events[0].status, EventStatus.synced);
      expect(timeline.events.length, 1);
    });
    test('sending an event 0 -> -1 -> 2', () async {
      timeline.events.clear();
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
      await Future.delayed(Duration(milliseconds: 50));
      expect(timeline.events[0].status, EventStatus.sending);
      expect(timeline.events.length, 1);
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
      await Future.delayed(Duration(milliseconds: 50));
      expect(timeline.events[0].status, EventStatus.error);
      expect(timeline.events.length, 1);
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
      await Future.delayed(Duration(milliseconds: 50));
      expect(timeline.events[0].status, EventStatus.synced);
      expect(timeline.events.length, 1);
    });
    test('sending an event 0 -> 2 -> -1', () async {
      timeline.events.clear();
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
      await Future.delayed(Duration(milliseconds: 50));
      expect(timeline.events[0].status, EventStatus.sending);
      expect(timeline.events.length, 1);
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
      await Future.delayed(Duration(milliseconds: 50));
      expect(timeline.events[0].status, EventStatus.synced);
      expect(timeline.events.length, 1);
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
      await Future.delayed(Duration(milliseconds: 50));
      expect(timeline.events[0].status, EventStatus.synced);
      expect(timeline.events.length, 1);
    });

    test('make sure aggregated events are updated on requestHistory', () async {
      timeline.events.clear();
      await client.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              timeline.room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent.fromJson({
                      'type': 'm.room.message',
                      'content': {'msgtype': 'm.text', 'body': 'Testcase'},
                      'event_id': '11',
                      'sender': '@alice:example.com',
                      'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
                    }),
                    MatrixEvent.fromJson({
                      'type': 'm.room.message',
                      'content': {'msgtype': 'm.text', 'body': 'Testcase'},
                      'event_id': '22',
                      'sender': '@alice:example.com',
                      'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
                    }),
                    MatrixEvent.fromJson({
                      'type': 'm.room.message',
                      'content': {
                        'msgtype': 'm.text',
                        'body': '* edit 11',
                        'm.new_content': {
                          'msgtype': 'm.text',
                          'body': 'edit 11',
                          'm.mentions': {},
                        },
                        'm.mentions': {},
                        'm.relates_to': {
                          'rel_type': 'm.replace',
                          'event_id': '11',
                        },
                      },
                      'event_id': '33',
                      'sender': '@alice:example.com',
                      'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
                    }),
                    MatrixEvent.fromJson({
                      'type': 'm.room.message',
                      'content': {
                        'msgtype': 'm.text',
                        'body': '* edit 22',
                        'm.new_content': {
                          'msgtype': 'm.text',
                          'body': 'edit 22',
                          'm.mentions': {},
                        },
                        'm.mentions': {},
                        'm.relates_to': {
                          'rel_type': 'm.replace',
                          'event_id': '22',
                        },
                      },
                      'event_id': '44',
                      'sender': '@alice:example.com',
                      'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
                    }),
                  ],
                ),
              ),
            },
          ),
        ),
      );

      final t = await room.getTimeline(limit: 1);

      expect(t.events.length, 1);

      expect(
        t.events.single.getDisplayEvent(t).body,
        '* edit 22',
      );

      await t.requestHistory();

      expect(
        t.events.reversed
            .where(
              (element) => element.relationshipType != RelationshipTypes.edit,
            )
            .last
            .getDisplayEvent(t)
            .body,
        'edit 22',
      );
      expect(
        t.events.reversed
            .where(
              (element) => element.relationshipType != RelationshipTypes.edit,
            )
            .first
            .getDisplayEvent(t)
            .body,
        'edit 11',
      );
    });

    test('make sure timeline with null prev_batch is not reset incorrectly',
        () async {
      timeline.events.clear();
      timeline.room.prev_batch = null;

      Timeline t = await room.getTimeline();
      expect(t.events.length, 0);
      expect(t.room.prev_batch, null);

      await client.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              timeline.room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  prevBatch: 'room_preset_1234',
                  events: [
                    MatrixEvent.fromJson({
                      'type': 'm.room.message',
                      'content': {'msgtype': 'm.text', 'body': 'Testcase 3'},
                      'event_id': '33',
                      'sender': '@alice:example.com',
                      'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
                    }),
                    MatrixEvent.fromJson({
                      'type': 'm.room.message',
                      'content': {'msgtype': 'm.text', 'body': 'Testcase 4'},
                      'event_id': '44',
                      'sender': '@alice:example.com',
                      'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
                    }),
                  ],
                ),
              ),
            },
          ),
        ),
      );

      t = await room.getTimeline();
      expect(t.events.length, 2);
      expect(
        t.room.prev_batch,
        null,
        reason:
            'The prev_batch is null, which means that no earlier events are available. Having a new prev_batch is sync shouldn\'t reset it.',
      );
    });

    test('make sure room prev_batch is set correctly when invited', () async {
      final newRoomId1 = '!newroom:example.com';
      final newRoomId2 = '!newroom2:example.com';

      await client.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            invite: {
              newRoomId1: InvitedRoomUpdate(
                inviteState: [
                  StrippedStateEvent(
                    type: EventTypes.RoomMember,
                    senderId: '@bob:example.com',
                    stateKey: client.userID,
                    content: {
                      'membership': 'invite',
                    },
                  ),
                ],
              ),
              newRoomId2: InvitedRoomUpdate(
                inviteState: [
                  StrippedStateEvent(
                    type: EventTypes.RoomMember,
                    senderId: '@bob:example.com',
                    stateKey: client.userID,
                    content: {
                      'membership': 'invite',
                    },
                  ),
                ],
              ),
            },
          ),
        ),
      );

      Room? newRoom1 = client.getRoomById(newRoomId1);
      expect(newRoom1?.membership, Membership.invite);
      expect(newRoom1?.prev_batch, null);

      Room? newRoom2 = client.getRoomById(newRoomId2);
      expect(newRoom2?.membership, Membership.invite);
      expect(newRoom2?.prev_batch, null);

      await client.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              newRoomId1: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  prevBatch:
                      null, // this means that no earlier events are available
                  events: [
                    MatrixEvent.fromJson({
                      'type': 'm.room.message',
                      'content': {'msgtype': 'm.text', 'body': 'Testcase'},
                      'event_id': '33',
                      'sender': '@alice:example.com',
                      'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
                    }),
                  ],
                ),
              ),
              newRoomId2: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  prevBatch: 'actual_prev_batch',
                  events: [
                    MatrixEvent.fromJson({
                      'type': 'm.room.message',
                      'content': {'msgtype': 'm.text', 'body': 'Testcase'},
                      'event_id': '33',
                      'sender': '@alice:example.com',
                      'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
                    }),
                  ],
                ),
              ),
            },
          ),
        ),
      );

      newRoom1 = client.getRoomById(newRoomId1);
      expect(newRoom1?.membership, Membership.join);
      expect(newRoom1?.prev_batch, null);

      newRoom2 = client.getRoomById(newRoomId2);
      expect(newRoom2?.membership, Membership.join);
      expect(newRoom2?.prev_batch, 'actual_prev_batch');
    });

    test('make sure a limited timeline resets the prev_batch', () async {
      timeline.events.clear();
      expect(timeline.room.prev_batch, 'room_preset_1234');

      await client.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              timeline.room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  prevBatch: 'room_preset_5678',
                  events: [
                    MatrixEvent.fromJson({
                      'type': 'm.room.message',
                      'content': {'msgtype': 'm.text', 'body': 'Testcase'},
                      'event_id': '11',
                      'sender': '@alice:example.com',
                      'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
                    }),
                    MatrixEvent.fromJson({
                      'type': 'm.room.message',
                      'content': {'msgtype': 'm.text', 'body': 'Testcase'},
                      'event_id': '22',
                      'sender': '@alice:example.com',
                      'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
                    }),
                  ],
                ),
              ),
            },
          ),
        ),
      );

      Timeline t = await room.getTimeline();

      expect(t.events.length, 2);
      expect(
        t.room.prev_batch,
        'room_preset_1234',
        reason:
            'The prev_batch should only be set the first time and be updated when requesting history. It shouldn\'t be updated every sync incorrectly.',
      );

      await client.handleSync(
        SyncUpdate(
          nextBatch: 'something2',
          rooms: RoomsUpdate(
            join: {
              timeline.room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  prevBatch: 'room_preset_1234_after_limited',
                  limited: true,
                  events: [
                    MatrixEvent.fromJson({
                      'type': 'm.room.message',
                      'content': {
                        'msgtype': 'm.text',
                        'body': '* edit 11',
                        'm.new_content': {
                          'msgtype': 'm.text',
                          'body': 'edit 11',
                          'm.mentions': {},
                        },
                        'm.mentions': {},
                        'm.relates_to': {
                          'rel_type': 'm.replace',
                          'event_id': '11',
                        },
                      },
                      'event_id': '33',
                      'sender': '@alice:example.com',
                      'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
                    }),
                    MatrixEvent.fromJson({
                      'type': 'm.room.message',
                      'content': {
                        'msgtype': 'm.text',
                        'body': '* edit 22',
                        'm.new_content': {
                          'msgtype': 'm.text',
                          'body': 'edit 22',
                          'm.mentions': {},
                        },
                        'm.mentions': {},
                        'm.relates_to': {
                          'rel_type': 'm.replace',
                          'event_id': '22',
                        },
                      },
                      'event_id': '44',
                      'sender': '@alice:example.com',
                      'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
                    }),
                  ],
                ),
              ),
            },
          ),
        ),
      );

      t = await room.getTimeline();
      expect(t.events.length, 2);
      expect(t.room.prev_batch, 'room_preset_1234_after_limited');
      await t.requestHistory();
      expect(t.room.prev_batch, 't47409-4357353_219380_26003_2265');
    });
    test('logout', () async {
      await client.logout();
    });
  });
}
