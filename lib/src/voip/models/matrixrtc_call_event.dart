import 'package:matrix/matrix.dart';

/// UNSTABLE API WARNING
/// The class herirachy is currently experimental and could have breaking changes
/// often.
sealed class MatrixRTCCallEvent {}

sealed class ParticipantsChangeEvent implements MatrixRTCCallEvent {}

final class ParticipantsJoinEvent implements ParticipantsChangeEvent {
  final List<CallParticipant> participants;

  ParticipantsJoinEvent({required this.participants});
}

final class ParticipantsLeftEvent implements ParticipantsChangeEvent {
  final List<CallParticipant> participants;

  ParticipantsLeftEvent({required this.participants});
}

sealed class ReactionEvent implements MatrixRTCCallEvent {}

final class ReactionAddedEvent implements ReactionEvent {
  final CallParticipant participant;
  final String reactionKey;
  final String eventId;
  final bool isEphemeral;

  ReactionAddedEvent({
    required this.participant,
    required this.reactionKey,
    required this.eventId,
    required this.isEphemeral,
  });
}

final class ReactionRemovedEvent implements ReactionEvent {
  final CallParticipant participant;
  final String reactionKey;
  final String? redactedEventId;

  ReactionRemovedEvent({
    required this.participant,
    required this.reactionKey,
    required this.redactedEventId,
  });
}

final class ReactionPayload {
  final String key;
  final bool isEphemeral;
  final String callId;
  final String deviceId;
  final String relType;
  final String eventId;

  ReactionPayload({
    required this.key,
    required this.isEphemeral,
    required this.callId,
    required this.deviceId,
    required this.relType,
    required this.eventId,
  });

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'is_ephemeral': isEphemeral,
      'call_id': callId,
      'device_id': deviceId,
      'm.relates_to': {
        'rel_type': relType,
        'event_id': eventId,
      },
    };
  }

  factory ReactionPayload.fromMap(Map<String, dynamic> map) {
    return ReactionPayload(
      key: map['key'] as String,
      isEphemeral: map['is_ephemeral'] as bool,
      callId: map['call_id'] as String,
      deviceId: map['device_id'] as String,
      relType: map['m.relates_to']['rel_type'] as String,
      eventId: map['m.relates_to']['event_id'] as String,
    );
  }
}
