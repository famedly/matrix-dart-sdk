import 'package:test/test.dart';

import 'package:matrix/matrix.dart';
import 'package:matrix/src/models/timeline_chunk.dart';

// Mock implementations

// MockClient: Simulates Matrix server responses for `getRoomEvents` calls that
// are used by the `TimelineExportExtension.export` method.
// This also allows testing error scenarios by throwing exceptions on demand.
class MockClient extends Client {
  List<Event> serverEvents, dbEvents;
  final bool throwError;

  MockClient(
    super.name, {
    this.serverEvents = const [],
    this.dbEvents = const [],
    this.throwError = false,
  }) : super(database: MockDatabase(dbEvents));

  @override
  Future<GetRoomEventsResponse> getRoomEvents(
    String roomId,
    Direction direction, {
    String? from,
    String? to,
    int? limit,
    String? filter,
  }) async {
    if (throwError) {
      throw MatrixException.fromJson({'errcode': 'M_FORBIDDEN'});
    }

    final chunk = serverEvents
        .skip(int.parse(from ?? '0'))
        .take(limit ?? serverEvents.length)
        .toList();
    return GetRoomEventsResponse(
      chunk: chunk,
      start: from ?? '0',
      end: chunk.isEmpty
          ? '0'
          : (serverEvents.indexOf(chunk.last) + 1).toString(),
      state: [],
    );
  }

  @override
  DatabaseApi get database => MockDatabase(dbEvents);
}

// MockDatabase: Simulates database access for the `TimelineExportExtension.export`
// method.
class MockDatabase implements DatabaseApi {
  final List<Event> dbEvents;

  MockDatabase(this.dbEvents);

  @override
  Future<List<Event>> getEventList(
    Room room, {
    int start = 0,
    int? limit,
    bool onlySending = false,
  }) async {
    if (start >= dbEvents.length) return [];
    return dbEvents.skip(start).take(limit ?? 50).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Test helpers
Event createTestEvent({
  required String eventId,
  required String type,
  required String msgtype,
  required DateTime timestamp,
  required Room room,
}) {
  return Event(
    eventId: eventId,
    type: type,
    content: {
      'msgtype': msgtype,
      'body': 'Test message $eventId',
    },
    senderId: '@user:example.com',
    originServerTs: timestamp,
    room: room,
    status: EventStatus.synced,
  );
}

List<Event> createMockEvents({
  required int count,
  required DateTime startTime,
  required Room room,
}) {
  return List.generate(
    count,
    (i) => createTestEvent(
      eventId: 'event$i',
      type: i % 3 == 0 ? EventTypes.Message : EventTypes.Encrypted,
      msgtype: i % 3 == 0 ? MessageTypes.Text : MessageTypes.BadEncrypted,
      timestamp: startTime.subtract(Duration(hours: i)),
      room: room,
    ),
  );
}

void main() {
  group('TimelineExportExtension', () {
    late DateTime now;
    late MockClient client;
    late Room room;
    late Timeline timeline;

    setUp(() {
      now = DateTime.now();
      client = MockClient('testclient');
      room = Room(id: '!testroom:example.com', client: client);
      timeline = Timeline(room: room, chunk: TimelineChunk(events: []));
    });

    group('basic export functionality', () {
      late List<Event> mockEvents;

      setUp(() {
        mockEvents = createMockEvents(count: 20, startTime: now, room: room);

        // Set up initial state
        timeline.events.addAll(mockEvents.take(5));
        client.dbEvents = mockEvents.take(10).toList();
        client.serverEvents = mockEvents;
        room.prev_batch = '10';
      });

      test('exports events from all sources in correct order', () async {
        final results = <ExportResult>[];
        await for (final result in timeline.export()) {
          results.add(result);
        }

        expect(results.whereType<ExportProgress>().length, greaterThan(1));
        expect(results.first, isA<ExportProgress>());
        expect(results.last, isA<ExportComplete>());

        final complete = results.last as ExportComplete;
        expect(complete.events.length, mockEvents.length);
        expect(
          complete.events.map((e) => e.eventId).toSet(),
          mockEvents.map((e) => e.eventId).toSet(),
        );

        // Verify events are in chronological order
        for (int i = 1; i < complete.events.length; i++) {
          expect(
            complete.events[i].originServerTs
                    .isBefore(complete.events[i - 1].originServerTs) ||
                complete.events[i].originServerTs
                    .isAtSameMomentAs(complete.events[i - 1].originServerTs),
            isTrue,
            reason: 'Events should be in reverse chronological order',
          );
        }
      });

      test('filters events by date range correctly', () async {
        final from = now.subtract(const Duration(hours: 8, seconds: 1));
        final until = now.subtract(const Duration(hours: 3, seconds: 1));

        final results = <ExportResult>[];
        await for (final result in timeline.export(from: from, until: until)) {
          results.add(result);
        }

        final complete = results.last as ExportComplete;

        expect(
          complete.events.every(
            (e) =>
                e.originServerTs.isAfter(from) &&
                e.originServerTs.isBefore(until),
          ),
          isTrue,
        );
      });
    });

    group('pagination handling', () {
      test('handles server pagination with large event sets', () async {
        final manyServerEvents = createMockEvents(
          count: 150,
          startTime: now.subtract(const Duration(hours: 10)),
          room: room,
        );

        client = MockClient('testclient', serverEvents: manyServerEvents);
        room = Room(id: '!testroom:example.com', client: client);
        timeline = Timeline(
          room: room,
          chunk: TimelineChunk(events: manyServerEvents.take(10).toList()),
        );
        room.prev_batch = '10';

        final results = <ExportResult>[];
        var serverProgressUpdates = 0;
        var lastTotalEvents = 0;

        await for (final result in timeline.export(requestHistoryCount: 100)) {
          results.add(result);
          if (result is ExportProgress &&
              result.source == ExportSource.server) {
            serverProgressUpdates++;
            expect(result.totalEvents, greaterThanOrEqualTo(lastTotalEvents));
            lastTotalEvents = result.totalEvents;
          }
        }

        final complete = results.last as ExportComplete;
        expect(complete.events.length, 150);
        expect(serverProgressUpdates, equals(2));
        expect(
          complete.events.map((e) => e.eventId).toSet(),
          manyServerEvents.map((e) => e.eventId).toSet(),
        );
      });
    });

    group('error handling', () {
      test('continues export when server returns error', () async {
        client = MockClient('testclient', throwError: true);
        room = Room(id: '!testroom:example.com', client: client);
        final initialEvents =
            createMockEvents(count: 5, startTime: now, room: room);
        client.dbEvents = initialEvents;
        client.serverEvents = initialEvents;
        timeline = Timeline(
          room: room,
          chunk: TimelineChunk(events: initialEvents),
        );
        room.prev_batch = '5';

        final results = <ExportResult>[];

        await for (final result in timeline.export()) {
          results.add(result);

          if (result is ExportProgress) {
            switch (result.source) {
              case ExportSource.timeline:
                expect(
                  result.totalEvents == 0 || result.totalEvents == 5,
                  isTrue,
                );
                break;
              case ExportSource.database:
                break;
              case ExportSource.server:
                // Should not see server progress due to error
                fail(
                  'Should not receive server progress updates when server throws error',
                );
            }
          }
        }

        final complete = results.last as ExportComplete;
        expect(complete.events.length, 5);
        expect(
          complete.events.map((e) => e.eventId).toSet(),
          initialEvents.map((e) => e.eventId).toSet(),
        );
      });
    });

    group('event type counting', () {
      test('correctly counts media and UTD events', () async {
        final mixedEvents = [
          createTestEvent(
            eventId: 'image1',
            type: EventTypes.Message,
            msgtype: MessageTypes.Image,
            timestamp: now,
            room: room,
          ),
          createTestEvent(
            eventId: 'video1',
            type: EventTypes.Message,
            msgtype: MessageTypes.Video,
            timestamp: now,
            room: room,
          ),
          createTestEvent(
            eventId: 'text1',
            type: EventTypes.Message,
            msgtype: MessageTypes.Text,
            timestamp: now,
            room: room,
          ),
          createTestEvent(
            eventId: 'utd1',
            type: EventTypes.Encrypted,
            msgtype: MessageTypes.BadEncrypted,
            timestamp: now,
            room: room,
          ),
        ];

        client = MockClient('testclient', serverEvents: mixedEvents);
        room = Room(id: '!testroom:example.com', client: client);
        timeline = Timeline(room: room, chunk: TimelineChunk(events: []));
        room.prev_batch = '0';

        final results = <ExportResult>[];
        await for (final result in timeline.export()) {
          results.add(result);
        }

        final complete = results.last as ExportComplete;
        expect(complete.mediaEvents, 2);
        expect(complete.utdEvents, 1);
        expect(complete.events.length, mixedEvents.length);

        final mediaEvents = complete.events.where(
          (e) =>
              e.type == EventTypes.Message &&
              (e.messageType == MessageTypes.Image ||
                  e.messageType == MessageTypes.Video),
        );
        expect(mediaEvents.length, 2);

        final utdEvents = complete.events.where(
          (e) =>
              e.type == EventTypes.Encrypted &&
              e.messageType == MessageTypes.BadEncrypted,
        );
        expect(utdEvents.length, 1);

        final textEvents = complete.events.where(
          (e) =>
              e.type == EventTypes.Message &&
              e.messageType == MessageTypes.Text,
        );
        expect(textEvents.length, 1);
      });
    });
  });
}
