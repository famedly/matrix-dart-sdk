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
  final String? reactionName;
  final String eventId;
  final bool isEphemeral;

  ReactionAddedEvent({
    required this.participant,
    required this.reactionKey,
    this.reactionName,
    required this.eventId,
    required this.isEphemeral,
  });
}

final class ReactionRemovedEvent implements ReactionEvent {
  final CallParticipant participant;
  final String reactionKey;
  final String? reactionName;
  final String? redactedEventId;

  ReactionRemovedEvent({
    required this.participant,
    required this.reactionKey,
    this.reactionName,
    required this.redactedEventId,
  });
}
