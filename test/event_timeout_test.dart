import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:test/test.dart';

import 'package:matrix/matrix.dart';
import 'fake_client.dart';

void main() {
  group('Event timeout tests', () {
    late Client client;
    late Room room;

    setUp(() async {
      client = await getClient(
        sendTimelineEventTimeout: const Duration(seconds: 5),
        databasePath: join(Directory.current.path, 'test.sqlite'),
      );
      room = Room(
        id: '!1234:example.com',
        client: client,
        roomAccountData: {},
      );
      client.rooms.add(room);
    });

    tearDown(() async {
      await client.logout();
      await client.dispose(closeDatabase: true);
    });

    test('Event constructor correctly checks timeout from originServerTs',
        () async {
      final completer = Completer();
      room.sendingQueue.add(completer); // to block the events from being sent

      String? eventId;
      // we don't await this because the actual sending will only be done after
      // `sendingQueue` is unblocked.
      // but the fake sync will be called with this event in sending state right away
      unawaited(
        room.sendTextEvent('test', txid: '1234').then((value) {
          eventId = value;
        }),
      );

      // do the timeout
      final timeout =
          Duration(seconds: client.sendTimelineEventTimeout.inSeconds + 2);
      await Future.delayed(timeout);

      // this will trigger the check in the Event constructor to see if the
      // event is in error state (and call fake sync with updated error status)
      await client.oneShotSync();
      Timeline timeline = await room.getTimeline();
      expect(timeline.events.length, 1);
      expect(timeline.events.first.status, EventStatus.sending);

      // fake sync would have been triggered by now (if there was one), which shouldn't happen
      await client.oneShotSync();
      timeline = await room.getTimeline();
      expect(timeline.events.length, 1);
      expect(timeline.events.first.status, EventStatus.sending);

      // now we unblock the sending queue and this will make `sendTextEvent`
      // actually send the event and the fake sync that's used to update the
      // event status to sent
      completer.complete();
      room.sendingQueue.remove(completer);
      await FakeMatrixApi.firstWhere(
        (a) => a.startsWith(
          '/client/v3/rooms/!1234%3Aexample.com/send/m.room.message/1234',
        ),
      );
      await Future.delayed(const Duration(seconds: 1));
      expect(eventId, isNotNull);

      // now the event should be in sent state after the fake sync is called
      await client.oneShotSync();
      timeline = await room.getTimeline();
      expect(timeline.events.length, 1);
      expect(timeline.events.first.status, EventStatus.sent);

      // simulate the event being synced from server
      await client.handleSync(
        SyncUpdate(
          nextBatch: '1',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    Event(
                      eventId: eventId!,
                      content: {'msgtype': 'm.text', 'body': 'test'},
                      type: 'm.room.message',
                      senderId: '@test:example.com',
                      originServerTs: DateTime.now(),
                      room: room,
                      unsigned: {
                        'transaction_id': '1234',
                      },
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );
      timeline = await room.getTimeline();
      expect(timeline.events.length, 1);
      expect(timeline.events.first.status, EventStatus.synced);
    });
  });
}
