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

import 'package:collection/collection.dart';
import 'package:webrtc_interface/webrtc_interface.dart';

import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:matrix/src/utils/crypto/crypto.dart';
import 'package:matrix/src/voip/models/call_membership.dart';
import 'package:matrix/src/voip/models/call_options.dart';
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
  final CallBackend backend;
  final String? application;
  final String? scope;

  String state = GroupCallState.LocalCallFeedUninitialized;
  StreamSubscription<CallSession>? _callSubscription;

  /// participant:volume
  final Map<Participant, double> audioLevelsMap = {};
  Participant? activeSpeaker;
  WrappedMediaStream? localUserMediaStream;
  WrappedMediaStream? localScreenshareStream;
  String? localDesktopCapturerSourceId;
  List<CallSession> callSessions = [];

  Participant get localParticipant => voip.localParticipant;

  /// userId:deviceId
  List<Participant> participants = [];
  List<WrappedMediaStream> userMediaStreams = [];
  List<WrappedMediaStream> screenshareStreams = [];
  late String groupCallId;

  GroupCallError? lastError;

  // Map<String, ICallHandlers> callHandlers = {};

  Timer? activeSpeakerLoopTimeout;

  Timer? resendMemberStateEventTimer;
  Timer? memberLeaveEncKeyRotateDebounceTimer;

  final CachedStreamController<GroupCallSession> onGroupCallFeedsChanged =
      CachedStreamController();

  final CachedStreamController<String> onGroupCallState =
      CachedStreamController();

  final CachedStreamController<String> onGroupCallEvent =
      CachedStreamController();

  final CachedStreamController<WrappedMediaStream> onStreamAdd =
      CachedStreamController();

  final CachedStreamController<WrappedMediaStream> onStreamRemoved =
      CachedStreamController();

  bool get isLivekitCall => backend is LiveKitBackend;

  GroupCallSession({
    String? groupCallId,
    required this.client,
    required this.room,
    required this.voip,
    required this.backend,
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

  // Event? getMemberStateEvent(String userId) {
  //   final event = room.getCallMembershipsForUser(userId);
  //   if (event != null) {
  //     return room.callMemberStateIsExpired(event, groupCallId) ? null : event;
  //   }
  //   return null;
  // }

  void setState(String newState) {
    state = newState;
    onGroupCallState.add(newState);
    onGroupCallEvent.add(GroupCallEvent.GroupCallStateChanged);
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
    return participants.indexWhere(
            (member) => member.id == client.userID! + client.deviceID!) !=
        -1;
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
      return await voip.delegate.mediaDevices.getUserMedia(mediaConstraints);
    } catch (e) {
      setState(GroupCallState.LocalCallFeedUninitialized);
    }
    return Null as MediaStream;
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
  Future<WrappedMediaStream?> initLocalStream(
      {WrappedMediaStream? stream}) async {
    if (isLivekitCall) {
      Logs().i('Livekit group call: not starting local call feed.');
      return null;
    }
    if (state != GroupCallState.LocalCallFeedUninitialized) {
      throw Exception('Cannot initialize local call feed in the $state state.');
    }

    setState(GroupCallState.InitializingLocalCallFeed);

    WrappedMediaStream localWrappedMediaStream;

    if (stream == null) {
      MediaStream stream;

      try {
        stream = await _getUserMedia(CallType.kVideo);
      } catch (error) {
        setState(GroupCallState.LocalCallFeedUninitialized);
        rethrow;
      }

      localWrappedMediaStream = WrappedMediaStream(
        renderer: voip.delegate.createRenderer(),
        stream: stream,
        participant: localParticipant,
        room: room,
        client: client,
        purpose: SDPStreamMetadataPurpose.Usermedia,
        audioMuted: stream.getAudioTracks().isEmpty,
        videoMuted: stream.getVideoTracks().isEmpty,
        isWeb: voip.delegate.isWeb,
        isGroupCall: true,
      );
    } else {
      localWrappedMediaStream = stream;
    }

    localUserMediaStream = localWrappedMediaStream;
    await localUserMediaStream!.initialize();
    await addUserMediaStream(localWrappedMediaStream);

    setState(GroupCallState.LocalCallFeedInitialized);

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

  /// enter the group call.
  Future<void> enter({WrappedMediaStream? stream}) async {
    if (!(state == GroupCallState.LocalCallFeedUninitialized ||
        state == GroupCallState.LocalCallFeedInitialized)) {
      throw Exception('Cannot enter call in the $state state');
    }

    if (state == GroupCallState.LocalCallFeedUninitialized) {
      await initLocalStream(stream: stream);
    }
    await _addParticipant(localParticipant);

    await sendMemberStateEvent();

    activeSpeaker = null;

    setState(GroupCallState.Entered);

    Logs().v('Entered group call $groupCallId');

    _callSubscription = voip.onIncomingCall.stream.listen(onIncomingCall);

    for (final call in callSessions) {
      await onIncomingCall(call);
    }

    // Set up participants for the members currently in the call.
    // Other members will be picked up by the RoomState.members event.

    final memberStateEvents = await room.getAllFamedlyCallMemberStateEvents();

    for (final memberState in memberStateEvents) {
      await onMemberStateChanged(memberState);
    }

    if (isLivekitCall) {
      await makeNewSenderKey(false);
    } else {
      onActiveSpeakerLoop();
    }
    voip.currentGroupCID = groupCallId;

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

    await _removeParticipant(localParticipant);

    await removeMemberStateEvent();

    // removeCall removes it from `callSessions` later.
    final callsCopy = callSessions.toList();

    for (final call in callsCopy) {
      await removeCall(call, CallErrorCode.UserHangup);
    }

    activeSpeaker = null;
    activeSpeakerLoopTimeout?.cancel();
    await _callSubscription?.cancel();
  }

  Future<void> leave() async {
    await dispose();
    setState(GroupCallState.LocalCallFeedUninitialized);
    voip.currentGroupCID = null;
    participants.clear();
    voip.groupCalls.remove(groupCallId);
    await voip.delegate.handleGroupCallEnded(this);
    resendMemberStateEventTimer?.cancel();
    memberLeaveEncKeyRotateDebounceTimer?.cancel();
    setState(GroupCallState.Ended);
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

    onGroupCallEvent.add(GroupCallEvent.LocalMuteStateChanged);
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

    onGroupCallEvent.add(GroupCallEvent.LocalMuteStateChanged);
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
          renderer: voip.delegate.createRenderer(),
          stream: stream,
          participant: localParticipant,
          room: room,
          client: client,
          purpose: SDPStreamMetadataPurpose.Screenshare,
          audioMuted: stream.getAudioTracks().isEmpty,
          videoMuted: stream.getVideoTracks().isEmpty,
          isWeb: voip.delegate.isWeb,
          isGroupCall: true,
        );

        addScreenshareStream(localScreenshareStream!);
        await localScreenshareStream!.initialize();

        onGroupCallEvent.add(GroupCallEvent.LocalScreenshareStateChanged);
        for (final call in callSessions) {
          await call.addLocalStream(
              await localScreenshareStream!.stream!.clone(),
              localScreenshareStream!.purpose);
        }

        //await sendMemberStateEvent();

        return true;
      } catch (e, s) {
        Logs().e('[VOIP] Enabling screensharing error', e, s);
        lastError = GroupCallError(GroupCallErrorCode.NoUserMedia,
            'Failed to get screen-sharing stream: ', e);
        onGroupCallEvent.add(GroupCallEvent.Error);
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
      onGroupCallEvent.add(GroupCallEvent.LocalMuteStateChanged);
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

    if (isLivekitCall) {
      Logs()
          .i('Received incoming call whilst in signaling-only mode! Ignoring.');
      return;
    }

    final existingCall = getCallForParticipant(newCall.remoteParticipant!);

    if (existingCall != null && existingCall.callId == newCall.callId) {
      return;
    }

    Logs().v(
        'GroupCallSession: incoming call from: ${newCall.remoteParticipant!.id}');

    // Check if the user calling has an existing call and use this call instead.
    if (existingCall != null) {
      await replaceCall(existingCall, newCall);
    } else {
      await addCall(newCall);
    }

    await newCall.answerWithStreams(getLocalStreams());
  }

  Future<void> sendMemberStateEvent() async {
    await room.updateFamedlyCallMemberStateEvent(
      CallMembership(
        userId: client.userID!,
        roomId: room.id,
        callId: groupCallId,
        application: application,
        scope: scope,
        backend: backend,
        deviceId: client.deviceID!,
        expiresTs: DateTime.now()
            .add(CallTimeouts.expireTsBumpDuration)
            .millisecondsSinceEpoch,
      ),
    );

    if (resendMemberStateEventTimer != null) {
      resendMemberStateEventTimer!.cancel();
    }
    resendMemberStateEventTimer = Timer.periodic(
        CallTimeouts.updateExpireTsTimerDuration, ((timer) async {
      Logs().d('sendMemberStateEvent updating member event with timer');
      if (state != GroupCallState.Ended ||
          state != GroupCallState.LocalCallFeedUninitialized) {
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

  // Future<void> updateMemberCallState(
  //     [IGroupCallRoomMemberCallState? memberCallState]) async {
  //   final localUserId = client.userID;

  //   final currentStateEvent = getMemberStateEvent(localUserId!);
  //   var calls = <IGroupCallRoomMemberCallState>[];

  //   if (currentStateEvent != null) {
  //     final memberStateEvent =
  //         IGroupCallRoomMemberState.fromJson(currentStateEvent);
  //     final unCheckedCalls = memberStateEvent.calls;

  //     // don't keep pushing stale devices every update
  //     final validCalls = <IGroupCallRoomMemberCallState>[];
  //     for (final call in unCheckedCalls) {
  //       final validDevices = [];
  //       for (final device in call.devices) {
  //         if (device.expires_ts != null &&
  //             device.expires_ts! >
  //                 DateTime.now()
  //                     // safety buffer just incase we were slow to process a
  //                     // call event, if the device is actually dead it should
  //                     // get removed pretty soon
  //                     .add(Duration(seconds: 10))
  //                     .millisecondsSinceEpoch) {
  //           validDevices.add(device);
  //         }
  //       }
  //       if (validDevices.isNotEmpty) {
  //         validCalls.add(call);
  //       }
  //     }

  //     calls = validCalls;

  //     final existingCallIndex =
  //         calls.indexWhere((element) => groupCallId == element.call_id);

  //     if (existingCallIndex != -1) {
  //       if (memberCallState != null) {
  //         calls[existingCallIndex] = memberCallState;
  //       } else {
  //         calls.removeAt(existingCallIndex);
  //       }
  //     } else if (memberCallState != null) {
  //       calls.add(memberCallState);
  //     }
  //   } else if (memberCallState != null) {
  //     calls.add(memberCallState);
  //   }
  //   final content = {
  //     'm.calls': calls.map((e) => e.toJson()).toList(),
  //   };

  //   await client.setRoomStateWithKey(
  //       room.id, EventTypes.GroupCallMemberPrefix, localUserId, content);
  // }

  Future<void> onMemberStateChanged(MatrixEvent event) async {
    // The member events may be received for another room, which we will ignore.
    final mems = room.getCallMembershipsFromEvent(event);
    final memsForCurrentGroupCall = mems.where((element) {
      return element.callId == groupCallId &&
          element.roomId == room.id; // sanity checks
    }).toList();

    if (memsForCurrentGroupCall.isEmpty &&
        participants
            .where((element) => element.userId == event.senderId)
            .isNotEmpty) {
      // someone just made their mem list empty, remove them from participants list
      // only place where we manually update participants
      participants.removeWhere((element) => element.userId == event.senderId);
    }

    for (final mem in memsForCurrentGroupCall) {
      Logs().e(
          '[VOIP] onMemberStateChanged, handling mem ${mem.userId}:${mem.deviceId}');
      final rp = Participant(userId: mem.userId, deviceId: mem.deviceId);
      // TODO: check why a member refresh won't send a new invite
      if (mem.isExpired) {
        await _removeParticipant(rp);
        return;
      } else {
        await _addParticipant(rp);
      }

      // final callsState = IGroupCallRoomMemberState.fromJson(event);

      // if (callsState is List) {
      //   Logs()
      //       .w('Ignoring member state from ${user.id} member not in any calls.');
      //   await _removeParticipant(user.id);
      //   return;
      // }

      // Currently we only support a single call per room. So grab the first call.
      // IGroupCallRoomMemberCallState? callState;

      // if (callsState.calls.isNotEmpty) {
      //   final index = callsState.calls
      //       .indexWhere((element) => element.call_id == groupCallId);
      //   if (index != -1) {
      //     callState = callsState.calls[index];
      //   }
      // }

      // if (callState == null) {
      //   Logs().w(
      //       'Room member ${user.id} does not have a valid m.call_id set. Ignoring.');
      //   await _removeParticipant(user.id);
      //   return;
      // }

      // final callId = callState.call_id;
      // if (callId != null && callId != groupCallId) {
      //   Logs().w(
      //       'Call id $callId does not match group call id $groupCallId, ignoring.');
      //   await _removeParticipant(user.id);
      //   return;
      // }

      // await _addParticipant(user);

      if (isLivekitCall) {
        Logs().w(
            '[VOIP] onMemberStateChanged deteceted livekit call, skipping native webrtc stuff for member update');
        continue;
      }

      if (state != GroupCallState.Entered) {
        Logs().w(
            '[VOIP] onMemberStateChanged groupCall state is currently $state, skipping member update');
        continue;
      }

      if (mem.userId == client.userID! && mem.deviceId == client.deviceID!) {
        Logs().e(
            '[VOIP] onMemberStateChanged ${mem.userId}:${mem.deviceId} Not updating participants list, looks like our own user and device');
        continue;
      }

      // Only initiate a call with a participant who has a id that is lexicographically
      // less than your own. Otherwise, that user will call you.
      if (localParticipant.id.compareTo(rp.id) > 0) {
        Logs().e('[VOIP] Waiting for ${rp.id} to send call invite.');
        continue;
      }

      if (getCallForParticipant(rp) != null) {
        Logs().e(
            '[VOIP] onMemberStateChanged Not updating participants list, already have a ongoing call with ${rp.id}');
        continue;
      }

      // if (memForGroupId?.deviceId == null) {
      //   Logs().w('No opponent device found for ${user.id}, ignoring.');
      //   lastError = GroupCallError(
      //     '400',
      //     GroupCallErrorCode.UnknownDevice,
      //     'Outgoing Call: No opponent device found for ${user.id}, ignoring.',
      //   );
      //   onGroupCallEvent.add(GroupCallEvent.Error);
      //   return;
      // }

      final opts = CallOptions(
        callId: genCallID(),
        room: room,
        voip: voip,
        dir: CallDirection.kOutgoing,
        localPartyId: client.deviceID!,
        groupCallId: groupCallId,
        type: CallType.kVideo,
        iceServers: await voip.getIceSevers(),
      );
      final newCall = voip.createNewCall(opts);
      newCall.opponentDeviceId = mem.deviceId;
      newCall.remoteParticipant = rp;

      /// both invitee userId and deviceId are set here because there can be
      /// multiple devices from same user in a call, so we specifiy who the
      /// invite is for
      newCall.inviteeUserId = mem.userId;
      newCall.inviteeDeviceId = mem.deviceId;
      await newCall.placeCallWithStreams(getLocalStreams());

      await addCall(newCall);
    }
  }

  // Future<IGroupCallRoomMemberDevice?> getDeviceForMember(String userId) async {
  //   final memberStateEvent = getMemberStateEvent(userId);
  //   if (memberStateEvent == null) {
  //     return null;
  //   }

  //   final memberState = IGroupCallRoomMemberState.fromJson(memberStateEvent);

  //   final memberGroupCallState =
  //       memberState.calls.where(((call) => call.call_id == groupCallId));

  //   if (memberGroupCallState.isEmpty) {
  //     return null;
  //   }

  //   final memberDevices = memberGroupCallState.first.devices;

  //   if (memberDevices.isEmpty) {
  //     return null;
  //   }

  //   /// NOTE: For now we only support one device so we use the device id in
  //   /// the first source.
  //   return memberDevices[0];
  // }

  CallSession? getCallForParticipant(Participant participant) {
    return callSessions.singleWhereOrNull((call) =>
        call.groupCallId == groupCallId &&
        call.remoteParticipant == participant);
  }

  Future<void> addCall(CallSession call) async {
    callSessions.add(call);
    await initCall(call);
    onGroupCallEvent.add(GroupCallEvent.CallsChanged);
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

    await disposeCall(existingCall, CallErrorCode.Replaced);
    await initCall(replacementCall);

    onGroupCallEvent.add(GroupCallEvent.CallsChanged);
  }

  /// Removes a peer call from group calls.
  Future<void> removeCall(CallSession call, String hangupReason) async {
    await disposeCall(call, hangupReason);

    callSessions.removeWhere((element) => call.callId == element.callId);

    onGroupCallEvent.add(GroupCallEvent.CallsChanged);
  }

  /// init a peer call from group calls.
  Future<void> initCall(CallSession call) async {
    if (call.remoteParticipant == null) {
      throw Exception('Cannot init call without user id');
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

  Future<void> disposeCall(CallSession call, String hangupReason) async {
    if (call.remoteParticipant == null) {
      throw Exception('Cannot dispose call without user id');
    }

    // callHandlers.remove(opponentMemberId);

    if (call.hangupReason == CallErrorCode.Replaced) {
      return;
    }

    if (call.state != CallState.kEnded) {
      await call.hangup(hangupReason, false);
    }

    final usermediaStream =
        getUserMediaStreamByParticipantId(call.remoteParticipant!.id);

    if (usermediaStream != null) {
      await removeUserMediaStream(usermediaStream);
    }

    final screenshareStream =
        getScreenshareStreamByParticipantId(call.remoteParticipant!.id);

    if (screenshareStream != null) {
      await removeScreenshareStream(screenshareStream);
    }
  }

  Future<void> onStreamsChanged(CallSession call) async {
    if (call.remoteParticipant == null) {
      throw Exception('Cannot change call streams without user id');
    }

    final currentUserMediaStream =
        getUserMediaStreamByParticipantId(call.remoteParticipant!.id);
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
        getScreenshareStreamByParticipantId(call.remoteParticipant!.id);
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
    if (call.hangupReason == CallErrorCode.Replaced) {
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
    onGroupCallEvent.add(GroupCallEvent.UserMediaStreamsChanged);
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
    onGroupCallEvent.add(GroupCallEvent.UserMediaStreamsChanged);
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
      await stream.disposeRenderer();
      await stopMediaStream(stream.stream);
    }

    onGroupCallEvent.add(GroupCallEvent.UserMediaStreamsChanged);

    if (activeSpeaker == stream.participant && userMediaStreams.isNotEmpty) {
      activeSpeaker = userMediaStreams[0].participant;
      onGroupCallEvent.add(GroupCallEvent.ActiveSpeakerChanged);
    }
  }

  void onActiveSpeakerLoop() async {
    Participant? nextActiveSpeaker;
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
      if (ownAudioLevel != null &&
          audioLevelsMap[localParticipant] != ownAudioLevel) {
        audioLevelsMap[localParticipant] = ownAudioLevel;
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
      onGroupCallEvent.add(GroupCallEvent.ActiveSpeakerChanged);
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
    onGroupCallEvent.add(GroupCallEvent.ScreenshareStreamsChanged);
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
    onGroupCallEvent.add(GroupCallEvent.ScreenshareStreamsChanged);
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
      await stream.disposeRenderer();
      await stopMediaStream(stream.stream);
    }

    onGroupCallEvent.add(GroupCallEvent.ScreenshareStreamsChanged);
  }

  Future<void> _addParticipant(Participant participant) async {
    if (participants.contains(participant)) return;

    participants.add(participant);

    onGroupCallEvent.add(GroupCallEvent.ParticipantsChanged);

    // final callsCopylist = List<CallSession>.from(callSessions);

    // for (final call in callsCopylist) {
    //   await call.updateMuteStatus();
    // }
    Logs().d(
        '[VOIP] participant added, current list: ${participants.map((e) => e.id).toString()}');
    // yes reuse the same key because why not?
    await sendEncryptionKeysEvent(remoteParticipants: [participant]);
  }

  Future<void> _removeParticipant(Participant participant) async {
    if (!participants.contains(participant)) return;

    participants.remove(participant);

    onGroupCallEvent.add(GroupCallEvent.ParticipantsChanged);

    // final callsCopylist = List<CallSession>.from(callSessions);

    // for (final call in callsCopylist) {
    //   await call.updateMuteStatus();
    // }

    Logs().d(
        '[VOIP] participant removed, current list: ${participants.map((e) => e.id).toString()}');
    // debounce it because people leave at the same time

    if (memberLeaveEncKeyRotateDebounceTimer != null) {
      memberLeaveEncKeyRotateDebounceTimer!.cancel();
    }
    memberLeaveEncKeyRotateDebounceTimer =
        Timer(CallTimeouts.makeKeyDelay, () async {
      await makeNewSenderKey(true);
    });
  }

  /// participant:keyIndex:keyBin
  Map<Participant, Map<int, Uint8List>> encryptionKeysMap = {};

  List<Timer> setNewKeyTimeouts = [];

  Map<int, Uint8List>? getKeysForParticipant(Participant participant) {
    return encryptionKeysMap[participant];
  }

  int getNewEncryptionKeyIndex() {
    return (getKeysForParticipant(localParticipant)?.length ?? 0) % 16;
  }

  /// makes a new e2ee key for local user and sets it with a delay if specified
  Future<void> makeNewSenderKey(bool delayBeforeUsingKeyOurself) async {
    final encryptionKey = base64Encode(secureRandomBytes(16));
    final encryptionKeyIndex = getNewEncryptionKeyIndex();
    Logs().i('Generated new key at index $encryptionKeyIndex');

    await _setEncryptionKey(
      localParticipant,
      encryptionKeyIndex,
      encryptionKey,
      delayBeforeUsingKeyOurself: delayBeforeUsingKeyOurself,
    );

    // we are about to set new keys for ourselves, time to update the users about it
    await sendEncryptionKeysEvent();
  }

  /// sets incoming keys and also sends the key if it was for the local user
  Future<void> _setEncryptionKey(Participant participant,
      int encryptionKeyIndex, String encryptionKeyString,
      {bool delayBeforeUsingKeyOurself = false}) async {
    final keyBin = base64Decode(encryptionKeyString);

    final encryptionKeys = encryptionKeysMap[participant] ?? <int, Uint8List>{};

    if (encryptionKeys[encryptionKeyIndex] != null &&
        listEquals(encryptionKeys[encryptionKeyIndex]!, keyBin)) {
      Logs().i('Ignoring duplicate key');
      return;
    }

    encryptionKeys[encryptionKeyIndex] = keyBin;

    encryptionKeysMap[participant] = encryptionKeys;

    if (delayBeforeUsingKeyOurself) {
      // now wait for the key to propogate and then set it, hopefully users can
      // stil decrypt everything
      final useKeyTimeout = Timer(CallTimeouts.useKeyDelay, () async {
        Logs().i(
            'Delayed-emitting key changed event for ${participant.id} idx $encryptionKeyIndex key $encryptionKeyString');
        await voip.delegate.keyProvider?.onSetEncryptionKey(
            participant, encryptionKeyString, encryptionKeyIndex);
      });
      setNewKeyTimeouts.add(useKeyTimeout);
    } else {
      await voip.delegate.keyProvider?.onSetEncryptionKey(
          participant, encryptionKeyString, encryptionKeyIndex);
    }
  }

  /// sends the enc key to the devices using todevice, passing a list of
  /// remoteParticipants only sends events to them
  Future<void> sendEncryptionKeysEvent(
      {List<Participant>? remoteParticipants}) async {
    Logs().i('Sending encryption keys event');

    final myKeys = getKeysForParticipant(localParticipant);
    final sendKeysTo =
        remoteParticipants ?? participants.where((p) => p != localParticipant);
    if (myKeys == null) {
      Logs().w(
          '[VOIP] sendEncryptionKeysEvent Tried to send encryption keys event but no keys found!');
      return;
    }

    try {
      final List<EncryptionKeyEntry> keys = [];
      for (int i = 0; i < myKeys.length; i++) {
        if (myKeys[i] != null) {
          keys.add(EncryptionKeyEntry(i, base64Encode(myKeys[i]!)));
        }
      }
      final keyContent = EncryptionKeysEventContent(
        keys,
        groupCallId,
      );
      final txid = VoIP.customTxid ?? client.generateUniqueTransactionId();
      final mustEncrypt = room.encrypted && client.encryptionEnabled;

      for (final participant in remoteParticipants ?? sendKeysTo) {
        final Map<String, Object> data = {
          ...keyContent.toJson(),
          // used to find group call in groupCalls when ToDeviceEvent happens,
          // plays nicely with backwards compatibility for mesh calls
          'conf_id': groupCallId,
          'party_id': client.deviceID!,
        };
        if (mustEncrypt) {
          await client.userDeviceKeysLoading;
          if (client.userDeviceKeys[participant.userId]
                  ?.deviceKeys[participant.deviceId] !=
              null) {
            await client.sendToDeviceEncrypted([
              client.userDeviceKeys[participant.userId]!
                  .deviceKeys[participant.deviceId]!
            ], VoIPEventTypes.EncryptionKeysEvent, data);
          } else {
            Logs().w(
                '[VOIP] sendEncryptionKeysEvent missing device keys for ${participant.id}');
          }
        } else {
          await client.sendToDevice(
            VoIPEventTypes.EncryptionKeysEvent,
            txid,
            {
              participant.userId: {participant.deviceId: data}
            },
          );
        }
        Logs().i(
            'E2EE: updateEncryptionKeyEvent participantId=${participant.id} numSent=${myKeys.length} data=$data');
      }
    } catch (e, s) {
      Logs().e('Failed to send e2ee keys, retrying', e, s);
      await sendEncryptionKeysEvent(remoteParticipants: remoteParticipants);
    }
  }

  Future<void> onCallEncryption(String roomId, Participant remoteParticipant,
      Map<String, dynamic> content) async {
    final keyContent = EncryptionKeysEventContent.fromJson(content);

    final callId = keyContent.callId;

    if (keyContent.keys.isEmpty) {
      Logs().w(
          'Received m.call.encryption_keys where keys is empty: callId=$callId');
      return;
    }

    for (final key in keyContent.keys) {
      final encryptionKey = key.key;
      final encryptionKeyIndex = key.index;
      Logs().i(
          'E2EE: onCallEncryption, got key from ${remoteParticipant.id} encryptionKeyIndex=$encryptionKeyIndex key=$encryptionKey');
      await _setEncryptionKey(
          remoteParticipant, encryptionKeyIndex, encryptionKey);
    }
  }
}
