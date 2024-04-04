// ignore_for_file: constant_identifier_names

class VoIPEventTypes {
  // static const String Prefix = 'com.famedly.call';
  static const String Prefix = 'org.matrix.msc3401.call';
  static const String FamedlyCallMemberEvent = '$Prefix.member';
  static const String EncryptionKeysEvent = '$Prefix.encryption_keys';
  static const String RequestEncryptionKeysEvent =
      '$EncryptionKeysEvent.request';
}

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

  /// End of call
  kEnded,
}

enum CallErrorCode {
  /// The user chose to end the call
  user_hangup,

  /// An error code when the local client failed to create an offer.
  local_offer_failed,

  /// An error code when there is no local mic/camera to use. This may be because
  /// the hardware isn't plugged in, or the user has explicitly denied access.
  user_media_failed,

  /// Error code used when a call event failed to send
  /// because unknown devices were present in the room
  unknown_device,

  /// Error code used when we fail to send the invite
  /// for some reason other than there being unknown devices
  send_invite,

  /// An answer could not be created

  create_answer,

  /// Error code used when we fail to send the answer
  /// for some reason other than there being unknown devices
  send_answer,

  /// The session description from the other side could not be set
  set_remote_description,

  /// The session description from this side could not be set
  set_local_description,

  /// A different device answered the call
  answered_elsewhere,

  /// No media connection could be established to the other party
  ice_failed,

  /// The invite timed out whilst waiting for an answer
  invite_timeout,

  /// The call was replaced by another call
  replaced,

  /// Signalling for the call could not be sent (other than the initial invite)
  ice_timeout,

  /// The remote party is busy
  user_busy,

  /// We transferred the call off to somewhere else
  transferred,

  /// Some other failure occurred that meant the client was unable to continue
  /// the call rather than the user choosing to end it.
  unknown_error,
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

enum CallEvent {
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

class GroupCallIntent {
  static String Ring = 'm.ring';
  static String Prompt = 'm.prompt';
  static String Room = 'm.room';
}

class GroupCallType {
  static String Video = 'm.video';
  static String Voice = 'm.voice';
}

class GroupCallTerminationReason {
  static String CallEnded = 'call_ended';
}

enum GroupCallErrorCode {
  user_media_failed,
  unknown_device,
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

enum GroupCallEvent {
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
