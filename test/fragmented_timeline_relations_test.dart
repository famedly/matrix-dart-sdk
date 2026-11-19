// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:collection/collection.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/models/timeline_chunk.dart';
import 'package:test/test.dart';

import 'fake_client.dart';
import 'fake_database.dart';

// Mirrors an app-defined task: a root event whose status and assignees live
// in relating state events, and which can be edited.
const taskType = 'com.example.task';
const stateRelType = 'com.example.task.state';
const roomId = '!fragmented:example.com';

Map<String, Object?> stateEventJson(
  String eventId,
  String taskEventId,
  String status,
  int ts,
) => {
  'event_id': eventId,
  'type': stateRelType,
  'sender': '@alice:example.com',
  'origin_server_ts': ts,
  'room_id': roomId,
  'content': {
    'status': status,
    'assignees': ['@bob:example.com'],
    'm.relates_to': {'rel_type': stateRelType, 'event_id': taskEventId},
  },
};

Map<String, Object?> taskEventJson(String eventId, int ts) => {
  'event_id': eventId,
  'type': taskType,
  'sender': '@alice:example.com',
  'origin_server_ts': ts,
  'room_id': roomId,
  'content': {'title': 'Task', 'body': '[Task] Task'},
};

String relationsPath(String eventId, String relType) =>
    '/client/v1/rooms/${Uri.encodeComponent(roomId)}/relations/'
    '$eventId/$relType?limit=50';

void stubRelations(
  String eventId,
  String relType,
  Map<String, Object?> Function() response,
) {
  final path = relationsPath(eventId, relType);
  (FakeMatrixApi.currentApi!.api['GET'] ??= {})[path] = (_) => response();
  addTearDown(() => FakeMatrixApi.currentApi!.api['GET']!.remove(path));
}

void stubMessages(
  String from,
  Direction direction,
  List<Map<String, Object?>> chunk,
) {
  final path =
      '/client/v3/rooms/${Uri.encodeComponent(roomId)}/messages'
      '?from=$from&dir=${direction.name}&limit=${Room.defaultHistoryCount}'
      '&filter=%7B%22lazy_load_members%22%3Atrue%7D';
  (FakeMatrixApi.currentApi!.api['GET'] ??= {})[path] = (_) => {
    'start': from,
    'end': '${from}_after',
    'chunk': chunk,
    'state': <Map<String, Object?>>[],
  };
  addTearDown(() => FakeMatrixApi.currentApi!.api['GET']!.remove(path));
}

Map<String, Object?> redactionJson(String redacts) => {
  'event_id': 'redaction_$redacts',
  'type': EventTypes.Redaction,
  'sender': '@alice:example.com',
  'origin_server_ts': 6000,
  'room_id': roomId,
  'redacts': redacts,
  'content': <String, Object?>{},
};

Iterable<String> calledRelationPaths() => FakeMatrixApi.calledEndpoints.keys
    .where((path) => path.contains('/relations/'));

void main() {
  group('Fragmented timeline relations', () {
    late Client client;
    late Room room;

    setUp(() async {
      client = await getClient();
      client.fragmentedTimelineRelations[taskType] = {
        stateRelType,
        RelationshipTypes.edit,
      };
      client.fragmentedTimelineSiblingRelations.add(stateRelType);
      room = Room(
        id: roomId,
        client: client,
        prev_batch: 'prev',
        roomAccountData: {},
      );
      FakeMatrixApi.calledEndpoints.clear();
    });
    tearDown(() async => client.dispose());

    Timeline fragmentedTimeline(
      List<Event> events, {
      void Function()? onUpdate,
      void Function(int)? onChange,
    }) => Timeline(
      room: room,
      chunk: TimelineChunk(
        events: events,
        nextBatch: 'next',
        prevBatch: 'prev',
      ),
      onUpdate: onUpdate,
      onChange: onChange,
    );

    test('poll default is merged into a configured poll entry', () async {
      final configured = {
        PollEventContent.startType: {'com.example.vote'},
      };
      final other = Client(
        'override',
        database: await getDatabase(),
        fragmentedTimelineRelations: configured,
      );
      addTearDown(other.dispose);

      expect(other.fragmentedTimelineRelations[PollEventContent.startType], {
        'com.example.vote',
        RelationshipTypes.reference,
      });
      expect(configured[PollEventContent.startType], {'com.example.vote'});
    });

    test('skips local echoes', () async {
      final timeline = fragmentedTimeline([
        Event.fromJson({
          ...taskEventJson('txid_1', 1000),
          'status': EventStatus.sending.intValue,
        }, room),
      ]);

      await timeline.fetchMissingRelations(timeline.events);

      expect(calledRelationPaths(), isEmpty);
    });

    test('paginating a fragmented timeline fetches relations', () async {
      stubMessages('next', Direction.f, [
        taskEventJson('task_2', 2000),
        stateEventJson('state_9', 'task_9', 'done', 3000),
      ]);
      stubRelations(
        'task_2',
        stateRelType,
        () => {
          'chunk': [stateEventJson('state_2', 'task_2', 'todo', 2500)],
        },
      );
      stubRelations('task_2', RelationshipTypes.edit, () => {'chunk': []});
      stubRelations(
        'task_9',
        stateRelType,
        () => {
          'chunk': [
            stateEventJson('state_9', 'task_9', 'done', 3000),
            stateEventJson('state_8', 'task_9', 'todo', 1500),
          ],
        },
      );
      final changes = <int>[];
      final timeline = fragmentedTimeline([
        Event.fromJson(taskEventJson('task_1', 1000), room),
      ], onChange: changes.add);

      await timeline.getRoomEvents(direction: Direction.f);

      expect(
        timeline.aggregatedEvents['task_2']![stateRelType]!.single.eventId,
        'state_2',
      );
      expect(
        timeline.aggregatedEvents['task_9']![stateRelType]!
            .map((e) => e.eventId)
            .toSet(),
        {'state_8', 'state_9'},
      );
      // task_9 is not loaded, so its siblings report no index.
      expect(changes, everyElement(lessThan(timeline.events.length)));
    });

    test('paginating a live timeline does not fetch relations', () async {
      stubMessages('prev', Direction.b, [
        taskEventJson('task_2', 500),
        stateEventJson('state_9', 'task_9', 'done', 400),
      ]);
      final timeline = Timeline(
        room: room,
        chunk: TimelineChunk(
          events: [Event.fromJson(taskEventJson('task_1', 1000), room)],
          prevBatch: 'prev',
        ),
      );
      expect(timeline.isFragmentedTimeline, false);

      expect(await timeline.getRoomEvents(), 2);

      expect(calledRelationPaths(), isEmpty);
    });

    test(
      'failed fetch does not throw for concurrent callers and can be retried',
      () async {
        var fail = true;
        stubRelations(
          'task_1',
          stateRelType,
          () => fail
              ? {'errcode': 'M_FORBIDDEN', 'error': 'Forbidden'}
              : {
                  'chunk': [stateEventJson('state_1', 'task_1', 'todo', 2000)],
                },
        );
        final timeline = fragmentedTimeline([
          Event.fromJson(taskEventJson('task_1', 1000), room),
        ]);

        await Future.wait([
          timeline.fetchAggregatedEvents('task_1', stateRelType),
          timeline.fetchAggregatedEvents('task_1', stateRelType),
        ]);
        expect(timeline.aggregatedEvents['task_1'], isNull);

        fail = false;
        await timeline.fetchAggregatedEvents('task_1', stateRelType);
        expect(
          timeline.aggregatedEvents['task_1']![stateRelType]!.single.eventId,
          'state_1',
        );
      },
    );

    // Chat opened on a pinned task whose latest state is outside the /context
    // window, then the status is changed on the card.
    test(
      'task card shows latest state and own changes in a context timeline',
      () async {
        final contextPath =
            '/client/v3/rooms/${Uri.encodeComponent(roomId)}/context/task_1'
            '?limit=${Room.defaultHistoryCount}';
        (FakeMatrixApi.currentApi!.api['GET'] ??= {})[contextPath] = (_) => {
          'start': 'ctx_start',
          'end': 'ctx_end',
          'event': taskEventJson('task_1', 1000),
          'events_before': <Map<String, Object?>>[],
          'events_after': <Map<String, Object?>>[],
          'state': <Map<String, Object?>>[],
        };
        addTearDown(
          () => FakeMatrixApi.currentApi!.api['GET']!.remove(contextPath),
        );
        stubRelations(
          'task_1',
          stateRelType,
          () => {
            'chunk': [stateEventJson('state_1', 'task_1', 'in_progress', 2000)],
          },
        );
        stubRelations(
          'task_1',
          RelationshipTypes.edit,
          () => {
            'chunk': [
              {
                'event_id': 'edit_1',
                'type': taskType,
                'sender': '@alice:example.com',
                'origin_server_ts': 4000,
                'room_id': roomId,
                'content': {
                  'm.new_content': {'title': 'Edited'},
                  'm.relates_to': {
                    'rel_type': RelationshipTypes.edit,
                    'event_id': 'task_1',
                  },
                },
              },
            ],
          },
        );
        var updates = 0;
        final timeline = await room.getTimeline(
          eventContextId: 'task_1',
          onUpdate: () => updates++,
        );
        expect(timeline.allowNewEvent, false);

        Event latestState() => timeline
            .aggregatedEvents['task_1']![stateRelType]!
            .sortedBy<num>((e) => e.originServerTs.millisecondsSinceEpoch)
            .last;
        expect(latestState().content['status'], 'in_progress');
        expect(latestState().content['assignees'], ['@bob:example.com']);
        expect(
          timeline
              .aggregatedEvents['task_1']![RelationshipTypes.edit]!
              .single
              .eventId,
          'edit_1',
        );

        // What Room.sendEvent emits: a local echo, then the synced event.
        final changed = stateEventJson('\$state_2', 'task_1', 'done', 3000);
        final updatesBefore = updates;
        client.onTimelineEvent.add(
          Event.fromJson({
            ...changed,
            'event_id': 'txid_2',
            'status': EventStatus.sending.intValue,
            'unsigned': {'transaction_id': 'txid_2'},
          }, room),
        );
        await pumpEventQueue();
        expect(latestState().content['status'], 'done');
        expect(updates, greaterThan(updatesBefore));

        client.onTimelineEvent.add(
          Event.fromJson({
            ...changed,
            'unsigned': {'transaction_id': 'txid_2'},
          }, room),
        );
        await pumpEventQueue();
        expect(
          timeline.aggregatedEvents['task_1']![stateRelType]!.map(
            (e) => e.eventId,
          ),
          unorderedEquals(['state_1', '\$state_2']),
        );
        // The state event itself stays out until the live end is reached.
        expect(timeline.events.map((e) => e.eventId), ['task_1']);

        final updatesBeforeUnknown = updates;
        client.onTimelineEvent.add(
          Event.fromJson(
            stateEventJson('state_x', 'unknown_task', 'done', 5000),
            room,
          ),
        );
        await pumpEventQueue();
        expect(timeline.aggregatedEvents['unknown_task'], isNull);
        expect(updates, updatesBeforeUnknown);
      },
    );

    test('removes redacted relations while not following live', () async {
      var updates = 0;
      final changes = <int>[];
      final timeline = fragmentedTimeline(
        [Event.fromJson(taskEventJson('task_1', 1000), room)],
        onUpdate: () => updates++,
        onChange: changes.add,
      );
      client.onTimelineEvent.add(
        Event.fromJson(stateEventJson('state_3', 'task_1', 'done', 5000), room),
      );
      await pumpEventQueue();
      changes.clear();
      final updatesBefore = updates;

      client.onTimelineEvent.add(
        Event.fromJson(redactionJson('state_3'), room),
      );
      await pumpEventQueue();

      expect(timeline.aggregatedEvents['task_1']![stateRelType], isEmpty);
      expect(changes, [0]);
      expect(updates, updatesBefore + 1);
      expect(timeline.events.map((e) => e.eventId), ['task_1']);
    });

    test('removes redacted fetched relations on a live timeline', () async {
      stubRelations(
        'task_1',
        stateRelType,
        () => {
          'chunk': [stateEventJson('state_1', 'task_1', 'todo', 2000)],
        },
      );
      final timeline = Timeline(
        room: room,
        chunk: TimelineChunk(
          events: [Event.fromJson(taskEventJson('task_1', 1000), room)],
        ),
      );
      await timeline.fetchAggregatedEvents('task_1', stateRelType);

      client.onTimelineEvent.add(
        Event.fromJson(redactionJson('state_1'), room),
      );
      await pumpEventQueue();

      expect(timeline.aggregatedEvents['task_1']![stateRelType], isEmpty);
    });

    test(
      'removes cancelled relation echoes while not following live',
      () async {
        final changes = <int>[];
        final timeline = fragmentedTimeline([
          Event.fromJson(taskEventJson('task_1', 1000), room),
        ], onChange: changes.add);
        client.onTimelineEvent.add(
          Event.fromJson({
            ...stateEventJson('txid_2', 'task_1', 'done', 3000),
            'status': EventStatus.error.intValue,
            'unsigned': {'transaction_id': 'txid_2'},
          }, room),
        );
        await pumpEventQueue();
        changes.clear();

        client.onCancelSendEvent.add('txid_2');
        await pumpEventQueue();

        expect(timeline.aggregatedEvents['task_1']![stateRelType], isEmpty);
        expect(changes, [0]);
      },
    );
  });
}
