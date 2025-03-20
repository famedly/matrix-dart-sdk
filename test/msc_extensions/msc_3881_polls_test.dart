import 'package:test/test.dart';

import 'package:matrix/matrix.dart';
import 'package:matrix/msc_extensions/msc_3381_polls/models/poll_event_content.dart';
import 'package:matrix/msc_extensions/msc_3381_polls/poll_event_extension.dart';
import 'package:matrix/msc_extensions/msc_3381_polls/poll_room_extension.dart';
import 'package:matrix/src/models/timeline_chunk.dart';
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
  });
}
