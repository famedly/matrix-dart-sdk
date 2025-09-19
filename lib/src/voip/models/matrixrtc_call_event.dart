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

/// Group call active speaker changed event
final class GroupCallActiveSpeakerChanged implements MatrixRTCCallEvent {}

/// Group calls changed event
sealed class GroupCallsChanged implements MatrixRTCCallEvent {}

final class GroupCallAddedEvent implements GroupCallsChanged {}

final class GroupCallRemovedEvent implements GroupCallsChanged {}

final class GroupCallReplacedEvent implements GroupCallsChanged {}

enum GroupCallStreamsChange {
  added,
  removed,
  replaced,
}

/// Group call user media streams changed event
final class GroupCallUserMediaStreamsChanged implements MatrixRTCCallEvent {
  final GroupCallStreamsChange change;
  GroupCallUserMediaStreamsChanged(this.change);
}

/// Group call screen share streams changed event
final class GroupCallScreenShareStreamsChanged implements MatrixRTCCallEvent {
  final GroupCallStreamsChange change;
  GroupCallScreenShareStreamsChanged(this.change);
}

/// Group call local screenshare state changed event
final class GroupCallLocalScreenshareStateChanged
    implements MatrixRTCCallEvent {
  final bool screensharing;
  GroupCallLocalScreenshareStateChanged(this.screensharing);
}

/// Group call local muted changed event
final class GroupCallLocalMutedChanged implements MatrixRTCCallEvent {
  final bool muted;
  final MediaInputKind kind;
  GroupCallLocalMutedChanged(this.muted, this.kind);
}

enum GroupCallState {
  localCallFeedUninitialized,
  initializingLocalCallFeed,
  localCallFeedInitialized,
  entering,
  entered,
  ended
}

/// Group call state changed event
final class GroupCallStateChanged implements MatrixRTCCallEvent {
  final GroupCallState state;
  GroupCallStateChanged(this.state);
}

/// Group call error event
final class GroupCallStateError implements MatrixRTCCallEvent {
  final String msg;
  final dynamic err;
  GroupCallStateError(this.msg, this.err);
}
