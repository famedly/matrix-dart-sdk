/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2021 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';
import 'dart:core';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:webrtc_interface/webrtc_interface.dart';

import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:matrix/src/voip/models/call_options.dart';
import 'package:matrix/src/voip/models/voip_id.dart';
import 'package:matrix/src/voip/utils/stream_helper.dart';
import 'package:matrix/src/voip/utils/user_media_constraints.dart';

/// Parses incoming matrix events to the apropriate webrtc layer underneath using
/// a `WebRTCDelegate`. This class is also responsible for sending any outgoing
/// matrix events if required (f.ex m.call.answer).
///
/// Handles p2p calls as well individual mesh group call peer connections.
class CallSession {
  CallSession(this.opts);
  CallOptions opts;
  CallType get type => opts.type;
  Room get room => opts.room;
  VoIP get voip => opts.voip;
  String? get groupCallId => opts.groupCallId;
  String get callId => opts.callId;
  String get localPartyId => opts.localPartyId;

  CallDirection get direction => opts.dir;

  CallState get state => _state;
  CallState _state = CallState.kFledgling;

  bool get isOutgoing => direction == CallDirection.kOutgoing;

  bool get isRinging => state == CallState.kRinging;

  RTCPeerConnection? pc;

  final _remoteCandidates = <RTCIceCandidate>[];
  final _localCandidates = <RTCIceCandidate>[];

  AssertedIdentity? get remoteAssertedIdentity => _remoteAssertedIdentity;
  AssertedIdentity? _remoteAssertedIdentity;

  bool get callHasEnded => state == CallState.kEnded;

  bool _iceGatheringFinished = false;

  bool _inviteOrAnswerSent = false;

  bool get localHold => _localHold;
  bool _localHold = false;

  bool get remoteOnHold => _remoteOnHold;
  bool _remoteOnHold = false;

  bool _answeredByUs = false;

  bool _speakerOn = false;

  bool _makingOffer = false;

  bool _ignoreOffer = false;

  bool get answeredByUs => _answeredByUs;

  Client get client => opts.room.client;

  /// The local participant in the call, with id userId + deviceId
  CallParticipant? get localParticipant => voip.localParticipant;

  /// The ID of the user being called. If omitted, any user in the room can answer.
  String? remoteUserId;

  User? get remoteUser => remoteUserId != null
      ? room.unsafeGetUserFromMemoryOrFallback(remoteUserId!)
      : null;

  /// The ID of the device being called. If omitted, any device for the remoteUserId in the room can answer.
  String? remoteDeviceId;
  String? remoteSessionId; // same
  String? remotePartyId; // random string

  CallErrorCode? hangupReason;
  CallSession? _successor;
  int _toDeviceSeq = 0;
  int _candidateSendTries = 0;
  bool get isGroupCall => groupCallId != null;
  bool _missedCall = true;

  final CachedStreamController<CallSession> onCallStreamsChanged =
      CachedStreamController();

  final CachedStreamController<CallSession> onCallReplaced =
      CachedStreamController();

  final CachedStreamController<CallSession> onCallHangupNotifierForGroupCalls =
      CachedStreamController();

  final CachedStreamController<CallState> onCallStateChanged =
      CachedStreamController();

  final CachedStreamController<CallStateChange> onCallEventChanged =
      CachedStreamController();

  final CachedStreamController<WrappedMediaStream> onStreamAdd =
      CachedStreamController();

  final CachedStreamController<WrappedMediaStream> onStreamRemoved =
      CachedStreamController();

  SDPStreamMetadata? _remoteSDPStreamMetadata;
  final List<RTCRtpSender> _usermediaSenders = [];
  final List<RTCRtpSender> _screensharingSenders = [];
  final List<WrappedMediaStream> _streams = <WrappedMediaStream>[];

  List<WrappedMediaStream> get getLocalStreams =>
      _streams.where((element) => element.isLocal()).toList();
  List<WrappedMediaStream> get getRemoteStreams =>
      _streams.where((element) => !element.isLocal()).toList();

  bool get isLocalVideoMuted => localUserMediaStream?.isVideoMuted() ?? false;

  bool get isMicrophoneMuted => localUserMediaStream?.isAudioMuted() ?? false;

  bool get screensharingEnabled => localScreenSharingStream != null;

  WrappedMediaStream? get localUserMediaStream {
    final stream = getLocalStreams.where(
      (element) => element.purpose == SDPStreamMetadataPurpose.Usermedia,
    );
    if (stream.isNotEmpty) {
      return stream.first;
    }
    return null;
  }

  WrappedMediaStream? get localScreenSharingStream {
    final stream = getLocalStreams.where(
      (element) => element.purpose == SDPStreamMetadataPurpose.Screenshare,
    );
    if (stream.isNotEmpty) {
      return stream.first;
    }
    return null;
  }

  WrappedMediaStream? get remoteUserMediaStream {
    final stream = getRemoteStreams.where(
      (element) => element.purpose == SDPStreamMetadataPurpose.Usermedia,
    );
    if (stream.isNotEmpty) {
      return stream.first;
    }
    return null;
  }

  WrappedMediaStream? get remoteScreenSharingStream {
    final stream = getRemoteStreams.where(
      (element) => element.purpose == SDPStreamMetadataPurpose.Screenshare,
    );
    if (stream.isNotEmpty) {
      return stream.first;
    }
    return null;
  }

  /// returns whether a 1:1 call sender has video tracks
  Future<bool> hasVideoToSend() async {
    final transceivers = await pc!.getTransceivers();
    final localUserMediaVideoTrack = localUserMediaStream?.stream
        ?.getTracks()
        .singleWhereOrNull((track) => track.kind == 'video');

    // check if we have a video track locally and have transceivers setup correctly.
    return localUserMediaVideoTrack != null &&
        transceivers.singleWhereOrNull(
              (transceiver) =>
                  transceiver.sender.track?.id == localUserMediaVideoTrack.id,
            ) !=
            null;
  }

  Timer? _inviteTimer;
  Timer? _ringingTimer;

  // outgoing call
  Future<void> initOutboundCall(CallType type) async {
    await _preparePeerConnection();
    setCallState(CallState.kCreateOffer);
    final stream = await _getUserMedia(type);
    if (stream != null) {
      await addLocalStream(stream, SDPStreamMetadataPurpose.Usermedia);
    }
  }

  // incoming call
  Future<void> initWithInvite(
    CallType type,
    RTCSessionDescription offer,
    SDPStreamMetadata? metadata,
    int lifetime,
    bool isGroupCall,
  ) async {
    if (!isGroupCall) {
      // glare fixes
      final prevCallId = voip.incomingCallRoomId[room.id];
      if (prevCallId != null) {
        // This is probably an outbound call, but we already have a incoming invite, so let's terminate it.
        final prevCall =
            voip.calls[VoipId(roomId: room.id, callId: prevCallId)];
        if (prevCall != null) {
          if (prevCall._inviteOrAnswerSent) {
            Logs().d('[glare] invite or answer sent, lex compare now');
            if (callId.compareTo(prevCall.callId) > 0) {
              Logs().d(
                '[glare] new call $callId needs to be canceled because the older one ${prevCall.callId} has a smaller lex',
              );
              await hangup(reason: CallErrorCode.unknownError);
              voip.currentCID =
                  VoipId(roomId: room.id, callId: prevCall.callId);
            } else {
              Logs().d(
                '[glare] nice, lex of newer call $callId is smaller auto accept this here',
              );

              /// These fixes do not work all the time because sometimes the code
              /// is at an unrecoverable stage (invite already sent when we were
              /// checking if we want to send a invite), so commented out answering
              /// automatically to prevent unknown cases
              // await answer();
              // return;
            }
          } else {
            Logs().d(
              '[glare] ${prevCall.callId} was still preparing prev call, nvm now cancel it',
            );
            await prevCall.hangup(reason: CallErrorCode.unknownError);
          }
        }
      }
    }

    await _preparePeerConnection();
    if (metadata != null) {
      _updateRemoteSDPStreamMetadata(metadata);
    }
    await pc!.setRemoteDescription(offer);

    /// only add local stream if it is not a group call.
    if (!isGroupCall) {
      final stream = await _getUserMedia(type);
      if (stream != null) {
        await addLocalStream(stream, SDPStreamMetadataPurpose.Usermedia);
      } else {
        // we don't have a localstream, call probably crashed
        // for sanity
        if (state == CallState.kEnded) {
          return;
        }
      }
    }

    setCallState(CallState.kRinging);

    _ringingTimer = Timer(CallTimeouts.callInviteLifetime, () {
      if (state == CallState.kRinging) {
        Logs().v('[VOIP] Call invite has expired. Hanging up.');

        fireCallEvent(CallStateChange.kHangup);
        hangup(reason: CallErrorCode.inviteTimeout);
      }
      _ringingTimer?.cancel();
      _ringingTimer = null;
    });
  }

  Future<void> answerWithStreams(List<WrappedMediaStream> callFeeds) async {
    if (_inviteOrAnswerSent) return;
    Logs().d('answering call $callId');
    await gotCallFeedsForAnswer(callFeeds);
  }

  Future<void> replacedBy(CallSession newCall) async {
    if (state == CallState.kWaitLocalMedia) {
      Logs().v('Telling new call to wait for local media');
    } else if (state == CallState.kCreateOffer ||
        state == CallState.kInviteSent) {
      Logs().v('Handing local stream to new call');
      await newCall.gotCallFeedsForAnswer(getLocalStreams);
    }
    _successor = newCall;
    onCallReplaced.add(newCall);
    // ignore: unawaited_futures
    hangup(reason: CallErrorCode.replaced);
  }

  Future<void> sendAnswer(RTCSessionDescription answer) async {
    final callCapabilities = CallCapabilities()
      ..dtmf = false
      ..transferee = false;

    final metadata = SDPStreamMetadata({
      localUserMediaStream!.stream!.id: SDPStreamPurpose(
        purpose: SDPStreamMetadataPurpose.Usermedia,
        audio_muted: localUserMediaStream!.stream!.getAudioTracks().isEmpty,
        video_muted: localUserMediaStream!.stream!.getVideoTracks().isEmpty,
      ),
    });

    final res = await sendAnswerCall(
      room,
      callId,
      answer.sdp!,
      localPartyId,
      type: answer.type!,
      capabilities: callCapabilities,
      metadata: metadata,
    );
    Logs().v('[VOIP] answer res => $res');
  }

  Future<void> gotCallFeedsForAnswer(List<WrappedMediaStream> callFeeds) async {
    if (state == CallState.kEnded) return;

    for (final element in callFeeds) {
      await addLocalStream(await element.stream!.clone(), element.purpose);
    }

    await answer();
  }

  Future<void> placeCallWithStreams(
    List<WrappedMediaStream> callFeeds, {
    bool requestScreenSharing = false,
  }) async {
    // create the peer connection now so it can be gathering candidates while we get user
    // media (assuming a candidate pool size is configured)
    await _preparePeerConnection();
    await gotCallFeedsForInvite(
      callFeeds,
      requestScreenSharing: requestScreenSharing,
    );
  }

  Future<void> gotCallFeedsForInvite(
    List<WrappedMediaStream> callFeeds, {
    bool requestScreenSharing = false,
  }) async {
    if (_successor != null) {
      await _successor!.gotCallFeedsForAnswer(callFeeds);
      return;
    }
    if (state == CallState.kEnded) {
      await cleanUp();
      return;
    }

    for (final element in callFeeds) {
      await addLocalStream(await element.stream!.clone(), element.purpose);
    }

    if (requestScreenSharing) {
      await pc!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
    }

    setCallState(CallState.kCreateOffer);

    Logs().d('gotUserMediaForInvite');
    // Now we wait for the negotiationneeded event
  }

  Future<void> onAnswerReceived(
    RTCSessionDescription answer,
    SDPStreamMetadata? metadata,
  ) async {
    if (metadata != null) {
      _updateRemoteSDPStreamMetadata(metadata);
    }

    if (direction == CallDirection.kOutgoing) {
      setCallState(CallState.kConnecting);
      await pc!.setRemoteDescription(answer);
      for (final candidate in _remoteCandidates) {
        await pc!.addCandidate(candidate);
      }
    }
    if (remotePartyId != null) {
      /// Send select_answer event.
      await sendSelectCallAnswer(
        opts.room,
        callId,
        localPartyId,
        remotePartyId!,
      );
    }
  }

  Future<void> onNegotiateReceived(
    SDPStreamMetadata? metadata,
    RTCSessionDescription description,
  ) async {
    final polite = direction == CallDirection.kIncoming;

    // Here we follow the perfect negotiation logic from
    // https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API/Perfect_negotiation
    final offerCollision = ((description.type == 'offer') &&
        (_makingOffer ||
            pc!.signalingState != RTCSignalingState.RTCSignalingStateStable));

    _ignoreOffer = !polite && offerCollision;
    if (_ignoreOffer) {
      Logs().i('Ignoring colliding negotiate event because we\'re impolite');
      return;
    }

    final prevLocalOnHold = await isLocalOnHold();

    if (metadata != null) {
      _updateRemoteSDPStreamMetadata(metadata);
    }

    try {
      await pc!.setRemoteDescription(description);
      RTCSessionDescription? answer;
      if (description.type == 'offer') {
        try {
          answer = await pc!.createAnswer({});
        } catch (e) {
          await terminate(CallParty.kLocal, CallErrorCode.createAnswer, true);
          rethrow;
        }

        await sendCallNegotiate(
          room,
          callId,
          CallTimeouts.defaultCallEventLifetime.inMilliseconds,
          localPartyId,
          answer.sdp!,
          type: answer.type!,
        );
        await pc!.setLocalDescription(answer);
      }
    } catch (e, s) {
      Logs().e('[VOIP] onNegotiateReceived => ', e, s);
      await _getLocalOfferFailed(e);
      return;
    }

    final newLocalOnHold = await isLocalOnHold();
    if (prevLocalOnHold != newLocalOnHold) {
      _localHold = newLocalOnHold;
      fireCallEvent(CallStateChange.kLocalHoldUnhold);
    }
  }

  Future<void> updateMediaDeviceForCall() async {
    await updateMediaDevice(
      voip.delegate,
      MediaKind.audio,
      _usermediaSenders,
    );
    await updateMediaDevice(
      voip.delegate,
      MediaKind.video,
      _usermediaSenders,
    );
  }

  void _updateRemoteSDPStreamMetadata(SDPStreamMetadata metadata) {
    _remoteSDPStreamMetadata = metadata;
    _remoteSDPStreamMetadata?.sdpStreamMetadatas
        .forEach((streamId, sdpStreamMetadata) {
      Logs().i(
        'Stream purpose update: \nid = "$streamId", \npurpose = "${sdpStreamMetadata.purpose}",  \naudio_muted = ${sdpStreamMetadata.audio_muted}, \nvideo_muted = ${sdpStreamMetadata.video_muted}',
      );
    });
    for (final wpstream in getRemoteStreams) {
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
        fireCallEvent(CallStateChange.kFeedsChanged);
      }
    }
  }

  Future<void> onSDPStreamMetadataReceived(SDPStreamMetadata metadata) async {
    _updateRemoteSDPStreamMetadata(metadata);
    fireCallEvent(CallStateChange.kFeedsChanged);
  }

  Future<void> onCandidatesReceived(List<dynamic> candidates) async {
    for (final json in candidates) {
      final candidate = RTCIceCandidate(
        json['candidate'],
        json['sdpMid'] ?? '',
        json['sdpMLineIndex']?.round() ?? 0,
      );

      if (!candidate.isValid) {
        Logs().w(
          '[VOIP] onCandidatesReceived => skip invalid candidate ${candidate.toMap()}',
        );
        continue;
      }

      if (direction == CallDirection.kOutgoing &&
          pc != null &&
          await pc!.getRemoteDescription() == null) {
        _remoteCandidates.add(candidate);
        continue;
      }

      if (pc != null && _inviteOrAnswerSent) {
        try {
          await pc!.addCandidate(candidate);
        } catch (e, s) {
          Logs().e('[VOIP] onCandidatesReceived => ', e, s);
        }
      } else {
        _remoteCandidates.add(candidate);
      }
    }
  }

  void onAssertedIdentityReceived(AssertedIdentity identity) {
    _remoteAssertedIdentity = identity;
    fireCallEvent(CallStateChange.kAssertedIdentityChanged);
  }

  Future<bool> setScreensharingEnabled(bool enabled) async {
    // Skip if there is nothing to do
    if (enabled && localScreenSharingStream != null) {
      Logs().w(
        'There is already a screensharing stream - there is nothing to do!',
      );
      return true;
    } else if (!enabled && localScreenSharingStream == null) {
      Logs().w(
        'There already isn\'t a screensharing stream - there is nothing to do!',
      );
      return false;
    }

    Logs().d('Set screensharing enabled? $enabled');

    if (enabled) {
      try {
        final stream = await _getDisplayMedia();
        if (stream == null) {
          return false;
        }
        for (final track in stream.getTracks()) {
          // screen sharing should only have 1 video track anyway, so this only
          // fires once
          track.onEnded = () async {
            await setScreensharingEnabled(false);
          };
        }

        await addLocalStream(stream, SDPStreamMetadataPurpose.Screenshare);
        return true;
      } catch (err) {
        fireCallEvent(CallStateChange.kError);
        return false;
      }
    } else {
      try {
        for (final sender in _screensharingSenders) {
          await pc!.removeTrack(sender);
        }
        for (final track in localScreenSharingStream!.stream!.getTracks()) {
          await track.stop();
        }
        localScreenSharingStream!.stopped = true;
        await _removeStream(localScreenSharingStream!.stream!);
        fireCallEvent(CallStateChange.kFeedsChanged);
        return false;
      } catch (e, s) {
        Logs().e('[VOIP] stopping screen sharing track failed', e, s);
        return false;
      }
    }
  }

  Future<void> addLocalStream(
    MediaStream stream,
    String purpose, {
    bool addToPeerConnection = true,
  }) async {
    final existingStream =
        getLocalStreams.where((element) => element.purpose == purpose);
    if (existingStream.isNotEmpty) {
      existingStream.first.setNewStream(stream);
    } else {
      final newStream = WrappedMediaStream(
        participant: localParticipant!,
        room: opts.room,
        stream: stream,
        purpose: purpose,
        client: client,
        audioMuted: stream.getAudioTracks().isEmpty,
        videoMuted: stream.getVideoTracks().isEmpty,
        isGroupCall: groupCallId != null,
        pc: pc,
        voip: voip,
      );
      _streams.add(newStream);
      onStreamAdd.add(newStream);
    }

    if (addToPeerConnection) {
      if (purpose == SDPStreamMetadataPurpose.Screenshare) {
        _screensharingSenders.clear();
        for (final track in stream.getTracks()) {
          _screensharingSenders.add(await pc!.addTrack(track, stream));
        }
      } else if (purpose == SDPStreamMetadataPurpose.Usermedia) {
        _usermediaSenders.clear();
        for (final track in stream.getTracks()) {
          _usermediaSenders.add(await pc!.addTrack(track, stream));
        }
      }
    }

    if (purpose == SDPStreamMetadataPurpose.Usermedia) {
      _speakerOn = type == CallType.kVideo;
      if (!voip.delegate.isWeb && stream.getAudioTracks().isNotEmpty) {
        final audioTrack = stream.getAudioTracks()[0];
        audioTrack.enableSpeakerphone(_speakerOn);
      }
    }

    fireCallEvent(CallStateChange.kFeedsChanged);
  }

  Future<void> _addRemoteStream(MediaStream stream) async {
    //final userId = remoteUser.id;
    final metadata = _remoteSDPStreamMetadata?.sdpStreamMetadatas[stream.id];
    if (metadata == null) {
      Logs().i(
        'Ignoring stream with id ${stream.id} because we didn\'t get any metadata about it',
      );
      return;
    }

    final purpose = metadata.purpose;
    final audioMuted = metadata.audio_muted;
    final videoMuted = metadata.video_muted;

    // Try to find a feed with the same purpose as the new stream,
    // if we find it replace the old stream with the new one
    final existingStream =
        getRemoteStreams.where((element) => element.purpose == purpose);
    if (existingStream.isNotEmpty) {
      existingStream.first.setNewStream(stream);
    } else {
      final newStream = WrappedMediaStream(
        participant: CallParticipant(
          voip,
          userId: remoteUserId!,
          deviceId: remoteDeviceId,
        ),
        room: opts.room,
        stream: stream,
        purpose: purpose,
        client: client,
        audioMuted: audioMuted,
        videoMuted: videoMuted,
        isGroupCall: groupCallId != null,
        pc: pc,
        voip: voip,
      );
      _streams.add(newStream);
      onStreamAdd.add(newStream);
    }
    fireCallEvent(CallStateChange.kFeedsChanged);
    Logs().i('Pushed remote stream (id="${stream.id}", purpose=$purpose)');
  }

  Future<void> deleteAllStreams() async {
    for (final stream in _streams) {
      if (stream.isLocal() || groupCallId == null) {
        await stream.dispose();
      }
    }
    _streams.clear();
    fireCallEvent(CallStateChange.kFeedsChanged);
  }

  Future<void> deleteFeedByStream(MediaStream stream) async {
    final index =
        _streams.indexWhere((element) => element.stream!.id == stream.id);
    if (index == -1) {
      Logs().w('Didn\'t find the feed with stream id ${stream.id} to delete');
      return;
    }
    final wstream = _streams.elementAt(index);
    onStreamRemoved.add(wstream);
    await deleteStream(wstream);
  }

  Future<void> deleteStream(WrappedMediaStream stream) async {
    await stream.dispose();
    _streams.removeAt(_streams.indexOf(stream));
    fireCallEvent(CallStateChange.kFeedsChanged);
  }

  Future<void> removeLocalStream(WrappedMediaStream callFeed) async {
    final senderArray = callFeed.purpose == SDPStreamMetadataPurpose.Usermedia
        ? _usermediaSenders
        : _screensharingSenders;

    for (final element in senderArray) {
      await pc!.removeTrack(element);
    }

    if (callFeed.purpose == SDPStreamMetadataPurpose.Screenshare) {
      await stopMediaStream(callFeed.stream);
    }

    // Empty the array
    senderArray.removeRange(0, senderArray.length);
    onStreamRemoved.add(callFeed);
    await deleteStream(callFeed);
  }

  void setCallState(CallState newState) {
    _state = newState;
    onCallStateChanged.add(newState);
    fireCallEvent(CallStateChange.kState);
  }

  Future<void> setLocalVideoMuted(bool muted) async {
    if (!muted) {
      final videoToSend = await hasVideoToSend();
      if (!videoToSend) {
        if (_remoteSDPStreamMetadata == null) return;
        await insertVideoTrackToAudioOnlyStream();
      }
    }
    localUserMediaStream?.setVideoMuted(muted);
    await updateMuteStatus();
  }

  // used for upgrading 1:1 calls
  Future<void> insertVideoTrackToAudioOnlyStream() async {
    if (localUserMediaStream != null && localUserMediaStream!.stream != null) {
      final stream = await _getUserMedia(CallType.kVideo);
      if (stream != null) {
        Logs().d('[VOIP] running replaceTracks() on stream: ${stream.id}');
        _setTracksEnabled(stream.getVideoTracks(), true);
        // replace local tracks
        for (final track in localUserMediaStream!.stream!.getTracks()) {
          try {
            await localUserMediaStream!.stream!.removeTrack(track);
            await track.stop();
          } catch (e) {
            Logs().w('failed to stop track');
          }
        }
        final streamTracks = stream.getTracks();
        for (final newTrack in streamTracks) {
          await localUserMediaStream!.stream!.addTrack(newTrack);
        }

        // remove any screen sharing or remote transceivers, these don't need
        // to be replaced anyway.
        final transceivers = await pc!.getTransceivers();
        transceivers.removeWhere(
          (transceiver) =>
              transceiver.sender.track == null ||
              (localScreenSharingStream != null &&
                  localScreenSharingStream!.stream != null &&
                  localScreenSharingStream!.stream!
                      .getTracks()
                      .map((e) => e.id)
                      .contains(transceiver.sender.track?.id)),
        );

        // in an ideal case the following should happen
        // - audio track gets replaced
        // - new video track gets added
        for (final newTrack in streamTracks) {
          final transceiver = transceivers.singleWhereOrNull(
            (transceiver) => transceiver.sender.track!.kind == newTrack.kind,
          );
          if (transceiver != null) {
            Logs().d(
              '[VOIP] replacing ${transceiver.sender.track} in transceiver',
            );
            final oldSender = transceiver.sender;
            await oldSender.replaceTrack(newTrack);
            await transceiver.setDirection(
              await transceiver.getDirection() ==
                      TransceiverDirection.Inactive // upgrade, send now
                  ? TransceiverDirection.SendOnly
                  : TransceiverDirection.SendRecv,
            );
          } else {
            // adding transceiver
            Logs().d('[VOIP] adding track $newTrack to pc');
            await pc!.addTrack(newTrack, localUserMediaStream!.stream!);
          }
        }
        // for renderer to be able to show new video track
        localUserMediaStream?.onStreamChanged
            .add(localUserMediaStream!.stream!);
      }
    }
  }

  Future<void> setMicrophoneMuted(bool muted) async {
    localUserMediaStream?.setAudioMuted(muted);
    await updateMuteStatus();
  }

  Future<void> setRemoteOnHold(bool onHold) async {
    if (remoteOnHold == onHold) return;
    _remoteOnHold = onHold;
    final transceivers = await pc!.getTransceivers();
    for (final transceiver in transceivers) {
      await transceiver.setDirection(
        onHold ? TransceiverDirection.SendOnly : TransceiverDirection.SendRecv,
      );
    }
    await updateMuteStatus();
    fireCallEvent(CallStateChange.kRemoteHoldUnhold);
  }

  Future<bool> isLocalOnHold() async {
    if (state != CallState.kConnected) return false;
    var callOnHold = true;
    // We consider a call to be on hold only if *all* the tracks are on hold
    // (is this the right thing to do?)
    final transceivers = await pc!.getTransceivers();
    for (final transceiver in transceivers) {
      final currentDirection = await transceiver.getCurrentDirection();
      final trackOnHold = (currentDirection == TransceiverDirection.Inactive ||
          currentDirection == TransceiverDirection.RecvOnly);
      if (!trackOnHold) {
        callOnHold = false;
      }
    }
    return callOnHold;
  }

  Future<void> answer({String? txid}) async {
    if (_inviteOrAnswerSent) {
      return;
    }
    // stop play ringtone
    await voip.delegate.stopRingtone();

    if (direction == CallDirection.kIncoming) {
      setCallState(CallState.kCreateAnswer);

      final answer = await pc!.createAnswer({});
      for (final candidate in _remoteCandidates) {
        await pc!.addCandidate(candidate);
      }

      final callCapabilities = CallCapabilities()
        ..dtmf = false
        ..transferee = false;

      final metadata = SDPStreamMetadata({
        if (localUserMediaStream != null)
          localUserMediaStream!.stream!.id: SDPStreamPurpose(
            purpose: SDPStreamMetadataPurpose.Usermedia,
            audio_muted: localUserMediaStream!.audioMuted,
            video_muted: localUserMediaStream!.videoMuted,
          ),
        if (localScreenSharingStream != null)
          localScreenSharingStream!.stream!.id: SDPStreamPurpose(
            purpose: SDPStreamMetadataPurpose.Screenshare,
            audio_muted: localScreenSharingStream!.audioMuted,
            video_muted: localScreenSharingStream!.videoMuted,
          ),
      });

      await pc!.setLocalDescription(answer);
      setCallState(CallState.kConnecting);

      // Allow a short time for initial candidates to be gathered
      await Future.delayed(Duration(milliseconds: 200));

      final res = await sendAnswerCall(
        room,
        callId,
        answer.sdp!,
        localPartyId,
        type: answer.type!,
        capabilities: callCapabilities,
        metadata: metadata,
        txid: txid,
      );
      Logs().v('[VOIP] answer res => $res');

      _inviteOrAnswerSent = true;
      _answeredByUs = true;
    }
  }

  /// Reject a call
  /// This used to be done by calling hangup, but is a separate method and protocol
  /// event as of MSC2746.
  Future<void> reject({CallErrorCode? reason, bool shouldEmit = true}) async {
    if (state != CallState.kRinging && state != CallState.kFledgling) {
      Logs().e(
        '[VOIP] Call must be in \'ringing|fledgling\' state to reject! (current state was: ${state.toString()}) Calling hangup instead',
      );
      await hangup(reason: CallErrorCode.userHangup, shouldEmit: shouldEmit);
      return;
    }
    Logs().d('[VOIP] Rejecting call: $callId');
    setCallState(CallState.kEnding);
    await terminate(CallParty.kLocal, CallErrorCode.userHangup, shouldEmit);
    if (shouldEmit) {
      await sendCallReject(room, callId, localPartyId);
    }
  }

  Future<void> hangup({
    required CallErrorCode reason,
    bool shouldEmit = true,
  }) async {
    setCallState(CallState.kEnding);
    await terminate(CallParty.kLocal, reason, shouldEmit);
    try {
      final res =
          await sendHangupCall(room, callId, localPartyId, 'userHangup');
      Logs().v('[VOIP] hangup res => $res');
    } catch (e) {
      Logs().v('[VOIP] hangup error => ${e.toString()}');
    }
  }

  Future<void> sendDTMF(String tones) async {
    final senders = await pc!.getSenders();
    for (final sender in senders) {
      if (sender.track != null && sender.track!.kind == 'audio') {
        await sender.dtmfSender.insertDTMF(tones);
        return;
      } else {
        Logs().w('[VOIP] Unable to find a track to send DTMF on');
      }
    }
  }

  Future<void> terminate(
    CallParty party,
    CallErrorCode reason,
    bool shouldEmit,
  ) async {
    if (state == CallState.kConnected) {
      await hangup(
        reason: CallErrorCode.userHangup,
        shouldEmit: true,
      );
      return;
    }

    Logs().d('[VOIP] terminating call');
    _inviteTimer?.cancel();
    _inviteTimer = null;

    _ringingTimer?.cancel();
    _ringingTimer = null;

    try {
      await voip.delegate.stopRingtone();
    } catch (e) {
      // maybe rigntone never started (group calls) or has been stopped already
      Logs().d('stopping ringtone failed ', e);
    }

    hangupReason = reason;

    // don't see any reason to wrap this with shouldEmit atm,
    // looks like a local state change only
    setCallState(CallState.kEnded);

    if (!isGroupCall) {
      // when a call crash and this call is already terminated the currentCId is null.
      // So don't return bc the hangup or reject will not proceed anymore.
      if (voip.currentCID != null &&
          voip.currentCID != VoipId(roomId: room.id, callId: callId)) return;
      voip.currentCID = null;
      voip.incomingCallRoomId.removeWhere((key, value) => value == callId);
    }

    voip.calls.removeWhere((key, value) => key.callId == callId);

    await cleanUp();
    if (shouldEmit) {
      onCallHangupNotifierForGroupCalls.add(this);
      await voip.delegate.handleCallEnded(this);
      fireCallEvent(CallStateChange.kHangup);
      if ((party == CallParty.kRemote &&
          _missedCall &&
          reason != CallErrorCode.answeredElsewhere)) {
        await voip.delegate.handleMissedCall(this);
      }
    }
  }

  Future<void> onRejectReceived(CallErrorCode? reason) async {
    Logs().v('[VOIP] Reject received for call ID $callId');
    // No need to check party_id for reject because if we'd received either
    // an answer or reject, we wouldn't be in state InviteSent
    final shouldTerminate = (state == CallState.kFledgling &&
            direction == CallDirection.kIncoming) ||
        CallState.kInviteSent == state ||
        CallState.kRinging == state;

    if (shouldTerminate) {
      await terminate(
        CallParty.kRemote,
        reason ?? CallErrorCode.userHangup,
        true,
      );
    } else {
      Logs().e('[VOIP] Call is in state: ${state.toString()}: ignoring reject');
    }
  }

  Future<void> _gotLocalOffer(RTCSessionDescription offer) async {
    if (callHasEnded) {
      Logs().d(
        'Ignoring newly created offer on call ID ${opts.callId} because the call has ended',
      );
      return;
    }

    try {
      await pc!.setLocalDescription(offer);
    } catch (err) {
      Logs().d('Error setting local description! ${err.toString()}');
      await terminate(
        CallParty.kLocal,
        CallErrorCode.setLocalDescription,
        true,
      );
      return;
    }

    if (pc!.iceGatheringState ==
        RTCIceGatheringState.RTCIceGatheringStateGathering) {
      // Allow a short time for initial candidates to be gathered
      await Future.delayed(CallTimeouts.iceGatheringDelay);
    }

    if (callHasEnded) return;

    final callCapabilities = CallCapabilities()
      ..dtmf = false
      ..transferee = false;
    final metadata = _getLocalSDPStreamMetadata();
    if (state == CallState.kCreateOffer) {
      await sendInviteToCall(
        room,
        callId,
        CallTimeouts.callInviteLifetime.inMilliseconds,
        localPartyId,
        offer.sdp!,
        capabilities: callCapabilities,
        metadata: metadata,
      );
      // just incase we ended the call but already sent the invite
      // raraley happens during glares
      if (state == CallState.kEnded) {
        await hangup(reason: CallErrorCode.replaced);
        return;
      }
      _inviteOrAnswerSent = true;

      if (!isGroupCall) {
        Logs().d('[glare] set callid because new invite sent');
        voip.incomingCallRoomId[room.id] = callId;
      }

      setCallState(CallState.kInviteSent);

      _inviteTimer = Timer(CallTimeouts.callInviteLifetime, () {
        if (state == CallState.kInviteSent) {
          hangup(reason: CallErrorCode.inviteTimeout);
        }
        _inviteTimer?.cancel();
        _inviteTimer = null;
      });
    } else {
      await sendCallNegotiate(
        room,
        callId,
        CallTimeouts.defaultCallEventLifetime.inMilliseconds,
        localPartyId,
        offer.sdp!,
        type: offer.type!,
        capabilities: callCapabilities,
        metadata: metadata,
      );
    }
  }

  Future<void> onNegotiationNeeded() async {
    Logs().d('Negotiation is needed!');
    _makingOffer = true;
    try {
      // The first addTrack(audio track) on iOS will trigger
      // onNegotiationNeeded, which causes creatOffer to only include
      // audio m-line, add delay and wait for video track to be added,
      // then createOffer can get audio/video m-line correctly.
      await Future.delayed(CallTimeouts.delayBeforeOffer);
      final offer = await pc!.createOffer({});
      await _gotLocalOffer(offer);
    } catch (e) {
      await _getLocalOfferFailed(e);
      return;
    } finally {
      _makingOffer = false;
    }
  }

  Future<void> _preparePeerConnection() async {
    int iceRestartedCount = 0;

    try {
      pc = await _createPeerConnection();
      pc!.onRenegotiationNeeded = onNegotiationNeeded;

      pc!.onIceCandidate = (RTCIceCandidate candidate) async {
        if (callHasEnded) return;
        _localCandidates.add(candidate);

        if (state == CallState.kRinging || !_inviteOrAnswerSent) return;

        // MSC2746 recommends these values (can be quite long when calling because the
        // callee will need a while to answer the call)
        final delay = direction == CallDirection.kIncoming ? 500 : 2000;
        if (_candidateSendTries == 0) {
          Timer(Duration(milliseconds: delay), () {
            _sendCandidateQueue();
          });
        }
      };

      pc!.onIceGatheringState = (RTCIceGatheringState state) async {
        Logs().v('[VOIP] IceGatheringState => ${state.toString()}');
        if (state == RTCIceGatheringState.RTCIceGatheringStateGathering) {
          Timer(Duration(seconds: 3), () async {
            if (!_iceGatheringFinished) {
              _iceGatheringFinished = true;
              await _sendCandidateQueue();
            }
          });
        }
        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
          if (!_iceGatheringFinished) {
            _iceGatheringFinished = true;
            await _sendCandidateQueue();
          }
        }
      };
      pc!.onIceConnectionState = (RTCIceConnectionState state) async {
        Logs().v('[VOIP] RTCIceConnectionState => ${state.toString()}');
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
          _localCandidates.clear();
          _remoteCandidates.clear();
          iceRestartedCount = 0;
          setCallState(CallState.kConnected);
          // fix any state/race issues we had with sdp packets and cloned streams
          await updateMuteStatus();
          _missedCall = false;
        } else if ({
          RTCIceConnectionState.RTCIceConnectionStateFailed,
          RTCIceConnectionState.RTCIceConnectionStateDisconnected,
        }.contains(state)) {
          if (iceRestartedCount < 3) {
            await restartIce();
            iceRestartedCount++;
          } else {
            await hangup(reason: CallErrorCode.iceFailed);
          }
        }
      };
    } catch (e) {
      Logs().v('[VOIP] prepareMediaStream error => ${e.toString()}');
    }
  }

  Future<void> onAnsweredElsewhere() async {
    Logs().d('Call ID $callId answered elsewhere');
    await terminate(CallParty.kRemote, CallErrorCode.answeredElsewhere, true);
  }

  Future<void> cleanUp() async {
    try {
      for (final stream in _streams) {
        await stream.dispose();
      }
      _streams.clear();
    } catch (e, s) {
      Logs().e('[VOIP] cleaning up streams failed', e, s);
    }

    try {
      if (pc != null) {
        await pc!.close();
        await pc!.dispose();
      }
    } catch (e, s) {
      Logs().e('[VOIP] removing pc failed', e, s);
    }
  }

  Future<void> updateMuteStatus() async {
    final micShouldBeMuted = (localUserMediaStream != null &&
            localUserMediaStream!.isAudioMuted()) ||
        _remoteOnHold;
    final vidShouldBeMuted = (localUserMediaStream != null &&
            localUserMediaStream!.isVideoMuted()) ||
        _remoteOnHold;

    _setTracksEnabled(
      localUserMediaStream?.stream?.getAudioTracks() ?? [],
      !micShouldBeMuted,
    );
    _setTracksEnabled(
      localUserMediaStream?.stream?.getVideoTracks() ?? [],
      !vidShouldBeMuted,
    );

    await sendSDPStreamMetadataChanged(
      room,
      callId,
      localPartyId,
      _getLocalSDPStreamMetadata(),
    );
  }

  void _setTracksEnabled(List<MediaStreamTrack> tracks, bool enabled) {
    for (final track in tracks) {
      track.enabled = enabled;
    }
  }

  SDPStreamMetadata _getLocalSDPStreamMetadata() {
    final sdpStreamMetadatas = <String, SDPStreamPurpose>{};
    for (final wpstream in getLocalStreams) {
      if (wpstream.stream != null) {
        sdpStreamMetadatas[wpstream.stream!.id] = SDPStreamPurpose(
          purpose: wpstream.purpose,
          audio_muted: wpstream.audioMuted,
          video_muted: wpstream.videoMuted,
        );
      }
    }
    final metadata = SDPStreamMetadata(sdpStreamMetadatas);
    Logs().v('Got local SDPStreamMetadata ${metadata.toJson().toString()}');
    return metadata;
  }

  Future<void> restartIce() async {
    Logs().v('[VOIP] iceRestart.');
    // Needs restart ice on session.pc and renegotiation.
    _iceGatheringFinished = false;
    _localCandidates.clear();
    await pc!.restartIce();
  }

  Future<MediaStream?> _getUserMedia(CallType type) async {
    final mediaConstraints = {
      'audio': UserMediaConstraints.micMediaConstraints,
      'video': type == CallType.kVideo
          ? UserMediaConstraints.camMediaConstraints
          : false,
    };
    try {
      return await voip.delegate.mediaDevices.getUserMedia(mediaConstraints);
    } catch (e) {
      await _getUserMediaFailed(e);
      rethrow;
    }
  }

  Future<MediaStream?> _getDisplayMedia() async {
    try {
      return await voip.delegate.mediaDevices
          .getDisplayMedia(UserMediaConstraints.screenMediaConstraints);
    } catch (e) {
      await _getUserMediaFailed(e);
    }
    return null;
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final configuration = <String, dynamic>{
      'iceServers': opts.iceServers,
      'sdpSemantics': 'unified-plan',
    };
    final pc = await voip.delegate.createPeerConnection(configuration);
    pc.onTrack = (RTCTrackEvent event) async {
      for (final stream in event.streams) {
        await _addRemoteStream(stream);
        for (final track in stream.getTracks()) {
          track.onEnded = () async {
            if (stream.getTracks().isEmpty) {
              Logs().d('[VOIP] detected a empty stream, removing it');
              await _removeStream(stream);
            }
          };
        }
      }
    };
    return pc;
  }

  Future<void> createDataChannel(
    String label,
    RTCDataChannelInit dataChannelDict,
  ) async {
    await pc?.createDataChannel(label, dataChannelDict);
  }

  Future<void> tryRemoveStopedStreams() async {
    final removedStreams = <String, WrappedMediaStream>{};
    for (final stream in _streams) {
      if (stream.stopped) {
        removedStreams[stream.stream!.id] = stream;
      }
    }
    _streams
        .removeWhere((stream) => removedStreams.containsKey(stream.stream!.id));
    for (final element in removedStreams.entries) {
      await _removeStream(element.value.stream!);
    }
  }

  Future<void> _removeStream(MediaStream stream) async {
    Logs().v('Removing feed with stream id ${stream.id}');

    final it = _streams.where((element) => element.stream!.id == stream.id);
    if (it.isEmpty) {
      Logs().v('Didn\'t find the feed with stream id ${stream.id} to delete');
      return;
    }
    final wpstream = it.first;
    _streams.removeWhere((element) => element.stream!.id == stream.id);
    onStreamRemoved.add(wpstream);
    fireCallEvent(CallStateChange.kFeedsChanged);
    await wpstream.dispose();
  }

  Future<void> _sendCandidateQueue() async {
    if (callHasEnded) return;
    /*
    Currently, trickle-ice is not supported, so it will take a
    long time to wait to collect all the canidates, set the
    timeout for collection canidates to speed up the connection.
    */
    final candidatesQueue = _localCandidates;
    try {
      if (candidatesQueue.isNotEmpty) {
        final candidates = <Map<String, dynamic>>[];
        for (final element in candidatesQueue) {
          candidates.add(element.toMap());
        }
        _localCandidates.clear();
        final res = await sendCallCandidates(
          opts.room,
          callId,
          localPartyId,
          candidates,
        );
        Logs().v('[VOIP] sendCallCandidates res => $res');
      }
    } catch (e) {
      Logs().v('[VOIP] sendCallCandidates e => ${e.toString()}');
      _candidateSendTries++;
      _localCandidates.clear();
      _localCandidates.addAll(candidatesQueue);

      if (_candidateSendTries > 5) {
        Logs().d(
          'Failed to send candidates on attempt $_candidateSendTries Giving up on this call.',
        );
        await hangup(reason: CallErrorCode.iceTimeout);
        return;
      }

      final delay = 500 * pow(2, _candidateSendTries);
      Timer(Duration(milliseconds: delay as int), () {
        _sendCandidateQueue();
      });
    }
  }

  void fireCallEvent(CallStateChange event) {
    onCallEventChanged.add(event);
    Logs().i('CallStateChange: ${event.toString()}');
    switch (event) {
      case CallStateChange.kFeedsChanged:
        onCallStreamsChanged.add(this);
        break;
      case CallStateChange.kState:
        Logs().i('CallState: ${state.toString()}');
        break;
      case CallStateChange.kError:
        break;
      case CallStateChange.kHangup:
        break;
      case CallStateChange.kReplaced:
        break;
      case CallStateChange.kLocalHoldUnhold:
        break;
      case CallStateChange.kRemoteHoldUnhold:
        break;
      case CallStateChange.kAssertedIdentityChanged:
        break;
    }
  }

  Future<void> _getLocalOfferFailed(dynamic err) async {
    Logs().e('Failed to get local offer ${err.toString()}');
    fireCallEvent(CallStateChange.kError);

    await terminate(CallParty.kLocal, CallErrorCode.localOfferFailed, true);
  }

  Future<void> _getUserMediaFailed(dynamic err) async {
    Logs().w('Failed to get user media - ending call ${err.toString()}');
    fireCallEvent(CallStateChange.kError);
    await terminate(CallParty.kLocal, CallErrorCode.userMediaFailed, true);
  }

  Future<void> onSelectAnswerReceived(String? selectedPartyId) async {
    if (direction != CallDirection.kIncoming) {
      Logs().w('Got select_answer for an outbound call: ignoring');
      return;
    }
    if (selectedPartyId == null) {
      Logs().w(
        'Got nonsensical select_answer with null/undefined selected_party_id: ignoring',
      );
      return;
    }

    if (selectedPartyId != localPartyId) {
      Logs().w(
        'Got select_answer for party ID $selectedPartyId: we are party ID $localPartyId.',
      );
      // The other party has picked somebody else's answer
      await terminate(CallParty.kRemote, CallErrorCode.answeredElsewhere, true);
    }
  }

  /// This is sent by the caller when they wish to establish a call.
  /// [callId] is a unique identifier for the call.
  /// [version] is the version of the VoIP specification this message adheres to. This specification is version 1.
  /// [lifetime] is the time in milliseconds that the invite is valid for. Once the invite age exceeds this value,
  /// clients should discard it. They should also no longer show the call as awaiting an answer in the UI.
  /// [type] The type of session description. Must be 'offer'.
  /// [sdp] The SDP text of the session description.
  /// [invitee] The user ID of the person who is being invited. Invites without an invitee field are defined to be
  /// intended for any member of the room other than the sender of the event.
  /// [party_id] The party ID for call, Can be set to client.deviceId.
  Future<String?> sendInviteToCall(
    Room room,
    String callId,
    int lifetime,
    String party_id,
    String sdp, {
    String type = 'offer',
    String version = voipProtoVersion,
    String? txid,
    CallCapabilities? capabilities,
    SDPStreamMetadata? metadata,
  }) async {
    final content = {
      'call_id': callId,
      'party_id': party_id,
      if (groupCallId != null) 'conf_id': groupCallId!,
      'version': version,
      'lifetime': lifetime,
      'offer': {'sdp': sdp, 'type': type},
      if (remoteUserId != null)
        'invitee':
            remoteUserId!, // TODO: rename this to invitee_user_id? breaks spec though
      if (remoteDeviceId != null) 'invitee_device_id': remoteDeviceId!,
      if (remoteDeviceId != null)
        'device_id': client
            .deviceID!, // Having a remoteDeviceId means you are doing to-device events, so you want to send your deviceId too
      if (capabilities != null) 'capabilities': capabilities.toJson(),
      if (metadata != null) sdpStreamMetadataKey: metadata.toJson(),
    };
    return await _sendContent(
      room,
      isGroupCall ? EventTypes.GroupCallMemberInvite : EventTypes.CallInvite,
      content,
      txid: txid,
    );
  }

  /// The calling party sends the party_id of the first selected answer.
  ///
  /// Usually after receiving the first answer sdp in the client.onCallAnswer event,
  /// save the `party_id`, and then send `CallSelectAnswer` to others peers that the call has been picked up.
  ///
  /// [callId] is a unique identifier for the call.
  /// [version] is the version of the VoIP specification this message adheres to. This specification is version 1.
  /// [party_id] The party ID for call, Can be set to client.deviceId.
  /// [selected_party_id] The party ID for the selected answer.
  Future<String?> sendSelectCallAnswer(
    Room room,
    String callId,
    String party_id,
    String selected_party_id, {
    String version = voipProtoVersion,
    String? txid,
  }) async {
    final content = {
      'call_id': callId,
      'party_id': party_id,
      if (groupCallId != null) 'conf_id': groupCallId!,
      'version': version,
      'selected_party_id': selected_party_id,
    };

    return await _sendContent(
      room,
      isGroupCall
          ? EventTypes.GroupCallMemberSelectAnswer
          : EventTypes.CallSelectAnswer,
      content,
      txid: txid,
    );
  }

  /// Reject a call
  /// [callId] is a unique identifier for the call.
  /// [version] is the version of the VoIP specification this message adheres to. This specification is version 1.
  /// [party_id] The party ID for call, Can be set to client.deviceId.
  Future<String?> sendCallReject(
    Room room,
    String callId,
    String party_id, {
    String version = voipProtoVersion,
    String? txid,
  }) async {
    final content = {
      'call_id': callId,
      'party_id': party_id,
      if (groupCallId != null) 'conf_id': groupCallId!,
      'version': version,
    };

    return await _sendContent(
      room,
      isGroupCall ? EventTypes.GroupCallMemberReject : EventTypes.CallReject,
      content,
      txid: txid,
    );
  }

  /// When local audio/video tracks are added/deleted or hold/unhold,
  /// need to createOffer and renegotiation.
  /// [callId] is a unique identifier for the call.
  /// [version] is the version of the VoIP specification this message adheres to. This specification is version 1.
  /// [party_id] The party ID for call, Can be set to client.deviceId.
  Future<String?> sendCallNegotiate(
    Room room,
    String callId,
    int lifetime,
    String party_id,
    String sdp, {
    String type = 'offer',
    String version = voipProtoVersion,
    String? txid,
    CallCapabilities? capabilities,
    SDPStreamMetadata? metadata,
  }) async {
    final content = {
      'call_id': callId,
      'party_id': party_id,
      if (groupCallId != null) 'conf_id': groupCallId!,
      'version': version,
      'lifetime': lifetime,
      'description': {'sdp': sdp, 'type': type},
      if (capabilities != null) 'capabilities': capabilities.toJson(),
      if (metadata != null) sdpStreamMetadataKey: metadata.toJson(),
    };
    return await _sendContent(
      room,
      isGroupCall
          ? EventTypes.GroupCallMemberNegotiate
          : EventTypes.CallNegotiate,
      content,
      txid: txid,
    );
  }

  /// This is sent by callers after sending an invite and by the callee after answering.
  /// Its purpose is to give the other party additional ICE candidates to try using to communicate.
  ///
  /// [callId] The ID of the call this event relates to.
  ///
  /// [version] The version of the VoIP specification this messages adheres to. This specification is version 1.
  ///
  /// [party_id] The party ID for call, Can be set to client.deviceId.
  ///
  /// [candidates] Array of objects describing the candidates. Example:
  ///
  /// ```
  /// [
  ///       {
  ///           "candidate": "candidate:863018703 1 udp 2122260223 10.9.64.156 43670 typ host generation 0",
  ///           "sdpMLineIndex": 0,
  ///           "sdpMid": "audio"
  ///       }
  ///   ],
  /// ```
  Future<String?> sendCallCandidates(
    Room room,
    String callId,
    String party_id,
    List<Map<String, dynamic>> candidates, {
    String version = voipProtoVersion,
    String? txid,
  }) async {
    final content = {
      'call_id': callId,
      'party_id': party_id,
      if (groupCallId != null) 'conf_id': groupCallId!,
      'version': version,
      'candidates': candidates,
    };
    return await _sendContent(
      room,
      isGroupCall
          ? EventTypes.GroupCallMemberCandidates
          : EventTypes.CallCandidates,
      content,
      txid: txid,
    );
  }

  /// This event is sent by the callee when they wish to answer the call.
  /// [callId] is a unique identifier for the call.
  /// [version] is the version of the VoIP specification this message adheres to. This specification is version 1.
  /// [type] The type of session description. Must be 'answer'.
  /// [sdp] The SDP text of the session description.
  /// [party_id] The party ID for call, Can be set to client.deviceId.
  Future<String?> sendAnswerCall(
    Room room,
    String callId,
    String sdp,
    String party_id, {
    String type = 'answer',
    String version = voipProtoVersion,
    String? txid,
    CallCapabilities? capabilities,
    SDPStreamMetadata? metadata,
  }) async {
    final content = {
      'call_id': callId,
      'party_id': party_id,
      if (groupCallId != null) 'conf_id': groupCallId!,
      'version': version,
      'answer': {'sdp': sdp, 'type': type},
      if (capabilities != null) 'capabilities': capabilities.toJson(),
      if (metadata != null) sdpStreamMetadataKey: metadata.toJson(),
    };
    return await _sendContent(
      room,
      isGroupCall ? EventTypes.GroupCallMemberAnswer : EventTypes.CallAnswer,
      content,
      txid: txid,
    );
  }

  /// This event is sent by the callee when they wish to answer the call.
  /// [callId] The ID of the call this event relates to.
  /// [version] is the version of the VoIP specification this message adheres to. This specification is version 1.
  /// [party_id] The party ID for call, Can be set to client.deviceId.
  Future<String?> sendHangupCall(
    Room room,
    String callId,
    String party_id,
    String? hangupCause, {
    String version = voipProtoVersion,
    String? txid,
  }) async {
    final content = {
      'call_id': callId,
      'party_id': party_id,
      if (groupCallId != null) 'conf_id': groupCallId!,
      'version': version,
      if (hangupCause != null) 'reason': hangupCause,
    };
    return await _sendContent(
      room,
      isGroupCall ? EventTypes.GroupCallMemberHangup : EventTypes.CallHangup,
      content,
      txid: txid,
    );
  }

  /// Send SdpStreamMetadata Changed event.
  ///
  /// This MSC also adds a new call event m.call.sdp_stream_metadata_changed,
  /// which has the common VoIP fields as specified in
  /// MSC2746 (version, call_id, party_id) and a sdp_stream_metadata object which
  /// is the same thing as sdp_stream_metadata in m.call.negotiate, m.call.invite
  /// and m.call.answer. The client sends this event the when sdp_stream_metadata
  /// has changed but no negotiation is required
  ///  (e.g. the user mutes their camera/microphone).
  ///
  /// [callId] The ID of the call this event relates to.
  /// [version] is the version of the VoIP specification this message adheres to. This specification is version 1.
  /// [party_id] The party ID for call, Can be set to client.deviceId.
  /// [metadata] The sdp_stream_metadata object.
  Future<String?> sendSDPStreamMetadataChanged(
    Room room,
    String callId,
    String party_id,
    SDPStreamMetadata metadata, {
    String version = voipProtoVersion,
    String? txid,
  }) async {
    final content = {
      'call_id': callId,
      'party_id': party_id,
      if (groupCallId != null) 'conf_id': groupCallId!,
      'version': version,
      sdpStreamMetadataKey: metadata.toJson(),
    };
    return await _sendContent(
      room,
      isGroupCall
          ? EventTypes.GroupCallMemberSDPStreamMetadataChanged
          : EventTypes.CallSDPStreamMetadataChanged,
      content,
      txid: txid,
    );
  }

  /// CallReplacesEvent for Transfered calls
  ///
  /// [callId] The ID of the call this event relates to.
  /// [version] is the version of the VoIP specification this message adheres to. This specification is version 1.
  /// [party_id] The party ID for call, Can be set to client.deviceId.
  /// [callReplaces] transfer info
  Future<String?> sendCallReplaces(
    Room room,
    String callId,
    String party_id,
    CallReplaces callReplaces, {
    String version = voipProtoVersion,
    String? txid,
  }) async {
    final content = {
      'call_id': callId,
      'party_id': party_id,
      if (groupCallId != null) 'conf_id': groupCallId!,
      'version': version,
      ...callReplaces.toJson(),
    };
    return await _sendContent(
      room,
      isGroupCall
          ? EventTypes.GroupCallMemberReplaces
          : EventTypes.CallReplaces,
      content,
      txid: txid,
    );
  }

  /// send AssertedIdentity event
  ///
  /// [callId] The ID of the call this event relates to.
  /// [version] is the version of the VoIP specification this message adheres to. This specification is version 1.
  /// [party_id] The party ID for call, Can be set to client.deviceId.
  /// [assertedIdentity] the asserted identity
  Future<String?> sendAssertedIdentity(
    Room room,
    String callId,
    String party_id,
    AssertedIdentity assertedIdentity, {
    String version = voipProtoVersion,
    String? txid,
  }) async {
    final content = {
      'call_id': callId,
      'party_id': party_id,
      if (groupCallId != null) 'conf_id': groupCallId!,
      'version': version,
      'asserted_identity': assertedIdentity.toJson(),
    };
    return await _sendContent(
      room,
      isGroupCall
          ? EventTypes.GroupCallMemberAssertedIdentity
          : EventTypes.CallAssertedIdentity,
      content,
      txid: txid,
    );
  }

  Future<String?> _sendContent(
    Room room,
    String type,
    Map<String, Object> content, {
    String? txid,
  }) async {
    Logs().d('[VOIP] sending content type $type, with conf: $content');
    txid ??= VoIP.customTxid ?? client.generateUniqueTransactionId();
    final mustEncrypt = room.encrypted && client.encryptionEnabled;

    // opponentDeviceId is only set for a few events during group calls,
    // therefore only group calls use to-device messages for call events
    if (isGroupCall && remoteDeviceId != null) {
      final toDeviceSeq = _toDeviceSeq++;
      final Map<String, Object> data = {
        ...content,
        'seq': toDeviceSeq,
        if (remoteSessionId != null) 'dest_session_id': remoteSessionId!,
        'sender_session_id': voip.currentSessionId,
        'room_id': room.id,
      };

      if (mustEncrypt) {
        await client.userDeviceKeysLoading;
        if (client.userDeviceKeys[remoteUserId]?.deviceKeys[remoteDeviceId] !=
            null) {
          await client.sendToDeviceEncrypted(
            [
              client.userDeviceKeys[remoteUserId]!.deviceKeys[remoteDeviceId]!,
            ],
            type,
            data,
          );
        } else {
          Logs().w(
            '[VOIP] _sendCallContent missing device keys for $remoteUserId',
          );
        }
      } else {
        await client.sendToDevice(
          type,
          txid,
          {
            remoteUserId!: {remoteDeviceId!: data},
          },
        );
      }
      return '';
    } else {
      final sendMessageContent = mustEncrypt
          ? await client.encryption!
              .encryptGroupMessagePayload(room.id, content, type: type)
          : content;
      return await client.sendMessage(
        room.id,
        sendMessageContent.containsKey('ciphertext')
            ? EventTypes.Encrypted
            : type,
        txid,
        sendMessageContent,
      );
    }
  }
}
