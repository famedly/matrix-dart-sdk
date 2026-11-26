// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:collection/collection.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/models/timeline_chunk.dart';
import 'package:test/test.dart';

import 'fake_client.dart';

const taskType = 'com.example.task';
const stateRel = 'com.example.task.state';
const roomId = '!fragmented:example.com';
final encRoomId = Uri.encodeComponent(roomId);

Map<String, Object?> task(String id, int ts) => {
  'event_id': id,
  'type': taskType,
  'sender': '@alice:example.com',
  'origin_server_ts': ts,
  'room_id': roomId,
  'content': {'title': 'Task', 'body': '[Task] Task'},
};

Map<String, Object?> state(
  String id,
  String taskId,
  String status,
  int ts, {
  String relType = stateRel,
}) => {
  ...task(id, ts),
  'type': stateRel,
  'content': {
    'status': status,
    'assignees': ['@bob:example.com'],
    'm.relates_to': {'rel_type': relType, 'event_id': taskId},
  },
};

Map<String, Object?> redaction(String redacts) => {
  ...task('redaction_$redacts', 6000),
  'type': EventTypes.Redaction,
  'redacts': redacts,
  'content': <String, Object?>{},
};

void stub(String path, Map<String, Object?> Function() response) {
  (FakeMatrixApi.currentApi!.api['GET'] ??= {})[path] = (_) => response();
  addTearDown(() => FakeMatrixApi.currentApi!.api['GET']!.remove(path));
}

void stubRelations(
  String id,
  String relType, [
  List<Map<String, Object?>> chunk = const [],
]) => stub(
  '/client/v1/rooms/$encRoomId/relations/$id/$relType?limit=50',
  () => {'chunk': chunk},
);

void stubMessages(
  String from,
  Direction dir,
  List<Map<String, Object?>> chunk,
) => stub(
  '/client/v3/rooms/$encRoomId/messages?from=$from&dir=${dir.name}'
  '&limit=${Room.defaultHistoryCount}'
  '&filter=%7B%22lazy_load_members%22%3Atrue%7D',
  () => {'start': from, 'end': '${from}_after', 'chunk': chunk, 'state': []},
);

Iterable<String> calledRelationPaths() => FakeMatrixApi.calledEndpoints.keys
    .where((path) => path.contains('/relations/'));

void main() {
  group('Fragmented timeline relations', () {
    late Client client;
    late Room room;

    setUp(() async {
      client = await getClient();
      client.fragmentedTimelineRelations[taskType] = {
        stateRel,
        RelationshipTypes.edit,
      };
      client.fragmentedTimelineSiblingRelations.add(stateRel);
      room = Room(
        id: roomId,
        client: client,
        prev_batch: 'prev',
        roomAccountData: {},
      );
      FakeMatrixApi.calledEndpoints.clear();
    });
    tearDown(() async => client.dispose());

    Event ev(Map<String, Object?> json) => Event.fromJson(json, room);
    void push(Map<String, Object?> json) =>
        client.onTimelineEvent.add(ev(json));
    Set<String> relIds(Timeline t, String id) =>
        t.aggregatedEvents[id]![stateRel]!.map((e) => e.eventId).toSet();

    Timeline timeline(
      List<Map<String, Object?>> events, {
      bool fragmented = true,
      void Function()? onUpdate,
      void Function(int)? onChange,
    }) => Timeline(
      room: room,
      chunk: TimelineChunk(
        events: events.map(ev).toList(),
        nextBatch: fragmented ? 'next' : '',
        prevBatch: 'prev',
      ),
      onUpdate: onUpdate,
      onChange: onChange,
    );

    test(
      'pagination fetches relations only where they may be missing',
      () async {
        stubMessages('prev', Direction.b, [task('task_2', 500)]);
        stubMessages('next', Direction.f, [
          state('state_9', 'task_9', 'done', 3000),
        ]);
        stubRelations('task_9', stateRel, [
          state('state_9', 'task_9', 'done', 3000),
          state('state_8', 'task_9', 'todo', 1500),
        ]);

        final live = timeline([task('task_1', 1000)], fragmented: false);
        expect(await live.getRoomEvents(), 1);
        await live.fetchMissingRelations([
          ev({...task('txid_1', 1000), 'status': EventStatus.sending.intValue}),
        ]);
        expect(calledRelationPaths(), isEmpty);

        final changes = <int>[];
        final fragmented = timeline([
          task('task_1', 1000),
        ], onChange: changes.add);
        await fragmented.getRoomEvents(direction: Direction.f);
        expect(relIds(fragmented, 'task_9'), {'state_8', 'state_9'});
        expect(changes, everyElement(lessThan(fragmented.events.length)));
      },
    );

    test('context timeline keeps task relations up to date', () async {
      stub(
        '/client/v3/rooms/$encRoomId/context/task_1'
        '?limit=${Room.defaultHistoryCount}',
        () => {
          'start': 'ctx_start',
          'end': 'ctx_end',
          'event': task('task_1', 1000),
          'events_before': [],
          'events_after': [],
          'state': [],
        },
      );
      stubRelations('task_1', stateRel, [
        state('state_1', 'task_1', 'in_progress', 2000),
      ]);
      stubRelations('task_1', RelationshipTypes.edit, [
        {
          ...state(
            'edit_1',
            'task_1',
            '',
            4000,
            relType: RelationshipTypes.edit,
          ),
          'type': taskType,
        },
      ]);
      var updates = 0;
      final t = await room.getTimeline(
        eventContextId: 'task_1',
        onUpdate: () => updates++,
      );
      expect(t.allowNewEvent, false);

      Event latestState() => t.aggregatedEvents['task_1']![stateRel]!
          .sortedBy<num>((e) => e.originServerTs.millisecondsSinceEpoch)
          .last;
      expect(latestState().content['status'], 'in_progress');
      expect(
        t.aggregatedEvents['task_1']![RelationshipTypes.edit]!.single.eventId,
        'edit_1',
      );

      final synced = {
        ...state('\$state_2', 'task_1', 'done', 3000),
        'unsigned': {'transaction_id': 'txid_2'},
      };
      var before = updates;
      push({
        ...synced,
        'event_id': 'txid_2',
        'status': EventStatus.sending.intValue,
      });
      await pumpEventQueue();
      expect(latestState().content['status'], 'done');
      expect(updates, greaterThan(before));

      push(synced);
      push({...synced, 'status': EventStatus.sent.intValue});
      await pumpEventQueue();
      expect(relIds(t, 'task_1'), {'state_1', '\$state_2'});
      expect(latestState().status, EventStatus.synced);
      expect(t.events.map((e) => e.eventId), ['task_1']);

      before = updates;
      push(state('state_x', 'unknown_task', 'done', 5000));
      await pumpEventQueue();
      expect(t.aggregatedEvents['unknown_task'], isNull);
      expect(updates, before);
    });

    test('removes redacted and cancelled relations', () async {
      stubRelations('task_5', stateRel, [
        state('state_5', 'task_5', 'todo', 2000),
      ]);
      var updates = 0;
      final changes = <int>[];
      final fragmented = timeline(
        [task('task_1', 1000)],
        onUpdate: () => updates++,
        onChange: changes.add,
      );
      late final Timeline live;
      live = timeline(
        [],
        fragmented: false,
        onChange: (i) => expect(i, lessThan(live.events.length)),
      );
      await live.fetchAggregatedEvents('task_5', stateRel);
      push(state('state_3', 'task_1', 'done', 5000));
      push({
        ...state('txid_2', 'task_1', 'done', 3000),
        'status': EventStatus.error.intValue,
        'unsigned': {'transaction_id': 'txid_2'},
      });
      await pumpEventQueue();
      changes.clear();
      final before = updates;

      push(redaction('state_3'));
      push(redaction('state_5'));
      client.onCancelSendEvent.add('txid_2');
      await pumpEventQueue();

      expect(fragmented.aggregatedEvents['task_1']![stateRel], isEmpty);
      expect(fragmented.events.map((e) => e.eventId), ['task_1']);
      expect(changes, [0, 0]);
      expect(updates, before + 2);
      expect(live.aggregatedEvents['task_1']![stateRel], isEmpty);
      expect(live.aggregatedEvents['task_5']![stateRel], isEmpty);
    });

    test('redacts loaded events, also via content.redacts', () async {
      var updates = 0;
      final changes = <int>[];
      final fragmented = timeline(
        [task('task_1', 1000)],
        onUpdate: () => updates++,
        onChange: changes.add,
      );
      push({
        ...redaction('task_1'),
        'redacts': null,
        'content': {'redacts': 'task_1'},
      });
      await pumpEventQueue();

      expect(fragmented.events.single.redacted, isTrue);
      expect(changes, [0]);
      expect(updates, 1);
    });

    test('failed fetch does not throw and can be retried', () async {
      var fail = true;
      stub(
        '/client/v1/rooms/$encRoomId/relations/task_1/$stateRel?limit=50',
        () => fail
            ? {'errcode': 'M_FORBIDDEN', 'error': 'Forbidden'}
            : {
                'chunk': [state('state_1', 'task_1', 'todo', 2000)],
              },
      );
      final t = timeline([task('task_1', 1000)]);

      await Future.wait([
        t.fetchAggregatedEvents('task_1', stateRel),
        t.fetchAggregatedEvents('task_1', stateRel),
      ]);
      expect(t.aggregatedEvents['task_1'], isNull);

      fail = false;
      await t.fetchAggregatedEvents('task_1', stateRel);
      expect(relIds(t, 'task_1'), {'state_1'});
    });

    test(
      'decrypts fetched relations and fetches their siblings once the key arrives',
      tags: 'olm',
      () async {
        final encryptedRoom = client.getRoomById('!726s6s6q:example.com')!;
        final payload = await client.encryption!.encryptGroupMessagePayload(
          encryptedRoom.id,
          {
            'status': 'done',
            'assignees': <String>[],
            'm.relates_to': {'rel_type': stateRel, 'event_id': 'task_1'},
          },
          type: stateRel,
        );
        final t = Timeline(
          room: encryptedRoom,
          chunk: TimelineChunk(events: [], nextBatch: 'next'),
        );
        t.addAggregatedEvent(
          Event(
            type: EventTypes.Encrypted,
            content: {
              ...payload,
              'msgtype': MessageTypes.BadEncrypted,
              'body': 'Unknown session',
              'can_request_session': true,
            },
            room: encryptedRoom,
            eventId: 'state_enc',
            senderId: client.userID!,
            originServerTs: DateTime.now(),
          ),
        );

        encryptedRoom.onSessionKeyReceived.add(payload['session_id']);
        await Future.doWhile(() async {
          await Future.delayed(const Duration(milliseconds: 10));
          return !calledRelationPaths().any(
            (p) => p.contains('/task_1/$stateRel'),
          );
        }).timeout(const Duration(seconds: 5));

        final s = t.aggregatedEvents['task_1']![stateRel]!.single;
        expect(s.type, stateRel);
        expect(s.content['status'], 'done');
      },
    );
  });
}
