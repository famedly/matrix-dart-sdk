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
  final Duration makeKeyDelay;

  /// The delay between creating and sending a new key and starting to encrypt with it. This gives others
  /// a chance to receive the new key to minimise the chance they don't get media they can't decrypt.
  /// The total time between a member leaving and the call switching to new keys is therefore
  /// makeKeyDelay + useKeyDelay
  final Duration useKeyDelay;

  CallTimeouts({
    this.defaultCallEventLifetime = const Duration(seconds: 10),
    this.callInviteLifetime = const Duration(seconds: 60),
    this.iceGatheringDelay = const Duration(milliseconds: 200),
    this.delayBeforeOffer = const Duration(milliseconds: 100),
    this.updateExpireTsTimerDuration = const Duration(minutes: 2),
    this.expireTsBumpDuration = const Duration(minutes: 6),
    this.activeSpeakerInterval = const Duration(seconds: 5),
    this.makeKeyDelay = const Duration(seconds: 4),
    this.useKeyDelay = const Duration(seconds: 4),
  });
}

class CallConstants {
  static final callEventsRegxp = RegExp(
    r'm.call.|org.matrix.call.|org.matrix.msc3401.call.|com.famedly.call.',
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
}
