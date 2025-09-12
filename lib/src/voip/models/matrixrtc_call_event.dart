import 'package:matrix/matrix.dart';

/// UNSTABLE API WARNING
/// The class herirachy is currently experimental and could have breaking changes
/// often.
sealed class MatrixRTCCallEvent {}

/// Event type for participants change
sealed class ParticipantsChangeEvent implements MatrixRTCCallEvent {
  /// The participants who joined or left the call
  final List<CallParticipant> participants;

  ParticipantsChangeEvent({required this.participants});
}

final class ParticipantsJoinEvent extends ParticipantsChangeEvent {
  ParticipantsJoinEvent({required super.participants});
}

final class ParticipantsLeftEvent extends ParticipantsChangeEvent {
  ParticipantsLeftEvent({required super.participants});
}

/// Event type for group call emoji reaction update
sealed class GroupCallEmojiReactionEvent implements MatrixRTCCallEvent {
  GroupCallEmojiReactionEvent({required this.participant});

  /// The participant who sent the reaction
  final CallParticipant participant;
}

final class GroupCallEmojiReactionAddedEvent
    extends GroupCallEmojiReactionEvent {
  /// The emoji character
  final String emoji;

  GroupCallEmojiReactionAddedEvent({
    required super.participant,
    required this.emoji,
  });
}

final class GroupCallEmojiReactionTimeoutEvent
    extends GroupCallEmojiReactionEvent {
  GroupCallEmojiReactionTimeoutEvent({required super.participant});
}
