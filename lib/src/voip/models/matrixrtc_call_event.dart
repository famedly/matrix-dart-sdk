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
