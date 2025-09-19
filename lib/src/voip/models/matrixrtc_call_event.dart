import 'package:matrix/matrix.dart';

/// UNSTABLE API WARNING
/// The class herirachy is currently experimental and could have breaking changes
/// often.
sealed class MatrixRTCCallEvent {}

/// Event type for participants change
sealed class ParticipantsChangeEvent implements MatrixRTCCallEvent {}

final class ParticipantsJoinEvent implements ParticipantsChangeEvent {
  /// The participants who joined the call
  final List<CallParticipant> participants;

  ParticipantsJoinEvent({required this.participants});
}

final class ParticipantsLeftEvent implements ParticipantsChangeEvent {
  /// The participants who left the call
  final List<CallParticipant> participants;

  ParticipantsLeftEvent({required this.participants});
}

/// Event type for group call emoji reaction update
final class GroupCallReactionAddedEvent implements MatrixRTCCallEvent {
  /// The participant who sent the reaction
  final CallParticipant participant;

  /// The emoji character
  final String emoji;

  /// Words describing the emoji
  final String? emojiName;

  final bool isEphemeral;

  GroupCallReactionAddedEvent({
    required this.participant,
    required this.emoji,
    required this.emojiName,
    required this.isEphemeral,
  });
}
