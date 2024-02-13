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
import 'dart:core';

import 'package:collection/collection.dart';
import 'package:webrtc_interface/webrtc_interface.dart';

import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';

/// TODO(@duan): Need to add voice activity detection mechanism
/// const int SPEAKING_THRESHOLD = -60; // dB

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

class GroupCallError extends Error {
  final String code;
  final String msg;
  final dynamic err;
  GroupCallError(this.code, this.msg, this.err);

  @override
  String toString() {
    return 'Group Call Error: [$code] $msg, err: ${err.toString()}';
  }
}

abstract class ISendEventResponse {
  String? event_id;
}

class IGroupCallRoomMemberFeed {
  String? purpose;
  // TODO: Sources for adaptive bitrate
  IGroupCallRoomMemberFeed.fromJson(Map<String, dynamic> json) {
    purpose = json['purpose'];
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['purpose'] = purpose;
    return data;
  }
}

class IGroupCallRoomMemberDevice {
  String? device_id;
  String? session_id;
  int? expires_ts;

  List<IGroupCallRoomMemberFeed> feeds = [];
  IGroupCallRoomMemberDevice.fromJson(Map<String, dynamic> json) {
    device_id = json['device_id'];
    session_id = json['session_id'];
    expires_ts = json['expires_ts'];

    if (json['feeds'] != null) {
      feeds = (json['feeds'] as List<dynamic>)
          .map((feed) => IGroupCallRoomMemberFeed.fromJson(feed))
          .toList();
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['device_id'] = device_id;
    data['session_id'] = session_id;
    data['expires_ts'] = expires_ts;
    data['feeds'] = feeds.map((feed) => feed.toJson()).toList();
    return data;
  }
}

class IGroupCallRoomMemberCallState {
  String? call_id;
  List<String>? foci;
  List<IGroupCallRoomMemberDevice> devices = [];
  IGroupCallRoomMemberCallState.fromJson(Map<String, dynamic> json) {
    call_id = json['m.call_id'];
    if (json['m.foci'] != null) {
      foci = (json['m.foci'] as List<dynamic>).cast<String>();
    }
    if (json['m.devices'] != null) {
      devices = (json['m.devices'] as List<dynamic>)
          .map((device) => IGroupCallRoomMemberDevice.fromJson(device))
          .toList();
    }
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['m.call_id'] = call_id;
    if (foci != null) {
      data['m.foci'] = foci;
    }
    if (devices.isNotEmpty) {
      data['m.devices'] = devices.map((e) => e.toJson()).toList();
    }
    return data;
  }
}

class IGroupCallRoomMemberState {
  List<IGroupCallRoomMemberCallState> calls = [];
  IGroupCallRoomMemberState.fromJson(MatrixEvent event) {
    if (event.content['m.calls'] != null) {
      for (final call in (event.content['m.calls'] as List<dynamic>)) {
        calls.add(IGroupCallRoomMemberCallState.fromJson(call));
      }
    }
  }
}

class GroupCallState {
  static String LocalCallFeedUninitialized = 'local_call_feed_uninitialized';
  static String InitializingLocalCallFeed = 'initializing_local_call_feed';
  static String LocalCallFeedInitialized = 'local_call_feed_initialized';
  static String Entering = 'entering';
  static String Entered = 'entered';
  static String Ended = 'ended';
}

abstract class ICallHandlers {
  Function(List<WrappedMediaStream> feeds)? onCallFeedsChanged;
  Function(CallState state, CallState oldState)? onCallStateChanged;
  Function(CallSession call)? onCallHangup;
  Function(CallSession newCall)? onCallReplaced;
}

class GroupCall {
  // Config

  static const updateExpireTsTimerDuration = Duration(seconds: 15);
  static const expireTsBumpDuration = Duration(seconds: 45);
  static const activeSpeakerInterval = Duration(seconds: 5);

  final Client client;
  final VoIP voip;
  final Room room;
  final String intent;
  final String type;
  String state = GroupCallState.LocalCallFeedUninitialized;
  StreamSubscription<CallSession>? _callSubscription;
  final Map<String, double> audioLevelsMap = {};
  String? activeSpeaker; // userId
  WrappedMediaStream? localUserMediaStream;
  WrappedMediaStream? localScreenshareStream;
  String? localDesktopCapturerSourceId;
  List<CallSession> callSessions = [];
  List<User> participants = [];
  List<WrappedMediaStream> userMediaStreams = [];
  List<WrappedMediaStream> screenshareStreams = [];
  late String groupCallId;

  GroupCallError? lastError;

  Map<String, ICallHandlers> callHandlers = {};

  Timer? activeSpeakerLoopTimeout;

  Timer? resendMemberStateEventTimer;

  final CachedStreamController<GroupCall> onGroupCallFeedsChanged =
      CachedStreamController();

  final CachedStreamController<String> onGroupCallState =
      CachedStreamController();

  final CachedStreamController<String> onGroupCallEvent =
      CachedStreamController();

  final CachedStreamController<WrappedMediaStream> onStreamAdd =
      CachedStreamController();

  final CachedStreamController<WrappedMediaStream> onStreamRemoved =
      CachedStreamController();

  GroupCall({
    String? groupCallId,
    required this.client,
    required this.voip,
    required this.room,
    required this.type,
    required this.intent,
  }) {
    this.groupCallId = groupCallId ?? genCallID();
  }

  Future<GroupCall> create() async {
    voip.groupCalls[groupCallId] = this;
    voip.groupCalls[room.id] = this;

    await client.setRoomStateWithKey(
      room.id,
      EventTypes.GroupCallPrefix,
      groupCallId,
      {
        'm.intent': intent,
        'm.type': type,
      },
    );

    return this;
  }

  bool get terminated =>
      room
          .getState(EventTypes.GroupCallPrefix, groupCallId)
          ?.content
          .containsKey('m.terminated') ??
      false;

  String get avatarName =>
      getUser().calcDisplayname(mxidLocalPartFallback: false);

  String? get displayName => getUser().displayName;

  User getUser() {
    return room.unsafeGetUserFromMemoryOrFallback(client.userID!);
  }

  Event? getMemberStateEvent(String userId) {
    final event = room.getState(EventTypes.GroupCallMemberPrefix, userId);
    if (event != null) {
      return room.callMemberStateForIdIsExpired(event, groupCallId)
          ? null
          : event;
    }
    return null;
  }

  Future<List<MatrixEvent>> getAllMemberStateEvents() async {
    final List<MatrixEvent> events = [];
    final roomStates = await client.getRoomState(room.id);
    roomStates.sort((a, b) => a.originServerTs.compareTo(b.originServerTs));
    for (final value in roomStates) {
      if (value.type == EventTypes.GroupCallMemberPrefix &&
          !room.callMemberStateForIdIsExpired(value, groupCallId)) {
        events.add(value);
      }
    }
    return events;
  }

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
    final userId = client.userID;
    return participants.indexWhere((member) => member.id == userId) != -1;
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
  Future<WrappedMediaStream> initLocalStream(
      {WrappedMediaStream? stream}) async {
    if (state != GroupCallState.LocalCallFeedUninitialized) {
      throw Exception('Cannot initialize local call feed in the $state state.');
    }

    setState(GroupCallState.InitializingLocalCallFeed);

    WrappedMediaStream localWrappedMediaStream;

    if (stream == null) {
      MediaStream stream;

      try {
        stream = await _getUserMedia(
            type == GroupCallType.Video ? CallType.kVideo : CallType.kVoice);
      } catch (error) {
        setState(GroupCallState.LocalCallFeedUninitialized);
        rethrow;
      }

      final userId = client.userID;
      localWrappedMediaStream = WrappedMediaStream(
        renderer: voip.delegate.createRenderer(),
        stream: stream,
        userId: userId!,
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

  Future<void> updateAudioDevice() async {
    final stream =
        await voip.delegate.mediaDevices.getUserMedia({'audio': true});
    final audioTrack = stream.getAudioTracks().first;
    for (final call in callSessions) {
      await call.updateAudioDevice(audioTrack);
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
    await _addParticipant(
        (await room.requestUser(client.userID!, ignoreErrors: true))!);

    await sendMemberStateEvent();

    activeSpeaker = null;

    setState(GroupCallState.Entered);

    Logs().v('Entered group call $groupCallId');

    _callSubscription = voip.onIncomingCall.stream.listen(onIncomingCall);

    for (final call in callSessions) {
      await onIncomingCall(call);
    }

    // Set up participants for the members currently in the room.
    // Other members will be picked up by the RoomState.members event.

    final memberStateEvents = await getAllMemberStateEvents();

    for (final memberState in memberStateEvents) {
      await onMemberStateChanged(memberState);
    }

    onActiveSpeakerLoop();

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

    await _removeParticipant(client.userID!);

    await removeMemberStateEvent();

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
    await voip.delegate.handleGroupCallEnded(this);
    final justLeftGroupCall = voip.groupCalls.tryGet<GroupCall>(room.id);
    // terminate group call if empty
    if (justLeftGroupCall != null &&
        justLeftGroupCall.intent != 'm.room' &&
        justLeftGroupCall.participants.isEmpty &&
        room.canCreateGroupCall) {
      await terminate();
    } else {
      Logs().d(
          '[VOIP] left group call but cannot terminate. participants: ${participants.length}, pl: ${room.canCreateGroupCall}');
    }
  }

  /// terminate group call.
  Future<void> terminate({bool emitStateEvent = true}) async {
    final existingStateEvent =
        room.getState(EventTypes.GroupCallPrefix, groupCallId);
    await dispose();
    participants = [];
    voip.groupCalls.remove(room.id);
    voip.groupCalls.remove(groupCallId);
    if (emitStateEvent) {
      await client.setRoomStateWithKey(
          room.id, EventTypes.GroupCallPrefix, groupCallId, {
        ...existingStateEvent!.content,
        'm.terminated': GroupCallTerminationReason.CallEnded,
      });
      Logs().d('[VOIP] Group call $groupCallId was killed');
    }
    await voip.delegate.handleGroupCallEnded(this);
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
    if (!await hasAudioDevice()) {
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
    if (!await hasVideoDevice()) {
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
          userId: client.userID!,
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

        await sendMemberStateEvent();

        return true;
      } catch (e, s) {
        Logs().e('Enabling screensharing error', e, s);
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
      await sendMemberStateEvent();
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

    final opponentMemberId = newCall.remoteUser!.id;
    final existingCall = getCallByUserId(opponentMemberId);

    if (existingCall != null && existingCall.callId == newCall.callId) {
      return;
    }

    Logs().v('GroupCall: incoming call from: $opponentMemberId');

    // Check if the user calling has an existing call and use this call instead.
    if (existingCall != null) {
      await replaceCall(existingCall, newCall);
    } else {
      await addCall(newCall);
    }

    await newCall.answerWithStreams(getLocalStreams());
  }

  Future<void> sendMemberStateEvent() async {
    final deviceId = client.deviceID;
    await updateMemberCallState(
      IGroupCallRoomMemberCallState.fromJson(
        {
          'm.call_id': groupCallId,
          'm.devices': [
            {
              'device_id': deviceId,
              'session_id': client.groupCallSessionId,
              'expires_ts': DateTime.now()
                  .add(expireTsBumpDuration)
                  .millisecondsSinceEpoch,
              'feeds': getLocalStreams()
                  .map((feed) => ({
                        'purpose': feed.purpose,
                      }))
                  .toList(),
              // TODO: Add data channels
            },
          ],
          // TODO 'm.foci'
        },
      ),
    );

    if (resendMemberStateEventTimer != null) {
      resendMemberStateEventTimer!.cancel();
    }
    resendMemberStateEventTimer =
        Timer.periodic(updateExpireTsTimerDuration, ((timer) async {
      Logs().d('updating member event with timer');
      return await sendMemberStateEvent();
    }));
  }

  Future<void> removeMemberStateEvent() {
    if (resendMemberStateEventTimer != null) {
      Logs().d('resend member event timer cancelled');
      resendMemberStateEventTimer!.cancel();
      resendMemberStateEventTimer = null;
    }
    return updateMemberCallState();
  }

  Future<void> updateMemberCallState(
      [IGroupCallRoomMemberCallState? memberCallState]) async {
    final localUserId = client.userID;

    final currentStateEvent = getMemberStateEvent(localUserId!);
    var calls = <IGroupCallRoomMemberCallState>[];

    if (currentStateEvent != null) {
      final memberStateEvent =
          IGroupCallRoomMemberState.fromJson(currentStateEvent);
      final unCheckedCalls = memberStateEvent.calls;

      // don't keep pushing stale devices every update
      final validCalls = <IGroupCallRoomMemberCallState>[];
      for (final call in unCheckedCalls) {
        final validDevices = [];
        for (final device in call.devices) {
          if (device.expires_ts != null &&
              device.expires_ts! >
                  DateTime.now()
                      // safety buffer just incase we were slow to process a
                      // call event, if the device is actually dead it should
                      // get removed pretty soon
                      .add(Duration(seconds: 10))
                      .millisecondsSinceEpoch) {
            validDevices.add(device);
          }
        }
        if (validDevices.isNotEmpty) {
          validCalls.add(call);
        }
      }

      calls = validCalls;

      final existingCallIndex =
          calls.indexWhere((element) => groupCallId == element.call_id);

      if (existingCallIndex != -1) {
        if (memberCallState != null) {
          calls[existingCallIndex] = memberCallState;
        } else {
          calls.removeAt(existingCallIndex);
        }
      } else if (memberCallState != null) {
        calls.add(memberCallState);
      }
    } else if (memberCallState != null) {
      calls.add(memberCallState);
    }
    final content = {
      'm.calls': calls.map((e) => e.toJson()).toList(),
    };

    await client.setRoomStateWithKey(
        room.id, EventTypes.GroupCallMemberPrefix, localUserId, content);
  }

  Future<void> onMemberStateChanged(MatrixEvent event) async {
    // The member events may be received for another room, which we will ignore.
    if (event.roomId != room.id) {
      return;
    }

    final user = await room.requestUser(event.stateKey!);

    if (user == null) {
      return;
    }

    final callsState = IGroupCallRoomMemberState.fromJson(event);

    if (callsState is List) {
      Logs()
          .w('Ignoring member state from ${user.id} member not in any calls.');
      await _removeParticipant(user.id);
      return;
    }

    // Currently we only support a single call per room. So grab the first call.
    IGroupCallRoomMemberCallState? callState;

    if (callsState.calls.isNotEmpty) {
      final index = callsState.calls
          .indexWhere((element) => element.call_id == groupCallId);
      if (index != -1) {
        callState = callsState.calls[index];
      }
    }

    if (callState == null) {
      Logs().w(
          'Room member ${user.id} does not have a valid m.call_id set. Ignoring.');
      await _removeParticipant(user.id);
      return;
    }

    final callId = callState.call_id;
    if (callId != null && callId != groupCallId) {
      Logs().w(
          'Call id $callId does not match group call id $groupCallId, ignoring.');
      await _removeParticipant(user.id);
      return;
    }

    await _addParticipant(user);

    // Don't process your own member.
    final localUserId = client.userID;

    if (user.id == localUserId) {
      return;
    }

    if (state != GroupCallState.Entered) {
      return;
    }

    // Only initiate a call with a user who has a userId that is lexicographically
    // less than your own. Otherwise, that user will call you.
    if (localUserId!.compareTo(user.id) > 0) {
      Logs().i('Waiting for ${user.id} to send call invite.');
      return;
    }

    final existingCall = getCallByUserId(user.id);

    if (existingCall != null) {
      return;
    }

    final opponentDevice = await getDeviceForMember(user.id);

    if (opponentDevice == null) {
      Logs().w('No opponent device found for ${user.id}, ignoring.');
      lastError = GroupCallError(
        '400',
        GroupCallErrorCode.UnknownDevice,
        'Outgoing Call: No opponent device found for ${user.id}, ignoring.',
      );
      onGroupCallEvent.add(GroupCallEvent.Error);
      return;
    }

    final opts = CallOptions()
      ..callId = genCallID()
      ..room = room
      ..voip = voip
      ..dir = CallDirection.kOutgoing
      ..localPartyId = client.deviceID!
      ..groupCallId = groupCallId
      ..type = CallType.kVideo
      ..iceServers = await voip.getIceSevers();

    final newCall = voip.createNewCall(opts);
    newCall.opponentDeviceId = opponentDevice.device_id;
    newCall.opponentSessionId = opponentDevice.session_id;
    newCall.remoteUser = await room.requestUser(user.id, ignoreErrors: true);
    newCall.invitee = user.id;

    final requestScreenshareFeed = opponentDevice.feeds.indexWhere(
            (IGroupCallRoomMemberFeed feed) =>
                feed.purpose == SDPStreamMetadataPurpose.Screenshare) !=
        -1;

    await newCall.placeCallWithStreams(
        getLocalStreams(), requestScreenshareFeed);

    await addCall(newCall);
  }

  Future<IGroupCallRoomMemberDevice?> getDeviceForMember(String userId) async {
    final memberStateEvent = getMemberStateEvent(userId);
    if (memberStateEvent == null) {
      return null;
    }

    final memberState = IGroupCallRoomMemberState.fromJson(memberStateEvent);

    final memberGroupCallState =
        memberState.calls.where(((call) => call.call_id == groupCallId));

    if (memberGroupCallState.isEmpty) {
      return null;
    }

    final memberDevices = memberGroupCallState.first.devices;

    if (memberDevices.isEmpty) {
      return null;
    }

    /// NOTE: For now we only support one device so we use the device id in
    /// the first source.
    return memberDevices[0];
  }

  CallSession? getCallByUserId(String userId) {
    final value = callSessions.where((item) => item.remoteUser!.id == userId);
    if (value.isNotEmpty) {
      return value.first;
    }
    return null;
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
    final opponentMemberId = call.opponentDeviceId;

    if (opponentMemberId == null) {
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
    final opponentMemberId = call.opponentDeviceId;

    if (opponentMemberId == null) {
      throw Exception('Cannot dispose call without user id');
    }

    callHandlers.remove(opponentMemberId);

    if (call.hangupReason == CallErrorCode.Replaced) {
      return;
    }

    if (call.state != CallState.kEnded) {
      await call.hangup(hangupReason, false);
    }

    final usermediaStream = getUserMediaStreamByUserId(opponentMemberId);

    if (usermediaStream != null) {
      await removeUserMediaStream(usermediaStream);
    }

    final screenshareStream = getScreenshareStreamByUserId(opponentMemberId);

    if (screenshareStream != null) {
      await removeScreenshareStream(screenshareStream);
    }
  }

  String? getCallUserId(CallSession call) {
    return call.remoteUser?.id ?? call.invitee;
  }

  Future<void> onStreamsChanged(CallSession call) async {
    final opponentMemberId = getCallUserId(call);

    if (opponentMemberId == null) {
      throw Exception('Cannot change call streams without user id');
    }

    final currentUserMediaStream = getUserMediaStreamByUserId(opponentMemberId);
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
        getScreenshareStreamByUserId(opponentMemberId);
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

  WrappedMediaStream? getUserMediaStreamByUserId(String userId) {
    final stream = userMediaStreams.where((stream) => stream.userId == userId);
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
    final streamIndex = userMediaStreams
        .indexWhere((stream) => stream.userId == existingStream.userId);

    if (streamIndex == -1) {
      throw Exception('Couldn\'t find user media stream to replace');
    }

    userMediaStreams.replaceRange(streamIndex, 1, [replacementStream]);

    await existingStream.dispose();
    //replacementStream.measureVolumeActivity(true);
    onGroupCallEvent.add(GroupCallEvent.UserMediaStreamsChanged);
  }

  Future<void> removeUserMediaStream(WrappedMediaStream stream) async {
    final streamIndex =
        userMediaStreams.indexWhere((stream) => stream.userId == stream.userId);

    if (streamIndex == -1) {
      throw Exception('Couldn\'t find user media stream to remove');
    }

    userMediaStreams.removeWhere((element) => element.userId == stream.userId);
    audioLevelsMap.remove(stream.userId);
    onStreamRemoved.add(stream);

    if (stream.isLocal()) {
      await stream.disposeRenderer();
      await stopMediaStream(stream.stream);
    }

    onGroupCallEvent.add(GroupCallEvent.UserMediaStreamsChanged);

    if (activeSpeaker == stream.userId && userMediaStreams.isNotEmpty) {
      activeSpeaker = userMediaStreams[0].userId;
      onGroupCallEvent.add(GroupCallEvent.ActiveSpeakerChanged);
    }
  }

  void onActiveSpeakerLoop() async {
    String? nextActiveSpeaker;
    // idc about screen sharing atm.
    final userMediaStreamsCopyList = List.from(userMediaStreams);
    for (final stream in userMediaStreamsCopyList) {
      if (stream.userId == client.userID && stream.pc == null) {
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
        audioLevelsMap[stream.userId] = otherPartyAudioLevel;
      }

      // https://www.w3.org/TR/webrtc-stats/#dom-rtcstatstype-media-source
      // firefox does not seem to have this though. Works on chrome and android
      final ownAudioLevel = statsReport
          .singleWhereOrNull((element) =>
              element.type == 'media-source' &&
              element.values['kind'] == 'audio')
          ?.values['audioLevel'];
      if (ownAudioLevel != null &&
          audioLevelsMap[client.userID] != ownAudioLevel) {
        audioLevelsMap[client.userID!] = ownAudioLevel;
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

  WrappedMediaStream? getScreenshareStreamByUserId(String userId) {
    final stream =
        screenshareStreams.where((stream) => stream.userId == userId);
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
    final streamIndex = screenshareStreams
        .indexWhere((stream) => stream.userId == existingStream.userId);

    if (streamIndex == -1) {
      throw Exception('Couldn\'t find screenshare stream to replace');
    }

    screenshareStreams.replaceRange(streamIndex, 1, [replacementStream]);

    await existingStream.dispose();
    onGroupCallEvent.add(GroupCallEvent.ScreenshareStreamsChanged);
  }

  Future<void> removeScreenshareStream(WrappedMediaStream stream) async {
    final streamIndex = screenshareStreams
        .indexWhere((stream) => stream.userId == stream.userId);

    if (streamIndex == -1) {
      throw Exception('Couldn\'t find screenshare stream to remove');
    }

    screenshareStreams
        .removeWhere((element) => element.userId == stream.userId);

    onStreamRemoved.add(stream);

    if (stream.isLocal()) {
      await stream.disposeRenderer();
      await stopMediaStream(stream.stream);
    }

    onGroupCallEvent.add(GroupCallEvent.ScreenshareStreamsChanged);
  }

  Future<void> _addParticipant(User user) async {
    if (participants.indexWhere((m) => m.id == user.id) != -1) {
      return;
    }

    participants.add(user);

    onGroupCallEvent.add(GroupCallEvent.ParticipantsChanged);

    final callsCopylist = List.from(callSessions);

    for (final call in callsCopylist) {
      await call.updateMuteStatus();
    }
  }

  Future<void> _removeParticipant(String userid) async {
    final index = participants.indexWhere((m) => m.id == userid);

    if (index == -1) {
      return;
    }

    participants.removeAt(index);

    onGroupCallEvent.add(GroupCallEvent.ParticipantsChanged);

    final callsCopylist = List.from(callSessions);

    for (final call in callsCopylist) {
      await call.updateMuteStatus();
    }
  }
}
