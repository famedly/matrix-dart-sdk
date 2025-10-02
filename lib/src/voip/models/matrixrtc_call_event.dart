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

sealed class CallReactionEvent implements MatrixRTCCallEvent {}

final class CallReactionAddedEvent implements CallReactionEvent {
  final CallParticipant participant;
  final String reactionKey;
  final String membershipEventId;
  final String reactionEventId;
  final bool isEphemeral;

  CallReactionAddedEvent({
    required this.participant,
    required this.reactionKey,
    required this.membershipEventId,
    required this.reactionEventId,
    required this.isEphemeral,
  });
}

final class CallReactionRemovedEvent implements CallReactionEvent {
  final CallParticipant participant;
  final String redactedEventId;

  CallReactionRemovedEvent({
    required this.participant,
    required this.redactedEventId,
  });
}
