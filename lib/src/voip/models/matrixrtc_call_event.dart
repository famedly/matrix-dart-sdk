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

/// Group call active speaker changed event
final class GroupCallActiveSpeakerChanged implements MatrixRTCCallEvent {
  final CallParticipant participant;
  GroupCallActiveSpeakerChanged(this.participant);
}

/// Group calls changed event type
sealed class GroupCallChanged implements MatrixRTCCallEvent {}

/// Group call, call added event
final class CallAddedEvent implements GroupCallChanged {
  final CallSession call;
  CallAddedEvent(this.call);
}

/// Group call, call removed event
final class CallRemovedEvent implements GroupCallChanged {
  final CallSession call;
  CallRemovedEvent(this.call);
}

/// Group call, call replaced event
final class CallReplacedEvent extends GroupCallChanged {
  final CallSession existingCall, replacementCall;
  CallReplacedEvent(this.existingCall, this.replacementCall);
}

enum GroupCallStreamType {
  userMedia,
  screenshare,
}

/// Group call stream added event
final class GroupCallStreamAdded implements MatrixRTCCallEvent {
  final GroupCallStreamType type;
  GroupCallStreamAdded(this.type);
}

/// Group call stream removed event
final class GroupCallStreamRemoved implements MatrixRTCCallEvent {
  final GroupCallStreamType type;
  GroupCallStreamRemoved(this.type);
}

/// Group call stream replaced event
final class GroupCallStreamReplaced implements MatrixRTCCallEvent {
  final GroupCallStreamType type;
  GroupCallStreamReplaced(this.type);
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
