import 'dart:async';
import 'dart:core';

import 'package:webrtc_interface/webrtc_interface.dart';
import 'package:sdp_transform/sdp_transform.dart' as sdp_transform;

import '../matrix.dart';

/// The default life time for call events, in millisecond.
const lifetimeMs = 10 * 1000;

/// The length of time a call can be ringing for.
const callTimeoutSec = 60;

/// Wrapped MediaStream, used to adapt Widget to display
class WrappedMediaStream {
  MediaStream? stream;
  final String userId;
  final Room room;

  /// Current stream type, usermedia or screen-sharing
  String purpose;
  bool audioMuted;
  bool videoMuted;
  final Client client;

  /// for debug
  String get title => '$displayName:$purpose:a[$audioMuted]:v[$videoMuted]';
  final VideoRenderer renderer;
  bool stopped = false;
  void Function(bool audioMuted, bool videoMuted)? onMuteStateChanged;
  void Function(MediaStream stream)? onNewStream;

  WrappedMediaStream(
      {this.stream,
      required this.renderer,
      required this.room,
      required this.userId,
      required this.purpose,
      required this.client,
      required this.audioMuted,
      required this.videoMuted});

  /// Initialize the video renderer
  Future<void> initialize() async {
    await renderer.initialize();
    renderer.srcObject = stream;
    renderer.onResize = () {
      Logs().i(
          'onResize [${stream!.id.substring(0, 8)}] ${renderer?.videoWidth} x ${renderer?.videoHeight}');
    };
  }

  Future<void> dispose() async {
    renderer.srcObject = null;
    await renderer.dispose();

    if (isLocal() && stream != null) {
      await stream?.dispose();
      stream = null;
    }
  }

  String get avatarName =>
      getUser().calcDisplayname(mxidLocalPartFallback: false);

  String? get displayName => getUser().displayName;

  User getUser() {
    return room.getUserByMXIDSync(userId);
  }

  bool isLocal() {
    return userId == client.userID;
  }

  bool isAudioMuted() {
    return (stream != null && stream!.getAudioTracks().isEmpty) || audioMuted;
  }

  bool isVideoMuted() {
    return (stream != null && stream!.getVideoTracks().isEmpty) || videoMuted;
  }

  void setNewStream(MediaStream newStream) {
    stream = newStream;
    renderer.srcObject = stream;
    if (onNewStream != null) {
      onNewStream?.call(stream!);
    }
  }

  void setAudioMuted(bool muted) {
    audioMuted = muted;
    if (onMuteStateChanged != null) {
      onMuteStateChanged?.call(audioMuted, videoMuted);
    }
  }

  void setVideoMuted(bool muted) {
    videoMuted = muted;
    if (onMuteStateChanged != null) {
      onMuteStateChanged?.call(audioMuted, videoMuted);
    }
  }
}

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

enum Direction { kIncoming, kOutgoing }

enum CallParty { kLocal, kRemote }

/// Initialization parameters of the call session.
class CallOptions {
  late String callId;
  late CallType type;
  late Direction dir;
  late String localPartyId;
  late VoIP voip;
  late Room room;
  late List<Map<String, dynamic>> iceServers;
}

/// A call session object
class CallSession {
  CallSession(this.opts);
  CallOptions opts;
  CallType get type => opts.type;
  Room get room => opts.room;
  VoIP get voip => opts.voip;
  String get callId => opts.callId;
  String get localPartyId => opts.localPartyId;
  String? get displayName => room.displayname;
  Direction get direction => opts.dir;
  CallState state = CallState.kFledgling;
  bool get isOutgoing => direction == Direction.kOutgoing;
  bool get isRinging => state == CallState.kRinging;
  RTCPeerConnection? pc;
  List<RTCIceCandidate> remoteCandidates = <RTCIceCandidate>[];
  List<RTCIceCandidate> localCandidates = <RTCIceCandidate>[];
  late AssertedIdentity remoteAssertedIdentity;
  bool get callHasEnded => state == CallState.kEnded;
  bool iceGatheringFinished = false;
  bool inviteOrAnswerSent = false;
  bool localHold = false;
  bool remoteOnHold = false;
  bool _answeredByUs = false;
  bool speakerOn = false;
  bool makingOffer = false;
  bool ignoreOffer = false;
  String facingMode = 'user';
  late Client client;
  String? remotePartyId;
  late User remoteUser;
  late CallParty hangupParty;
  late String hangupReason;

  SDPStreamMetadata? remoteSDPStreamMetadata;
  List<RTCRtpSender> usermediaSenders = [];
  List<RTCRtpSender> screensharingSenders = [];
  Map<String, WrappedMediaStream> streams = <String, WrappedMediaStream>{};
  List<WrappedMediaStream> get getLocalStreams =>
      streams.values.where((element) => element.isLocal()).toList();
  List<WrappedMediaStream> get getRemoteStreams =>
      streams.values.where((element) => !element.isLocal()).toList();
  WrappedMediaStream? get localUserMediaStream => getLocalStreams.firstWhere(
      (element) => element.purpose == SDPStreamMetadataPurpose.Usermedia,
      orElse: () => Null as WrappedMediaStream);
  WrappedMediaStream? get localScreenSharingStream =>
      getLocalStreams.firstWhere(
          (element) => element.purpose == SDPStreamMetadataPurpose.Screenshare,
          orElse: () => Null as WrappedMediaStream);
  WrappedMediaStream? get remoteUserMediaStream => getRemoteStreams.firstWhere(
      (element) => element.purpose == SDPStreamMetadataPurpose.Usermedia,
      orElse: () => Null as WrappedMediaStream);
  WrappedMediaStream? get remoteScreenSharingStream =>
      getRemoteStreams.firstWhere(
          (element) => element.purpose == SDPStreamMetadataPurpose.Screenshare,
          orElse: () => Null as WrappedMediaStream);
  final _callStateController =
      StreamController<CallState>.broadcast(sync: true);
  Stream<CallState> get onCallStateChanged => _callStateController.stream;
  final _callEventController =
      StreamController<CallEvent>.broadcast(sync: true);
  Stream<CallEvent> get onCallEventChanged => _callEventController.stream;
  Timer? inviteTimer;
  Timer? ringingTimer;

  Future<void> initOutboundCall(CallType type) async {
    await _preparePeerConnection();
    setCallState(CallState.kCreateOffer);
    final stream = await _getUserMedia(type);
    _addLocalStream(stream, SDPStreamMetadataPurpose.Usermedia);
  }

  Future<void> initWithInvite(CallType type, RTCSessionDescription offer,
      SDPStreamMetadata? metadata, int lifetime) async {
    await _preparePeerConnection();

    _addLocalStream(
        await _getUserMedia(type), SDPStreamMetadataPurpose.Usermedia);

    if (metadata != null) {
      _updateRemoteSDPStreamMetadata(metadata);
    }

    await pc!.setRemoteDescription(offer);

    setCallState(CallState.kRinging);

    ringingTimer = Timer(Duration(milliseconds: lifetime - 3000), () {
      if (state == CallState.kRinging) {
        Logs().v('[VOIP] Call invite has expired. Hanging up.');
        hangupParty = CallParty.kRemote; // effectively
        setCallState(CallState.kEnded);
        emit(CallEvent.kHangup);
      }
      ringingTimer?.cancel();
      ringingTimer = null;
    });
  }

  void initWithHangup() {
    setCallState(CallState.kEnded);
  }

  void onAnswerReceived(
      RTCSessionDescription answer, SDPStreamMetadata? metadata) async {
    if (metadata != null) {
      _updateRemoteSDPStreamMetadata(metadata);
    }

    if (direction == Direction.kOutgoing) {
      setCallState(CallState.kConnecting);
      await pc!.setRemoteDescription(answer);
      remoteCandidates.forEach((candidate) => pc!.addCandidate(candidate));
    }
  }

  void onNegotiateReceived(
      SDPStreamMetadata? metadata, RTCSessionDescription description) async {
    final polite = direction == Direction.kIncoming;

    // Here we follow the perfect negotiation logic from
    // https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API/Perfect_negotiation
    final offerCollision = ((description.type == 'offer') &&
        (makingOffer ||
            pc!.signalingState != RTCSignalingState.RTCSignalingStateStable));

    ignoreOffer = !polite && offerCollision;
    if (ignoreOffer) {
      Logs().i('Ignoring colliding negotiate event because we\'re impolite');
      return;
    }

    final prevLocalOnHold = await isLocalOnHold();

    if (metadata != null) {
      _updateRemoteSDPStreamMetadata(metadata);
    }

    try {
      await pc!.setRemoteDescription(description);
      if (description.type == 'offer') {
        final answer = await pc!.createAnswer({});
        await room.sendCallNegotiate(
            callId, lifetimeMs, localPartyId, answer.sdp!,
            type: answer.type!);
        await pc!.setLocalDescription(answer);
      }
    } catch (e) {
      _getLocalOfferFailed(e);
      Logs().e('[VOIP] onNegotiateReceived => ${e.toString()}');
      return;
    }

    final newLocalOnHold = await isLocalOnHold();
    if (prevLocalOnHold != newLocalOnHold) {
      localHold = newLocalOnHold;
      emit(CallEvent.kLocalHoldUnhold, newLocalOnHold);
    }
  }

  void _updateRemoteSDPStreamMetadata(SDPStreamMetadata metadata) {
    remoteSDPStreamMetadata = metadata;
    remoteSDPStreamMetadata!.sdpStreamMetadatas
        .forEach((streamId, sdpStreamMetadata) {
      Logs().i(
          'Stream purpose update: \nid = "$streamId", \npurpose = "${sdpStreamMetadata.purpose}",  \naudio_muted = ${sdpStreamMetadata.audio_muted}, \nvideo_muted = ${sdpStreamMetadata.video_muted}');
    });
    getRemoteStreams.forEach((wpstream) {
      final streamId = wpstream.stream!.id;
      final purpose = metadata.sdpStreamMetadatas[streamId];
      if (purpose != null) {
        wpstream
            .setAudioMuted(metadata.sdpStreamMetadatas[streamId]!.audio_muted);
        wpstream
            .setVideoMuted(metadata.sdpStreamMetadatas[streamId]!.video_muted);
        wpstream.purpose = metadata.sdpStreamMetadatas[streamId]!.purpose;
      } else {
        Logs().i('Not found purpose for remote stream $streamId, remove it?');
        wpstream.stopped = true;
        emit(CallEvent.kFeedsChanged, streams);
      }
    });
  }

  void onSDPStreamMetadataReceived(SDPStreamMetadata metadata) async {
    _updateRemoteSDPStreamMetadata(metadata);
    emit(CallEvent.kFeedsChanged, streams);
  }

  void onCandidatesReceived(List<dynamic> candidates) {
    candidates.forEach((json) async {
      final candidate = RTCIceCandidate(
        json['candidate'],
        json['sdpMid'] ?? '',
        json['sdpMLineIndex']?.round() ?? 0,
      );

      if (pc != null && inviteOrAnswerSent && remotePartyId != null) {
        try {
          await pc!.addCandidate(candidate);
        } catch (e) {
          Logs().e('[VOIP] onCandidatesReceived => ${e.toString()}');
        }
      } else {
        remoteCandidates.add(candidate);
      }
    });

    if (pc != null &&
        pc!.iceConnectionState ==
            RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
      _restartIce();
    }
  }

  void onAssertedIdentityReceived(AssertedIdentity identity) async {
    remoteAssertedIdentity = identity;
    emit(CallEvent.kAssertedIdentityChanged);
  }

  bool get screensharingEnabled => localScreenSharingStream != null;

  Future<bool> setScreensharingEnabled(bool enabled) async {
    // Skip if there is nothing to do
    if (enabled && localScreenSharingStream != null) {
      Logs().w(
          'There is already a screensharing stream - there is nothing to do!');
      return true;
    } else if (!enabled && localScreenSharingStream == null) {
      Logs().w(
          'There already isn\'t a screensharing stream - there is nothing to do!');
      return false;
    }

    Logs().d('Set screensharing enabled? $enabled');

    if (enabled) {
      try {
        final MediaStream? stream = await _getDisplayMedia();
        if (stream == null) {
          return false;
        }
        _addLocalStream(stream, SDPStreamMetadataPurpose.Screenshare);
        return true;
      } catch (err) {
        emit(
            CallEvent.kError,
            CallError(CallErrorCode.NoUserMedia,
                'Failed to get screen-sharing stream: ', err));
        return false;
      }
    } else {
      for (final sender in screensharingSenders) {
        await pc!.removeTrack(sender);
      }
      for (final track in localScreenSharingStream!.stream!.getTracks()) {
        await track.stop();
      }
      localScreenSharingStream!.stopped = true;
      emit(CallEvent.kFeedsChanged, streams);
      return false;
    }
  }

  void _addLocalStream(MediaStream stream, String purpose,
      {bool addToPeerConnection = true}) async {
    final WrappedMediaStream? existingStream = getLocalStreams.firstWhere(
        (element) => element.purpose == purpose,
        orElse: () => Null as WrappedMediaStream);
    if (existingStream != null) {
      existingStream.setNewStream(stream);
    } else {
      final newStream = WrappedMediaStream(
        renderer: voip.factory.videoRenderer(),
        userId: client.userID!,
        room: opts.room,
        stream: stream,
        purpose: purpose,
        client: client,
        audioMuted: stream.getAudioTracks().isEmpty,
        videoMuted: stream.getVideoTracks().isEmpty,
      );
      await newStream.initialize();
      streams[stream.id] = newStream;
      emit(CallEvent.kFeedsChanged, streams);
    }

    if (addToPeerConnection) {
      if (purpose == SDPStreamMetadataPurpose.Screenshare) {
        screensharingSenders.clear();
        stream.getTracks().forEach((track) async {
          screensharingSenders.add(await pc!.addTrack(track, stream));
        });
      } else if (purpose == SDPStreamMetadataPurpose.Usermedia) {
        usermediaSenders.clear();
        stream.getTracks().forEach((track) async {
          usermediaSenders.add(await pc!.addTrack(track, stream));
        });
      }
      emit(CallEvent.kFeedsChanged, streams);
    }

    if (purpose == SDPStreamMetadataPurpose.Usermedia) {
      speakerOn = type == CallType.kVideo;
      //TODO: Confirm that the platform is not Web.
      if (/*!kIsWeb && */ !voip.background) {
        final audioTrack = stream.getAudioTracks()[0];
        audioTrack.enableSpeakerphone(speakerOn);
      }
    }
  }

  void _addRemoteStream(MediaStream stream) async {
    //const userId = this.getOpponentMember().userId;
    final metadata = remoteSDPStreamMetadata!.sdpStreamMetadatas[stream.id];
    if (metadata == null) {
      Logs().i(
          'Ignoring stream with id ${stream.id} because we didn\'t get any metadata about it');
      return;
    }

    final purpose = metadata.purpose;
    final audioMuted = metadata.audio_muted;
    final videoMuted = metadata.video_muted;

    // Try to find a feed with the same purpose as the new stream,
    // if we find it replace the old stream with the new one
    final WrappedMediaStream? existingStream = getRemoteStreams.firstWhere(
        (element) => element.purpose == purpose,
        orElse: () => Null as WrappedMediaStream);
    if (existingStream != null) {
      existingStream.setNewStream(stream);
    } else {
      final newStream = WrappedMediaStream(
        renderer: voip.factory.videoRenderer(),
        userId: remoteUser.id,
        room: opts.room,
        stream: stream,
        purpose: purpose,
        client: client,
        audioMuted: audioMuted,
        videoMuted: videoMuted,
      );
      await newStream.initialize();
      streams[stream.id] = newStream;
    }
    emit(CallEvent.kFeedsChanged, streams);
    Logs().i('Pushed remote stream (id="${stream.id}", purpose=$purpose)');
  }

  void setCallState(CallState newState) {
    final oldState = state;
    state = newState;
    _callStateController.add(newState);
    emit(CallEvent.kState, state, oldState);
  }

  void setLocalVideoMuted(bool muted) {
    localUserMediaStream?.setVideoMuted(muted);
    _updateMuteStatus();
  }

  bool get isLocalVideoMuted => localUserMediaStream?.isVideoMuted() ?? false;

  void setMicrophoneMuted(bool muted) {
    localUserMediaStream?.setAudioMuted(muted);
    _updateMuteStatus();
  }

  bool get isMicrophoneMuted => localUserMediaStream?.isAudioMuted() ?? false;

  void setRemoteOnHold(bool onHold) async {
    if (isRemoteOnHold == onHold) return;
    remoteOnHold = onHold;
    final transceivers = await pc!.getTransceivers();
    for (final transceiver in transceivers) {
      await transceiver.setDirection(onHold
          ? TransceiverDirection.SendOnly
          : TransceiverDirection.SendRecv);
    }
    _updateMuteStatus();
    emit(CallEvent.kRemoteHoldUnhold, remoteOnHold);
  }

  bool get isRemoteOnHold => remoteOnHold;

  Future<bool> isLocalOnHold() async {
    if (state != CallState.kConnected) return false;
    var callOnHold = true;
    // We consider a call to be on hold only if *all* the tracks are on hold
    // (is this the right thing to do?)
    final transceivers = await pc!.getTransceivers();
    for (final transceiver in transceivers) {
      final currentDirection = await transceiver.getCurrentDirection();
      Logs()
          .i('transceiver.currentDirection = ${currentDirection?.toString()}');
      final trackOnHold = (currentDirection == TransceiverDirection.Inactive ||
          currentDirection == TransceiverDirection.RecvOnly);
      if (!trackOnHold) {
        callOnHold = false;
      }
    }
    return callOnHold;
  }

  void setSpeakerOn() {
    speakerOn = !speakerOn;
  }

  //TODO: move to the app.
  Future<void> switchCamera() async {
    if (localUserMediaStream != null) {
      /*
      await Helper.switchCamera(
          localUserMediaStream!.stream!.getVideoTracks()[0]);
      if (kIsMobile) {
        facingMode == 'user' ? facingMode = 'environment' : facingMode = 'user';
      }
      */
    }
  }

  void answer() async {
    if (inviteOrAnswerSent) {
      return;
    }
    // stop play ringtone
    voip.stopRingTone();

    if (direction == Direction.kIncoming) {
      setCallState(CallState.kCreateAnswer);

      final answer = await pc!.createAnswer({});
      remoteCandidates.forEach((candidate) => pc!.addCandidate(candidate));

      final callCapabilities = CallCapabilities()
        ..dtmf = false
        ..transferee = false;

      final metadata = SDPStreamMetadata({
        localUserMediaStream!.stream!.id: SDPStreamPurpose(
            purpose: SDPStreamMetadataPurpose.Usermedia,
            audio_muted: localUserMediaStream!.stream!.getAudioTracks().isEmpty,
            video_muted: localUserMediaStream!.stream!.getVideoTracks().isEmpty)
      });

      final res = await room.answerCall(callId, answer.sdp!, localPartyId,
          type: answer.type!,
          capabilities: callCapabilities,
          metadata: metadata);
      Logs().v('[VOIP] answer res => $res');
      await pc!.setLocalDescription(answer);
      setCallState(CallState.kConnecting);
      inviteOrAnswerSent = true;
      _answeredByUs = true;
    }
  }

  /// Reject a call
  /// This used to be done by calling hangup, but is a separate method and protocol
  /// event as of MSC2746.
  ///
  void reject() {
    if (state != CallState.kRinging) {
      Logs().e('[VOIP] Call must be in \'ringing\' state to reject!');
      return;
    }
    Logs().d('[VOIP] Rejecting call: $callId');
    terminate(CallParty.kLocal, CallErrorCode.UserHangup, true);
    room.sendCallReject(callId, lifetimeMs, localPartyId);
  }

  void hangup([String? reason, bool suppressEvent = true]) async {
    // stop play ringtone
    voip.stopRingTone();

    terminate(
        CallParty.kLocal, reason ?? CallErrorCode.UserHangup, !suppressEvent);

    try {
      final res = await room.hangupCall(callId, localPartyId, 'userHangup');
      Logs().v('[VOIP] hangup res => $res');
    } catch (e) {
      Logs().v('[VOIP] hangup error => ${e.toString()}');
    }
  }

  void sendDTMF(String tones) async {
    final senders = await pc!.getSenders();
    for (final sender in senders) {
      if (sender.track != null && sender.track!.kind == 'audio') {
        await sender.dtmfSender.insertDTMF(tones);
        return;
      }
    }
    Logs().e('Unable to find a track to send DTMF on');
  }

  void terminate(CallParty party, String hangupReason, bool shouldEmit) async {
    if (state == CallState.kEnded) {
      return;
    }

    inviteTimer?.cancel();
    inviteTimer = null;

    ringingTimer?.cancel();
    ringingTimer = null;

    hangupParty = party;
    hangupReason = hangupReason;

    setCallState(CallState.kEnded);
    voip.currentCID = null;
    voip.calls.remove(callId);

    if (shouldEmit) {
      emit(CallEvent.kHangup, this);
    }
  }

  void onRejectReceived(String? reason) {
    Logs().v('[VOIP] Reject received for call ID ' + callId);
    // No need to check party_id for reject because if we'd received either
    // an answer or reject, we wouldn't be in state InviteSent
    final shouldTerminate =
        (state == CallState.kFledgling && direction == Direction.kIncoming) ||
            CallState.kInviteSent == state ||
            CallState.kRinging == state;

    if (shouldTerminate) {
      terminate(CallParty.kRemote, reason ?? CallErrorCode.UserHangup, true);
    } else {
      Logs().e('Call is in state: ${state.toString()}: ignoring reject');
    }
  }

  Future<void> _gotLocalOffer(RTCSessionDescription offer) async {
    if (callHasEnded) {
      Logs().d(
          'Ignoring newly created offer on call ID ${opts.callId} because the call has ended');
      return;
    }

    try {
      await pc!.setLocalDescription(offer);
    } catch (err) {
      Logs().d('Error setting local description! ${err.toString()}');
      terminate(CallParty.kLocal, CallErrorCode.SetLocalDescription, true);
      return;
    }

    if (callHasEnded) return;

    final callCapabilities = CallCapabilities()
      ..dtmf = false
      ..transferee = false;
    final metadata = _getLocalSDPStreamMetadata();
    if (state == CallState.kCreateOffer) {
      await room.inviteToCall(
          callId, lifetimeMs, localPartyId, null, offer.sdp!,
          capabilities: callCapabilities, metadata: metadata);
      inviteOrAnswerSent = true;
      setCallState(CallState.kInviteSent);

      inviteTimer = Timer(Duration(seconds: callTimeoutSec), () {
        if (state == CallState.kInviteSent) {
          hangup(CallErrorCode.InviteTimeout, false);
        }
        inviteTimer?.cancel();
        inviteTimer = null;
      });
    } else {
      await room.sendCallNegotiate(callId, lifetimeMs, localPartyId, offer.sdp!,
          type: offer.type!,
          capabilities: callCapabilities,
          metadata: metadata);
    }
  }

  void onNegotiationNeeded() async {
    Logs().i('Negotiation is needed!');
    makingOffer = true;
    try {
      final offer = await pc!.createOffer({});
      await _gotLocalOffer(offer);
    } catch (e) {
      _getLocalOfferFailed(e);
      return;
    } finally {
      makingOffer = false;
    }
  }

  Future<void> _preparePeerConnection() async {
    try {
      pc = await _createPeerConnection();

      pc!.onRenegotiationNeeded = onNegotiationNeeded;

      pc!.onIceCandidate = (RTCIceCandidate candidate) async {
        //Logs().v('[VOIP] onIceCandidate => ${candidate.toMap().toString()}');
        localCandidates.add(candidate);
      };
      pc!.onIceGatheringState = (RTCIceGatheringState state) async {
        Logs().v('[VOIP] IceGatheringState => ${state.toString()}');
        if (state == RTCIceGatheringState.RTCIceGatheringStateGathering) {
          Timer(Duration(milliseconds: 3000), () async {
            if (!iceGatheringFinished) {
              iceGatheringFinished = true;
              await _candidateReady();
            }
          });
        }
        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
          if (!iceGatheringFinished) {
            iceGatheringFinished = true;
            await _candidateReady();
          }
        }
      };
      pc!.onIceConnectionState = (RTCIceConnectionState state) {
        Logs().v('[VOIP] RTCIceConnectionState => ${state.toString()}');
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
          localCandidates.clear();
          remoteCandidates.clear();
          setCallState(CallState.kConnected);
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          hangup(CallErrorCode.IceFailed, false);
        }
      };
    } catch (e) {
      Logs().v('[VOIP] prepareMediaStream error => ${e.toString()}');
    }
  }

  void onAnsweredElsewhere(String msg) {
    Logs().d('Call ID $callId answered elsewhere');
    terminate(CallParty.kRemote, CallErrorCode.AnsweredElsewhere, true);
  }

  void cleanUp() async {
    streams.forEach((id, stream) {
      stream.dispose();
    });
    streams.clear();
    if (pc != null) {
      await pc!.close();
      await pc!.dispose();
    }
  }

  void _updateMuteStatus() async {
    final micShouldBeMuted = (localUserMediaStream != null &&
            localUserMediaStream!.isAudioMuted()) ||
        remoteOnHold;
    final vidShouldBeMuted = (localUserMediaStream != null &&
            localUserMediaStream!.isVideoMuted()) ||
        remoteOnHold;

    _setTracksEnabled(localUserMediaStream?.stream!.getAudioTracks() ?? [],
        !micShouldBeMuted);
    _setTracksEnabled(localUserMediaStream?.stream!.getVideoTracks() ?? [],
        !vidShouldBeMuted);

    await opts.room.sendSDPStreamMetadataChanged(
        callId, localPartyId, _getLocalSDPStreamMetadata());
  }

  void _setTracksEnabled(List<MediaStreamTrack> tracks, bool enabled) {
    tracks.forEach((track) async {
      track.enabled = enabled;
    });
  }

  SDPStreamMetadata _getLocalSDPStreamMetadata() {
    final sdpStreamMetadatas = <String, SDPStreamPurpose>{};
    for (final wpstream in getLocalStreams) {
      sdpStreamMetadatas[wpstream.stream!.id] = SDPStreamPurpose(
          purpose: wpstream.purpose,
          audio_muted: wpstream.audioMuted,
          video_muted: wpstream.videoMuted);
    }
    final metadata = SDPStreamMetadata(sdpStreamMetadatas);
    Logs().v('Got local SDPStreamMetadata ${metadata.toJson().toString()}');
    return metadata;
  }

  void _restartIce() async {
    Logs().v('[VOIP] iceRestart.');
    // Needs restart ice on session.pc and renegotiation.
    iceGatheringFinished = false;
    final desc =
        await pc!.createOffer(_getOfferAnswerConstraints(iceRestart: true));
    await pc!.setLocalDescription(desc);
    localCandidates.clear();
  }

  Future<MediaStream> _getUserMedia(CallType type) async {
    final mediaConstraints = {
      'audio': true,
      'video': type == CallType.kVideo
          ? {
              'mandatory': {
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '30',
              },
              'facingMode': 'user',
              'optional': [],
            }
          : false,
    };
    try {
      return await voip.factory.navigator.mediaDevices
          .getUserMedia(mediaConstraints);
    } catch (e) {
      _getUserMediaFailed(e);
    }
    return Null as MediaStream;
  }

  Future<MediaStream> _getDisplayMedia() async {
    final mediaConstraints = {
      'audio': false,
      'video': true,
    };
    try {
      return await voip.factory.navigator.mediaDevices
          .getDisplayMedia(mediaConstraints);
    } catch (e) {
      _getUserMediaFailed(e);
    }
    return Null as MediaStream;
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final configuration = <String, dynamic>{
      'iceServers': opts.iceServers,
      'sdpSemantics': 'unified-plan'
    };
    final pc = await voip.factory.createPeerConnection(configuration);
    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        final stream = event.streams[0];
        _addRemoteStream(stream);
      }
    };
    return pc;
  }

  void tryRemoveStopedStreams() {
    final removedStreams = <String, WrappedMediaStream>{};
    streams.forEach((id, stream) {
      if (stream.stopped) {
        removedStreams[id] = stream;
      }
    });
    streams.removeWhere((id, stream) => removedStreams.containsKey(id));
    removedStreams.forEach((id, element) {
      _removeStream(id);
    });
  }

  Future<void> _removeStream(String streamId) async {
    Logs().v('Removing feed with stream id $streamId');
    final removedStream = streams.remove(streamId);
    if (removedStream == null) {
      Logs().v('Didn\'t find the feed with stream id $streamId to delete');
      return;
    }
    await removedStream.dispose();
  }

  Map<String, dynamic> _getOfferAnswerConstraints({bool iceRestart = false}) {
    return {
      'mandatory': {if (iceRestart) 'IceRestart': true},
      'optional': [],
    };
  }

  Future<void> _candidateReady() async {
    /*
    Currently, trickle-ice is not supported, so it will take a
    long time to wait to collect all the canidates, set the
    timeout for collection canidates to speed up the connection.
    */
    try {
      final candidates = <Map<String, dynamic>>[];
      localCandidates.forEach((element) {
        candidates.add(element.toMap());
      });
      final res =
          await room.sendCallCandidates(callId, localPartyId, candidates);
      Logs().v('[VOIP] sendCallCandidates res => $res');
    } catch (e) {
      Logs().v('[VOIP] sendCallCandidates e => ${e.toString()}');
    }
  }

  void emit(CallEvent event, [dynamic arg1, dynamic arg2, dynamic arg3]) {
    _callEventController.add(event);
    Logs().i('CallEvent: ${event.toString()}');
    switch (event) {
      case CallEvent.kFeedsChanged:
        break;
      case CallEvent.kState:
        Logs().i('CallState: ${state.toString()}');
        break;
      case CallEvent.kError:
        break;
      case CallEvent.kHangup:
        break;
      case CallEvent.kReplaced:
        break;
      case CallEvent.kLocalHoldUnhold:
        break;
      case CallEvent.kRemoteHoldUnhold:
        break;
      case CallEvent.kAssertedIdentityChanged:
        break;
    }
  }

  void _getLocalOfferFailed(dynamic err) {
    Logs().e('Failed to get local offer ${err.toString()}');

    emit(
      CallEvent.kError,
      CallError(
        CallErrorCode.LocalOfferFailed,
        'Failed to get local offer!',
        err,
      ),
    );
    terminate(CallParty.kLocal, CallErrorCode.LocalOfferFailed, false);
  }

  void _getUserMediaFailed(dynamic err) {
    Logs().w('Failed to get user media - ending call ${err.toString()}');
    emit(
      CallEvent.kError,
      CallError(
        CallErrorCode.NoUserMedia,
        'Couldn\'t start capturing media! Is your microphone set up and does this app have permission?',
        err,
      ),
    );
    terminate(CallParty.kLocal, CallErrorCode.NoUserMedia, false);
  }

  void onSelectAnswerReceived(String? selectedPartyId) {
    if (direction != Direction.kIncoming) {
      Logs().w('Got select_answer for an outbound call: ignoring');
      return;
    }
    if (selectedPartyId == null) {
      Logs().w(
          'Got nonsensical select_answer with null/undefined selected_party_id: ignoring');
      return;
    }

    if (selectedPartyId != localPartyId) {
      Logs().w(
          'Got select_answer for party ID $selectedPartyId: we are party ID $localPartyId.');
      // The other party has picked somebody else's answer
      terminate(CallParty.kRemote, CallErrorCode.AnsweredElsewhere, true);
    }
  }
}

class VoIP {
  TurnServerCredentials? _turnServerCredentials;
  Map<String, CallSession> calls = <String, CallSession>{};
  String? currentCID;
  Function(CallSession session)? onNewCall;
  Function(CallSession session)? onCallEnded;
  String? get localPartyId => client.deviceID;
  bool background = false;
  final Client client;
  final RTCFactory factory;

  VoIP(this.client, this.factory) : super() {
    client.onCallInvite.stream.listen(onCallInvite);
    client.onCallAnswer.stream.listen(onCallAnswer);
    client.onCallCandidates.stream.listen(onCallCandidates);
    client.onCallHangup.stream.listen(onCallHangup);
    client.onCallReject.stream.listen(onCallReject);
    client.onCallNegotiate.stream.listen(onCallNegotiate);
    client.onCallReplaces.stream.listen(onCallReplaces);
    client.onCallSelectAnswer.stream.listen(onCallSelectAnswer);
    client.onSDPStreamMetadataChangedReceived.stream
        .listen(onSDPStreamMetadataChangedReceived);
    client.onAssertedIdentityReceived.stream.listen(onAssertedIdentityReceived);

    /* TODO: implement this in the fanedly-app.
      Connectivity().onConnectivityChanged.listen(_handleNetworkChanged);
      Connectivity()
          .checkConnectivity()
          .then((result) => _currentConnectivity = result)
          .catchError((e) => _currentConnectivity = ConnectivityResult.none);
      if (!kIsWeb) {
        final wb = WidgetsBinding.instance;
        wb!.addObserver(this);
        didChangeAppLifecycleState(wb.lifecycleState!);
      }
    */
  }

  Future<void> onCallInvite(Event event) async {
    if (event.senderId == client.userID) {
      // Ignore messages to yourself.
      return;
    }

    Logs().v(
        '[VOIP] onCallInvite ${event.senderId} => ${client.userID}, \ncontent => ${event.content.toString()}');

    final String callId = event.content['call_id'];
    final String partyId = event.content['party_id'];
    final int lifetime = event.content['lifetime'];

    if (currentCID != null) {
      // Only one session at a time.
      Logs().v('[VOIP] onCallInvite: There is already a session.');
      await event.room.hangupCall(callId, localPartyId!, 'userBusy');
      return;
    }
    if (calls[callId] != null) {
      // Session already exist.
      Logs().v('[VOIP] onCallInvite: Session [$callId] already exist.');
      return;
    }

    if (event.content['capabilities'] != null) {
      final capabilities =
          CallCapabilities.fromJson(event.content['capabilities']);
      Logs().v(
          '[VOIP] CallCapabilities: dtmf => ${capabilities.dtmf}, transferee => ${capabilities.transferee}');
    }

    var callType = CallType.kVoice;
    SDPStreamMetadata? sdpStreamMetadata;
    if (event.content[sdpStreamMetadataKey] != null) {
      sdpStreamMetadata =
          SDPStreamMetadata.fromJson(event.content[sdpStreamMetadataKey]);
      sdpStreamMetadata.sdpStreamMetadatas
          .forEach((streamId, SDPStreamPurpose purpose) {
        Logs().v(
            '[VOIP] [$streamId] => purpose: ${purpose.purpose}, audioMuted: ${purpose.audio_muted}, videoMuted:  ${purpose.video_muted}');

        if (!purpose.video_muted) {
          callType = CallType.kVideo;
        }
      });
    } else {
      callType = getCallType(event.content['offer']['sdp']);
    }

    final opts = CallOptions()
      ..voip = this
      ..callId = callId
      ..dir = Direction.kIncoming
      ..type = callType
      ..room = event.room
      ..localPartyId = localPartyId!
      ..iceServers = await getIceSevers();

    final newCall = createNewCall(opts);
    newCall.remotePartyId = partyId;
    newCall.remoteUser = event.sender;
    final offer = RTCSessionDescription(
      event.content['offer']['sdp'],
      event.content['offer']['type'],
    );
    await newCall
        .initWithInvite(callType, offer, sdpStreamMetadata, lifetime)
        .then((_) {
      // Popup CallingPage for incoming call.
      if (!background) {
        onNewCall?.call(newCall);
      }
    });
    currentCID = callId;

    if (background) {
      /// Forced to enable signaling synchronization until the end of the call.
      client.backgroundSync = true;

      ///TODO: notify the callkeep that the call is incoming.
    }
    // Play ringtone
    playRingtone();
  }

  void playRingtone() async {
    if (!background) {
      try {
        // TODO: callback the event to the user.
        // await UserMediaManager().startRinginTone();
      } catch (_) {}
    }
  }

  void stopRingTone() async {
    if (!background) {
      try {
        // TODO:
        // await UserMediaManager().stopRingingTone();
      } catch (_) {}
    }
  }

  void onCallAnswer(Event event) async {
    Logs().v('[VOIP] onCallAnswer => ${event.content.toString()}');
    final String callId = event.content['call_id'];
    final String partyId = event.content['party_id'];

    final call = calls[callId];
    if (call != null) {
      if (event.senderId == client.userID) {
        // Ignore messages to yourself.
        if (!call._answeredByUs) {
          stopRingTone();
        }
        return;
      }

      call.remotePartyId = partyId;
      call.remoteUser = event.sender;

      final answer = RTCSessionDescription(
          event.content['answer']['sdp'], event.content['answer']['type']);

      SDPStreamMetadata? metadata;
      if (event.content[sdpStreamMetadataKey] != null) {
        metadata =
            SDPStreamMetadata.fromJson(event.content[sdpStreamMetadataKey]);
      }
      call.onAnswerReceived(answer, metadata);

      /// Send select_answer event.
      await event.room.selectCallAnswer(
          callId, lifetimeMs, localPartyId!, call.remotePartyId!);
    } else {
      Logs().v('[VOIP] onCallAnswer: Session [$callId] not found!');
    }
  }

  void onCallCandidates(Event event) async {
    if (event.senderId == client.userID) {
      // Ignore messages to yourself.
      return;
    }
    Logs().v('[VOIP] onCallCandidates => ${event.content.toString()}');
    final String callId = event.content['call_id'];
    final call = calls[callId];
    if (call != null) {
      call.onCandidatesReceived(event.content['candidates']);
    } else {
      Logs().v('[VOIP] onCallCandidates: Session [$callId] not found!');
    }
  }

  void onCallHangup(Event event) async {
    // stop play ringtone, if this is an incoming call
    if (!background) {
      stopRingTone();
    }
    Logs().v('[VOIP] onCallHangup => ${event.content.toString()}');
    final String callId = event.content['call_id'];
    final call = calls[callId];
    if (call != null) {
      // hangup in any case, either if the other party hung up or we did on another device
      call.terminate(CallParty.kRemote,
          event.content['reason'] ?? CallErrorCode.UserHangup, true);
      onCallEnded?.call(call);
    } else {
      Logs().v('[VOIP] onCallHangup: Session [$callId] not found!');
    }
    currentCID = null;
  }

  void onCallReject(Event event) async {
    if (event.senderId == client.userID) {
      // Ignore messages to yourself.
      return;
    }
    final String callId = event.content['call_id'];
    Logs().d('Reject received for call ID ' + callId);

    final call = calls[callId];
    if (call != null) {
      call.onRejectReceived(event.content['reason']);
    } else {
      Logs().v('[VOIP] onCallHangup: Session [$callId] not found!');
    }
  }

  void onCallReplaces(Event event) async {
    if (event.senderId == client.userID) {
      // Ignore messages to yourself.
      return;
    }
    final String callId = event.content['call_id'];
    Logs().d('onCallReplaces received for call ID ' + callId);
    final call = calls[callId];
    if (call != null) {
      //TODO: handle replaces
    }
  }

  void onCallSelectAnswer(Event event) async {
    if (event.senderId == client.userID) {
      // Ignore messages to yourself.
      return;
    }
    final String callId = event.content['call_id'];
    Logs().d('SelectAnswer received for call ID ' + callId);
    final call = calls[callId];
    final String selectedPartyId = event.content['selected_party_id'];

    if (call != null) {
      call.onSelectAnswerReceived(selectedPartyId);
    }
  }

  void onSDPStreamMetadataChangedReceived(Event event) async {
    if (event.senderId == client.userID) {
      // Ignore messages to yourself.
      return;
    }
    final String callId = event.content['call_id'];
    Logs().d('SDP Stream metadata received for call ID ' + callId);
    final call = calls[callId];
    if (call != null) {
      if (event.content[sdpStreamMetadataKey] == null) {
        Logs().d('SDP Stream metadata is null');
        return;
      }
      call.onSDPStreamMetadataReceived(
          SDPStreamMetadata.fromJson(event.content[sdpStreamMetadataKey]));
    }
  }

  void onAssertedIdentityReceived(Event event) async {
    if (event.senderId == client.userID) {
      // Ignore messages to yourself.
      return;
    }
    final String callId = event.content['call_id'];
    Logs().d('Asserted identity received for call ID ' + callId);
    final call = calls[callId];
    if (call != null) {
      if (event.content['asserted_identity'] == null) {
        Logs().d('asserted_identity is null ');
        return;
      }
      call.onAssertedIdentityReceived(
          AssertedIdentity.fromJson(event.content['asserted_identity']));
    }
  }

  void onCallNegotiate(Event event) async {
    if (event.senderId == client.userID) {
      // Ignore messages to yourself.
      return;
    }
    final String callId = event.content['call_id'];
    Logs().d('Negotiate received for call ID ' + callId);
    final call = calls[callId];
    if (call != null) {
      final description = event.content['description'];
      try {
        SDPStreamMetadata? metadata;
        if (event.content[sdpStreamMetadataKey] != null) {
          metadata =
              SDPStreamMetadata.fromJson(event.content[sdpStreamMetadataKey]);
        }
        call.onNegotiateReceived(metadata,
            RTCSessionDescription(description['sdp'], description['type']));
      } catch (err) {
        Logs().e('Failed to complete negotiation ${err.toString()}');
      }
    }
  }

  CallType getCallType(String sdp) {
    try {
      final session = sdp_transform.parse(sdp);
      if (session['media'].indexWhere((e) => e['type'] == 'video') != -1) {
        return CallType.kVideo;
      }
    } catch (err) {
      Logs().e('Failed to getCallType ${err.toString()}');
    }

    return CallType.kVoice;
  }

  Future<bool> requestTurnServerCredentials() async {
    return true;
  }

  Future<List<Map<String, dynamic>>> getIceSevers() async {
    if (_turnServerCredentials == null) {
      try {
        _turnServerCredentials = await client.getTurnServer();
      } catch (e) {
        Logs().v('[VOIP] getTurnServerCredentials error => ${e.toString()}');
      }
    }

    if (_turnServerCredentials == null) {
      return [];
    }

    return [
      {
        'username': _turnServerCredentials!.username,
        'credential': _turnServerCredentials!.password,
        'url': _turnServerCredentials!.uris[0]
      }
    ];
  }
  /*
  void _handleNetworkChanged(ConnectivityResult result) async {
    // Got a new connectivity status!
    if (_currentConnectivity != result) {
      calls.forEach((_, sess) {
        sess._restartIce();
      });
    }
    _currentConnectivity = result;
  }*/

  Future<CallSession> inviteToCall(String roomId, CallType type) async {
    final room = client.getRoomById(roomId);
    if (room == null) {
      Logs().v('[VOIP] Invalid room id [$roomId].');
      return Null as CallSession;
    }
    final callId = 'cid${DateTime.now().millisecondsSinceEpoch}';
    final opts = CallOptions()
      ..callId = callId
      ..type = type
      ..dir = Direction.kOutgoing
      ..room = room
      ..voip = this
      ..localPartyId = localPartyId!
      ..iceServers = await getIceSevers();

    final newCall = createNewCall(opts);
    currentCID = callId;
    await newCall.initOutboundCall(type).then((_) {
      if (!background) {
        onNewCall?.call(newCall);
      }
    });
    currentCID = callId;
    return newCall;
  }

  CallSession createNewCall(CallOptions opts) {
    final call = CallSession(opts);
    calls[opts.callId] = call;
    return call;
  }
}
