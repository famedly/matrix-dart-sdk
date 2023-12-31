import 'package:matrix/matrix.dart';

/// https://github.com/matrix-org/matrix-doc/pull/2746
/// version 1
const String voipProtoVersion = '1';

class CallTimeouts {
  /// The default life time for call events, in millisecond.
  static const defaultCallEventLifetime = Duration(seconds: 10);

  /// The length of time a call can be ringing for.
  static const callInviteLifetime = Duration(seconds: 60);

  /// The delay for ice gathering.
  static const iceGatheringDelay = Duration(milliseconds: 200);

  /// Delay before createOffer.
  static const delayBeforeOffer = Duration(milliseconds: 100);

  /// How often to update the expiresTs
  static const updateExpireTsTimerDuration = Duration(seconds: 15);

  /// the expiresTs bump, currently 1 minute
  static const expireTsBumpDuration = Duration(minutes: 1);

  /// Update the active speaker value
  static const activeSpeakerInterval = Duration(seconds: 5);
}

const callEndedEventTypes = {
  EventTypes.CallAnswer,
  EventTypes.CallHangup,
  EventTypes.CallReject,
  EventTypes.CallReplaces,
};
const ommitWhenCallEndedTypes = {
  EventTypes.CallInvite,
  EventTypes.CallCandidates,
  EventTypes.CallNegotiate,
  EventTypes.CallSDPStreamMetadataChanged,
  EventTypes.CallSDPStreamMetadataChangedPrefix,
};
