import 'package:matrix/matrix.dart';
import 'package:matrix/msc_extensions/msc_3381_polls/models/poll_event_content.dart';

extension PollEventExtension on Event {
  PollEventContent get parsedPollEventContent {
    assert(type == PollEventContent.startType);
    return PollEventContent.fromJson(content);
  }

  /// Returns a Map of answer IDs to a Set of user IDs.
  Map<String, Set<String>> getPollResponses(Timeline timeline) {
    assert(type == PollEventContent.startType);
    final aggregatedEvents =
        timeline.aggregatedEvents[eventId]?['m.reference']?.toList();
    if (aggregatedEvents == null || aggregatedEvents.isEmpty) return {};

    final responses = <String, Set<String>>{};

    final maxSelection = parsedPollEventContent.pollStartContent.maxSelections;

    aggregatedEvents.removeWhere((event) {
      if (event.type != PollEventContent.responseType) return true;

      // Votes with timestamps after the poll has closed are ignored, as if they
      // never happened.
      if (originServerTs.isAfter(event.originServerTs)) {
        Logs().d('Ignore poll answer which came after poll was closed.');
        return true;
      }

      final answers = event.content
          .tryGetMap<String, Object?>(PollEventContent.responseType)
          ?.tryGetList<String>('answers');
      if (answers == null) {
        Logs().d('Ignore poll answer with now valid answer IDs');
        return true;
      }
      if (answers.length > maxSelection) {
        Logs().d(
          'Ignore poll answer with ${answers.length} while only $maxSelection are allowed.',
        );
        return true;
      }
      return false;
    });

    // Sort by date so only the users most recent vote is used in the end, even
    // if it is invalid.
    aggregatedEvents
        .sort((a, b) => a.originServerTs.compareTo(b.originServerTs));

    for (final event in aggregatedEvents) {
      final answers = event.content
              .tryGetMap<String, Object?>(PollEventContent.responseType)
              ?.tryGetList<String>('answers') ??
          [];
      responses[event.senderId] = answers.toSet();
    }
    return responses;
  }

  bool getPollHasBeenEnded(Timeline timeline) {
    assert(type == PollEventContent.startType);
    final aggregatedEvents = timeline.aggregatedEvents[eventId]?['m.reference'];
    if (aggregatedEvents == null || aggregatedEvents.isEmpty) return false;

    final redactPowerLevel = (room
            .getState(EventTypes.RoomPowerLevels)
            ?.content
            .tryGet<int>('redact') ??
        50);

    return aggregatedEvents.any(
      (event) {
        if (event.content
                .tryGetMap<String, Object?>(PollEventContent.endType) ==
            null) {
          return false;
        }

        // If a m.poll.end event is received from someone other than the poll
        //creator or user with permission to redact other's messages in the
        //room, the event must be ignored by clients due to being invalid.
        if (event.senderId == senderId ||
            event.senderFromMemoryOrFallback.powerLevel >= redactPowerLevel) {
          return true;
        }
        Logs().w(
          'Ignore poll end event form user without permission ${event.senderId}',
        );
        return false;
      },
    );
  }

  Future<String?> answerPoll(
    List<String> answerIds, {
    String? txid,
  }) {
    final maxSelection = parsedPollEventContent.pollStartContent.maxSelections;
    if (answerIds.length > maxSelection) {
      throw Exception(
        'Can not add ${answerIds.length} answers while max selection is $maxSelection',
      );
    }
    return room.sendEvent(
      {
        'm.relates_to': {
          'rel_type': 'm.reference',
          'event_id': eventId,
        },
        PollEventContent.responseType: {'answers': answerIds},
      },
      type: PollEventContent.responseType,
      txid: txid,
    );
  }

  Future<String?> endPoll({String? txid}) => room.sendEvent(
        {
          'm.relates_to': {
            'rel_type': 'm.reference',
            'event_id': eventId,
          },
          PollEventContent.endType: {},
        },
        type: PollEventContent.endType,
        txid: txid,
      );
}
