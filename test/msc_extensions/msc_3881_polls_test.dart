import 'package:matrix/matrix.dart';
import 'package:matrix/src/models/timeline_chunk.dart';
import 'package:test/test.dart';

import '../fake_client.dart';

void main() {
  group('MSC 3881 Polls', () {
    late Client client;
    const roomId = '!696r7674:example.com';
    setUpAll(() async {
      client = await getClient();
    });
    tearDownAll(() async => client.dispose());
    test('Start poll', () async {
      final room = client.getRoomById(roomId)!;
      final eventId = await room.startPoll(
        question: 'What do you like more?',
        kind: PollKind.undisclosed,
        maxSelections: 2,
        answers: [
          PollAnswer(
            id: 'pepsi',
            mText: 'Pepsi',
          ),
          PollAnswer(
            id: 'coca',
            mText: 'Coca Cola',
          ),
        ],
        txid: '1234',
      );

      expect(eventId, '1234');
    });
    test('Check Poll Event', () async {
      final room = client.getRoomById(roomId)!;
      final pollEventContent = PollEventContent(
        mText: 'TestPoll',
        pollStartContent: PollStartContent(
          maxSelections: 2,
          question: PollQuestion(mText: 'Question'),
          answers: [PollAnswer(id: 'id', mText: 'mText')],
        ),
      );
      final pollEvent = Event(
        content: pollEventContent.toJson(),
        type: PollEventContent.startType,
        eventId: 'testevent',
        senderId: client.userID!,
        originServerTs: DateTime.now().subtract(const Duration(seconds: 10)),
        room: room,
      );
      expect(
        pollEvent.parsedPollEventContent.toJson(),
        pollEventContent.toJson(),
      );

      final timeline = Timeline(
        room: room,
        chunk: TimelineChunk(
          events: [pollEvent],
        ),
      );

      expect(pollEvent.getPollResponses(timeline), {});
      expect(pollEvent.getPollHasBeenEnded(timeline), false);

      timeline.aggregatedEvents['testevent'] ??= {};
      timeline.aggregatedEvents['testevent']?['m.reference'] ??= {};

      timeline.aggregatedEvents['testevent']!['m.reference']!.add(
        Event(
          content: {
            'm.relates_to': {
              'rel_type': 'm.reference',
              'event_id': 'testevent',
            },
            'org.matrix.msc3381.poll.response': {
              'answers': ['pepsi'],
            },
          },
          type: PollEventContent.responseType,
          eventId: 'testevent2',
          senderId: client.userID!,
          originServerTs: DateTime.now().subtract(const Duration(seconds: 9)),
          room: room,
        ),
      );

      expect(
        pollEvent.getPollResponses(timeline),
        {
          '@test:fakeServer.notExisting': ['pepsi'],
        },
      );

      timeline.aggregatedEvents['testevent']!['m.reference']!.add(
        Event(
          content: {
            'm.relates_to': {
              'rel_type': 'm.reference',
              'event_id': 'testevent',
            },
            'org.matrix.msc3381.poll.end': {},
          },
          type: PollEventContent.responseType,
          eventId: 'testevent3',
          senderId: client.userID!,
          originServerTs: DateTime.now().subtract(const Duration(seconds: 8)),
          room: room,
        ),
      );
      expect(pollEvent.getPollHasBeenEnded(timeline), true);

      final respondeEventId = await pollEvent.answerPoll(
        ['pepsi'],
        txid: '1234',
      );
      expect(respondeEventId, '1234');
    });

    test('fetchPollResponses on fragmented timeline', () async {
      final room = client.getRoomById(roomId)!;
      final pollEventContent = PollEventContent(
        mText: 'FragmentedPoll',
        pollStartContent: PollStartContent(
          maxSelections: 1,
          question: PollQuestion(mText: 'Favorite drink?'),
          answers: [
            PollAnswer(id: 'pepsi', mText: 'Pepsi'),
            PollAnswer(id: 'coca', mText: 'Coca Cola'),
          ],
        ),
      );
      final pollEvent = Event(
        content: pollEventContent.toJson(),
        type: PollEventContent.startType,
        eventId: 'poll_frag_1',
        senderId: client.userID!,
        originServerTs: DateTime.now().subtract(const Duration(hours: 1)),
        room: room,
      );

      // Create a fragmented timeline (nextBatch != '')
      final timeline = Timeline(
        room: room,
        chunk: TimelineChunk(
          events: [pollEvent],
          nextBatch: 'frag_next',
          prevBatch: 'frag_prev',
        ),
      );

      expect(timeline.isFragmentedTimeline, true);
      // No poll responses in the chunk
      expect(pollEvent.getPollResponses(timeline), {});

      // Set up mock /relations endpoint to return poll response events
      final responseTs = DateTime.now().subtract(const Duration(minutes: 30));
      final relationsPath =
          '/client/v1/rooms/${Uri.encodeComponent(roomId)}/relations/poll_frag_1/m.reference?limit=50';
      (FakeMatrixApi.currentApi!.api['GET'] ??= {})[relationsPath] =
          (dynamic data) => {
                'chunk': [
                  {
                    'event_id': '\$response_1',
                    'type': PollEventContent.responseType,
                    'sender': '@alice:example.com',
                    'origin_server_ts': responseTs.millisecondsSinceEpoch,
                    'content': {
                      'm.relates_to': {
                        'rel_type': RelationshipTypes.reference,
                        'event_id': 'poll_frag_1',
                      },
                      PollEventContent.responseType: {
                        'answers': ['pepsi'],
                      },
                    },
                  },
                  {
                    'event_id': '\$response_2',
                    'type': PollEventContent.responseType,
                    'sender': '@bob:example.com',
                    'origin_server_ts': responseTs
                        .add(const Duration(minutes: 5))
                        .millisecondsSinceEpoch,
                    'content': {
                      'm.relates_to': {
                        'rel_type': RelationshipTypes.reference,
                        'event_id': 'poll_frag_1',
                      },
                      PollEventContent.responseType: {
                        'answers': ['coca'],
                      },
                    },
                  },
                ],
              };

      // Fetch poll responses from the server
      await pollEvent.fetchPollResponses(timeline);

      // Now getPollResponses should return the fetched data
      final responses = pollEvent.getPollResponses(timeline);
      expect(responses.length, 2);
      expect(responses['@alice:example.com'], {'pepsi'});
      expect(responses['@bob:example.com'], {'coca'});

      // Calling again should be a no-op (cached)
      await pollEvent.fetchPollResponses(timeline);
      expect(pollEvent.getPollResponses(timeline).length, 2);

      // Clean up mock
      FakeMatrixApi.currentApi!.api['GET']!.remove(relationsPath);
    });
  });
}
