import 'package:matrix/matrix.dart';

/// https://github.com/matrix-org/matrix-doc/pull/2746
/// version 1
const String voipProtoVersion = '1';

class CallTimeouts {
  /// The default life time for call events, in millisecond.
  final Duration defaultCallEventLifetime;

  /// The length of time a call can be ringing for.
  final Duration callInviteLifetime;

  /// The delay for ice gathering.
  final Duration iceGatheringDelay;

  /// Delay before createOffer.
  final Duration delayBeforeOffer;

  /// How often to update the expiresTs
  final Duration updateExpireTsTimerDuration;

  /// the expiresTs bump
  final Duration expireTsBumpDuration;

  /// Update the active speaker value
  final Duration activeSpeakerInterval;

  // source: element call?
  /// A delay after a member leaves before we create and publish a new key, because people
  /// tend to leave calls at the same time
  final Duration makeKeyOnLeaveDelay;

  /// A delay used for joins, only creates new keys if last new created key was before
  /// $makeKeyDelay duration, or it was recently made and it's safe to send that
  /// The bigger this is the easier key sharing would be, but also less secure
  /// Not used if ratcheting is enabled
  final Duration makeKeyOnJoinDelay;

  /// The delay between creating and sending a new key and starting to encrypt with it. This gives others
  /// a chance to receive the new key to minimise the chance they don't get media they can't decrypt.
  /// The total time between a member leaving and the call switching to new keys is therefore
  /// makeKeyDelay + useKeyDelay
  final Duration useKeyDelay;

  /// After how long the homeserver should send the delayed leave event which
  /// gracefully leaves you from the call
  final Duration delayedEventApplyLeave;

  /// How often the delayed event should be restarted on the homeserver
  final Duration delayedEventRestart;

  CallTimeouts({
    this.defaultCallEventLifetime = const Duration(seconds: 10),
    this.callInviteLifetime = const Duration(seconds: 60),
    this.iceGatheringDelay = const Duration(milliseconds: 200),
    this.delayBeforeOffer = const Duration(milliseconds: 100),
    this.updateExpireTsTimerDuration = const Duration(minutes: 2),
    this.expireTsBumpDuration = const Duration(minutes: 6),
    this.activeSpeakerInterval = const Duration(seconds: 5),
    this.makeKeyOnLeaveDelay = const Duration(seconds: 4),
    this.makeKeyOnJoinDelay = const Duration(seconds: 8),
    this.useKeyDelay = const Duration(seconds: 4),
    this.delayedEventApplyLeave = const Duration(seconds: 18),
    this.delayedEventRestart = const Duration(seconds: 4),
  });
}

class CallConstants {
  static final callEventsRegxp = RegExp(
    r'm.call.|org.matrix.call.|org.matrix.msc3401.call.|com.famedly.call.|m.room.redaction',
  );

  static const callEndedEventTypes = {
    EventTypes.CallAnswer,
    EventTypes.CallHangup,
    EventTypes.CallReject,
    EventTypes.CallReplaces,
  };
  static const omitWhenCallEndedTypes = {
    EventTypes.CallInvite,
    EventTypes.CallCandidates,
    EventTypes.CallNegotiate,
    EventTypes.CallSDPStreamMetadataChanged,
    EventTypes.CallSDPStreamMetadataChangedPrefix,
  };

  static const updateExpireTsTimerDuration = Duration(seconds: 15);
  static const expireTsBumpDuration = Duration(seconds: 45);
  static const activeSpeakerInterval = Duration(seconds: 5);
  static const ephemeralReactionTimeout = Duration(seconds: 2);
}
