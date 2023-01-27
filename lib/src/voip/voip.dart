import 'dart:async';
import 'dart:core';

import 'package:sdp_transform/sdp_transform.dart' as sdp_transform;
import 'package:webrtc_interface/webrtc_interface.dart';

import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';

/// Delegate WebRTC basic functionality.
abstract class WebRTCDelegate {
  MediaDevices get mediaDevices;
  Future<RTCPeerConnection> createPeerConnection(
      Map<String, dynamic> configuration,
      [Map<String, dynamic> constraints = const {}]);
  VideoRenderer createRenderer();
  void playRingtone();
  void stopRingtone();
  void handleNewCall(CallSession session);
  void handleCallEnded(CallSession session);
  void handleMissedCall(CallSession session);
  void handleNewGroupCall(GroupCall groupCall);
  void handleGroupCallEnded(GroupCall groupCall);
  bool get isWeb;

  /// This should be set to false if any calls in the client are in kConnected
  /// state. If another room tries to call you during a connected call this fires
  /// a handleMissedCall
  bool get canHandleNewCall => true;
}

class VoIP {
  TurnServerCredentials? _turnServerCredentials;
  Map<String, CallSession> calls = <String, CallSession>{};
  Map<String, GroupCall> groupCalls = <String, GroupCall>{};
  final CachedStreamController<CallSession> onIncomingCall =
      CachedStreamController();
  String? currentCID;
  String? currentGroupCID;
  String? get localPartyId => client.deviceID;
  final Client client;
  final WebRTCDelegate delegate;
  final StreamController<GroupCall> onIncomingGroupCall = StreamController();
  void _handleEvent(
          Event event,
          Function(String roomId, String senderId, Map<String, dynamic> content)
              func) =>
      func(event.roomId!, event.senderId, event.content);
  Map<String, String> incomingCallRoomId = {};

  VoIP(this.client, this.delegate) : super() {
    client.onCallInvite.stream
        .listen((event) => _handleEvent(event, onCallInvite));
    client.onCallAnswer.stream
        .listen((event) => _handleEvent(event, onCallAnswer));
    client.onCallCandidates.stream
        .listen((event) => _handleEvent(event, onCallCandidates));
    client.onCallHangup.stream
        .listen((event) => _handleEvent(event, onCallHangup));
    client.onCallReject.stream
        .listen((event) => _handleEvent(event, onCallReject));
    client.onCallNegotiate.stream
        .listen((event) => _handleEvent(event, onCallNegotiate));
    client.onCallReplaces.stream
        .listen((event) => _handleEvent(event, onCallReplaces));
    client.onCallSelectAnswer.stream
        .listen((event) => _handleEvent(event, onCallSelectAnswer));
    client.onSDPStreamMetadataChangedReceived.stream.listen(
        (event) => _handleEvent(event, onSDPStreamMetadataChangedReceived));
    client.onAssertedIdentityReceived.stream
        .listen((event) => _handleEvent(event, onAssertedIdentityReceived));

    client.onRoomState.stream.listen((event) {
      if ([
        EventTypes.GroupCallPrefix,
        EventTypes.GroupCallMemberPrefix,
      ].contains(event.type)) {
        Logs().v('[VOIP] onRoomState: type ${event.toJson()}.');
        onRoomStateChanged(event);
      }
    });

    client.onToDeviceEvent.stream.listen((event) {
      Logs().v('[VOIP] onToDeviceEvent: type ${event.toJson()}.');

      if (event.type == 'org.matrix.call_duplicate_session') {
        Logs().v('[VOIP] onToDeviceEvent: duplicate session.');
        return;
      }

      final confId = event.content['conf_id'];
      final groupCall = groupCalls[confId];
      if (groupCall == null) {
        Logs().d('[VOIP] onToDeviceEvent: groupCall is null.');
        return;
      }
      final roomId = groupCall.room.id;
      final senderId = event.senderId;
      final content = event.content;
      switch (event.type) {
        case EventTypes.CallInvite:
          onCallInvite(roomId, senderId, content);
          break;
        case EventTypes.CallAnswer:
          onCallAnswer(roomId, senderId, content);
          break;
        case EventTypes.CallCandidates:
          onCallCandidates(roomId, senderId, content);
          break;
        case EventTypes.CallHangup:
          onCallHangup(roomId, senderId, content);
          break;
        case EventTypes.CallReject:
          onCallReject(roomId, senderId, content);
          break;
        case EventTypes.CallNegotiate:
          onCallNegotiate(roomId, senderId, content);
          break;
        case EventTypes.CallReplaces:
          onCallReplaces(roomId, senderId, content);
          break;
        case EventTypes.CallSelectAnswer:
          onCallSelectAnswer(roomId, senderId, content);
          break;
        case EventTypes.CallSDPStreamMetadataChanged:
        case EventTypes.CallSDPStreamMetadataChangedPrefix:
          onSDPStreamMetadataChangedReceived(roomId, senderId, content);
          break;
        case EventTypes.CallAssertedIdentity:
          onAssertedIdentityReceived(roomId, senderId, content);
          break;
      }
    });

    delegate.mediaDevices.ondevicechange = _onDeviceChange;
  }

  Future<void> _onDeviceChange(dynamic _) async {
    Logs().v('[VOIP] _onDeviceChange');
    for (final call in calls.values) {
      if (call.state == CallState.kConnected && !call.isGroupCall) {
        await call.updateAudioDevice();
      }
    }
    for (final groupCall in groupCalls.values) {
      if (groupCall.state == GroupCallState.Entered) {
        await groupCall.updateAudioDevice();
      }
    }
  }

  Future<void> onCallInvite(
      String roomId, String senderId, Map<String, dynamic> content) async {
    if (senderId == client.userID) {
      // Ignore messages to yourself.
      return;
    }

    Logs().v(
        '[VOIP] onCallInvite $senderId => ${client.userID}, \ncontent => ${content.toString()}');

    final String callId = content['call_id'];
    final String partyId = content['party_id'];
    final int lifetime = content['lifetime'];
    final String? confId = content['conf_id'];
    final String? deviceId = content['device_id'];
    final call = calls[callId];

    Logs().d(
        '[glare] got new call ${content.tryGet('call_id')} and currently room id is mapped to ${incomingCallRoomId.tryGet(roomId)}');

    if (call != null && call.state == CallState.kEnded) {
      // Session already exist.
      Logs().v('[VOIP] onCallInvite: Session [$callId] already exist.');
      return;
    }

    if (content['invitee'] != null && content['invitee'] != client.userID) {
      return; // This invite was meant for another user in the room
    }

    if (content['capabilities'] != null) {
      final capabilities = CallCapabilities.fromJson(content['capabilities']);
      Logs().v(
          '[VOIP] CallCapabilities: dtmf => ${capabilities.dtmf}, transferee => ${capabilities.transferee}');
    }

    var callType = CallType.kVoice;
    SDPStreamMetadata? sdpStreamMetadata;
    if (content[sdpStreamMetadataKey] != null) {
      sdpStreamMetadata =
          SDPStreamMetadata.fromJson(content[sdpStreamMetadataKey]);
      sdpStreamMetadata.sdpStreamMetadatas
          .forEach((streamId, SDPStreamPurpose purpose) {
        Logs().v(
            '[VOIP] [$streamId] => purpose: ${purpose.purpose}, audioMuted: ${purpose.audio_muted}, videoMuted:  ${purpose.video_muted}');

        if (!purpose.video_muted) {
          callType = CallType.kVideo;
        }
      });
    } else {
      callType = getCallType(content['offer']['sdp']);
    }

    final room = client.getRoomById(roomId);

    final opts = CallOptions()
      ..voip = this
      ..callId = callId
      ..groupCallId = confId
      ..dir = CallDirection.kIncoming
      ..type = callType
      ..room = room!
      ..localPartyId = localPartyId!
      ..iceServers = await getIceSevers();

    final newCall = createNewCall(opts);
    newCall.remotePartyId = partyId;
    newCall.remoteUser = await room.requestUser(senderId);
    newCall.opponentDeviceId = deviceId;
    newCall.opponentSessionId = content['sender_session_id'];
    if (!delegate.canHandleNewCall &&
        (confId == null || confId != currentGroupCID)) {
      Logs().v(
          '[VOIP] onCallInvite: Unable to handle new calls, maybe user is busy.');
      await newCall.reject(reason: CallErrorCode.UserBusy, shouldEmit: false);
      delegate.handleMissedCall(newCall);
      return;
    }

    final offer = RTCSessionDescription(
      content['offer']['sdp'],
      content['offer']['type'],
    );

    /// play ringtone. We decided to play the ringtone before adding the call to
    /// the incoming call stream because getUserMedia from initWithInvite fails
    /// on firefox unless the tab is in focus. We should atleast be able to notify
    /// the user about an incoming call
    ///
    /// Autoplay on firefox still needs interaction, without which all notifications
    /// could be blocked.
    if (confId == null) {
      delegate.playRingtone();
    }

    await newCall.initWithInvite(
        callType, offer, sdpStreamMetadata, lifetime, confId != null);

    currentCID = callId;

    // Popup CallingPage for incoming call.
    if (confId == null && !newCall.callHasEnded) {
      delegate.handleNewCall(newCall);
    }

    onIncomingCall.add(newCall);
  }

  Future<void> onCallAnswer(
      String roomId, String senderId, Map<String, dynamic> content) async {
    Logs().v('[VOIP] onCallAnswer => ${content.toString()}');
    final String callId = content['call_id'];
    final String partyId = content['party_id'];

    final call = calls[callId];
    if (call != null) {
      if (senderId == client.userID) {
        // Ignore messages to yourself.
        if (!call.answeredByUs) {
          delegate.stopRingtone();
        }
        if (call.state == CallState.kRinging) {
          call.onAnsweredElsewhere();
        }
        return;
      }
      if (call.room.id != roomId) {
        Logs().w(
            'Ignoring call answer for room $roomId claiming to be for call in room ${call.room.id}');
        return;
      }
      call.remotePartyId = partyId;
      call.remoteUser = await call.room.requestUser(senderId);

      final answer = RTCSessionDescription(
          content['answer']['sdp'], content['answer']['type']);

      SDPStreamMetadata? metadata;
      if (content[sdpStreamMetadataKey] != null) {
        metadata = SDPStreamMetadata.fromJson(content[sdpStreamMetadataKey]);
      }
      await call.onAnswerReceived(answer, metadata);
    } else {
      Logs().v('[VOIP] onCallAnswer: Session [$callId] not found!');
    }
  }

  Future<void> onCallCandidates(
      String roomId, String senderId, Map<String, dynamic> content) async {
    if (senderId == client.userID) {
      // Ignore messages to yourself.
      return;
    }
    Logs().v('[VOIP] onCallCandidates => ${content.toString()}');
    final String callId = content['call_id'];
    final call = calls[callId];
    if (call != null) {
      if (call.room.id != roomId) {
        Logs().w(
            'Ignoring call candidates for room $roomId claiming to be for call in room ${call.room.id}');
        return;
      }
      await call.onCandidatesReceived(content['candidates']);
    } else {
      Logs().v('[VOIP] onCallCandidates: Session [$callId] not found!');
    }
  }

  Future<void> onCallHangup(String roomId, String _ /*senderId unused*/,
      Map<String, dynamic> content) async {
    // stop play ringtone, if this is an incoming call
    delegate.stopRingtone();
    Logs().v('[VOIP] onCallHangup => ${content.toString()}');
    final String callId = content['call_id'];
    final call = calls[callId];
    if (call != null) {
      if (call.room.id != roomId) {
        Logs().w(
            'Ignoring call hangup for room $roomId claiming to be for call in room ${call.room.id}');
        return;
      }
      // hangup in any case, either if the other party hung up or we did on another device
      await call.terminate(CallParty.kRemote,
          content['reason'] ?? CallErrorCode.UserHangup, true);
    } else {
      Logs().v('[VOIP] onCallHangup: Session [$callId] not found!');
    }
    if (callId == currentCID) {
      currentCID = null;
    }
  }

  Future<void> onCallReject(
      String roomId, String senderId, Map<String, dynamic> content) async {
    if (senderId == client.userID) {
      // Ignore messages to yourself.
      return;
    }
    final String callId = content['call_id'];
    Logs().d('Reject received for call ID $callId');

    final call = calls[callId];
    if (call != null) {
      if (call.room.id != roomId) {
        Logs().w(
            'Ignoring call reject for room $roomId claiming to be for call in room ${call.room.id}');
        return;
      }
      await call.onRejectReceived(content['reason']);
    } else {
      Logs().v('[VOIP] onCallHangup: Session [$callId] not found!');
    }
  }

  Future<void> onCallReplaces(
      String roomId, String senderId, Map<String, dynamic> content) async {
    if (senderId == client.userID) {
      // Ignore messages to yourself.
      return;
    }
    final String callId = content['call_id'];
    Logs().d('onCallReplaces received for call ID $callId');
    final call = calls[callId];
    if (call != null) {
      if (call.room.id != roomId) {
        Logs().w(
            'Ignoring call replace for room $roomId claiming to be for call in room ${call.room.id}');
        return;
      }
      //TODO: handle replaces
    }
  }

  Future<void> onCallSelectAnswer(
      String roomId, String senderId, Map<String, dynamic> content) async {
    if (senderId == client.userID) {
      // Ignore messages to yourself.
      return;
    }
    final String callId = content['call_id'];
    Logs().d('SelectAnswer received for call ID $callId');
    final call = calls[callId];
    final String selectedPartyId = content['selected_party_id'];

    if (call != null) {
      if (call.room.id != roomId) {
        Logs().w(
            'Ignoring call select answer for room $roomId claiming to be for call in room ${call.room.id}');
        return;
      }
      call.onSelectAnswerReceived(selectedPartyId);
    }
  }

  Future<void> onSDPStreamMetadataChangedReceived(
      String roomId, String senderId, Map<String, dynamic> content) async {
    if (senderId == client.userID) {
      // Ignore messages to yourself.
      return;
    }
    final String callId = content['call_id'];
    Logs().d('SDP Stream metadata received for call ID $callId');
    final call = calls[callId];
    if (call != null) {
      if (call.room.id != roomId) {
        Logs().w(
            'Ignoring call sdp metadata change for room $roomId claiming to be for call in room ${call.room.id}');
        return;
      }

      if (content[sdpStreamMetadataKey] == null) {
        Logs().d('SDP Stream metadata is null');
        return;
      }
      await call.onSDPStreamMetadataReceived(
          SDPStreamMetadata.fromJson(content[sdpStreamMetadataKey]));
    }
  }

  Future<void> onAssertedIdentityReceived(
      String roomId, String senderId, Map<String, dynamic> content) async {
    if (senderId == client.userID) {
      // Ignore messages to yourself.
      return;
    }
    final String callId = content['call_id'];
    Logs().d('Asserted identity received for call ID $callId');
    final call = calls[callId];
    if (call != null) {
      if (call.room.id != roomId) {
        Logs().w(
            'Ignoring call asserted identity for room $roomId claiming to be for call in room ${call.room.id}');
        return;
      }

      if (content['asserted_identity'] == null) {
        Logs().d('asserted_identity is null ');
        return;
      }
      call.onAssertedIdentityReceived(
          AssertedIdentity.fromJson(content['asserted_identity']));
    }
  }

  Future<void> onCallNegotiate(
      String roomId, String senderId, Map<String, dynamic> content) async {
    if (senderId == client.userID) {
      // Ignore messages to yourself.
      return;
    }
    final String callId = content['call_id'];
    Logs().d('Negotiate received for call ID $callId');
    final call = calls[callId];
    if (call != null) {
      if (call.room.id != roomId) {
        Logs().w(
            'Ignoring call negotiation for room $roomId claiming to be for call in room ${call.room.id}');
        return;
      }

      final description = content['description'];
      try {
        SDPStreamMetadata? metadata;
        if (content[sdpStreamMetadataKey] != null) {
          metadata = SDPStreamMetadata.fromJson(content[sdpStreamMetadataKey]);
        }
        await call.onNegotiateReceived(metadata,
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
        'urls': _turnServerCredentials!.uris
      }
    ];
  }

  /// Make a P2P call to room
  ///
  /// [roomId] The room id to call
  ///
  /// [type] The type of call to be made.
  Future<CallSession> inviteToCall(String roomId, CallType type) async {
    final room = client.getRoomById(roomId);
    if (room == null) {
      Logs().v('[VOIP] Invalid room id [$roomId].');
      return Null as CallSession;
    }
    final callId = 'cid${DateTime.now().millisecondsSinceEpoch}';
    if (currentGroupCID == null) {
      incomingCallRoomId[roomId] = callId;
    }
    final opts = CallOptions()
      ..callId = callId
      ..type = type
      ..dir = CallDirection.kOutgoing
      ..room = room
      ..voip = this
      ..localPartyId = localPartyId!
      ..iceServers = await getIceSevers();

    final newCall = createNewCall(opts);
    currentCID = callId;
    await newCall.initOutboundCall(type).then((_) {
      delegate.handleNewCall(newCall);
    });
    currentCID = callId;
    return newCall;
  }

  CallSession createNewCall(CallOptions opts) {
    final call = CallSession(opts);
    calls[opts.callId] = call;
    return call;
  }

  /// Create a new group call in an existing room.
  ///
  /// [roomId] The room id to call
  ///
  /// [type] The type of call to be made.
  ///
  /// [intent] The intent of the call.
  ///
  /// [dataChannelsEnabled] Whether data channels are enabled.
  ///
  /// [dataChannelOptions] The data channel options.
  Future<GroupCall?> newGroupCall(String roomId, String type, String intent,
      [bool? dataChannelsEnabled,
      RTCDataChannelInit? dataChannelOptions]) async {
    if (getGroupCallForRoom(roomId) != null) {
      Logs().e('[VOIP] [$roomId] already has an existing group call.');
      return null;
    }
    final room = client.getRoomById(roomId);
    if (room == null) {
      Logs().v('[VOIP] Invalid room id [$roomId].');
      return null;
    }
    final groupId = genCallID();
    final groupCall = GroupCall(
      groupCallId: groupId,
      client: client,
      voip: this,
      room: room,
      type: type,
      intent: intent,
      dataChannelsEnabled: dataChannelsEnabled ?? false,
      dataChannelOptions: dataChannelOptions ?? RTCDataChannelInit(),
    ).create();
    groupCalls[groupId] = groupCall;
    groupCalls[roomId] = groupCall;
    return groupCall;
  }

  Future<GroupCall?> fetchOrCreateGroupCall(String roomId) async {
    final groupCall = getGroupCallForRoom(roomId);
    final room = client.getRoomById(roomId);
    if (room == null) {
      Logs().w('Not found room id = $roomId');
      return null;
    }

    if (groupCall != null) {
      if (!room.canJoinGroupCall) {
        Logs().w('No permission to join group calls in room $roomId');
        return null;
      }
      return groupCall;
    }

    if (!room.groupCallsEnabled) {
      await room.enableGroupCalls();
    }

    if (room.canCreateGroupCall) {
      // The call doesn't exist, but we can create it

      final groupCall = await newGroupCall(
          roomId, GroupCallType.Video, GroupCallIntent.Prompt);
      if (groupCall != null) {
        await groupCall.sendMemberStateEvent();
      }
      return groupCall;
    }

    final completer = Completer<GroupCall?>();
    Timer? timer;
    final subscription = onIncomingGroupCall.stream.listen((GroupCall call) {
      if (call.room.id == roomId) {
        timer?.cancel();
        completer.complete(call);
      }
    });

    timer = Timer(Duration(seconds: 30), () {
      subscription.cancel();
      completer.completeError('timeout');
    });

    return completer.future;
  }

  GroupCall? getGroupCallForRoom(String roomId) {
    return groupCalls[roomId];
  }

  GroupCall? getGroupCallById(String groupCallId) {
    return groupCalls[groupCallId];
  }

  Future<void> startGroupCalls() async {
    final rooms = client.rooms;
    rooms.forEach((element) {
      createGroupCallForRoom(element);
    });
  }

  void stopGroupCalls() {
    groupCalls.forEach((_, groupCall) {
      groupCall.terminate();
    });
    groupCalls.clear();
  }

  /// Create a new group call in an existing room.
  Future<void> createGroupCallForRoom(Room room) async {
    final events = await client.getRoomState(room.id);
    events.sort((a, b) => a.originServerTs.compareTo(b.originServerTs));
    events.forEach((element) async {
      if (element.type == EventTypes.GroupCallPrefix) {
        if (element.content['m.terminated'] != null) {
          return;
        }
        await createGroupCallFromRoomStateEvent(element);
      }
    });
    return;
  }

  /// Create a new group call from a room state event.
  Future<GroupCall?> createGroupCallFromRoomStateEvent(
      MatrixEvent event) async {
    final roomId = event.roomId;
    final content = event.content;

    final room = client.getRoomById(roomId!);

    if (room == null) {
      Logs().w('Couldn\'t find room $roomId for GroupCall');
      return null;
    }

    final groupCallId = event.stateKey;

    final callType = content['m.type'];

    if (callType != GroupCallType.Video && callType != GroupCallType.Voice) {
      Logs().w('Received invalid group call type $callType for room $roomId.');
      return null;
    }

    final callIntent = content['m.intent'];

    if (callIntent != GroupCallIntent.Prompt &&
        callIntent != GroupCallIntent.Room &&
        callIntent != GroupCallIntent.Ring) {
      Logs()
          .w('Received invalid group call intent $callType for room $roomId.');
      return null;
    }

    final dataChannelOptionsMap = content['m.data_channel_options'];

    var dataChannelsEnabled = false;
    final dataChannelOptions = RTCDataChannelInit();

    if (dataChannelOptionsMap != null) {
      dataChannelsEnabled =
          dataChannelOptionsMap['dataChannelsEnabled'] as bool;
      dataChannelOptions.ordered = dataChannelOptionsMap['ordered'] as bool;
      dataChannelOptions.maxRetransmits =
          dataChannelOptionsMap['maxRetransmits'] as int;
      dataChannelOptions.maxRetransmits =
          dataChannelOptionsMap['maxRetransmits'] as int;
      dataChannelOptions.protocol = dataChannelOptionsMap['protocol'] as String;
    }

    final groupCall = GroupCall(
        client: client,
        voip: this,
        room: room,
        groupCallId: groupCallId,
        type: callType,
        intent: callIntent,
        dataChannelsEnabled: dataChannelsEnabled,
        dataChannelOptions: dataChannelOptions);

    groupCalls[groupCallId!] = groupCall;
    groupCalls[room.id] = groupCall;
    onIncomingGroupCall.add(groupCall);
    delegate.handleNewGroupCall(groupCall);
    return groupCall;
  }

  void onRoomStateChanged(MatrixEvent event) {
    final eventType = event.type;
    final roomId = event.roomId;
    if (eventType == EventTypes.GroupCallPrefix) {
      final groupCallId = event.content['groupCallId'];
      final content = event.content;
      final currentGroupCall = groupCalls[groupCallId];
      if (currentGroupCall == null && content['m.terminated'] == null) {
        createGroupCallFromRoomStateEvent(event);
      } else if (currentGroupCall != null &&
          currentGroupCall.groupCallId == groupCallId) {
        if (content['m.terminated'] != null) {
          currentGroupCall.terminate(emitStateEvent: false);
        } else if (content['m.type'] != currentGroupCall.type) {
          // TODO: Handle the callType changing when the room state changes
          Logs().w(
              'The group call type changed for room: $roomId. Changing the group call type is currently unsupported.');
        }
      } else if (currentGroupCall != null &&
          currentGroupCall.groupCallId != groupCallId) {
        // TODO: Handle new group calls and multiple group calls
        Logs().w(
            'Multiple group calls detected for room: $roomId. Multiple group calls are currently unsupported.');
      }
    } else if (eventType == EventTypes.GroupCallMemberPrefix) {
      final groupCall = groupCalls[roomId];
      if (groupCall == null) {
        return;
      }
      groupCall.onMemberStateChanged(event);
    }
  }

  bool hasActiveCall(Room room) {
    final groupCallStates =
        room.states.tryGetMap<dynamic, Event>(EventTypes.GroupCallPrefix);
    if (groupCallStates != null) {
      groupCallStates.values
          .toList()
          .sort((a, b) => a.originServerTs.compareTo(b.originServerTs));
      final latestGroupCallEvent = groupCallStates.values.last;
      if (!latestGroupCallEvent.content.containsKey('m.terminated')) {
        return true;
      }
    }
    return false;
  }

  Future sendGroupCallTerminateEvent(Room room, String groupCallId) async {
    try {
      Logs().d('[VOIP] running sendterminator');
      final existingStateEvent =
          room.getState(EventTypes.GroupCallPrefix, groupCallId);
      if (existingStateEvent == null) {
        Logs().e('could not find group call with id $groupCallId');
        return;
      }
      await client.setRoomStateWithKey(
          room.id, EventTypes.GroupCallPrefix, groupCallId, {
        ...existingStateEvent.content,
        'm.terminated': GroupCallTerminationReason.CallEnded,
      });
      Logs().d('[VOIP] Group call $groupCallId was killed uwu');
    } catch (e) {
      Logs().i('killing stale call $groupCallId failed. reason: $e');
    }
  }

  Map<String, Timer> staleGroupCallsTimer = {};

  /// stops the stale call checker timer
  void stopStaleCallsChecker(String roomId) {
    if (staleGroupCallsTimer.tryGet(roomId) != null) {
      staleGroupCallsTimer[roomId]!.cancel();
    } else {
      Logs().w('[VOIP] no stale call checker for room found');
    }
  }

  static const staleCallCheckerDuration = Duration(seconds: 30);

  /// checks for stale calls in a room and sends `m.terminated` if all the
  /// expires_ts are expired. Call when opening a room
  void startStaleCallsChecker(String roomId) async {
    staleGroupCallsTimer[roomId] = Timer.periodic(
      staleCallCheckerDuration,
      (timer) {
        final room = client.getRoomById(roomId);
        if (room == null) {
          Logs().w('[VOIP] stale call checker got incorrect room id');
        } else {
          Logs().d('checking for stale group calls.');
          final copyGroupCallIds =
              room.states.tryGetMap<dynamic, Event>(EventTypes.GroupCallPrefix);
          if (copyGroupCallIds == null) return;
          copyGroupCallIds.forEach(
            (groupCallId, groupCallEvent) async {
              if (groupCallEvent.content.tryGet('m.intent') == 'm.room') return;
              if (!groupCallEvent.content.containsKey('m.terminated')) {
                if (groupCallId != null) {
                  Logs().i(
                      'found non terminated group call with id $groupCallId');
                  // call is not empty but check for stale participants (gone offline)
                  // with expire_ts
                  final Map<String, int> participants = {};
                  final callMemberEvents = room.states.tryGetMap<String, Event>(
                      EventTypes.GroupCallMemberPrefix);
                  Logs().e(
                      'callmemeberEvents length ${callMemberEvents?.length}');
                  if (callMemberEvents != null) {
                    callMemberEvents.forEach((userId, memberEvent) async {
                      final callMemberEvent = groupCallEvent.room.getState(
                        EventTypes.GroupCallMemberPrefix,
                        userId,
                      );
                      if (callMemberEvent != null) {
                        final event =
                            IGroupCallRoomMemberState.fromJson(callMemberEvent);
                        participants[userId] = event.expireTs;
                      }
                    });
                  }

                  Logs().e(participants.toString());
                  if (!participants.values.any((expire_ts) =>
                      expire_ts > DateTime.now().millisecondsSinceEpoch)) {
                    Logs().i(
                        'Group call with expired timestamps detected, terminating');
                    await sendGroupCallTerminateEvent(room, groupCallId);
                  }
                }
              }
            },
          );
        }
      },
    );
  }
}
