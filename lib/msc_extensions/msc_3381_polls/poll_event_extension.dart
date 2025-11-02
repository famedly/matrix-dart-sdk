import 'package:collection/collection.dart';

import 'package:matrix/matrix.dart';

extension PollEventExtension on Event {
  PollEventContent get parsedPollEventContent {
    assert(type == PollEventContent.startType);
    return PollEventContent.fromJson(content);
  }

  /// Returns a Map of user IDs to a Set of answer IDs.
  Map<String, Set<String>> getPollResponses(Timeline timeline) {
    assert(type == PollEventContent.startType);
    final aggregatedEvents = timeline.aggregatedEvents[eventId]
            ?[RelationshipTypes.reference]
        ?.toList();
    if (aggregatedEvents == null || aggregatedEvents.isEmpty) return {};
    aggregatedEvents
        .removeWhere((event) => event.type != PollEventContent.responseType);

    final responses = <String, Event>{};

    final endPollEvent = _getEndPollEvent(timeline);

    for (final event in aggregatedEvents) {
      // Ignore older responses if we already have a newer one:
      final existingEvent = responses[event.senderId];
      if (existingEvent != null &&
          existingEvent.originServerTs.isAfter(event.originServerTs)) {
        continue;
      }
      // Ignore all responses sent **after** the poll end event:
      if (endPollEvent != null &&
          event.originServerTs.isAfter(endPollEvent.originServerTs)) {
        continue;
      }
      responses[event.senderId] = event;
    }
    return responses.map(
      (userId, event) => MapEntry(
        userId,
        event.content
                .tryGetMap<String, Object?>(PollEventContent.responseType)
                ?.tryGetList<String>('answers')
                ?.toSet() ??
            {},
      ),
    );
  }

  Event? _getEndPollEvent(Timeline timeline) {
    assert(type == PollEventContent.startType);
    final aggregatedEvents =
        timeline.aggregatedEvents[eventId]?[RelationshipTypes.reference];
    if (aggregatedEvents == null || aggregatedEvents.isEmpty) return null;

    final redactPowerLevel = (room
            .getState(EventTypes.RoomPowerLevels)
            ?.content
            .tryGet<int>('redact') ??
        50);

    return aggregatedEvents.firstWhereOrNull(
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

  bool getPollHasBeenEnded(Timeline timeline) =>
      _getEndPollEvent(timeline) != null;

  Future<String?> answerPoll(
    List<String> answerIds, {
    String? txid,
  }) {
    if (type != PollEventContent.startType) {
      throw Exception('Event is not a poll.');
    }
    if (answerIds.length >
        parsedPollEventContent.pollStartContent.maxSelections) {
      throw Exception('Selected more answers than allowed in this poll.');
    }
    return room.sendEvent(
      {
        'm.relates_to': {
          'rel_type': RelationshipTypes.reference,
          'event_id': eventId,
        },
        PollEventContent.responseType: {'answers': answerIds},
      },
      type: PollEventContent.responseType,
      txid: txid,
    );
  }

  Future<String?> endPoll({String? txid}) {
    if (type != PollEventContent.startType) {
      throw Exception('Event is not a poll.');
    }
    if (senderId != room.client.userID) {
      throw Exception('You can not end a poll created by someone else.');
    }
    return room.sendEvent(
      {
        'm.relates_to': {
          'rel_type': RelationshipTypes.reference,
          'event_id': eventId,
        },
        PollEventContent.endType: {},
      },
      type: PollEventContent.endType,
      txid: txid,
    );
  }
}
