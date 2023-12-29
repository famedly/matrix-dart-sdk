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
}
