// ignore_for_file: constant_identifier_names

enum EncryptionKeyTypes { remote, local }

// Call state
enum CallState {
  /// The call is inilalized but not yet started
  kFledgling,

  /// The first time an invite is sent, the local has createdOffer
  kInviteSent,

  /// getUserMedia or getDisplayMedia has been called,
  /// but MediaStream has not yet been returned
  kWaitLocalMedia,

  /// The local has createdOffer
  kCreateOffer,

  /// Received a remote offer message and created a local Answer
  kCreateAnswer,

  /// Answer sdp is set, but ice is not connected
  kConnecting,

  /// WebRTC media stream is connected
  kConnected,

  /// The call was received, but no processing has been done yet.
  kRinging,

  /// Ending a call
  kEnding,

  /// End of call
  kEnded,
}

enum CallErrorCode {
  /// The user chose to end the call
  userHangup('user_hangup'),

  /// An error code when the local client failed to create an offer.
  localOfferFailed('local_offer_failed'),

  /// An error code when there is no local mic/camera to use. This may be because
  /// the hardware isn't plugged in, or the user has explicitly denied access.
  userMediaFailed('user_media_failed'),

  /// Error code used when a call event failed to send
  /// because unknown devices were present in the room
  unknownDevice('unknown_device'),

  /// An answer could not be created
  createAnswer('create_answer'),

  /// The session description from the other side could not be set

  setRemoteDescription('set_remote_description'),

  /// The session description from this side could not be set
  setLocalDescription('set_local_description'),

  /// A different device answered the call
  answeredElsewhere('answered_elsewhere'),

  /// No media connection could be established to the other party
  iceFailed('ice_failed'),

  /// The invite timed out whilst waiting for an answer
  inviteTimeout('invite_timeout'),

  /// The call was replaced by another call
  replaced('replaced'),

  /// Signalling for the call could not be sent (other than the initial invite)
  iceTimeout('ice_timeout'),

  /// The remote party is busy
  userBusy('user_busy'),

  /// We transferred the call off to somewhere else
  transferred('transferred'),

  /// Some other failure occurred that meant the client was unable to continue
  /// the call rather than the user choosing to end it.
  unknownError('unknown_error');

  final String reason;

  const CallErrorCode(this.reason);
}

class CallError extends Error {
  final CallErrorCode code;
  final String msg;
  final dynamic err;
  CallError(this.code, this.msg, this.err);

  @override
  String toString() {
    return '[$code] $msg, err: ${err.toString()}';
  }
}

enum CallStateChange {
  /// The call was hangup by the local|remote user.
  kHangup,

  /// The call state has changed
  kState,

  /// The call got some error.
  kError,

  /// Call transfer
  kReplaced,

  /// The value of isLocalOnHold() has changed
  kLocalHoldUnhold,

  /// The value of isRemoteOnHold() has changed
  kRemoteHoldUnhold,

  /// Feeds have changed
  kFeedsChanged,

  /// For sip calls. support in the future.
  kAssertedIdentityChanged,
}

enum CallType { kVoice, kVideo }

enum CallDirection { kIncoming, kOutgoing }

enum CallParty { kLocal, kRemote }

enum MediaInputKind { videoinput, audioinput }

enum MediaKind { video, audio }

enum GroupCallErrorCode {
  /// An error code when there is no local mic/camera to use. This may be because
  /// the hardware isn't plugged in, or the user has explicitly denied access.
  userMediaFailed('user_media_failed'),

  /// Some other failure occurred that meant the client was unable to continue
  /// the call rather than the user choosing to end it.
  unknownError('unknownError');

  final String reason;

  const GroupCallErrorCode(this.reason);
}

class GroupCallError extends Error {
  final GroupCallErrorCode code;
  final String msg;
  final dynamic err;
  GroupCallError(this.code, this.msg, this.err);

  @override
  String toString() {
    return 'Group Call Error: [$code] $msg, err: ${err.toString()}';
  }
}

enum GroupCallStateChange {
  groupCallStateChanged,
  activeSpeakerChanged,
  callsChanged,
  userMediaStreamsChanged,
  screenshareStreamsChanged,
  localScreenshareStateChanged,
  localMuteStateChanged,
  participantsChanged,
  error
}

enum GroupCallState {
  localCallFeedUninitialized,
  initializingLocalCallFeed,
  localCallFeedInitialized,
  entering,
  entered,
  ended
}
