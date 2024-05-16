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

import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:matrix/src/voip/models/call_membership.dart';
import 'package:matrix/src/voip/models/voip_id.dart';
import 'package:matrix/src/voip/utils/stream_helper.dart';

/// Holds methods for managing a group call. This class is also responsible for
/// holding and managing the individual `CallSession`s in a group call.
class GroupCallSession {
  // Config
  final Client client;
  final VoIP voip;
  final Room room;
  VoipId get voipId => VoipId(
        roomId: room.id,
        callId: groupCallId,
        callBackendType: backend.type,
        application: application,
        scope: scope,
      );

  /// is a list of backend to allow passing multiple backend in the future
  /// we use the first backend everywhere as of now
  final CallBackend backend;

  /// something like normal calls or thirdroom
  final String? application;

  /// either room scoped or user scoped calls
  final String? scope;

  GroupCallState state = GroupCallState.localCallFeedUninitialized;

  CallParticipant? get localParticipant => voip.localParticipant;

  List<CallParticipant> get participants => List.unmodifiable(_participants);
  final List<CallParticipant> _participants = [];

  String groupCallId;

  final CachedStreamController<GroupCallState> onGroupCallState =
      CachedStreamController();

  final CachedStreamController<GroupCallStateChange> onGroupCallEvent =
      CachedStreamController();

  Timer? _resendMemberStateEventTimer;

  factory GroupCallSession.withAutoGenId(
    Room room,
    VoIP voip,
    CallBackend backend,
    String? application,
    String? scope,
    String? groupCallId,
  ) {
    return GroupCallSession(
      client: room.client,
      room: room,
      voip: voip,
      backend: backend,
      application: application ?? 'm.call',
      scope: scope ?? 'm.room',
      groupCallId: groupCallId ?? genCallID(),
    );
  }

  GroupCallSession({
    required this.client,
    required this.room,
    required this.voip,
    required this.backend,
    required this.groupCallId,
    required this.application,
    required this.scope,
  });

  String get avatarName =>
      _getUser().calcDisplayname(mxidLocalPartFallback: false);

  String? get displayName => _getUser().displayName;

  User _getUser() {
    return room.unsafeGetUserFromMemoryOrFallback(client.userID!);
  }

  void setState(GroupCallState newState) {
    state = newState;
    onGroupCallState.add(newState);
    onGroupCallEvent.add(GroupCallStateChange.groupCallStateChanged);
  }

  bool hasLocalParticipant() {
    return _participants.contains(localParticipant);
  }

  /// enter the group call.
  Future<void> enter({WrappedMediaStream? stream}) async {
    if (!(state == GroupCallState.localCallFeedUninitialized ||
        state == GroupCallState.localCallFeedInitialized)) {
      throw Exception('Cannot enter call in the $state state');
    }

    if (state == GroupCallState.localCallFeedUninitialized) {
      await backend.initLocalStream(this, stream: stream);
    }

    await sendMemberStateEvent();

    setState(GroupCallState.entered);

    Logs().v('Entered group call $groupCallId');

    // Set up _participants for the members currently in the call.
    // Other members will be picked up by the RoomState.members event.
    await onMemberStateChanged();

    await backend.setupP2PCallsWithExistingMembers(this);

    voip.currentGroupCID = VoipId(
      roomId: room.id,
      callId: groupCallId,
      callBackendType: backend.type,
      application: application,
      scope: scope,
    );

    await voip.delegate.handleNewGroupCall(this);
  }

  Future<void> leave() async {
    await removeMemberStateEvent();
    await backend.dispose(this);
    setState(GroupCallState.localCallFeedUninitialized);
    voip.currentGroupCID = null;
    _participants.clear();
    voip.groupCalls.remove(this);
    await voip.delegate.handleGroupCallEnded(this);
    _resendMemberStateEventTimer?.cancel();
    setState(GroupCallState.ended);
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
        membershipId: voip.currentSessionId,
        feeds: backend.getCurrentFeeds(),
      ),
    );

    if (_resendMemberStateEventTimer != null) {
      _resendMemberStateEventTimer!.cancel();
    }
    _resendMemberStateEventTimer = Timer.periodic(
        CallTimeouts.updateExpireTsTimerDuration, ((timer) async {
      Logs().d('sendMemberStateEvent updating member event with timer');
      if (state != GroupCallState.ended ||
          state != GroupCallState.localCallFeedUninitialized) {
        await sendMemberStateEvent();
      } else {
        Logs().d(
            '[VOIP] deteceted groupCall in state $state, removing state event');
        await removeMemberStateEvent();
      }
    }));
  }

  Future<void> removeMemberStateEvent() {
    if (_resendMemberStateEventTimer != null) {
      Logs().d('resend member event timer cancelled');
      _resendMemberStateEventTimer!.cancel();
      _resendMemberStateEventTimer = null;
    }
    return room.removeFamedlyCallMemberEvent(
      groupCallId,
      client.deviceID!,
      application: application,
      scope: scope,
    );
  }

  /// compltetely rebuilds the local _participants list
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
          '[VOIP] Ignored ${mem.userId}\'s mem event ${mem.toJson()} while updating _participants list for callId: $groupCallId, expiry status: ${mem.isExpired}');
    }

    final List<CallParticipant> newP = [];

    for (final mem in memsForCurrentGroupCall) {
      final rp = CallParticipant(
        voip,
        userId: mem.userId,
        deviceId: mem.deviceId,
      );

      newP.add(rp);

      if (rp.isLocal) continue;

      if (state != GroupCallState.entered) {
        Logs().w(
            '[VOIP] onMemberStateChanged groupCall state is currently $state, skipping member update');
        continue;
      }

      await backend.setupP2PCallWithNewMember(this, rp, mem);
    }
    final newPcopy = List<CallParticipant>.from(newP);
    final oldPcopy = List<CallParticipant>.from(_participants);
    final anyJoined = newPcopy.where((element) => !oldPcopy.contains(element));
    final anyLeft = oldPcopy.where((element) => !newPcopy.contains(element));

    if (anyJoined.isNotEmpty || anyLeft.isNotEmpty) {
      if (anyJoined.isNotEmpty) {
        Logs().d('anyJoined: ${anyJoined.map((e) => e.id).toString()}');
        _participants.addAll(anyJoined);
        await backend.onNewParticipant(this, anyJoined.toList());
      }
      if (anyLeft.isNotEmpty) {
        Logs().d('anyLeft: ${anyLeft.map((e) => e.id).toString()}');
        for (final leftp in anyLeft) {
          _participants.remove(leftp);
        }
        await backend.onLeftParticipant(this, anyLeft.toList());
      }

      onGroupCallEvent.add(GroupCallStateChange.participantsChanged);
      Logs().d(
          '[VOIP] onMemberStateChanged current list: ${_participants.map((e) => e.id).toString()}');
    }
  }
}
