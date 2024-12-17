import 'dart:async';

import 'package:collection/collection.dart';
import 'package:webrtc_interface/webrtc_interface.dart';

import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:matrix/src/voip/models/call_membership.dart';
import 'package:matrix/src/voip/models/call_options.dart';
import 'package:matrix/src/voip/utils/stream_helper.dart';
import 'package:matrix/src/voip/utils/user_media_constraints.dart';

class MeshBackend extends CallBackend {
  MeshBackend({
    super.type = 'mesh',
  });

  final List<CallSession> _callSessions = [];

  /// participant:volume
  final Map<CallParticipant, double> _audioLevelsMap = {};

  StreamSubscription<CallSession>? _callSubscription;

  Timer? _activeSpeakerLoopTimeout;

  final CachedStreamController<WrappedMediaStream> onStreamAdd =
      CachedStreamController();

  final CachedStreamController<WrappedMediaStream> onStreamRemoved =
      CachedStreamController();

  final CachedStreamController<GroupCallSession> onGroupCallFeedsChanged =
      CachedStreamController();

  @override
  Map<String, Object?> toJson() {
    return {
      'type': type,
    };
  }

  CallParticipant? _activeSpeaker;
  WrappedMediaStream? _localUserMediaStream;
  WrappedMediaStream? _localScreenshareStream;
  final List<WrappedMediaStream> _userMediaStreams = [];
  final List<WrappedMediaStream> _screenshareStreams = [];

  List<WrappedMediaStream> _getLocalStreams() {
    final feeds = <WrappedMediaStream>[];

    if (localUserMediaStream != null) {
      feeds.add(localUserMediaStream!);
    }

    if (localScreenshareStream != null) {
      feeds.add(localScreenshareStream!);
    }

    return feeds;
  }

  Future<MediaStream> _getUserMedia(
    GroupCallSession groupCall,
    CallType type,
  ) async {
    final mediaConstraints = {
      'audio': UserMediaConstraints.micMediaConstraints,
      'video': type == CallType.kVideo
          ? UserMediaConstraints.camMediaConstraints
          : false,
    };

    try {
      return await groupCall.voip.delegate.mediaDevices
          .getUserMedia(mediaConstraints);
    } catch (e) {
      groupCall.setState(GroupCallState.localCallFeedUninitialized);
      rethrow;
    }
  }

  Future<MediaStream> _getDisplayMedia(GroupCallSession groupCall) async {
    final mediaConstraints = {
      'audio': false,
      'video': true,
    };
    try {
      return await groupCall.voip.delegate.mediaDevices
          .getDisplayMedia(mediaConstraints);
    } catch (e, s) {
      throw MatrixSDKVoipException('_getDisplayMedia failed', stackTrace: s);
    }
  }

  CallSession? _getCallForParticipant(
    GroupCallSession groupCall,
    CallParticipant participant,
  ) {
    return _callSessions.singleWhereOrNull(
      (call) =>
          call.groupCallId == groupCall.groupCallId &&
          CallParticipant(
                groupCall.voip,
                userId: call.remoteUserId!,
                deviceId: call.remoteDeviceId,
              ) ==
              participant,
    );
  }

  Future<void> _addCall(GroupCallSession groupCall, CallSession call) async {
    _callSessions.add(call);
    await _initCall(groupCall, call);
    groupCall.onGroupCallEvent.add(GroupCallStateChange.callsChanged);
  }

  /// init a peer call from group calls.
  Future<void> _initCall(GroupCallSession groupCall, CallSession call) async {
    if (call.remoteUserId == null) {
      throw MatrixSDKVoipException(
        'Cannot init call without proper invitee user and device Id',
      );
    }

    call.onCallStateChanged.stream.listen(
      ((event) async {
        await _onCallStateChanged(call, event);
      }),
    );

    call.onCallReplaced.stream.listen((CallSession newCall) async {
      await _replaceCall(groupCall, call, newCall);
    });

    call.onCallStreamsChanged.stream.listen((call) async {
      await call.tryRemoveStopedStreams();
      await _onStreamsChanged(groupCall, call);
    });

    call.onCallHangupNotifierForGroupCalls.stream.listen((event) async {
      await _onCallHangup(groupCall, call);
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

  Future<void> _replaceCall(
    GroupCallSession groupCall,
    CallSession existingCall,
    CallSession replacementCall,
  ) async {
    final existingCallIndex = _callSessions
        .indexWhere((element) => element.callId == existingCall.callId);

    if (existingCallIndex == -1) {
      throw MatrixSDKVoipException('Couldn\'t find call to replace');
    }

    _callSessions.removeAt(existingCallIndex);
    _callSessions.add(replacementCall);

    await _disposeCall(groupCall, existingCall, CallErrorCode.replaced);
    await _initCall(groupCall, replacementCall);

    groupCall.onGroupCallEvent.add(GroupCallStateChange.callsChanged);
  }

  /// Removes a peer call from group calls.
  Future<void> _removeCall(
    GroupCallSession groupCall,
    CallSession call,
    CallErrorCode hangupReason,
  ) async {
    await _disposeCall(groupCall, call, hangupReason);

    _callSessions.removeWhere((element) => call.callId == element.callId);

    groupCall.onGroupCallEvent.add(GroupCallStateChange.callsChanged);
  }

  Future<void> _disposeCall(
    GroupCallSession groupCall,
    CallSession call,
    CallErrorCode hangupReason,
  ) async {
    if (call.remoteUserId == null) {
      throw MatrixSDKVoipException(
        'Cannot init call without proper invitee user and device Id',
      );
    }

    if (call.hangupReason == CallErrorCode.replaced) {
      return;
    }

    if (call.state != CallState.kEnded) {
      // no need to emit individual handleCallEnded on group calls
      // also prevents a loop of hangup and onCallHangupNotifierForGroupCalls
      await call.hangup(reason: hangupReason, shouldEmit: false);
    }

    final usermediaStream = _getUserMediaStreamByParticipantId(
      CallParticipant(
        groupCall.voip,
        userId: call.remoteUserId!,
        deviceId: call.remoteDeviceId,
      ).id,
    );

    if (usermediaStream != null) {
      await _removeUserMediaStream(groupCall, usermediaStream);
    }

    final screenshareStream = _getScreenshareStreamByParticipantId(
      CallParticipant(
        groupCall.voip,
        userId: call.remoteUserId!,
        deviceId: call.remoteDeviceId,
      ).id,
    );

    if (screenshareStream != null) {
      await _removeScreenshareStream(groupCall, screenshareStream);
    }
  }

  Future<void> _onStreamsChanged(
    GroupCallSession groupCall,
    CallSession call,
  ) async {
    if (call.remoteUserId == null) {
      throw MatrixSDKVoipException(
        'Cannot init call without proper invitee user and device Id',
      );
    }

    final currentUserMediaStream = _getUserMediaStreamByParticipantId(
      CallParticipant(
        groupCall.voip,
        userId: call.remoteUserId!,
        deviceId: call.remoteDeviceId,
      ).id,
    );

    final remoteUsermediaStream = call.remoteUserMediaStream;
    final remoteStreamChanged = remoteUsermediaStream != currentUserMediaStream;

    if (remoteStreamChanged) {
      if (currentUserMediaStream == null && remoteUsermediaStream != null) {
        await _addUserMediaStream(groupCall, remoteUsermediaStream);
      } else if (currentUserMediaStream != null &&
          remoteUsermediaStream != null) {
        await _replaceUserMediaStream(
          groupCall,
          currentUserMediaStream,
          remoteUsermediaStream,
        );
      } else if (currentUserMediaStream != null &&
          remoteUsermediaStream == null) {
        await _removeUserMediaStream(groupCall, currentUserMediaStream);
      }
    }

    final currentScreenshareStream = _getScreenshareStreamByParticipantId(
      CallParticipant(
        groupCall.voip,
        userId: call.remoteUserId!,
        deviceId: call.remoteDeviceId,
      ).id,
    );
    final remoteScreensharingStream = call.remoteScreenSharingStream;
    final remoteScreenshareStreamChanged =
        remoteScreensharingStream != currentScreenshareStream;

    if (remoteScreenshareStreamChanged) {
      if (currentScreenshareStream == null &&
          remoteScreensharingStream != null) {
        _addScreenshareStream(groupCall, remoteScreensharingStream);
      } else if (currentScreenshareStream != null &&
          remoteScreensharingStream != null) {
        await _replaceScreenshareStream(
          groupCall,
          currentScreenshareStream,
          remoteScreensharingStream,
        );
      } else if (currentScreenshareStream != null &&
          remoteScreensharingStream == null) {
        await _removeScreenshareStream(groupCall, currentScreenshareStream);
      }
    }

    onGroupCallFeedsChanged.add(groupCall);
  }

  WrappedMediaStream? _getUserMediaStreamByParticipantId(String participantId) {
    final stream = _userMediaStreams
        .where((stream) => stream.participant.id == participantId);
    if (stream.isNotEmpty) {
      return stream.first;
    }
    return null;
  }

  void _onActiveSpeakerLoop(GroupCallSession groupCall) async {
    CallParticipant? nextActiveSpeaker;
    // idc about screen sharing atm.
    final userMediaStreamsCopyList =
        List<WrappedMediaStream>.from(_userMediaStreams);
    for (final stream in userMediaStreamsCopyList) {
      if (stream.participant.isLocal && stream.pc == null) {
        continue;
      }

      final List<StatsReport> statsReport = await stream.pc!.getStats();
      statsReport
          .removeWhere((element) => !element.values.containsKey('audioLevel'));

      // https://www.w3.org/TR/webrtc-stats/#summary
      final otherPartyAudioLevel = statsReport
          .singleWhereOrNull(
            (element) =>
                element.type == 'inbound-rtp' &&
                element.values['kind'] == 'audio',
          )
          ?.values['audioLevel'];
      if (otherPartyAudioLevel != null) {
        _audioLevelsMap[stream.participant] = otherPartyAudioLevel;
      }

      // https://www.w3.org/TR/webrtc-stats/#dom-rtcstatstype-media-source
      // firefox does not seem to have this though. Works on chrome and android
      final ownAudioLevel = statsReport
          .singleWhereOrNull(
            (element) =>
                element.type == 'media-source' &&
                element.values['kind'] == 'audio',
          )
          ?.values['audioLevel'];
      if (groupCall.localParticipant != null &&
          ownAudioLevel != null &&
          _audioLevelsMap[groupCall.localParticipant] != ownAudioLevel) {
        _audioLevelsMap[groupCall.localParticipant!] = ownAudioLevel;
      }
    }

    double maxAudioLevel = double.negativeInfinity;
    // TODO: we probably want a threshold here?
    _audioLevelsMap.forEach((key, value) {
      if (value > maxAudioLevel) {
        nextActiveSpeaker = key;
        maxAudioLevel = value;
      }
    });

    if (nextActiveSpeaker != null && _activeSpeaker != nextActiveSpeaker) {
      _activeSpeaker = nextActiveSpeaker;
      groupCall.onGroupCallEvent.add(GroupCallStateChange.activeSpeakerChanged);
    }
    _activeSpeakerLoopTimeout?.cancel();
    _activeSpeakerLoopTimeout = Timer(
      CallConstants.activeSpeakerInterval,
      () => _onActiveSpeakerLoop(groupCall),
    );
  }

  WrappedMediaStream? _getScreenshareStreamByParticipantId(
    String participantId,
  ) {
    final stream = _screenshareStreams
        .where((stream) => stream.participant.id == participantId);
    if (stream.isNotEmpty) {
      return stream.first;
    }
    return null;
  }

  void _addScreenshareStream(
    GroupCallSession groupCall,
    WrappedMediaStream stream,
  ) {
    _screenshareStreams.add(stream);
    onStreamAdd.add(stream);
    groupCall.onGroupCallEvent
        .add(GroupCallStateChange.screenshareStreamsChanged);
  }

  Future<void> _replaceScreenshareStream(
    GroupCallSession groupCall,
    WrappedMediaStream existingStream,
    WrappedMediaStream replacementStream,
  ) async {
    final streamIndex = _screenshareStreams.indexWhere(
      (stream) => stream.participant.id == existingStream.participant.id,
    );

    if (streamIndex == -1) {
      throw MatrixSDKVoipException(
        'Couldn\'t find screenshare stream to replace',
      );
    }

    _screenshareStreams.replaceRange(streamIndex, 1, [replacementStream]);

    await existingStream.dispose();
    groupCall.onGroupCallEvent
        .add(GroupCallStateChange.screenshareStreamsChanged);
  }

  Future<void> _removeScreenshareStream(
    GroupCallSession groupCall,
    WrappedMediaStream stream,
  ) async {
    final streamIndex = _screenshareStreams
        .indexWhere((stream) => stream.participant.id == stream.participant.id);

    if (streamIndex == -1) {
      throw MatrixSDKVoipException(
        'Couldn\'t find screenshare stream to remove',
      );
    }

    _screenshareStreams.removeWhere(
      (element) => element.participant.id == stream.participant.id,
    );

    onStreamRemoved.add(stream);

    if (stream.isLocal()) {
      await stopMediaStream(stream.stream);
    }

    groupCall.onGroupCallEvent
        .add(GroupCallStateChange.screenshareStreamsChanged);
  }

  Future<void> _onCallStateChanged(CallSession call, CallState state) async {
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

  Future<void> _onCallHangup(
    GroupCallSession groupCall,
    CallSession call,
  ) async {
    if (call.hangupReason == CallErrorCode.replaced) {
      return;
    }
    await _onStreamsChanged(groupCall, call);
    await _removeCall(groupCall, call, call.hangupReason!);
  }

  Future<void> _addUserMediaStream(
    GroupCallSession groupCall,
    WrappedMediaStream stream,
  ) async {
    _userMediaStreams.add(stream);
    onStreamAdd.add(stream);
    groupCall.onGroupCallEvent
        .add(GroupCallStateChange.userMediaStreamsChanged);
  }

  Future<void> _replaceUserMediaStream(
    GroupCallSession groupCall,
    WrappedMediaStream existingStream,
    WrappedMediaStream replacementStream,
  ) async {
    final streamIndex = _userMediaStreams.indexWhere(
      (stream) => stream.participant.id == existingStream.participant.id,
    );

    if (streamIndex == -1) {
      throw MatrixSDKVoipException(
        'Couldn\'t find user media stream to replace',
      );
    }

    _userMediaStreams.replaceRange(streamIndex, 1, [replacementStream]);

    await existingStream.dispose();
    groupCall.onGroupCallEvent
        .add(GroupCallStateChange.userMediaStreamsChanged);
  }

  Future<void> _removeUserMediaStream(
    GroupCallSession groupCall,
    WrappedMediaStream stream,
  ) async {
    final streamIndex = _userMediaStreams.indexWhere(
      (element) => element.participant.id == stream.participant.id,
    );

    if (streamIndex == -1) {
      throw MatrixSDKVoipException(
        'Couldn\'t find user media stream to remove',
      );
    }

    _userMediaStreams.removeWhere(
      (element) => element.participant.id == stream.participant.id,
    );
    _audioLevelsMap.remove(stream.participant);
    onStreamRemoved.add(stream);

    if (stream.isLocal()) {
      await stopMediaStream(stream.stream);
    }

    groupCall.onGroupCallEvent
        .add(GroupCallStateChange.userMediaStreamsChanged);

    if (_activeSpeaker == stream.participant && _userMediaStreams.isNotEmpty) {
      _activeSpeaker = _userMediaStreams[0].participant;
      groupCall.onGroupCallEvent.add(GroupCallStateChange.activeSpeakerChanged);
    }
  }

  @override
  bool get e2eeEnabled => false;

  @override
  CallParticipant? get activeSpeaker => _activeSpeaker;

  @override
  WrappedMediaStream? get localUserMediaStream => _localUserMediaStream;

  @override
  WrappedMediaStream? get localScreenshareStream => _localScreenshareStream;

  @override
  List<WrappedMediaStream> get userMediaStreams =>
      List.unmodifiable(_userMediaStreams);

  @override
  List<WrappedMediaStream> get screenShareStreams =>
      List.unmodifiable(_screenshareStreams);

  @override
  Future<void> updateMediaDeviceForCalls() async {
    for (final call in _callSessions) {
      await call.updateMediaDeviceForCall();
    }
  }

  /// Initializes the local user media stream.
  /// The media stream must be prepared before the group call enters.
  /// if you allow the user to configure their camera and such ahead of time,
  /// you can pass that `stream` on to this function.
  /// This allows you to configure the camera before joining the call without
  ///  having to reopen the stream and possibly losing settings.
  @override
  Future<WrappedMediaStream?> initLocalStream(
    GroupCallSession groupCall, {
    WrappedMediaStream? stream,
  }) async {
    if (groupCall.state != GroupCallState.localCallFeedUninitialized) {
      throw MatrixSDKVoipException(
        'Cannot initialize local call feed in the ${groupCall.state} state.',
      );
    }

    groupCall.setState(GroupCallState.initializingLocalCallFeed);

    WrappedMediaStream localWrappedMediaStream;

    if (stream == null) {
      MediaStream stream;

      try {
        stream = await _getUserMedia(groupCall, CallType.kVideo);
      } catch (error) {
        groupCall.setState(GroupCallState.localCallFeedUninitialized);
        rethrow;
      }

      localWrappedMediaStream = WrappedMediaStream(
        stream: stream,
        participant: groupCall.localParticipant!,
        room: groupCall.room,
        client: groupCall.client,
        purpose: SDPStreamMetadataPurpose.Usermedia,
        audioMuted: stream.getAudioTracks().isEmpty,
        videoMuted: stream.getVideoTracks().isEmpty,
        isGroupCall: true,
        voip: groupCall.voip,
      );
    } else {
      localWrappedMediaStream = stream;
    }

    _localUserMediaStream = localWrappedMediaStream;
    await _addUserMediaStream(groupCall, localWrappedMediaStream);

    groupCall.setState(GroupCallState.localCallFeedInitialized);

    _activeSpeaker = null;

    return localWrappedMediaStream;
  }

  @override
  Future<void> setDeviceMuted(
    GroupCallSession groupCall,
    bool muted,
    MediaInputKind kind,
  ) async {
    if (!await hasMediaDevice(groupCall.voip.delegate, kind)) {
      return;
    }

    if (localUserMediaStream != null) {
      switch (kind) {
        case MediaInputKind.audioinput:
          localUserMediaStream!.setAudioMuted(muted);
          setTracksEnabled(
            localUserMediaStream!.stream!.getAudioTracks(),
            !muted,
          );
          for (final call in _callSessions) {
            await call.setMicrophoneMuted(muted);
          }
          break;
        case MediaInputKind.videoinput:
          localUserMediaStream!.setVideoMuted(muted);
          setTracksEnabled(
            localUserMediaStream!.stream!.getVideoTracks(),
            !muted,
          );
          for (final call in _callSessions) {
            await call.setLocalVideoMuted(muted);
          }
          break;
      }
    }

    groupCall.onGroupCallEvent.add(GroupCallStateChange.localMuteStateChanged);
    return;
  }

  Future<void> _onIncomingCall(
    GroupCallSession groupCall,
    CallSession newCall,
  ) async {
    // The incoming calls may be for another room, which we will ignore.
    if (newCall.room.id != groupCall.room.id) {
      return;
    }

    if (newCall.state != CallState.kRinging) {
      Logs().w('Incoming call no longer in ringing state. Ignoring.');
      return;
    }

    if (newCall.groupCallId == null ||
        newCall.groupCallId != groupCall.groupCallId) {
      Logs().v(
        'Incoming call with groupCallId ${newCall.groupCallId} ignored because it doesn\'t match the current group call',
      );
      await newCall.reject();
      return;
    }

    final existingCall = _getCallForParticipant(
      groupCall,
      CallParticipant(
        groupCall.voip,
        userId: newCall.remoteUserId!,
        deviceId: newCall.remoteDeviceId,
      ),
    );

    if (existingCall != null && existingCall.callId == newCall.callId) {
      return;
    }

    Logs().v(
      'GroupCallSession: incoming call from: ${newCall.remoteUserId}${newCall.remoteDeviceId}${newCall.remotePartyId}',
    );

    // Check if the user calling has an existing call and use this call instead.
    if (existingCall != null) {
      await _replaceCall(groupCall, existingCall, newCall);
    } else {
      await _addCall(groupCall, newCall);
    }

    await newCall.answerWithStreams(_getLocalStreams());
  }

  @override
  Future<void> setScreensharingEnabled(
    GroupCallSession groupCall,
    bool enabled,
    String desktopCapturerSourceId,
  ) async {
    if (enabled == (localScreenshareStream != null)) {
      return;
    }

    if (enabled) {
      try {
        Logs().v('Asking for screensharing permissions...');
        final stream = await _getDisplayMedia(groupCall);
        for (final track in stream.getTracks()) {
          // screen sharing should only have 1 video track anyway, so this only
          // fires once
          track.onEnded = () async {
            await setScreensharingEnabled(groupCall, false, '');
          };
        }
        Logs().v(
          'Screensharing permissions granted. Setting screensharing enabled on all calls',
        );
        _localScreenshareStream = WrappedMediaStream(
          stream: stream,
          participant: groupCall.localParticipant!,
          room: groupCall.room,
          client: groupCall.client,
          purpose: SDPStreamMetadataPurpose.Screenshare,
          audioMuted: stream.getAudioTracks().isEmpty,
          videoMuted: stream.getVideoTracks().isEmpty,
          isGroupCall: true,
          voip: groupCall.voip,
        );

        _addScreenshareStream(groupCall, localScreenshareStream!);

        groupCall.onGroupCallEvent
            .add(GroupCallStateChange.localScreenshareStateChanged);
        for (final call in _callSessions) {
          await call.addLocalStream(
            await localScreenshareStream!.stream!.clone(),
            localScreenshareStream!.purpose,
          );
        }

        await groupCall.sendMemberStateEvent();

        return;
      } catch (e, s) {
        Logs().e('[VOIP] Enabling screensharing error', e, s);
        groupCall.onGroupCallEvent.add(GroupCallStateChange.error);
        return;
      }
    } else {
      for (final call in _callSessions) {
        await call.removeLocalStream(call.localScreenSharingStream!);
      }
      await stopMediaStream(localScreenshareStream?.stream);
      await _removeScreenshareStream(groupCall, localScreenshareStream!);
      _localScreenshareStream = null;

      await groupCall.sendMemberStateEvent();

      groupCall.onGroupCallEvent
          .add(GroupCallStateChange.localMuteStateChanged);
      return;
    }
  }

  @override
  Future<void> dispose(GroupCallSession groupCall) async {
    if (localUserMediaStream != null) {
      await _removeUserMediaStream(groupCall, localUserMediaStream!);
      _localUserMediaStream = null;
    }

    if (localScreenshareStream != null) {
      await stopMediaStream(localScreenshareStream!.stream);
      await _removeScreenshareStream(groupCall, localScreenshareStream!);
      _localScreenshareStream = null;
    }

    // removeCall removes it from `_callSessions` later.
    final callsCopy = _callSessions.toList();

    for (final call in callsCopy) {
      await _removeCall(groupCall, call, CallErrorCode.userHangup);
    }

    _activeSpeaker = null;
    _activeSpeakerLoopTimeout?.cancel();
    await _callSubscription?.cancel();
  }

  @override
  bool get isLocalVideoMuted {
    if (localUserMediaStream != null) {
      return localUserMediaStream!.isVideoMuted();
    }

    return true;
  }

  @override
  bool get isMicrophoneMuted {
    if (localUserMediaStream != null) {
      return localUserMediaStream!.isAudioMuted();
    }

    return true;
  }

  @override
  Future<void> setupP2PCallsWithExistingMembers(
    GroupCallSession groupCall,
  ) async {
    for (final call in _callSessions) {
      await _onIncomingCall(groupCall, call);
    }

    _callSubscription = groupCall.voip.onIncomingCall.stream.listen(
      (newCall) => _onIncomingCall(groupCall, newCall),
    );

    _onActiveSpeakerLoop(groupCall);
  }

  @override
  Future<void> setupP2PCallWithNewMember(
    GroupCallSession groupCall,
    CallParticipant rp,
    CallMembership mem,
  ) async {
    final existingCall = _getCallForParticipant(groupCall, rp);
    if (existingCall != null) {
      if (existingCall.remoteSessionId != mem.membershipId) {
        await existingCall.hangup(reason: CallErrorCode.unknownError);
      } else {
        Logs().e(
          '[VOIP] onMemberStateChanged Not updating _participants list, already have a ongoing call with ${rp.id}',
        );
        return;
      }
    }

    // Only initiate a call with a participant who has a id that is lexicographically
    // less than your own. Otherwise, that user will call you.
    if (groupCall.localParticipant!.id.compareTo(rp.id) > 0) {
      Logs().i('[VOIP] Waiting for ${rp.id} to send call invite.');
      return;
    }

    final opts = CallOptions(
      callId: genCallID(),
      room: groupCall.room,
      voip: groupCall.voip,
      dir: CallDirection.kOutgoing,
      localPartyId: groupCall.voip.currentSessionId,
      groupCallId: groupCall.groupCallId,
      type: CallType.kVideo,
      iceServers: await groupCall.voip.getIceServers(),
    );
    final newCall = groupCall.voip.createNewCall(opts);

    /// both invitee userId and deviceId are set here because there can be
    /// multiple devices from same user in a call, so we specifiy who the
    /// invite is for
    ///
    /// MOVE TO CREATENEWCALL?
    newCall.remoteUserId = mem.userId;
    newCall.remoteDeviceId = mem.deviceId;
    // party id set to when answered
    newCall.remoteSessionId = mem.membershipId;

    await newCall.placeCallWithStreams(
      _getLocalStreams(),
      requestScreenSharing: mem.feeds?.any(
            (element) =>
                element['purpose'] == SDPStreamMetadataPurpose.Screenshare,
          ) ??
          false,
    );

    await _addCall(groupCall, newCall);
  }

  @override
  List<Map<String, String>>? getCurrentFeeds() {
    return _getLocalStreams()
        .map(
          (feed) => ({
            'purpose': feed.purpose,
          }),
        )
        .toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MeshBackend && type == other.type);
  @override
  int get hashCode => type.hashCode;

  /// get everything is livekit specific mesh calls shouldn't be affected by these
  @override
  Future<void> onCallEncryption(
    GroupCallSession groupCall,
    String userId,
    String deviceId,
    Map<String, dynamic> content,
  ) async {
    return;
  }

  @override
  Future<void> onCallEncryptionKeyRequest(
    GroupCallSession groupCall,
    String userId,
    String deviceId,
    Map<String, dynamic> content,
  ) async {
    return;
  }

  @override
  Future<void> onLeftParticipant(
    GroupCallSession groupCall,
    List<CallParticipant> anyLeft,
  ) async {
    return;
  }

  @override
  Future<void> onNewParticipant(
    GroupCallSession groupCall,
    List<CallParticipant> anyJoined,
  ) async {
    return;
  }

  @override
  Future<void> requestEncrytionKey(
    GroupCallSession groupCall,
    List<CallParticipant> remoteParticipants,
  ) async {
    return;
  }

  @override
  Future<void> preShareKey(GroupCallSession groupCall) async {
    return;
  }
}
