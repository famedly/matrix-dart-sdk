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

class CallErrorCode {
  /// The user chose to end the call
  static String UserHangup = 'user_hangup';

  /// An error code when the local client failed to create an offer.
  static String LocalOfferFailed = 'local_offer_failed';

  /// An error code when there is no local mic/camera to use. This may be because
  /// the hardware isn't plugged in, or the user has explicitly denied access.
  static String NoUserMedia = 'no_user_media';

  /// Error code used when a call event failed to send
  /// because unknown devices were present in the room
  static String UnknownDevices = 'unknown_devices';

  /// Error code used when we fail to send the invite
  /// for some reason other than there being unknown devices
  static String SendInvite = 'send_invite';

  /// An answer could not be created

  static String CreateAnswer = 'create_answer';

  /// Error code used when we fail to send the answer
  /// for some reason other than there being unknown devices

  static String SendAnswer = 'send_answer';

  /// The session description from the other side could not be set
  static String SetRemoteDescription = 'set_remote_description';

  /// The session description from this side could not be set
  static String SetLocalDescription = 'set_local_description';

  /// A different device answered the call
  static String AnsweredElsewhere = 'answered_elsewhere';

  /// No media connection could be established to the other party
  static String IceFailed = 'ice_failed';

  /// The invite timed out whilst waiting for an answer
  static String InviteTimeout = 'invite_timeout';

  /// The call was replaced by another call
  static String Replaced = 'replaced';

  /// Signalling for the call could not be sent (other than the initial invite)
  static String SignallingFailed = 'signalling_timeout';

  /// The remote party is busy
  static String UserBusy = 'user_busy';

  /// We transferred the call off to somewhere else
  static String Transfered = 'transferred';
}

class CallError extends Error {
  final String code;
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

class GroupCallEvent {
  static String GroupCallStateChanged = 'group_call_state_changed';
  static String ActiveSpeakerChanged = 'active_speaker_changed';
  static String CallsChanged = 'calls_changed';
  static String UserMediaStreamsChanged = 'user_media_feeds_changed';
  static String ScreenshareStreamsChanged = 'screenshare_feeds_changed';
  static String LocalScreenshareStateChanged =
      'local_screenshare_state_changed';
  static String LocalMuteStateChanged = 'local_mute_state_changed';
  static String ParticipantsChanged = 'participants_changed';
  static String Error = 'error';
}

class GroupCallErrorCode {
  static String NoUserMedia = 'no_user_media';
  static String UnknownDevice = 'unknown_device';
}
