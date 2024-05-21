import 'dart:async';
import 'dart:convert';
import 'dart:core';

import 'package:collection/collection.dart';
import 'package:sdp_transform/sdp_transform.dart' as sdp_transform;
import 'package:webrtc_interface/webrtc_interface.dart';

import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:matrix/src/utils/crypto/crypto.dart';
import 'package:matrix/src/voip/models/call_membership.dart';
import 'package:matrix/src/voip/models/call_options.dart';
import 'package:matrix/src/voip/models/voip_id.dart';
import 'package:matrix/src/voip/utils/stream_helper.dart';

/// The parent highlevel voip class, this trnslates matrix events to webrtc methods via
/// `CallSession` or `GroupCallSession` methods
class VoIP {
  // used only for internal tests, all txids for call events will be overwritten to this
  static String? customTxid;

  /// set to true if you want to use the ratcheting mechanism with your keyprovider
  /// remember to set the window size correctly on your keyprovider
  ///
  /// at client level because reinitializing a `GroupCallSession` and its `KeyProvider`
  /// everytime this changed would be a pain
  final bool enableSFUE2EEKeyRatcheting;

  /// cached turn creds
  TurnServerCredentials? _turnServerCredentials;

  Map<VoipId, CallSession> get calls => _calls;
  final Map<VoipId, CallSession> _calls = {};

  Map<VoipId, GroupCallSession> get groupCalls => _groupCalls;
  final Map<VoipId, GroupCallSession> _groupCalls = {};

  final CachedStreamController<CallSession> onIncomingCall =
      CachedStreamController();

  VoipId? currentCID;
  VoipId? currentGroupCID;

  String get localPartyId => currentSessionId;

  final Client client;
  final WebRTCDelegate delegate;
  final StreamController<GroupCallSession> onIncomingGroupCall =
      StreamController();

  CallParticipant? get localParticipant => client.isLogged()
      ? CallParticipant(
          this,
          userId: client.userID!,
          deviceId: client.deviceID,
        )
      : null;

  /// map of roomIds to the invites they are currently processing or in a call with
  /// used for handling glare in p2p calls
  Map<String, String> get incomingCallRoomId => _incomingCallRoomId;
  final Map<String, String> _incomingCallRoomId = {};

  /// the current instance of voip, changing this will drop any ongoing mesh calls
  /// with that sessionId
  late String currentSessionId;
  VoIP(
    this.client,
    this.delegate, {
    this.enableSFUE2EEKeyRatcheting = false,
  }) : super() {
    currentSessionId = base64Encode(secureRandomBytes(16));
    Logs().v('set currentSessionId to $currentSessionId');
    // to populate groupCalls with already present calls
    for (final room in client.rooms) {
      final memsList = room.getCallMembershipsFromRoom();
      for (final mems in memsList.values) {
        for (final mem in mems) {
          unawaited(createGroupCallFromRoomStateEvent(mem));
        }
      }
    }

    /// handles events todevice and matrix events for invite, candidates, hangup, etc.
    client.onCallEvents.stream.listen((events) async {
      await _handleCallEvents(events);
    });

    // handles the com.famedly.call events.
    client.onRoomState.stream.listen(
      (update) async {
        final event = update.state;
        if (event is! Event) return;
        if (event.room.membership != Membership.join) return;
        if (event.type != EventTypes.GroupCallMember) return;

        Logs().v('[VOIP] onRoomState: type ${event.toJson()}');
        final mems = event.room.getCallMembershipsFromEvent(event);
        for (final mem in mems) {
          unawaited(createGroupCallFromRoomStateEvent(mem));
        }
        for (final map in groupCalls.entries) {
          if (map.key.roomId == event.room.id) {
            // because we don't know which call got updated, just update all
            // group calls we have entered for that room
            await map.value.onMemberStateChanged();
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
          if (CallConstants.omitWhenCallEndedTypes.contains(event.type) &&
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
            Logs().w(
                '[VOIP] Ommiting invite event ${callEvent.eventId} as age was older than lifetime');
            return true;
          }
          return false;
        });
      }
    }

    // and finally call the respective methods on the clean callEvents list
    for (final callEvent in callEvents) {
      await _handleCallEvent(callEvent);
    }
  }

  Future<void> _handleCallEvent(BasicEventWithSender event) async {
    // member event updates handled in onRoomState for ease
    if (event.type == EventTypes.GroupCallMember) return;

    GroupCallSession? groupCallSession;
    Room? room;
    final remoteUserId = event.senderId;
    String? remoteDeviceId;

    if (event is Event) {
      room = event.room;

      /// this can also be sent in p2p calls when they want to call a specific device
      remoteDeviceId = event.content.tryGet<String>('invitee_device_id');
    } else if (event is ToDeviceEvent) {
      final roomId = event.content.tryGet<String>('room_id');
      final confId = event.content.tryGet<String>('conf_id');

      /// to-device events specifically, m.call.invite and encryption key sending and requesting
      remoteDeviceId = event.content.tryGet<String>('device_id');

      if (roomId != null && confId != null) {
        room = client.getRoomById(roomId);
        groupCallSession = groupCalls[VoipId(roomId: roomId, callId: confId)];
      } else {
        Logs().w(
            '[VOIP] Ignoring to_device event of type ${event.type} but did not find group call for id: $confId');
        return;
      }

      if (!event.type.startsWith(EventTypes.GroupCallMemberEncryptionKeys)) {
        // livekit calls have their own session deduplication logic so ignore sessionId deduplication for them
        final destSessionId = event.content.tryGet<String>('dest_session_id');
        if (destSessionId != currentSessionId) {
          Logs().w(
              '[VOIP] Ignoring to_device event of type ${event.type} did not match currentSessionId: $currentSessionId, dest_session_id was set to $destSessionId');
          return;
        }
      } else if (groupCallSession == null || remoteDeviceId == null) {
        Logs().w(
            '[VOIP] _handleCallEvent ${event.type} recieved but either groupCall ${groupCallSession?.groupCallId} or deviceId $remoteDeviceId was null, ignoring');
        return;
      }
    } else {
      Logs().w(
          '[VOIP] _handleCallEvent can only handle Event or ToDeviceEvent, it got ${event.runtimeType}');
      return;
    }

    final content = event.content;

    if (room == null) {
      Logs().w(
          '[VOIP] _handleCallEvent call event does not contain a room_id, ignoring');
      return;
    } else if (!event.type
        .startsWith(EventTypes.GroupCallMemberEncryptionKeys)) {
      // skip webrtc event checks on encryption_keys
      final callId = content['call_id'] as String?;
      final partyId = content['party_id'] as String?;
      if (callId == null && event.type.startsWith('m.call')) {
        Logs().w('Ignoring call event ${event.type} because call_id was null');
        return;
      }
      if (callId != null) {
        final call = calls[VoipId(roomId: room.id, callId: callId)];
        if (call == null &&
            !{EventTypes.CallInvite, EventTypes.GroupCallMemberInvite}
                .contains(event.type)) {
          Logs().w(
              'Ignoring call event ${event.type} because we do not have the call');
          return;
        } else if (call != null) {
          // multiple checks to make sure the events sent are from the the
          // expected party
          if (call.room.id != room.id) {
            Logs().w(
                'Ignoring call event ${event.type} for room ${room.id} claiming to be for call in room ${call.room.id}');
            return;
          }
          if (call.remoteUserId != null && call.remoteUserId != remoteUserId) {
            Logs().w(
                'Ignoring call event ${event.type} from sender $remoteUserId, expected sender: ${call.remoteUserId}');
            return;
          }
          if (call.remotePartyId != null && call.remotePartyId != partyId) {
            Logs().w(
                'Ignoring call event ${event.type} from sender with a different party_id $partyId, expected party_id: ${call.remotePartyId}');
            return;
          }
          if ((call.remotePartyId != null &&
                  call.remotePartyId == localPartyId) ||
              (remoteUserId == client.userID &&
                  remoteDeviceId == client.deviceID!)) {
            Logs().w('Ignoring call event ${event.type} from ourself');
            return;
          }
        }
      }
    }
    Logs().v(
        '[VOIP] Handling event of type: ${event.type}, content ${event.content} from sender ${event.senderId} rp: $remoteUserId:$remoteDeviceId');

    switch (event.type) {
      case EventTypes.CallInvite:
      case EventTypes.GroupCallMemberInvite:
        await onCallInvite(room, remoteUserId, remoteDeviceId, content);
        break;
      case EventTypes.CallAnswer:
      case EventTypes.GroupCallMemberAnswer:
        await onCallAnswer(room, remoteUserId, remoteDeviceId, content);
        break;
      case EventTypes.CallCandidates:
      case EventTypes.GroupCallMemberCandidates:
        await onCallCandidates(room, content);
        break;
      case EventTypes.CallHangup:
      case EventTypes.GroupCallMemberHangup:
        await onCallHangup(room, content);
        break;
      case EventTypes.CallReject:
      case EventTypes.GroupCallMemberReject:
        await onCallReject(room, content);
        break;
      case EventTypes.CallNegotiate:
      case EventTypes.GroupCallMemberNegotiate:
        await onCallNegotiate(room, content);
        break;
      // case EventTypes.CallReplaces:
      //   await onCallReplaces(room, content);
      //   break;
      case EventTypes.CallSelectAnswer:
      case EventTypes.GroupCallMemberSelectAnswer:
        await onCallSelectAnswer(room, content);
        break;
      case EventTypes.CallSDPStreamMetadataChanged:
      case EventTypes.CallSDPStreamMetadataChangedPrefix:
      case EventTypes.GroupCallMemberSDPStreamMetadataChanged:
        await onSDPStreamMetadataChangedReceived(room, content);
        break;
      case EventTypes.CallAssertedIdentity:
      case EventTypes.CallAssertedIdentityPrefix:
      case EventTypes.GroupCallMemberAssertedIdentity:
        await onAssertedIdentityReceived(room, content);
        break;
      case EventTypes.GroupCallMemberEncryptionKeys:
        await groupCallSession!.backend.onCallEncryption(
            groupCallSession, remoteUserId, remoteDeviceId!, content);
        break;
      case EventTypes.GroupCallMemberEncryptionKeysRequest:
        await groupCallSession!.backend.onCallEncryptionKeyRequest(
            groupCallSession, remoteUserId, remoteDeviceId!, content);
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
      if (groupCall.state == GroupCallState.entered) {
        await groupCall.backend.updateMediaDeviceForCalls();
      }
    }
  }

  Future<void> onCallInvite(Room room, String remoteUserId,
      String? remoteDeviceId, Map<String, dynamic> content) async {
    Logs().v(
        '[VOIP] onCallInvite $remoteUserId:$remoteDeviceId => ${client.userID}:${client.deviceID}, \ncontent => ${content.toString()}');

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

    final inviteeUserId = content['invitee'];
    if (inviteeUserId != null && inviteeUserId != localParticipant?.userId) {
      Logs().w('[VOIP] Ignoring call, meant for user $inviteeUserId');
      return; // This invite was meant for another user in the room
    }
    final inviteeDeviceId = content['invitee_device_id'];
    if (inviteeDeviceId != null &&
        inviteeDeviceId != localParticipant?.deviceId) {
      Logs().w('[VOIP] Ignoring call, meant for device $inviteeDeviceId');
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
      localPartyId: localPartyId,
      iceServers: await getIceServers(),
    );

    final newCall = createNewCall(opts);

    /// both invitee userId and deviceId are set here because there can be
    /// multiple devices from same user in a call, so we specifiy who the
    /// invite is for
    newCall.remoteUserId = remoteUserId;
    newCall.remoteDeviceId = remoteDeviceId;
    newCall.remotePartyId = content['party_id'];
    newCall.remoteSessionId = content['sender_session_id'];

    // newCall.remoteSessionId = remoteParticipant.sessionId;

    if (!delegate.canHandleNewCall &&
        (confId == null ||
            currentGroupCID != VoipId(roomId: room.id, callId: confId))) {
      Logs().v(
          '[VOIP] onCallInvite: Unable to handle new calls, maybe user is busy.');
      // no need to emit here because handleNewCall was never triggered yet
      await newCall.reject(reason: CallErrorCode.userBusy, shouldEmit: false);
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

  Future<void> onCallAnswer(Room room, String remoteUserId,
      String? remoteDeviceId, Map<String, dynamic> content) async {
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

      if (call.remoteUserId == null) {
        Logs().i(
            '[VOIP] you probably called the room without setting a userId in invite, setting the calls remote user id to what I get from m.call.answer now');
        call.remoteUserId = remoteUserId;
      }

      if (call.remoteDeviceId == null) {
        Logs().i(
            '[VOIP] you probably called the room without setting a userId in invite, setting the calls remote user id to what I get from m.call.answer now');
        call.remoteDeviceId = remoteDeviceId;
      }
      if (call.remotePartyId != null) {
        Logs().d(
            'Ignoring call answer from party ${content['party_id']}, we are already with ${call.remotePartyId}');
        return;
      } else {
        call.remotePartyId = content['party_id'];
      }

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

  Future<void> onCallCandidates(Room room, Map<String, dynamic> content) async {
    Logs().v('[VOIP] onCallCandidates => ${content.toString()}');
    final String callId = content['call_id'];
    final call = calls[VoipId(roomId: room.id, callId: callId)];
    if (call != null) {
      await call.onCandidatesReceived(content['candidates']);
    } else {
      Logs().v('[VOIP] onCallCandidates: Session [$callId] not found!');
    }
  }

  Future<void> onCallHangup(Room room, Map<String, dynamic> content) async {
    // stop play ringtone, if this is an incoming call
    await delegate.stopRingtone();
    Logs().v('[VOIP] onCallHangup => ${content.toString()}');
    final String callId = content['call_id'];

    final call = calls[VoipId(roomId: room.id, callId: callId)];
    if (call != null) {
      // hangup in any case, either if the other party hung up or we did on another device
      await call.terminate(
          CallParty.kRemote,
          CallErrorCode.values.firstWhereOrNull(
                  (element) => element.reason == content['reason']) ??
              CallErrorCode.userHangup,
          true);
    } else {
      Logs().v('[VOIP] onCallHangup: Session [$callId] not found!');
    }
    if (callId == currentCID?.callId) {
      currentCID = null;
    }
  }

  Future<void> onCallReject(Room room, Map<String, dynamic> content) async {
    final String callId = content['call_id'];
    Logs().d('Reject received for call ID $callId');

    final call = calls[VoipId(roomId: room.id, callId: callId)];
    if (call != null) {
      await call.onRejectReceived(
        CallErrorCode.values.firstWhereOrNull(
                (element) => element.reason == content['reason']) ??
            CallErrorCode.userHangup,
      );
    } else {
      Logs().v('[VOIP] onCallReject: Session [$callId] not found!');
    }
  }

  Future<void> onCallSelectAnswer(
      Room room, Map<String, dynamic> content) async {
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

  Future<void> onSDPStreamMetadataChangedReceived(
      Room room, Map<String, dynamic> content) async {
    final String callId = content['call_id'];
    Logs().d('SDP Stream metadata received for call ID $callId');

    final call = calls[VoipId(roomId: room.id, callId: callId)];
    if (call != null) {
      if (content[sdpStreamMetadataKey] == null) {
        Logs().d('SDP Stream metadata is null');
        return;
      }
      await call.onSDPStreamMetadataReceived(
          SDPStreamMetadata.fromJson(content[sdpStreamMetadataKey]));
    }
  }

  Future<void> onAssertedIdentityReceived(
      Room room, Map<String, dynamic> content) async {
    final String callId = content['call_id'];
    Logs().d('Asserted identity received for call ID $callId');

    final call = calls[VoipId(roomId: room.id, callId: callId)];
    if (call != null) {
      if (content['asserted_identity'] == null) {
        Logs().d('asserted_identity is null ');
        return;
      }
      call.onAssertedIdentityReceived(
          AssertedIdentity.fromJson(content['asserted_identity']));
    }
  }

  Future<void> onCallNegotiate(Room room, Map<String, dynamic> content) async {
    final String callId = content['call_id'];
    Logs().d('Negotiate received for call ID $callId');

    final call = calls[VoipId(roomId: room.id, callId: callId)];
    if (call != null) {
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

  Future<List<Map<String, dynamic>>> getIceServers() async {
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
  /// Including your own other devices, so just set it to directChatMatrixId
  ///
  /// Setting the deviceId would make all other devices for that userId ignore the call
  /// Ideally only group calls would need setting both userId and deviceId to allow
  /// having 2 devices from the same user in a group call
  ///
  /// For p2p call, you want to have all the devices of the specified `userId` ring
  Future<CallSession> inviteToCall(
    Room room,
    CallType type, {
    String? userId,
    String? deviceId,
  }) async {
    final roomId = room.id;
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
      localPartyId: localPartyId,
      iceServers: await getIceServers(),
    );
    final newCall = createNewCall(opts);

    newCall.remoteUserId = userId;
    newCall.remoteDeviceId = deviceId;

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
    CallBackend backend,
    String? application,
    String? scope,
  ) async {
    if (getGroupCallById(room.id, groupCallId) != null) {
      Logs().v('[VOIP] [$groupCallId] already exists.');
      return getGroupCallById(room.id, groupCallId)!;
    }

    final groupCall = GroupCallSession(
      groupCallId: groupCallId,
      client: client,
      room: room,
      voip: this,
      backend: backend,
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
    CallBackend backend,
    String? application,
    String? scope,
  ) async {
    if (!room.groupCallsEnabledForEveryone) {
      await room.enableGroupCalls();
    }

    final groupCall = getGroupCallById(room.id, groupCallId);

    if (groupCall != null) {
      if (!room.canJoinGroupCall) {
        throw Exception(
            '[VOIP] User is not allowed to join famedly calls in the room');
      }
      return groupCall;
    }

    // The call doesn't exist, but we can create it
    return await _newGroupCall(
      groupCallId,
      room,
      backend,
      application,
      scope,
    );
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
  Future<void> createGroupCallFromRoomStateEvent(
    CallMembership membership, {
    bool emitHandleNewGroupCall = true,
  }) async {
    if (membership.isExpired) {
      Logs().d(
          'Ignoring expired membership in passive groupCall creator. ${membership.toJson()}');
      return;
    }

    final room = client.getRoomById(membership.roomId);

    if (room == null) {
      Logs().w('Couldn\'t find room ${membership.roomId} for GroupCallSession');
      return;
    }

    if (membership.application != 'm.call' && membership.scope != 'm.room') {
      Logs().w('Received invalid group call application or scope.');
      return;
    }

    final groupCall = GroupCallSession(
      client: client,
      voip: this,
      room: room,
      backend: membership.backend,
      groupCallId: membership.callId,
      application: membership.application,
      scope: membership.scope,
    );

    if (groupCalls.containsKey(
        VoipId(roomId: membership.roomId, callId: membership.callId))) {
      return;
    }

    setGroupCallById(groupCall);

    onIncomingGroupCall.add(groupCall);
    if (emitHandleNewGroupCall) {
      await delegate.handleNewGroupCall(groupCall);
    }
  }

  @Deprecated('Call `hasActiveGroupCall` on the room directly instead')
  bool hasActiveCall(Room room) => room.hasActiveGroupCall;
}
