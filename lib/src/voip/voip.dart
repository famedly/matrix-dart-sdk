import 'dart:async';
import 'dart:core';

import 'package:sdp_transform/sdp_transform.dart' as sdp_transform;
import 'package:webrtc_interface/webrtc_interface.dart';

import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:matrix/src/voip/models/call_membership.dart';
import 'package:matrix/src/voip/models/call_options.dart';
import 'package:matrix/src/voip/models/voip_id.dart';
import 'package:matrix/src/voip/utils/stream_helper.dart';

/// The parent highlevel voip class, this trnslates matrix events to webrtc methods via
/// `CallSession` or `GroupCallSession` methods
class VoIP {
  // used only for internal tests, all txids for call events will be overwritten to this
  static String? customTxid;

  /// cached turn creds
  TurnServerCredentials? _turnServerCredentials;

  Map<VoipId, CallSession> calls = {};
  Map<VoipId, GroupCallSession> groupCalls = {};

  final CachedStreamController<CallSession> onIncomingCall =
      CachedStreamController();

  VoipId? currentCID;
  VoipId? currentGroupCID;

  String? get localPartyId => client.deviceID;
  final Client client;
  final WebRTCDelegate delegate;
  final StreamController<GroupCallSession> onIncomingGroupCall =
      StreamController();

  Participant? get localParticipant => client.isLogged()
      ? Participant(userId: client.userID!, deviceId: client.deviceID!)
      : null;

  /// map of roomIds to the invites they are currently processing or in a call with
  /// used for handling glare in p2p calls
  Map<String, String> incomingCallRoomId = {};

  VoIP(this.client, this.delegate) : super() {
    // to populate groupCalls with already present calls
    for (final room in client.rooms) {
      final memsList = room.getCallMembershipsFromRoom();
      for (final mems in memsList.values) {
        for (final mem in mems) {
          if (!mem.isExpired) {
            unawaited(createGroupCallFromRoomStateEvent(mem));
          }
        }
      }
    }

    /// handles events todevice and matrix events for invite, candidates, hangup, etc.
    client.onCallEvents.stream.listen((events) async {
      await _handleCallEvents(events);
    });

    // handles the com.famedly.call events.
    client.onRoomState.stream.listen(
      (event) async {
        if ([
          VoIPEventTypes.FamedlyCallMemberEvent,
        ].contains(event.type)) {
          Logs().v('[VOIP] onRoomState: type ${event.toJson()}');
          for (final map in groupCalls.entries) {
            if (map.key.roomId == event.room.id) {
              // because we don't know which call got updated, just update all
              // group calls for that room
              await map.value.onMemberStateChanged();
            }
          }
        }
      },
    );

    delegate.mediaDevices.ondevicechange = _onDeviceChange;
  }

  Future<void> _handleCallEvents(List<BasicEventWithSender> callEvents) async {
    // Call invites should be omitted for a call that is already answered,
    // has ended, is rejectd or replaced.
    final callEventsCopy = List<BasicEventWithSender>.from(callEvents);
    for (final callEvent in callEventsCopy) {
      final callId = callEvent.content.tryGet<String>('call_id');

      if (CallConstants.callEndedEventTypes.contains(callEvent.type)) {
        callEvents.removeWhere((event) {
          if (CallConstants.ommitWhenCallEndedTypes.contains(event.type) &&
              event.content.tryGet<String>('call_id') == callId) {
            Logs().v(
                'Ommit "${event.type}" event for an already terminated call');
            return true;
          }

          return false;
        });
      }

      // checks for ended events and removes invites for that call id.
      if (callEvent is Event) {
        // removes expired invites
        final age = callEvent.unsigned?.tryGet<int>('age') ??
            (DateTime.now().millisecondsSinceEpoch -
                callEvent.originServerTs.millisecondsSinceEpoch);

        callEvents.removeWhere((element) {
          if (callEvent.type == EventTypes.CallInvite &&
              age >
                  (callEvent.content.tryGet<int>('lifetime') ??
                      CallTimeouts.callInviteLifetime.inMilliseconds)) {
            Logs().e(
                '[VOIP] Ommiting invite event ${callEvent.eventId} as age was older than lifetime');
            return true;
          }
          return false;
        });
      }
    }

    // and finally call the respective methods on the clean callEvents list
    for (final callEvent in callEvents) {
      await _callStreamByCallEvent(callEvent);
    }
  }

  Future<void> _callStreamByCallEvent(BasicEventWithSender event) async {
    // member event updates handled in onRoomState for ease
    if (event.type == VoIPEventTypes.FamedlyCallMemberEvent) return;
    Logs().v(
        '[VOIP] Handling event of type: ${event.type}, content ${event.content} from sender ${event.senderId}');

    GroupCallSession? groupCallSession;
    Room? room;

    if (event is Event) {
      room = event.room;
    } else if (event is ToDeviceEvent) {
      final roomId = event.content.tryGet<String>('room_id');
      final confId = event.content.tryGet<String>('conf_id');

      if (roomId != null && confId != null) {
        room = client.getRoomById(roomId);
        groupCallSession = groupCalls[VoipId(roomId: roomId, callId: confId)];
      } else {
        Logs().e(
            '[VOIP] to_device event of type ${event.type} but did not find group call for id: $confId');
        return;
      }
    } else {
      Logs().e(
          '[VOIP] _callStreamByCallEvent can only handle Event or ToDeviceEvent, it got ${event.runtimeType}');
      return;
    }

    if (room == null) {
      Logs().e(
          '[VOIP] _callStreamByCallEvent call event does not contain a room_id, ignoring');
      return;
    }

    if (event.type.startsWith(VoIPEventTypes.EncryptionKeysEvent) &&
        groupCallSession == null) {
      Logs().e(
          '[VOIP] _callStreamByCallEvent ${event.type} recieved but no groupCall found, ignoring');
      return;
    }

    final senderId = event.senderId;
    final deviceId = event.content['party_id'] ?? // 1:1 calls do this
        event.content['sender_session_id']; // group calls do this

    final content = event.content;

    /// Calls HACK:
    /// Because we want to allow calls between devices and the current spec only
    /// does calls between userIds, we use partyId as a deviceId here. It is very
    /// important that you partyId is set to the sender device id for this to work
    /// As of Jan 2024 both dart sdk and element do this so it's probably fine.
    final remoteParticipant =
        Participant(userId: senderId, deviceId: deviceId.toString());

    if (remoteParticipant == localParticipant) {
      return;
    }

    Logs().d('[VOIP] received ${event.type} from rp: ${remoteParticipant.id}');

    switch (event.type) {
      case EventTypes.CallInvite:
        await onCallInvite(room, remoteParticipant, content);
        break;
      case EventTypes.CallAnswer:
        await onCallAnswer(room, remoteParticipant, content);
        break;
      case EventTypes.CallCandidates:
        await onCallCandidates(room, remoteParticipant, content);
        break;
      case EventTypes.CallHangup:
        await onCallHangup(room, remoteParticipant, content);
        break;
      case EventTypes.CallReject:
        await onCallReject(room, remoteParticipant, content);
        break;
      case EventTypes.CallNegotiate:
        await onCallNegotiate(room, remoteParticipant, content);
        break;
      case EventTypes.CallReplaces:
        await onCallReplaces(room, remoteParticipant, content);
        break;
      case EventTypes.CallSelectAnswer:
        await onCallSelectAnswer(room, remoteParticipant, content);
        break;
      case EventTypes.CallSDPStreamMetadataChanged:
      case EventTypes.CallSDPStreamMetadataChangedPrefix:
        await onSDPStreamMetadataChangedReceived(
            room, remoteParticipant, content);
        break;
      case EventTypes.CallAssertedIdentity:
        await onAssertedIdentityReceived(room, remoteParticipant, content);
        break;
      case VoIPEventTypes.EncryptionKeysEvent:
        await groupCallSession!
            .onCallEncryption(room, remoteParticipant, content);
        break;
      case VoIPEventTypes.RequestEncryptionKeysEvent:
        await groupCallSession!
            .onCallEncryptionKeyRequest(room, remoteParticipant, content);
        break;
    }
  }

  Future<void> _onDeviceChange(dynamic _) async {
    Logs().v('[VOIP] _onDeviceChange');
    for (final call in calls.values) {
      if (call.state == CallState.kConnected && !call.isGroupCall) {
        await call.updateMediaDeviceForCall();
      }
    }
    for (final groupCall in groupCalls.values) {
      if (groupCall.state == GroupCallState.Entered) {
        await groupCall.updateMediaDeviceForCalls();
      }
    }
  }

  Future<void> onCallInvite(Room room, Participant remoteParticipant,
      Map<String, dynamic> content) async {
    Logs().v(
        '[VOIP] onCallInvite ${remoteParticipant.userId} => ${client.userID}, \ncontent => ${content.toString()}');

    final String callId = content['call_id'];
    final int lifetime = content['lifetime'];
    final String? confId = content['conf_id'];

    final call = calls[VoipId(roomId: room.id, callId: callId)];

    Logs().d(
        '[glare] got new call ${content.tryGet('call_id')} and currently room id is mapped to ${incomingCallRoomId.tryGet(room.id)}');

    if (call != null && call.state == CallState.kEnded) {
      // Session already exist.
      Logs().v('[VOIP] onCallInvite: Session [$callId] already exist.');
      return;
    }

    if (content['invitee_user_id'] != null &&
        content['invitee_user_id'] != localParticipant?.userId) {
      Logs().w('[VOIP] Ignoring call, meant for ${content['invitee_user_id']}');
      return; // This invite was meant for another user in the room
    }

    if (content['invitee_device_id'] != null &&
        content['invitee_device_id'] != localParticipant?.deviceId) {
      Logs()
          .w('[VOIP] Ignoring call, meant for ${content['invitee_device_id']}');
      return; // This invite was meant for another device in the room
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

    final opts = CallOptions(
      voip: this,
      callId: callId,
      groupCallId: confId,
      dir: CallDirection.kIncoming,
      type: callType,
      room: room,
      localPartyId: localPartyId!,
      iceServers: await getIceSevers(),
    );

    final newCall = createNewCall(opts);

    /// both invitee userId and deviceId are set here because there can be
    /// multiple devices from same user in a call, so we specifiy who the
    /// invite is for
    newCall.remoteUserId = remoteParticipant.userId;
    newCall.remoteUserDeviceId = remoteParticipant.deviceId;

    if (!delegate.canHandleNewCall &&
        (confId == null ||
            currentGroupCID != VoipId(roomId: room.id, callId: confId))) {
      Logs().v(
          '[VOIP] onCallInvite: Unable to handle new calls, maybe user is busy.');
      await newCall.reject(reason: CallErrorCode.UserBusy, shouldEmit: false);
      await delegate.handleMissedCall(newCall);
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
      await delegate.playRingtone();
    }

    // When getUserMedia throws an exception, we handle it by terminating the call,
    // and all this happens inside initWithInvite. If we set currentCID after
    // initWithInvite, we might set it to callId even after it was reset to null
    // by terminate.
    currentCID = VoipId(roomId: room.id, callId: callId);

    await newCall.initWithInvite(
        callType, offer, sdpStreamMetadata, lifetime, confId != null);

    // Popup CallingPage for incoming call.
    if (confId == null && !newCall.callHasEnded) {
      await delegate.handleNewCall(newCall);
    }

    if (confId != null) {
      // the stream is used to monitor incoming peer calls in a mesh call
      onIncomingCall.add(newCall);
    }
  }

  Future<void> onCallAnswer(Room room, Participant remoteParticipant,
      Map<String, dynamic> content) async {
    Logs().v('[VOIP] onCallAnswer => ${content.toString()}');
    final String callId = content['call_id'];

    final call = calls[VoipId(roomId: room.id, callId: callId)];
    if (call != null) {
      if (!call.answeredByUs) {
        await delegate.stopRingtone();
      }
      if (call.state == CallState.kRinging) {
        await call.onAnsweredElsewhere();
      }

      if (call.room.id != room.id) {
        Logs().w(
            'Ignoring call answer for room ${room.id} claiming to be for call in room ${call.room.id}');
        return;
      }

      call.remoteUserId = remoteParticipant.userId;
      call.remoteUserDeviceId = remoteParticipant.deviceId;

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

  Future<void> onCallCandidates(Room room, Participant remoteParticipant,
      Map<String, dynamic> content) async {
    Logs().v('[VOIP] onCallCandidates => ${content.toString()}');
    final String callId = content['call_id'];

    final call = calls[VoipId(roomId: room.id, callId: callId)];
    if (call != null) {
      if (call.room.id != room.id) {
        Logs().w(
            'Ignoring call candidates for room ${room.id} claiming to be for call in room ${call.room.id}');
        return;
      }
      await call.onCandidatesReceived(content['candidates']);
    } else {
      Logs().v('[VOIP] onCallCandidates: Session [$callId] not found!');
    }
  }

  Future<void> onCallHangup(Room room, Participant remoteParticipant,
      Map<String, dynamic> content) async {
    // stop play ringtone, if this is an incoming call
    await delegate.stopRingtone();
    Logs().v('[VOIP] onCallHangup => ${content.toString()}');
    final String callId = content['call_id'];
    final String partyId = content['party_id'];

    final call = calls[VoipId(roomId: room.id, callId: callId)];
    if (call != null) {
      if (call.room.id != room.id) {
        Logs().w(
            'Ignoring call hangup for room ${room.id} claiming to be for call in room ${call.room.id}');
        return;
      }
      if (call.remoteUserDeviceId != null &&
          call.remoteUserDeviceId != partyId) {
        Logs().w(
            'Ignoring call hangup from sender with a different party_id $partyId for call in room ${call.room.id}');
        return;
      }
      // hangup in any case, either if the other party hung up or we did on another device
      await call.terminate(CallParty.kRemote,
          content['reason'] ?? CallErrorCode.UserHangup, true);
    } else {
      Logs().v('[VOIP] onCallHangup: Session [$callId] not found!');
    }
    if (callId == currentCID?.callId) {
      currentCID = null;
    }
  }

  Future<void> onCallReject(Room room, Participant remoteParticipant,
      Map<String, dynamic> content) async {
    final String callId = content['call_id'];
    final String partyId = content['party_id'];
    Logs().d('Reject received for call ID $callId');

    final call = calls[VoipId(roomId: room.id, callId: callId)];
    if (call != null) {
      if (call.room.id != room.id) {
        Logs().w(
            'Ignoring call reject for room ${room.id} claiming to be for call in room ${call.room.id}');
        return;
      }
      if (call.remoteUserDeviceId != null &&
          call.remoteUserDeviceId != partyId) {
        Logs().w(
            'Ignoring call reject from sender with a different party_id $partyId for call in room ${call.room.id}');
        return;
      }
      await call.onRejectReceived(content['reason']);
    } else {
      Logs().v('[VOIP] onCallReject: Session [$callId] not found!');
    }
  }

  Future<void> onCallReplaces(Room room, Participant remoteParticipant,
      Map<String, dynamic> content) async {
    final String callId = content['call_id'];
    Logs().d('onCallReplaces received for call ID $callId');

    final call = calls[VoipId(roomId: room.id, callId: callId)];
    if (call != null) {
      if (call.room.id != room.id) {
        Logs().w(
            'Ignoring call replace for room ${room.id} claiming to be for call in room ${call.room.id}');
        return;
      }
      //TODO: handle replaces
    }
  }

  Future<void> onCallSelectAnswer(Room room, Participant remoteParticipant,
      Map<String, dynamic> content) async {
    final String callId = content['call_id'];
    Logs().d('SelectAnswer received for call ID $callId');
    final String selectedPartyId = content['selected_party_id'];

    final call = calls[VoipId(roomId: room.id, callId: callId)];
    if (call != null) {
      if (call.room.id != room.id) {
        Logs().w(
            'Ignoring call select answer for room ${room.id} claiming to be for call in room ${call.room.id}');
        return;
      }
      await call.onSelectAnswerReceived(selectedPartyId);
    }
  }

  Future<void> onSDPStreamMetadataChangedReceived(Room room,
      Participant remoteParticipant, Map<String, dynamic> content) async {
    final String callId = content['call_id'];
    Logs().d('SDP Stream metadata received for call ID $callId');

    final call = calls[VoipId(roomId: room.id, callId: callId)];
    if (call != null) {
      if (call.room.id != room.id) {
        Logs().w(
            'Ignoring call sdp metadata change for room ${room.id} claiming to be for call in room ${call.room.id}');
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

  Future<void> onAssertedIdentityReceived(Room room,
      Participant remoteParticipant, Map<String, dynamic> content) async {
    final String callId = content['call_id'];
    Logs().d('Asserted identity received for call ID $callId');

    final call = calls[VoipId(roomId: room.id, callId: callId)];
    if (call != null) {
      if (call.room.id != room.id) {
        Logs().w(
            'Ignoring call asserted identity for room ${room.id} claiming to be for call in room ${call.room.id}');
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

  Future<void> onCallNegotiate(Room room, Participant remoteParticipant,
      Map<String, dynamic> content) async {
    final String callId = content['call_id'];
    Logs().d('Negotiate received for call ID $callId');

    final call = calls[VoipId(roomId: room.id, callId: callId)];
    if (call != null) {
      if (call.room.id != room.id) {
        Logs().w(
            'Ignoring call negotiation for room ${room.id} claiming to be for call in room ${call.room.id}');
        return;
      }
      if (content['party_id'] != call.remoteUserDeviceId) {
        Logs().w('Ignoring call negotiation, wrong partyId detected');
        return;
      }
      if (content['party_id'] == call.localPartyId) {
        Logs().w('Ignoring call negotiation echo');
        return;
      }

      // ideally you also check the lifetime here and discard negotiation events
      // if age of the event was older than the lifetime but as to device events
      // do not have a unsigned age nor a origin_server_ts there's no easy way to
      // override this one function atm

      final description = content['description'];
      try {
        SDPStreamMetadata? metadata;
        if (content[sdpStreamMetadataKey] != null) {
          metadata = SDPStreamMetadata.fromJson(content[sdpStreamMetadataKey]);
        }
        await call.onNegotiateReceived(metadata,
            RTCSessionDescription(description['sdp'], description['type']));
      } catch (e, s) {
        Logs().e('[VOIP] Failed to complete negotiation', e, s);
      }
    }
  }

  CallType getCallType(String sdp) {
    try {
      final session = sdp_transform.parse(sdp);
      if (session['media'].indexWhere((e) => e['type'] == 'video') != -1) {
        return CallType.kVideo;
      }
    } catch (e, s) {
      Logs().e('[VOIP] Failed to getCallType', e, s);
    }

    return CallType.kVoice;
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
  /// Pretty important to set the userId, or all the users in the room get a call.
  /// Including your own other devices
  ///
  /// A userId is mandatory to if you want to set a deviceId
  /// Setting the deviceId would make all other devices for that userId ignore the call
  /// Ideally only group calls would need setting both userId and deviceId to allow
  /// having 2 devices from the same user in a group call
  ///
  /// For p2p call, you want to have all the devices of the specified `userId` ring
  ///
  /// yes I forced you to call a particular user in a room, letting anyone answer
  /// doesn't make sense
  Future<CallSession> inviteToCall(
    String roomId,
    CallType type,
    String userId, {
    String? deviceId,
  }) async {
    final room = client.getRoomById(roomId);
    if (room == null) {
      Logs().v('[VOIP] Invalid room id [$roomId].');
      return Null as CallSession;
    }
    final callId = genCallID();
    if (currentGroupCID == null) {
      incomingCallRoomId[roomId] = callId;
    }
    final opts = CallOptions(
      callId: callId,
      type: type,
      dir: CallDirection.kOutgoing,
      room: room,
      voip: this,
      localPartyId: localPartyId!,
      iceServers: await getIceSevers(),
    );
    final newCall = createNewCall(opts);

    newCall.remoteUserId = userId;
    newCall.remoteUserDeviceId = deviceId;

    currentCID = VoipId(roomId: roomId, callId: callId);
    await newCall.initOutboundCall(type).then((_) {
      delegate.handleNewCall(newCall);
    });
    return newCall;
  }

  CallSession createNewCall(CallOptions opts) {
    final call = CallSession(opts);
    calls[VoipId(roomId: opts.room.id, callId: opts.callId)] = call;
    return call;
  }

  /// Create a new group call in an existing room.
  ///
  /// [groupCallId] The room id to call
  ///
  /// [application] normal group call, thrirdroom, etc
  ///
  /// [scope] room, between specifc users, etc.
  Future<GroupCallSession> _newGroupCall(
    String groupCallId,
    Room room,
    List<CallBackend> backends,
    String? application,
    String? scope,
  ) async {
    if (getGroupCallById(room.id, groupCallId) != null) {
      Logs().e('[VOIP] [$groupCallId] already exists.');
      return getGroupCallById(room.id, groupCallId)!;
    }

    final groupCall = GroupCallSession(
      groupCallId: groupCallId,
      client: client,
      room: room,
      voip: this,
      backends: backends,
      application: application,
      scope: scope,
    );

    setGroupCallById(groupCall);

    return groupCall;
  }

  /// Create a new group call in an existing room.
  ///
  /// [groupCallId] The room id to call
  ///
  /// [application] normal group call, thrirdroom, etc
  ///
  /// [scope] room, between specifc users, etc.

  Future<GroupCallSession> fetchOrCreateGroupCall(
    String groupCallId,
    Room room,
    List<CallBackend> backends,
    String? application,
    String? scope,
  ) async {
    final groupCall = getGroupCallById(room.id, groupCallId);

    if (groupCall != null) {
      if (!room.canJoinGroupCall) {
        throw Exception(
            'User is not allowed to join famedly calls in the room');
      }
      return groupCall;
    }

    if (!room.canJoinGroupCall) {
      await room.enableGroupCalls();
      if (!room.canJoinGroupCall) {
        throw Exception(
            'User is not allowed to join famedly calls in the room');
      }
    }

    if (room.canJoinGroupCall) {
      // The call doesn't exist, but we can create it
      final groupCall = await _newGroupCall(
        groupCallId,
        room,
        backends,
        application,
        scope,
      );

      return groupCall;
    } else {
      throw Exception('User is not allowed to join famedly calls in the room');
    }
  }

  GroupCallSession? getGroupCallById(String roomId, String groupCallId) {
    return groupCalls[VoipId(roomId: roomId, callId: groupCallId)];
  }

  void setGroupCallById(GroupCallSession groupCallSession) {
    groupCalls[VoipId(
      roomId: groupCallSession.room.id,
      callId: groupCallSession.groupCallId,
    )] = groupCallSession;
  }

  /// Create a new group call from a room state event.
  Future<GroupCallSession?> createGroupCallFromRoomStateEvent(
      CallMembership membership,
      {bool emitHandleNewGroupCall = true}) async {
    final room = client.getRoomById(membership.roomId);

    if (room == null) {
      Logs().w('Couldn\'t find room ${membership.roomId} for GroupCallSession');
      return null;
    }

    if (membership.application != 'm.call' && membership.scope != 'm.room') {
      Logs().w('Received invalid group call application or scope.');
      return null;
    }

    final groupCall = GroupCallSession(
      client: client,
      voip: this,
      room: room,
      backends: membership.backends,
      groupCallId: membership.roomId,
      application: membership.application,
      scope: membership.scope,
    );

    if (groupCalls.containsKey(
        VoipId(roomId: membership.roomId, callId: membership.callId))) {
      return null;
    }

    setGroupCallById(groupCall);

    onIncomingGroupCall.add(groupCall);
    if (emitHandleNewGroupCall) {
      await delegate.handleNewGroupCall(groupCall);
    }
    return groupCall;
  }

  @Deprecated('Call `hasActiveGroupCall` on the room directly instead')
  bool hasActiveCall(Room room) => room.hasActiveGroupCall;
}
