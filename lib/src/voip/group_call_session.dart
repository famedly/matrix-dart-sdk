/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2021 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General License for more details.
 *
 *   You should have received a copy of the GNU Affero General License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:typed_data';

import 'package:built_collection/built_collection.dart';
import 'package:cloudflare_calls_api/cloudflare_calls_api.dart';
import 'package:collection/collection.dart';
import 'package:webrtc_interface/webrtc_interface.dart';

import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:matrix/src/utils/crypto/crypto.dart';
import 'package:matrix/src/voip/models/call_membership.dart';
import 'package:matrix/src/voip/models/call_options.dart';
import 'package:matrix/src/voip/models/cloudflare_minisdp_mode.dart';
import 'package:matrix/src/voip/models/cloudflare_rt.dart';
import 'package:matrix/src/voip/models/voip_id.dart';
import 'package:matrix/src/voip/utils/stream_helper.dart';

/// Holds methods for managing a group call. This class is also responsible for
/// holding and managing the individual `CallSession`s in a group call.
class GroupCallSession {
  // Config
  static const updateExpireTsTimerDuration = Duration(seconds: 15);
  static const expireTsBumpDuration = Duration(seconds: 45);
  static const activeSpeakerInterval = Duration(seconds: 5);

  final Client client;
  final VoIP voip;
  final Room room;

  /// is a list of backend to allow passing multiple backends in the future
  /// we use the first backend everywhere as of now
  final List<CallBackend> backends;
  final String? application;
  final String? scope;

  GroupCallState state = GroupCallState.localCallFeedUninitialized;
  StreamSubscription<CallSession>? _callSubscription;

  /// participant:volume
  final Map<CallParticipant, double> audioLevelsMap = {};
  CallParticipant? activeSpeaker;
  WrappedMediaStream? localUserMediaStream;
  WrappedMediaStream? localScreenshareStream;
  String? localDesktopCapturerSourceId;
  List<CallSession> callSessions = [];

  CallParticipant? get localParticipant => voip.localParticipant;

  /// userId:deviceId
  List<CallParticipant> participants = [];
  List<WrappedMediaStream> userMediaStreams = [];
  List<WrappedMediaStream> screenshareStreams = [];
  late String groupCallId;

  GroupCallError? lastError;

  Timer? activeSpeakerLoopTimeout;

  Timer? resendMemberStateEventTimer;
  Timer? memberLeaveEncKeyRotateDebounceTimer;

  final CachedStreamController<GroupCallSession> onGroupCallFeedsChanged =
      CachedStreamController();

  final CachedStreamController<GroupCallState> onGroupCallState =
      CachedStreamController();

  final CachedStreamController<GroupCallEvent> onGroupCallEvent =
      CachedStreamController();

  final CachedStreamController<WrappedMediaStream> onStreamAdd =
      CachedStreamController();

  final CachedStreamController<WrappedMediaStream> onStreamRemoved =
      CachedStreamController();

  bool get isMeshBackend => backends.first is MeshBackend;

  bool get isLivekitCall => backends.first is LivekitBackend;

  bool get isCloudflareCall => backends.first is CloudflareBackend;

  /// toggle e2ee setup and key sharing
  final bool enableE2EE;

  GroupCallSession({
    String? groupCallId,
    required this.client,
    required this.room,
    required this.voip,
    required this.backends,
    required this.enableE2EE,
    this.application = 'm.call',
    this.scope = 'm.room',
  }) {
    this.groupCallId = groupCallId ?? genCallID();
  }

  String get avatarName =>
      getUser().calcDisplayname(mxidLocalPartFallback: false);

  String? get displayName => getUser().displayName;

  User getUser() {
    return room.unsafeGetUserFromMemoryOrFallback(client.userID!);
  }

  void setState(GroupCallState newState) {
    state = newState;
    onGroupCallState.add(newState);
    onGroupCallEvent.add(GroupCallEvent.groupCallStateChanged);
  }

  List<WrappedMediaStream> getLocalStreams() {
    final feeds = <WrappedMediaStream>[];

    if (localUserMediaStream != null) {
      feeds.add(localUserMediaStream!);
    }

    if (localScreenshareStream != null) {
      feeds.add(localScreenshareStream!);
    }

    return feeds;
  }

  bool hasLocalParticipant() {
    return participants.contains(localParticipant);
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
              'optional': [CallConstants.optionalAudioConfig],
            }
          : false,
    };
    try {
      return await voip.delegate.mediaDevices.getUserMedia(mediaConstraints);
    } catch (e) {
      setState(GroupCallState.localCallFeedUninitialized);
      rethrow;
    }
  }

  Future<MediaStream> _getDisplayMedia() async {
    final mediaConstraints = {
      'audio': false,
      'video': true,
    };
    try {
      return await voip.delegate.mediaDevices.getDisplayMedia(mediaConstraints);
    } catch (e, s) {
      Logs().e('[VOIP] _getDisplayMedia failed because,', e, s);
    }
    return Null as MediaStream;
  }

  /// Initializes the local user media stream.
  /// The media stream must be prepared before the group call enters.
  /// if you allow the user to configure their camera and such ahead of time,
  /// you can pass that `stream` on to this function.
  /// This allows you to configure the camera before joining the call without
  ///  having to reopen the stream and possibly losing settings.
  Future<WrappedMediaStream> initLocalStream(
      {WrappedMediaStream? stream}) async {
    if (state != GroupCallState.localCallFeedUninitialized) {
      throw Exception('Cannot initialize local call feed in the $state state.');
    }

    setState(GroupCallState.initializingLocalCallFeed);

    WrappedMediaStream localWrappedMediaStream;

    if (stream == null) {
      MediaStream stream;

      try {
        stream = await _getUserMedia(CallType.kVideo);
      } catch (error) {
        setState(GroupCallState.localCallFeedUninitialized);
        rethrow;
      }

      localWrappedMediaStream = WrappedMediaStream(
        stream: stream,
        participant: localParticipant!,
        room: room,
        client: client,
        purpose: SDPStreamMetadataPurpose.Usermedia,
        audioMuted: stream.getAudioTracks().isEmpty,
        videoMuted: stream.getVideoTracks().isEmpty,
        isWeb: voip.delegate.isWeb,
        isGroupCall: true,
        voip: voip,
      );
    } else {
      localWrappedMediaStream = stream;
    }

    localUserMediaStream = localWrappedMediaStream;
    await addUserMediaStream(localWrappedMediaStream);

    setState(GroupCallState.localCallFeedInitialized);

    return localWrappedMediaStream;
  }

  Future<void> updateMediaDeviceForCalls() async {
    for (final call in callSessions) {
      await call.updateMediaDeviceForCall();
    }
  }

  void updateLocalUsermediaStream(WrappedMediaStream stream) {
    if (localUserMediaStream != null) {
      final oldStream = localUserMediaStream!.stream;
      localUserMediaStream!.setNewStream(stream.stream!);
      // ignore: discarded_futures
      stopMediaStream(oldStream);
    }
  }

// help- autogen kinda sucks
  String getSDPTypeFromSDP(SessionDescriptionTypeEnum type) {
    switch (type) {
      case SessionDescriptionTypeEnum.answer:
        return 'answer';
      case SessionDescriptionTypeEnum.offer:
        return 'offer';
      default:
        return 'wtf';
    }
  }

// help- autogen kinda sucks
  String getSDPTypeFromNewSDP(
      NewSessionResponseSessionDescriptionTypeEnum type) {
    switch (type) {
      case NewSessionResponseSessionDescriptionTypeEnum.answer:
        return 'answer';
      case NewSessionResponseSessionDescriptionTypeEnum.offer:
        return 'offer';
      default:
        return 'wtf';
    }
  }

  /// the current cloudflare session id
  String? cloudflareSessionId;

  /// the current cloudflare CallSession
  CallSession? cloudflareCall;

  AppsAppIdSessionsNewPostRequest createNewSessionPacket(
      SessionDescription sdp) {
    final appsAppIdSessionsNewPostRequestBuilder =
        AppsAppIdSessionsNewPostRequestBuilder();
    appsAppIdSessionsNewPostRequestBuilder.sessionDescription = sdp.toBuilder();
    return appsAppIdSessionsNewPostRequestBuilder.build();
  }

  SessionDescription createSdpPacket(RTCSessionDescription offer) {
    final offerSdpBuilder = SessionDescriptionBuilder();
    offerSdpBuilder.sdp = offer.sdp;
    offerSdpBuilder.type = offer.type == 'answer'
        ? SessionDescriptionTypeEnum.answer
        : SessionDescriptionTypeEnum.offer;
    return offerSdpBuilder.build();
  }

  TracksRequest createTrackRequestPacket(
      BuiltList<TrackObject> tracks, SessionDescription? sdp) {
    final trackRequest = TracksRequestBuilder();
    trackRequest.sessionDescription = sdp?.toBuilder();
    trackRequest.tracks = tracks.toBuilder();
    return trackRequest.build();
  }

  Future<BuiltList<TrackObject>> createLocalTrackObjectPushPacket(
      RTCPeerConnection pc, List<MediaStreamTrack> tracks) async {
    if (tracks.isEmpty) return BuiltList();
    final trackObjectList = ListBuilder<TrackObject>();
    final tss = await pc.getTransceivers();

    for (final track in tracks) {
      final ts =
          tss.firstWhere((element) => element.sender.track?.id == track.id);
      final trackObjectBuilder = $TrackObjectBuilder();
      trackObjectBuilder.location = TrackObjectLocationEnum.local;
      trackObjectBuilder.mid = ts.mid;
      trackObjectBuilder.trackName = track.id;
      (backends.first as CloudflareBackend)
          .remoteTracks
          .add(CloudflareRemoteTrack(
            sessionId: cloudflareSessionId!,
            trackName: track.id!,
            mid: ts.mid,
          ));

      trackObjectList.add(trackObjectBuilder.build());
    }
    await sendMemberStateEvent();
    return trackObjectList.build();
  }

  Future<BuiltList<TrackObject>> createRemoteTrackObjectPushPacket(
      List<CloudflareRemoteTrack> remoteTracks) async {
    final trackObjectList = ListBuilder<TrackObject>();
    for (final rt in remoteTracks) {
      final trackObjectBuilder = $TrackObjectBuilder();
      trackObjectBuilder.location = TrackObjectLocationEnum.remote;
      trackObjectBuilder.sessionId = rt.sessionId;
      trackObjectBuilder.trackName = rt.trackName;
      trackObjectList.add(trackObjectBuilder.build());
    }
    return trackObjectList.build();
  }

  BuiltList<CloseTrackObject> createCloseTrackObjectPushPacket(
      List<String> remoteTracks) {
    final closeTrackObjectList = ListBuilder<CloseTrackObject>();
    for (final rt in remoteTracks) {
      final trackObjectBuilder = $CloseTrackObjectBuilder();
      trackObjectBuilder.mid = rt;
      closeTrackObjectList.add(trackObjectBuilder.build());
    }
    return closeTrackObjectList.build();
  }

  AppsAppIdSessionsSessionIdRenegotiatePutRequest createRenegotiationPushPacket(
      RTCSessionDescription localSDP) {
    final rengBuilder =
        AppsAppIdSessionsSessionIdRenegotiatePutRequestBuilder();
    rengBuilder.sessionDescription = createSdpPacket(localSDP).toBuilder();
    return rengBuilder.build();
  }

  AppsAppIdSessionsSessionIdTracksClosePutRequest createClosePutPacket(
    SessionDescription sdp,
    BuiltList<CloseTrackObject> closeTracks,
    bool force,
  ) {
    final closeBuilder =
        AppsAppIdSessionsSessionIdTracksClosePutRequestBuilder();
    closeBuilder.sessionDescription = sdp.toBuilder();
    closeBuilder.tracks = closeTracks.toBuilder();
    closeBuilder.force = force;

    return closeBuilder.build();
  }

  /// enter the group call.
  Future<void> enter({WrappedMediaStream? stream}) async {
    if (!(state == GroupCallState.localCallFeedUninitialized ||
        state == GroupCallState.localCallFeedInitialized)) {
      throw Exception('Cannot enter call in the $state state');
    }

    if (state == GroupCallState.localCallFeedUninitialized && !isLivekitCall) {
      await initLocalStream(stream: stream);
    }

    if (isCloudflareCall) {
      final opts = CallOptions(
        callId: groupCallId,
        type: CallType.kVideo,
        dir: CallDirection.kOutgoing,
        localPartyId: voip.currentSessionId,
        voip: voip,
        room: room,
        iceServers: [
          {
            'urls': 'stun:stun.cloudflare.com:3478',
          }
        ],
      );

      final newCall = cloudflareCall = voip.createNewCall(opts);

      newCall.onStreamAdd.stream.listen((stream) {
        if (!stream.isLocal()) {
          Logs().e('adding ${stream.id}');
          userMediaStreams.add(stream);
        }
      });
      newCall.onStreamRemoved.stream.listen((stream) {
        if (!stream.isLocal()) {
          Logs().e('removing ${stream.id}');
          userMediaStreams.remove(stream);
        }
      });

      if (cloudflareCall == null) {
        throw Exception('Failed to create cloudflareCall');
      }
      newCall.sendRelatedMatrixEvent = false;
      newCall.setCallState(CallState.kWaitLocalMedia);
      final localUserMedia = getLocalStreams();

      await newCall.placeCallWithStreams(localUserMedia, false);

      while (!newCall.iceGatheringFinished) {
        await Future.delayed(Duration(seconds: 1));
        Logs()
            .d('[VOIP] cloudflare call waiting for ice gathering to complete');
      }

      final offer = await newCall.pc!.createOffer();
      await newCall.pc!.setLocalDescription(offer);

      final cloudflareCallSession = (await voip.cloudflareCallsApi!
              .getNewSessionApi()
              .appsAppIdSessionsNewPost(
                  appId: CallConstants.cloudflareAppId,
                  appsAppIdSessionsNewPostRequest:
                      createNewSessionPacket(createSdpPacket(offer))))
          .data;

      if (cloudflareCallSession == null ||
          cloudflareCallSession.sessionDescription == null ||
          cloudflareCallSession.sessionId == null) {
        throw Exception('could not create session');
      }

      cloudflareSessionId = cloudflareCallSession.sessionId;

      if (cloudflareCallSession.sessionDescription?.sdp != null &&
          cloudflareCallSession.sessionDescription?.type != null) {
        await newCall.pc!.setRemoteDescription(
          RTCSessionDescription(
            cloudflareCallSession.sessionDescription!.sdp,
            getSDPTypeFromNewSDP(
              cloudflareCallSession.sessionDescription!.type!,
            ),
          ),
        );
      }
      final senderTracks = await createLocalTrackObjectPushPacket(
          newCall.pc!, localUserMediaStream?.stream?.getTracks() ?? []);
      if (senderTracks.isNotEmpty) {
        // again?
        final lo = await newCall.pc!.createOffer();
        await newCall.pc!.setLocalDescription(lo);
        final trackResp = (await voip.cloudflareCallsApi!
                .getAddATrackApi()
                .appsAppIdSessionsSessionIdTracksNewPost(
                  appId: CallConstants.cloudflareAppId,
                  sessionId: cloudflareCallSession.sessionId!,
                  tracksRequest: createTrackRequestPacket(
                      senderTracks, createSdpPacket(lo)),
                ))
            .data;

        if (trackResp?.sessionDescription?.sdp != null &&
            trackResp?.sessionDescription?.type != null) {
          await newCall.pc!.setRemoteDescription(
            RTCSessionDescription(
              trackResp?.sessionDescription?.sdp,
              getSDPTypeFromSDP(trackResp!.sessionDescription!.type!),
            ),
          );
        }
      }
    }

    // yes cloudflare calls send this twice at start because it's also called in
    // createLocalTrackRequestPacket
    // what if no tracks? unblock this then
    if (!isCloudflareCall) await sendMemberStateEvent();

    activeSpeaker = null;

    setState(GroupCallState.entered);

    Logs().v('Entered group call $groupCallId');

    // Set up participants for the members currently in the call.
    // Other members will be picked up by the RoomState.members event.
    await onMemberStateChanged();

    if (isMeshBackend) {
      for (final call in callSessions) {
        await onIncomingCall(call);
      }

      _callSubscription = voip.onIncomingCall.stream.listen(onIncomingCall);

      onActiveSpeakerLoop();
    }

    voip.currentGroupCID = VoipId(roomId: room.id, callId: groupCallId);

    await voip.delegate.handleNewGroupCall(this);
  }

  Future<void> dispose() async {
    if (localUserMediaStream != null) {
      await removeUserMediaStream(localUserMediaStream!);
      localUserMediaStream = null;
    }

    if (localScreenshareStream != null) {
      await stopMediaStream(localScreenshareStream!.stream);
      await removeScreenshareStream(localScreenshareStream!);
      localScreenshareStream = null;
      localDesktopCapturerSourceId = null;
    }

    await removeMemberStateEvent();

    // removeCall removes it from `callSessions` later.
    final callsCopy = callSessions.toList();

    for (final call in callsCopy) {
      await removeCall(call, CallErrorCode.user_hangup);
    }

    activeSpeaker = null;
    activeSpeakerLoopTimeout?.cancel();
    await _callSubscription?.cancel();
  }

  Future<void> leave() async {
    if (isCloudflareCall && cloudflareCall != null) {
      await cloudflareCall!.cleanUp();
    }
    await dispose();
    setState(GroupCallState.localCallFeedUninitialized);
    voip.currentGroupCID = null;
    participants.clear();
    // only remove our own, to save requesting if we join again, yes the other side
    // will send it anyway but welp
    encryptionKeysMap.remove(localParticipant!);
    _currentLocalKeyIndex = 0;
    _latestLocalKeyIndex = 0;
    voip.groupCalls.remove(VoipId(roomId: room.id, callId: groupCallId));
    await voip.delegate.handleGroupCallEnded(this);
    resendMemberStateEventTimer?.cancel();
    memberLeaveEncKeyRotateDebounceTimer?.cancel();
    setState(GroupCallState.ended);
  }

  bool get isLocalVideoMuted {
    if (localUserMediaStream != null) {
      return localUserMediaStream!.isVideoMuted();
    }

    return true;
  }

  bool get isMicrophoneMuted {
    if (localUserMediaStream != null) {
      return localUserMediaStream!.isAudioMuted();
    }

    return true;
  }

  Future<bool> setMicrophoneMuted(bool muted) async {
    if (!await hasMediaDevice(voip.delegate, MediaInputKind.audioinput)) {
      return false;
    }

    if (localUserMediaStream != null) {
      localUserMediaStream!.setAudioMuted(muted);
      setTracksEnabled(localUserMediaStream!.stream!.getAudioTracks(), !muted);
    }

    for (final call in callSessions) {
      await call.setMicrophoneMuted(muted);
    }

    onGroupCallEvent.add(GroupCallEvent.localMuteStateChanged);
    return true;
  }

  Future<bool> setLocalVideoMuted(bool muted) async {
    if (!await hasMediaDevice(voip.delegate, MediaInputKind.videoinput)) {
      return false;
    }

    if (localUserMediaStream != null) {
      localUserMediaStream!.setVideoMuted(muted);
      setTracksEnabled(localUserMediaStream!.stream!.getVideoTracks(), !muted);
    }

    for (final call in callSessions) {
      await call.setLocalVideoMuted(muted);
    }

    onGroupCallEvent.add(GroupCallEvent.localMuteStateChanged);
    return true;
  }

  bool get screensharingEnabled => isScreensharing();

  Future<bool> setScreensharingEnabled(
    bool enabled,
    String desktopCapturerSourceId,
  ) async {
    if (enabled == isScreensharing()) {
      return enabled;
    }

    if (enabled) {
      try {
        Logs().v('Asking for screensharing permissions...');
        final stream = await _getDisplayMedia();
        for (final track in stream.getTracks()) {
          // screen sharing should only have 1 video track anyway, so this only
          // fires once
          track.onEnded = () async {
            await setScreensharingEnabled(false, '');
          };
        }
        Logs().v(
            'Screensharing permissions granted. Setting screensharing enabled on all calls');
        localDesktopCapturerSourceId = desktopCapturerSourceId;
        localScreenshareStream = WrappedMediaStream(
          stream: stream,
          participant: localParticipant!,
          room: room,
          client: client,
          purpose: SDPStreamMetadataPurpose.Screenshare,
          audioMuted: stream.getAudioTracks().isEmpty,
          videoMuted: stream.getVideoTracks().isEmpty,
          isWeb: voip.delegate.isWeb,
          isGroupCall: true,
          voip: voip,
        );

        addScreenshareStream(localScreenshareStream!);

        onGroupCallEvent.add(GroupCallEvent.localScreenshareStateChanged);
        for (final call in callSessions) {
          await call.addLocalStream(
              await localScreenshareStream!.stream!.clone(),
              localScreenshareStream!.purpose);
        }

        //await sendMemberStateEvent();

        return true;
      } catch (e, s) {
        Logs().e('[VOIP] Enabling screensharing error', e, s);
        lastError = GroupCallError(GroupCallErrorCode.user_media_failed,
            'Failed to get screen-sharing stream: ', e);
        onGroupCallEvent.add(GroupCallEvent.error);
        return false;
      }
    } else {
      for (final call in callSessions) {
        await call.removeLocalStream(call.localScreenSharingStream!);
      }

      await stopMediaStream(localScreenshareStream?.stream);
      await removeScreenshareStream(localScreenshareStream!);
      localScreenshareStream = null;
      localDesktopCapturerSourceId = null;
      //await sendMemberStateEvent();
      onGroupCallEvent.add(GroupCallEvent.localMuteStateChanged);
      return false;
    }
  }

  bool isScreensharing() {
    return localScreenshareStream != null;
  }

  Future<void> onIncomingCall(CallSession newCall) async {
    // The incoming calls may be for another room, which we will ignore.
    if (newCall.room.id != room.id) {
      return;
    }

    if (newCall.state != CallState.kRinging) {
      Logs().w('Incoming call no longer in ringing state. Ignoring.');
      return;
    }

    if (newCall.groupCallId == null || newCall.groupCallId != groupCallId) {
      Logs().v(
          'Incoming call with groupCallId ${newCall.groupCallId} ignored because it doesn\'t match the current group call');
      await newCall.reject();
      return;
    }

    if (!isMeshBackend) {
      Logs()
          .i('Received incoming call whilst in signaling-only mode! Ignoring.');
      return;
    }

    final existingCall = getCallForParticipant(
      CallParticipant(
        userId: newCall.remoteUserId!,
        deviceId: newCall.remoteDeviceId,
        // sessionId: newCall.remoteSessionId,
      ),
    );

    if (existingCall != null && existingCall.callId == newCall.callId) {
      return;
    }

    Logs().v(
        'GroupCallSession: incoming call from: ${newCall.remoteUserId}${newCall.remoteDeviceId}${newCall.remotePartyId}');

    // Check if the user calling has an existing call and use this call instead.
    if (existingCall != null) {
      await replaceCall(existingCall, newCall);
    } else {
      await addCall(newCall);
    }

    await newCall.answerWithStreams(getLocalStreams(), true);
  }

  Future<void> sendMemberStateEvent() async {
    await room.updateFamedlyCallMemberStateEvent(
      CallMembership(
        userId: client.userID!,
        roomId: room.id,
        callId: groupCallId,
        application: application,
        scope: scope,
        backends: backends,
        deviceId: client.deviceID!,
        expiresTs: DateTime.now()
            .add(CallTimeouts.expireTsBumpDuration)
            .millisecondsSinceEpoch,
        membershipId: voip.currentSessionId,
      ),
    );

    if (resendMemberStateEventTimer != null) {
      resendMemberStateEventTimer!.cancel();
    }
    resendMemberStateEventTimer = Timer.periodic(
        CallTimeouts.updateExpireTsTimerDuration, ((timer) async {
      Logs().d('sendMemberStateEvent updating member event with timer');
      if (state != GroupCallState.ended ||
          state != GroupCallState.localCallFeedUninitialized) {
        await sendMemberStateEvent();
      } else {
        await removeMemberStateEvent();
      }
    }));
  }

  Future<void> removeMemberStateEvent() {
    if (resendMemberStateEventTimer != null) {
      Logs().d('resend member event timer cancelled');
      resendMemberStateEventTimer!.cancel();
      resendMemberStateEventTimer = null;
    }
    return room.removeFamedlyCallMemberEvent(
      groupCallId,
      client.deviceID!,
      application: application,
      scope: scope,
    );
  }

  /// compltetely rebuilds the local participants list
  Future<void> onMemberStateChanged() async {
    if (state != GroupCallState.entered) {
      Logs().d(
          '[VOIP] early return onMemberStateChanged, group call state is not Entered. Actual state: ${state.toString()} ');
      return;
    }

    // The member events may be received for another room, which we will ignore.
    final mems =
        room.getCallMembershipsFromRoom().values.expand((element) => element);
    final memsForCurrentGroupCall = mems.where((element) {
      return element.callId == groupCallId &&
          !element.isExpired &&
          element.application == application &&
          element.scope == scope &&
          element.roomId == room.id; // sanity checks
    }).toList();

    final ignoredMems =
        mems.where((element) => !memsForCurrentGroupCall.contains(element));

    for (final mem in ignoredMems) {
      Logs().w(
          '[VOIP] Ignored ${mem.userId}\'s mem event ${mem.toJson()} while updating participants list for callId: $groupCallId, expiry status: ${mem.isExpired}');
    }

    final List<CallParticipant> newP = [];
    final List<TrackObject> rtsreq = [];
    for (final mem in memsForCurrentGroupCall) {
      final rp = CallParticipant(
        userId: mem.userId,
        deviceId: mem.deviceId,
      );

      newP.add(rp);

      if (rp == localParticipant) continue;

      if (isCloudflareCall && cloudflareSessionId != null) {
        final existingCall = cloudflareCall;
        final rts = (mem.backends.first as CloudflareBackend).remoteTracks;

        if (existingCall != null && rts.isNotEmpty) {
          bool listEquals<T>(List<T> list1, List<T> list2) {
            if (list1.length != list2.length) {
              return false;
            }
            return list1.every((element) => list2.contains(element));
          }

          if (existingCall.remoteTrackUserIdMap[rp] != null &&
              listEquals(existingCall.remoteTrackUserIdMap[rp]!,
                  rts.map((e) => e.trackName).toList())) {
            Logs()
                .d('Skipping cloudflare webrtc stuff, remote tracks identical');
            continue;
          }

          existingCall.remoteTrackUserIdMap[rp] = rts
              .map((e) =>
                  CloudflareMiniSdpMode(trackId: e.trackName, mid: e.mid))
              .toList();
          Logs().e('set');
          Logs().e(rp.toString());
          Logs().e(existingCall.remoteTrackUserIdMap[rp].toString());
          if (rts.isNotEmpty) {
            rtsreq.addAll(await createRemoteTrackObjectPushPacket(rts));
          }
        }
      }

      if (!isMeshBackend) {
        Logs().w(
            '[VOIP] onMemberStateChanged deteceted non mesh call, skipping native webrtc stuff for member update');
        continue;
      }

      if (state != GroupCallState.entered) {
        Logs().w(
            '[VOIP] onMemberStateChanged groupCall state is currently $state, skipping member update');
        continue;
      }

      // Only initiate a call with a participant who has a id that is lexicographically
      // less than your own. Otherwise, that user will call you.
      if (localParticipant!.id.compareTo(rp.id) > 0) {
        Logs().e('[VOIP] Waiting for ${rp.id} to send call invite.');
        continue;
      }

      final existingCall = getCallForParticipant(rp);
      if (existingCall != null) {
        if (existingCall.remoteSessionId != mem.membershipId) {
          await existingCall.hangup(reason: CallErrorCode.unknown_error);
        } else {
          Logs().e(
              '[VOIP] onMemberStateChanged Not updating participants list, already have a ongoing call with ${rp.id}');
          continue;
        }
      }

      final opts = CallOptions(
        callId: genCallID(),
        room: room,
        voip: voip,
        dir: CallDirection.kOutgoing,
        localPartyId: voip.currentSessionId,
        groupCallId: groupCallId,
        type: CallType.kVideo,
        iceServers: await voip.getIceServers(),
      );
      final newCall = voip.createNewCall(opts);

      /// both invitee userId and deviceId are set here because there can be
      /// multiple devices from same user in a call, so we specifiy who the
      /// invite is for
      ///
      /// MOVE TO CREATENEWCALL?
      newCall.remoteUserId = mem.userId;
      newCall.remoteDeviceId = mem.deviceId;
      // party id set to when answered
      newCall.remoteSessionId = mem.membershipId;

      await newCall.placeCallWithStreams(getLocalStreams(), true);

      await addCall(newCall);
    }
    final newPcopy = List<CallParticipant>.from(newP);
    final oldPcopy = List<CallParticipant>.from(participants);
    final anyJoined = newPcopy.where((element) => !oldPcopy.contains(element));
    final anyLeft = oldPcopy.where((element) => !newPcopy.contains(element));

    if (anyJoined.isNotEmpty || anyLeft.isNotEmpty) {
      if (anyJoined.isNotEmpty) {
        Logs().d('anyJoined: ${anyJoined.map((e) => e.id).toString()}');
        Logs().e('newTracksToBeAddedLen: ${rtsreq.length}');
        participants.addAll(anyJoined);
        if (isCloudflareCall && cloudflareCall != null && rtsreq.isNotEmpty) {
          final existingCall = cloudflareCall;
          TracksResponse? rtresp;
          await Future.delayed(Duration(seconds: 5));
          final rtJson = await voip.cloudflareCallsApi!
              .getAddATrackApi()
              .appsAppIdSessionsSessionIdTracksNewPost(
                appId: CallConstants.cloudflareAppId,
                sessionId: cloudflareSessionId!,
                tracksRequest:
                    createTrackRequestPacket(rtsreq.toBuiltList(), null),
              );

          rtresp = rtJson.data;

          // final startTime = DateTime.now();

          // while (
          //     (rtresp?.tracks?.any((p0) => p0.mid?.isEmpty ?? true) ?? true)) {
          //   if (startTime.add(Duration(seconds: 10)).isBefore(DateTime.now())) {
          //     Logs().e('remtoe tracks still broken');
          //     break;
          //   }
          //   await Future.delayed(Duration(seconds: 2));
          //   Logs().e('repulling remote tracks');
          //   rtresp = (await voip.cloudflareCallsApi!
          //           .getAddATrackApi()
          //           .appsAppIdSessionsSessionIdTracksNewPost(
          //             appId: CallConstants.cloudflareAppId,
          //             sessionId: cloudflareSessionId!,
          //             tracksRequest:
          //                 createTrackRequestPacket(rtsreq.toBuiltList(), null),
          //           ))
          //       .data;
          // }

          if (rtresp != null &&
              (rtresp.requiresImmediateRenegotiation ?? false)) {
            if (rtresp.sessionDescription?.sdp != null &&
                rtresp.sessionDescription?.type != null &&
                rtresp.tracks != null) {
              String magicSDP = rtresp.sessionDescription!.sdp!;
              Logs().e(magicSDP.toString());

              for (final track in rtresp.tracks!) {
                if (track.mid == null) continue;
                Logs().e('updaing ${track.mid} msid with ${track.trackName}');

                final List<String> lines = magicSDP.split('\r\n');

                final int midIndex = lines
                    .indexWhere((line) => line.contains('a=mid:${track.mid!}'));

                if (midIndex != -1) {
                  for (int i = midIndex; i < lines.length; i++) {
                    if (lines[i].startsWith('m=')) {
                      break;
                    }
                    final int msidIndex = lines.indexWhere(
                        (line) => line.contains('a=msid:'), midIndex);

                    if (msidIndex != -1) {
                      final currentId = lines[msidIndex].split('a=msid:').last;
                      final splitIds = currentId.split(' ');
                      // Logs().e(currentId.toString());
                      // Logs().e(splitIds.toString());

                      lines[i] = lines[i].replaceAll(
                        splitIds.last,
                        track.trackName!,
                      );
                    }
                  }
                }

                // Join the modified lines back into SDP
                final String modifiedSdp = lines.join('\r\n');
                magicSDP = modifiedSdp;
              }

              Logs().e(magicSDP.toString());

              await existingCall!.pc!.setRemoteDescription(
                RTCSessionDescription(
                  magicSDP,
                  getSDPTypeFromSDP(rtresp.sessionDescription!.type!),
                ),
              );
              final answer = await existingCall.pc!.createAnswer();
              await existingCall.pc!.setLocalDescription(answer);
              await voip.cloudflareCallsApi!
                  .getRenegotiateWebRTCSessionApi()
                  .appsAppIdSessionsSessionIdRenegotiatePut(
                    appId: CallConstants.cloudflareAppId,
                    sessionId: cloudflareSessionId!,
                    appsAppIdSessionsSessionIdRenegotiatePutRequest:
                        createRenegotiationPushPacket(answer),
                  );
            }
          }
        }

        if (isLivekitCall && enableE2EE) {
          // ratcheting does not work on web, we just create a whole new key everywhere
          if (voip.enableSFUE2EEKeyRatcheting) {
            await _ratchetLocalParticipantKey(anyJoined.toList());
          } else {
            await makeNewSenderKey(true);
          }
        }
      }
      if (anyLeft.isNotEmpty) {
        Logs().d('anyLeft: ${anyLeft.map((e) => e.id).toString()}');
        final List<String> toCloseMids = [];
        for (final leftp in anyLeft) {
          participants.remove(leftp);

          // map trans to mid and then inactivate
          // if (isCloudflareCall && cloudflareCall != null) {
          //   final existingCall = cloudflareCall;
          //   final tss = await existingCall!.pc!.getTransceivers();

          //   final sdps = existingCall.remoteTrackUserIdMap[leftp] ?? [];

          //   final toCloseTss =
          //       tss.where((ts) => sdps.any((sdp) => sdp.mid == ts.mid));

          //   for (final ts in toCloseTss) {
          //     toCloseMids.add(ts.mid);
          //     await ts.setDirection(TransceiverDirection.Inactive);
          //   }
          //   existingCall.remoteTrackUserIdMap.remove(leftp);
          // }
        }
        if (isCloudflareCall && cloudflareCall != null) {
          // final existingCall = cloudflareCall;
          // final offer = await existingCall!.pc!.createOffer();
          // await existingCall.pc!.setLocalDescription(offer);

          // final closeResp = (await voip.cloudflareCallsApi!
          //         .getCloseATrackApi()
          //         .appsAppIdSessionsSessionIdTracksClosePut(
          //           appId: CallConstants.cloudflareAppId,
          //           sessionId: cloudflareSessionId!,
          //           appsAppIdSessionsSessionIdTracksClosePutRequest:
          //               createClosePutPacket(
          //                   createSdpPacket(offer),
          //                   createCloseTrackObjectPushPacket(toCloseMids),
          //                   true),
          //         ))
          //     .data;
          // if (closeResp?.sessionDescription != null) {
          //   await existingCall.pc!.setRemoteDescription(
          //     RTCSessionDescription(
          //       closeResp!.sessionDescription!.sdp,
          //       getSDPTypeFromSDP(closeResp.sessionDescription!.type!),
          //     ),
          //   );
          // }
        }

        if (isLivekitCall && enableE2EE) {
          encryptionKeysMap.removeWhere((key, value) => anyLeft.contains(key));

          // debounce it because people leave at the same time
          if (memberLeaveEncKeyRotateDebounceTimer != null) {
            memberLeaveEncKeyRotateDebounceTimer!.cancel();
          }
          memberLeaveEncKeyRotateDebounceTimer =
              Timer(CallTimeouts.makeKeyDelay, () async {
            await makeNewSenderKey(true);
          });
        }
      }

      onGroupCallEvent.add(GroupCallEvent.participantsChanged);
      Logs().d(
          '[VOIP] onMemberStateChanged current list: ${participants.map((e) => e.id).toString()}');
    }
  }

  CallSession? getCallForParticipant(CallParticipant participant) {
    return callSessions.singleWhereOrNull((call) =>
        call.groupCallId == groupCallId &&
        CallParticipant(
              userId: call.remoteUserId!,
              deviceId: call.remoteDeviceId,
              //sessionId: call.remoteSessionId,
            ) ==
            participant);
  }

  Future<void> addCall(CallSession call) async {
    callSessions.add(call);
    await initCall(call);
    onGroupCallEvent.add(GroupCallEvent.callsChanged);
  }

  Future<void> replaceCall(
      CallSession existingCall, CallSession replacementCall) async {
    final existingCallIndex =
        callSessions.indexWhere((element) => element == existingCall);

    if (existingCallIndex == -1) {
      throw Exception('Couldn\'t find call to replace');
    }

    callSessions.removeAt(existingCallIndex);
    callSessions.add(replacementCall);

    await disposeCall(existingCall, CallErrorCode.replaced);
    await initCall(replacementCall);

    onGroupCallEvent.add(GroupCallEvent.callsChanged);
  }

  /// Removes a peer call from group calls.
  Future<void> removeCall(CallSession call, CallErrorCode hangupReason) async {
    await disposeCall(call, hangupReason);

    callSessions.removeWhere((element) => call.callId == element.callId);

    onGroupCallEvent.add(GroupCallEvent.callsChanged);
  }

  /// init a peer call from group calls.
  Future<void> initCall(CallSession call) async {
    if (call.remoteUserId == null) {
      throw Exception(
          'Cannot init call without proper invitee user and device Id');
    }

    call.onCallStateChanged.stream.listen(((event) async {
      await onCallStateChanged(call, event);
    }));

    call.onCallReplaced.stream.listen((CallSession newCall) async {
      await replaceCall(call, newCall);
    });

    call.onCallStreamsChanged.stream.listen((call) async {
      await call.tryRemoveStopedStreams();
      await onStreamsChanged(call);
    });

    call.onCallHangupNotifierForGroupCalls.stream.listen((event) async {
      await onCallHangup(call);
    });

    call.onStreamAdd.stream.listen((stream) {
      if (!stream.isLocal()) {
        onStreamAdd.add(stream);
      }
    });

    call.onStreamRemoved.stream.listen((stream) {
      if (!stream.isLocal()) {
        onStreamRemoved.add(stream);
      }
    });
  }

  Future<void> disposeCall(CallSession call, CallErrorCode hangupReason) async {
    if (call.remoteUserId == null) {
      throw Exception(
          'Cannot init call without proper invitee user and device Id');
    }

    if (call.hangupReason == CallErrorCode.replaced) {
      return;
    }

    if (call.state != CallState.kEnded) {
      // no need to emit individual handleCallEnded on group calls
      // also prevents a loop of hangup and onCallHangupNotifierForGroupCalls
      await call.hangup(reason: hangupReason, shouldEmit: false);
    }

    final usermediaStream = getUserMediaStreamByParticipantId(CallParticipant(
      userId: call.remoteUserId!,
      deviceId: call.remoteDeviceId,
      // sessionId: call.remoteSessionId,
    ).id);

    if (usermediaStream != null) {
      await removeUserMediaStream(usermediaStream);
    }

    final screenshareStream =
        getScreenshareStreamByParticipantId(CallParticipant(
      userId: call.remoteUserId!,
      deviceId: call.remoteDeviceId,
      //  sessionId: call.remoteSessionId,
    ).id);

    if (screenshareStream != null) {
      await removeScreenshareStream(screenshareStream);
    }
  }

  Future<void> onStreamsChanged(CallSession call) async {
    if (call.remoteUserId == null) {
      throw Exception(
          'Cannot init call without proper invitee user and device Id');
    }

    final currentUserMediaStream =
        getUserMediaStreamByParticipantId(CallParticipant(
      userId: call.remoteUserId!,
      deviceId: call.remoteDeviceId,
      //sessionId: call.remoteSessionId,
    ).id);
    final remoteUsermediaStream = call.remoteUserMediaStream;
    final remoteStreamChanged = remoteUsermediaStream != currentUserMediaStream;

    if (remoteStreamChanged) {
      if (currentUserMediaStream == null && remoteUsermediaStream != null) {
        await addUserMediaStream(remoteUsermediaStream);
      } else if (currentUserMediaStream != null &&
          remoteUsermediaStream != null) {
        await replaceUserMediaStream(
            currentUserMediaStream, remoteUsermediaStream);
      } else if (currentUserMediaStream != null &&
          remoteUsermediaStream == null) {
        await removeUserMediaStream(currentUserMediaStream);
      }
    }

    final currentScreenshareStream =
        getScreenshareStreamByParticipantId(CallParticipant(
      userId: call.remoteUserId!,
      deviceId: call.remoteDeviceId,
      //  sessionId: call.remoteSessionId,
    ).id);
    final remoteScreensharingStream = call.remoteScreenSharingStream;
    final remoteScreenshareStreamChanged =
        remoteScreensharingStream != currentScreenshareStream;

    if (remoteScreenshareStreamChanged) {
      if (currentScreenshareStream == null &&
          remoteScreensharingStream != null) {
        addScreenshareStream(remoteScreensharingStream);
      } else if (currentScreenshareStream != null &&
          remoteScreensharingStream != null) {
        await replaceScreenshareStream(
            currentScreenshareStream, remoteScreensharingStream);
      } else if (currentScreenshareStream != null &&
          remoteScreensharingStream == null) {
        await removeScreenshareStream(currentScreenshareStream);
      }
    }

    onGroupCallFeedsChanged.add(this);
  }

  Future<void> onCallStateChanged(CallSession call, CallState state) async {
    final audioMuted = localUserMediaStream?.isAudioMuted() ?? true;
    if (call.localUserMediaStream != null &&
        call.isMicrophoneMuted != audioMuted) {
      await call.setMicrophoneMuted(audioMuted);
    }

    final videoMuted = localUserMediaStream?.isVideoMuted() ?? true;

    if (call.localUserMediaStream != null &&
        call.isLocalVideoMuted != videoMuted) {
      await call.setLocalVideoMuted(videoMuted);
    }
  }

  Future<void> onCallHangup(CallSession call) async {
    if (call.hangupReason == CallErrorCode.replaced) {
      return;
    }
    await onStreamsChanged(call);
    await removeCall(call, call.hangupReason!);
  }

  WrappedMediaStream? getUserMediaStreamByParticipantId(String participantId) {
    final stream = userMediaStreams
        .where((stream) => stream.participant.id == participantId);
    if (stream.isNotEmpty) {
      return stream.first;
    }
    return null;
  }

  Future<void> addUserMediaStream(WrappedMediaStream stream) async {
    userMediaStreams.add(stream);
    //callFeed.measureVolumeActivity(true);
    onStreamAdd.add(stream);
    onGroupCallEvent.add(GroupCallEvent.userMediaStreamsChanged);
  }

  Future<void> replaceUserMediaStream(WrappedMediaStream existingStream,
      WrappedMediaStream replacementStream) async {
    final streamIndex = userMediaStreams.indexWhere(
        (stream) => stream.participant.id == existingStream.participant.id);

    if (streamIndex == -1) {
      throw Exception('Couldn\'t find user media stream to replace');
    }

    userMediaStreams.replaceRange(streamIndex, 1, [replacementStream]);

    await existingStream.dispose();
    //replacementStream.measureVolumeActivity(true);
    onGroupCallEvent.add(GroupCallEvent.userMediaStreamsChanged);
  }

  Future<void> removeUserMediaStream(WrappedMediaStream stream) async {
    final streamIndex = userMediaStreams.indexWhere(
        (element) => element.participant.id == stream.participant.id);

    if (streamIndex == -1) {
      throw Exception('Couldn\'t find user media stream to remove');
    }

    userMediaStreams.removeWhere(
        (element) => element.participant.id == stream.participant.id);
    audioLevelsMap.remove(stream.participant);
    onStreamRemoved.add(stream);

    if (stream.isLocal()) {
      await stopMediaStream(stream.stream);
    }

    onGroupCallEvent.add(GroupCallEvent.userMediaStreamsChanged);

    if (activeSpeaker == stream.participant && userMediaStreams.isNotEmpty) {
      activeSpeaker = userMediaStreams[0].participant;
      onGroupCallEvent.add(GroupCallEvent.activeSpeakerChanged);
    }
  }

  void onActiveSpeakerLoop() async {
    CallParticipant? nextActiveSpeaker;
    // idc about screen sharing atm.
    final userMediaStreamsCopyList =
        List<WrappedMediaStream>.from(userMediaStreams);
    for (final stream in userMediaStreamsCopyList) {
      if (stream.participant == localParticipant && stream.pc == null) {
        continue;
      }

      final List<StatsReport> statsReport = await stream.pc!.getStats();
      statsReport
          .removeWhere((element) => !element.values.containsKey('audioLevel'));

      // https://www.w3.org/TR/webrtc-stats/#summary
      final otherPartyAudioLevel = statsReport
          .singleWhereOrNull((element) =>
              element.type == 'inbound-rtp' &&
              element.values['kind'] == 'audio')
          ?.values['audioLevel'];
      if (otherPartyAudioLevel != null) {
        audioLevelsMap[stream.participant] = otherPartyAudioLevel;
      }

      // https://www.w3.org/TR/webrtc-stats/#dom-rtcstatstype-media-source
      // firefox does not seem to have this though. Works on chrome and android
      final ownAudioLevel = statsReport
          .singleWhereOrNull((element) =>
              element.type == 'media-source' &&
              element.values['kind'] == 'audio')
          ?.values['audioLevel'];
      if (localParticipant != null &&
          ownAudioLevel != null &&
          audioLevelsMap[localParticipant] != ownAudioLevel) {
        audioLevelsMap[localParticipant!] = ownAudioLevel;
      }
    }

    double maxAudioLevel = double.negativeInfinity;
    // TODO: we probably want a threshold here?
    audioLevelsMap.forEach((key, value) {
      if (value > maxAudioLevel) {
        nextActiveSpeaker = key;
        maxAudioLevel = value;
      }
    });

    if (nextActiveSpeaker != null && activeSpeaker != nextActiveSpeaker) {
      activeSpeaker = nextActiveSpeaker;
      onGroupCallEvent.add(GroupCallEvent.activeSpeakerChanged);
    }
    activeSpeakerLoopTimeout?.cancel();
    activeSpeakerLoopTimeout =
        Timer(activeSpeakerInterval, onActiveSpeakerLoop);
  }

  WrappedMediaStream? getScreenshareStreamByParticipantId(
      String participantId) {
    final stream = screenshareStreams
        .where((stream) => stream.participant.id == participantId);
    if (stream.isNotEmpty) {
      return stream.first;
    }
    return null;
  }

  void addScreenshareStream(WrappedMediaStream stream) {
    screenshareStreams.add(stream);
    onStreamAdd.add(stream);
    onGroupCallEvent.add(GroupCallEvent.screenshareStreamsChanged);
  }

  Future<void> replaceScreenshareStream(WrappedMediaStream existingStream,
      WrappedMediaStream replacementStream) async {
    final streamIndex = screenshareStreams.indexWhere(
        (stream) => stream.participant.id == existingStream.participant.id);

    if (streamIndex == -1) {
      throw Exception('Couldn\'t find screenshare stream to replace');
    }

    screenshareStreams.replaceRange(streamIndex, 1, [replacementStream]);

    await existingStream.dispose();
    onGroupCallEvent.add(GroupCallEvent.screenshareStreamsChanged);
  }

  Future<void> removeScreenshareStream(WrappedMediaStream stream) async {
    final streamIndex = screenshareStreams
        .indexWhere((stream) => stream.participant.id == stream.participant.id);

    if (streamIndex == -1) {
      throw Exception('Couldn\'t find screenshare stream to remove');
    }

    screenshareStreams.removeWhere(
        (element) => element.participant.id == stream.participant.id);

    onStreamRemoved.add(stream);

    if (stream.isLocal()) {
      await stopMediaStream(stream.stream);
    }

    onGroupCallEvent.add(GroupCallEvent.screenshareStreamsChanged);
  }

  /// participant:keyIndex:keyBin
  Map<CallParticipant, Map<int, Uint8List>> encryptionKeysMap = {};

  List<Future> setNewKeyTimeouts = [];

  Map<int, Uint8List>? getKeysForParticipant(CallParticipant participant) {
    return encryptionKeysMap[participant];
  }

  int indexCounter = 0;

  /// always chooses the next possible index, we cycle after 16 because
  /// no real adv with infinite list
  int getNewEncryptionKeyIndex() {
    final newIndex = indexCounter % 16;
    indexCounter++;
    return newIndex;
  }

  /// makes a new e2ee key for local user and sets it with a delay if specified
  /// used on first join and when someone leaves
  ///
  /// also does the sending for you
  Future<void> makeNewSenderKey(bool delayBeforeUsingKeyOurself) async {
    final key = secureRandomBytes(32);
    final keyIndex = getNewEncryptionKeyIndex();
    Logs().i('[VOIP E2EE] Generated new key $key at index $keyIndex');

    await _setEncryptionKey(
      localParticipant!,
      keyIndex,
      key,
      delayBeforeUsingKeyOurself: delayBeforeUsingKeyOurself,
      send: true,
    );
  }

  /// also does the sending for you
  Future<void> _ratchetLocalParticipantKey(List<CallParticipant> sendTo) async {
    final keyProvider = voip.delegate.keyProvider;

    if (keyProvider == null) {
      throw Exception('[VOIP] _ratchetKey called but KeyProvider was null');
    }

    final myKeys = encryptionKeysMap[localParticipant];

    if (myKeys == null || myKeys.isEmpty) {
      await makeNewSenderKey(false);
      return;
    }

    Uint8List? ratchetedKey;

    while (ratchetedKey == null || ratchetedKey.isEmpty) {
      Logs().i('[VOIP E2EE] Ignoring empty ratcheted key');
      ratchetedKey = await keyProvider.onRatchetKey(
          localParticipant!, latestLocalKeyIndex);
    }

    Logs().i(
        '[VOIP E2EE] Ratched latest key to $ratchetedKey at idx $latestLocalKeyIndex');

    await _setEncryptionKey(
      localParticipant!,
      latestLocalKeyIndex,
      ratchetedKey,
      delayBeforeUsingKeyOurself: false,
      send: true,
      sendTo: sendTo,
    );
  }

  /// used to send the key again incase someone `onCallEncryptionKeyRequest` but don't just send
  /// the last one because you also cycle back in your window which means you
  /// could potentially end up sharing a past key
  int get latestLocalKeyIndex => _latestLocalKeyIndex;
  int _latestLocalKeyIndex = 0;

  /// the key currently being used by the local cryptor, can possibly not be the latest
  /// key, check `latestLocalKeyIndex` for latest key
  int get currentLocalKeyIndex => _currentLocalKeyIndex;
  int _currentLocalKeyIndex = 0;

  /// sets incoming keys and also sends the key if it was for the local user
  /// if sendTo is null, its sent to all participants, see `_sendEncryptionKeysEvent`
  Future<void> _setEncryptionKey(
    CallParticipant participant,
    int encryptionKeyIndex,
    Uint8List encryptionKeyBin, {
    bool delayBeforeUsingKeyOurself = false,
    bool send = false,
    List<CallParticipant>? sendTo,
  }) async {
    final encryptionKeys = encryptionKeysMap[participant] ?? <int, Uint8List>{};

    // if (encryptionKeys[encryptionKeyIndex] != null &&
    //     listEquals(encryptionKeys[encryptionKeyIndex]!, keyBin)) {
    //   Logs().i('[VOIP E2EE] Ignoring duplicate key');
    //   return;
    // }

    encryptionKeys[encryptionKeyIndex] = encryptionKeyBin;
    encryptionKeysMap[participant] = encryptionKeys;
    if (participant == localParticipant) {
      _latestLocalKeyIndex = encryptionKeyIndex;
    }

    if (send) {
      await _sendEncryptionKeysEvent(encryptionKeyIndex, sendTo: sendTo);
    }

    if (delayBeforeUsingKeyOurself) {
      // now wait for the key to propogate and then set it, hopefully users can
      // stil decrypt everything
      final useKeyTimeout = Future.delayed(CallTimeouts.useKeyDelay, () async {
        Logs().i(
            '[VOIP E2EE] setting key changed event for ${participant.id} idx $encryptionKeyIndex key $encryptionKeyBin');
        await voip.delegate.keyProvider?.onSetEncryptionKey(
            participant, encryptionKeyBin, encryptionKeyIndex);
        if (participant == localParticipant) {
          _currentLocalKeyIndex = encryptionKeyIndex;
        }
      });
      setNewKeyTimeouts.add(useKeyTimeout);
    } else {
      Logs().i(
          '[VOIP E2EE] setting key changed event for ${participant.id} idx $encryptionKeyIndex key $encryptionKeyBin');
      await voip.delegate.keyProvider?.onSetEncryptionKey(
          participant, encryptionKeyBin, encryptionKeyIndex);
      if (participant == localParticipant) {
        _currentLocalKeyIndex = encryptionKeyIndex;
      }
    }
  }

  /// sends the enc key to the devices using todevice, passing a list of
  /// sendTo only sends events to them
  /// setting keyIndex to null will send the latestKey
  Future<void> _sendEncryptionKeysEvent(int keyIndex,
      {List<CallParticipant>? sendTo}) async {
    Logs().i('Sending encryption keys event');

    final myKeys = getKeysForParticipant(localParticipant!);
    final myLatestKey = myKeys?[keyIndex];

    final sendKeysTo =
        sendTo ?? participants.where((p) => p != localParticipant);

    if (myKeys == null || myLatestKey == null) {
      Logs().w(
          '[VOIP E2EE] _sendEncryptionKeysEvent Tried to send encryption keys event but no keys found!');
      await makeNewSenderKey(false);
      await _sendEncryptionKeysEvent(
        keyIndex,
        sendTo: sendTo,
      );
      return;
    }

    try {
      final keyContent = EncryptionKeysEventContent(
        [EncryptionKeyEntry(keyIndex, base64Encode(myLatestKey))],
        groupCallId,
      );
      final Map<String, Object> data = {
        ...keyContent.toJson(),
        // used to find group call in groupCalls when ToDeviceEvent happens,
        // plays nicely with backwards compatibility for mesh calls
        'conf_id': groupCallId,
        'device_id': client.deviceID!,
        'room_id': room.id,
      };
      await _sendToDeviceEvent(
        sendTo ?? sendKeysTo.toList(),
        data,
        VoIPEventTypes.EncryptionKeysEvent,
      );
    } catch (e, s) {
      Logs().e('Failed to send e2ee keys, retrying', e, s);
      await _sendEncryptionKeysEvent(
        keyIndex,
        sendTo: sendTo,
      );
    }
  }

  Future<void> onCallEncryption(Room room, String userId, String deviceId,
      Map<String, dynamic> content) async {
    if (!enableE2EE) {
      Logs().w('[VOIP] got sframe key but we do not support e2ee');
      return;
    }
    final keyContent = EncryptionKeysEventContent.fromJson(content);

    final callId = keyContent.callId;

    if (keyContent.keys.isEmpty) {
      Logs().w(
          '[VOIP E2EE] Received m.call.encryption_keys where keys is empty: callId=$callId');
      return;
    } else {
      Logs().i(
          '[VOIP E2EE]: onCallEncryption, got keys from $userId:$deviceId ${keyContent.toJson()}');
    }

    for (final key in keyContent.keys) {
      final encryptionKey = key.key;
      final encryptionKeyIndex = key.index;
      await _setEncryptionKey(
        CallParticipant(userId: userId, deviceId: deviceId),
        encryptionKeyIndex,
        base64Decode(
            encryptionKey), // base64Decode here because we receive base64Encoded version
        delayBeforeUsingKeyOurself: false,
        send: false,
      );
    }
  }

  Future<void> requestEncrytionKey(
      List<CallParticipant> remoteParticipants) async {
    final Map<String, Object> data = {
      'conf_id': groupCallId,
      'device_id': client.deviceID!,
      'room_id': room.id,
    };

    await _sendToDeviceEvent(
      remoteParticipants,
      data,
      VoIPEventTypes.RequestEncryptionKeysEvent,
    );
  }

  Future<void> onCallEncryptionKeyRequest(Room room, String userId,
      String deviceId, Map<String, dynamic> content) async {
    if (room.id != room.id) return;
    if (!enableE2EE) {
      Logs().w('[VOIP] got sframe key request but we do not support e2ee');
      return;
    }
    final mems = room.getCallMembershipsForUser(userId);
    if (mems
        .where((mem) =>
            mem.callId == groupCallId &&
            mem.userId == userId &&
            mem.deviceId == deviceId &&
            !mem.isExpired &&
            // sanity checks
            mem.backends.first.type == backends.first.type &&
            mem.roomId == room.id &&
            mem.application == application)
        .isNotEmpty) {
      Logs().d(
          '[VOIP] onCallEncryptionKeyRequest: request checks out, sending key on index: $latestLocalKeyIndex to $userId:$deviceId');
      await _sendEncryptionKeysEvent(
        latestLocalKeyIndex,
        sendTo: [CallParticipant(userId: userId, deviceId: deviceId)],
      );
    }
  }

  Future<void> _sendToDeviceEvent(List<CallParticipant> remoteParticipants,
      Map<String, Object> data, String eventType) async {
    Logs().v(
        '[VOIP] _sendToDeviceEvent: sending ${data.toString()} to ${remoteParticipants.map((e) => e.id)} ');
    final txid = VoIP.customTxid ?? client.generateUniqueTransactionId();
    final mustEncrypt = room.encrypted && client.encryptionEnabled;

    // could just combine the two but do not want to rewrite the enc thingy
    // wrappers here again.
    final List<DeviceKeys> mustEncryptkeysToSendTo = [];
    final Map<String, Map<String, Map<String, Object>>> unencryptedDataToSend =
        {};

    for (final participant in remoteParticipants) {
      if (participant.deviceId == null) continue;
      if (mustEncrypt) {
        await client.userDeviceKeysLoading;
        final deviceKey = client.userDeviceKeys[participant.userId]
            ?.deviceKeys[participant.deviceId];
        if (deviceKey != null) {
          mustEncryptkeysToSendTo.add(deviceKey);
        }
      } else {
        unencryptedDataToSend.addAll({
          participant.userId: {participant.deviceId!: data}
        });
      }
    }

    // prepped data, now we send
    if (mustEncrypt) {
      await client.sendToDeviceEncrypted(
          mustEncryptkeysToSendTo, eventType, data);
    } else {
      await client.sendToDevice(
        eventType,
        txid,
        unencryptedDataToSend,
      );
    }
  }
}
