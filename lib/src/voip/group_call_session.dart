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

import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:matrix/src/voip/models/voip_id.dart';
import 'package:matrix/src/voip/utils/stream_helper.dart';

/// Holds methods for managing a group call. This class is also responsible for
/// holding and managing the individual `CallSession`s in a group call.
class GroupCallSession {
  // Config
  final Client client;
  final VoIP voip;
  final Room room;

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
  final Set<CallParticipant> _participants = {};

  String groupCallId;

  final CachedStreamController<GroupCallState> onGroupCallState =
      CachedStreamController();

  final CachedStreamController<GroupCallStateChange> onGroupCallEvent =
      CachedStreamController();

  final CachedStreamController<MatrixRTCCallEvent> matrixRTCEventStream =
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
      throw MatrixSDKVoipException('Cannot enter call in the $state state');
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

    voip.currentGroupCID = VoipId(roomId: room.id, callId: groupCallId);

    await voip.delegate.handleNewGroupCall(this);
  }

  Future<void> leave() async {
    await removeMemberStateEvent();
    await backend.dispose(this);
    setState(GroupCallState.localCallFeedUninitialized);
    voip.currentGroupCID = null;
    _participants.clear();
    voip.groupCalls.remove(VoipId(roomId: room.id, callId: groupCallId));
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
            .add(voip.timeouts!.expireTsBumpDuration)
            .millisecondsSinceEpoch,
        membershipId: voip.currentSessionId,
        feeds: backend.getCurrentFeeds(),
        voip: voip,
      ),
    );

    if (_resendMemberStateEventTimer != null) {
      _resendMemberStateEventTimer!.cancel();
    }
    _resendMemberStateEventTimer = Timer.periodic(
      voip.timeouts!.updateExpireTsTimerDuration,
      ((timer) async {
        Logs().d('sendMemberStateEvent updating member event with timer');
        if (state != GroupCallState.ended ||
            state != GroupCallState.localCallFeedUninitialized) {
          await sendMemberStateEvent();
        } else {
          Logs().d(
            '[VOIP] deteceted groupCall in state $state, removing state event',
          );
          await removeMemberStateEvent();
        }
      }),
    );
  }

  Future<void> removeMemberStateEvent() {
    if (_resendMemberStateEventTimer != null) {
      Logs().d('resend member event timer cancelled');
      _resendMemberStateEventTimer!.cancel();
      _resendMemberStateEventTimer = null;
    }
    return room.removeFamedlyCallMemberEvent(
      groupCallId,
      voip,
      application: application,
      scope: scope,
    );
  }

  /// compltetely rebuilds the local _participants list
  Future<void> onMemberStateChanged() async {
    // The member events may be received for another room, which we will ignore.
    final mems = room
        .getCallMembershipsFromRoom(voip)
        .values
        .expand((element) => element);
    final memsForCurrentGroupCall = mems.where((element) {
      return element.callId == groupCallId &&
          !element.isExpired &&
          element.application == application &&
          element.scope == scope &&
          element.roomId == room.id; // sanity checks
    }).toList();

    final Set<CallParticipant> newP = {};

    for (final mem in memsForCurrentGroupCall) {
      final rp = CallParticipant(
        voip,
        userId: mem.userId,
        deviceId: mem.deviceId,
      );

      newP.add(rp);

      if (rp.isLocal) continue;

      if (state != GroupCallState.entered) continue;

      await backend.setupP2PCallWithNewMember(this, rp, mem);
    }
    final newPcopy = Set<CallParticipant>.from(newP);
    final oldPcopy = Set<CallParticipant>.from(_participants);
    final anyJoined = newPcopy.difference(oldPcopy);
    final anyLeft = oldPcopy.difference(newPcopy);

    if (anyJoined.isNotEmpty || anyLeft.isNotEmpty) {
      if (anyJoined.isNotEmpty) {
        final nonLocalAnyJoined = Set<CallParticipant>.from(anyJoined)
          ..remove(localParticipant);
        if (nonLocalAnyJoined.isNotEmpty && state == GroupCallState.entered) {
          Logs().v(
            'nonLocalAnyJoined: ${nonLocalAnyJoined.map((e) => e.id).toString()} roomId: ${room.id} groupCallId: $groupCallId',
          );
          await backend.onNewParticipant(this, nonLocalAnyJoined.toList());
        }
        _participants.addAll(anyJoined);
        matrixRTCEventStream
            .add(ParticipantsJoinEvent(participants: anyJoined.toList()));
      }
      if (anyLeft.isNotEmpty) {
        final nonLocalAnyLeft = Set<CallParticipant>.from(anyLeft)
          ..remove(localParticipant);
        if (nonLocalAnyLeft.isNotEmpty && state == GroupCallState.entered) {
          Logs().v(
            'nonLocalAnyLeft: ${nonLocalAnyLeft.map((e) => e.id).toString()} roomId: ${room.id} groupCallId: $groupCallId',
          );
          await backend.onLeftParticipant(this, nonLocalAnyLeft.toList());
        }
        _participants.removeAll(anyLeft);
        matrixRTCEventStream
            .add(ParticipantsLeftEvent(participants: anyLeft.toList()));
      }

      onGroupCallEvent.add(GroupCallStateChange.participantsChanged);
    }
  }

  Future<Map<String, dynamic>?> _buildReactionEvent({
    required String emoji,
    required String name,
    bool isEphemeral = true,
  }) async {
    Logs().d('Group call reaction selected: $emoji');
    final memberships =
        room.getCallMembershipsForUser(client.userID!, client.deviceID!, voip);
    final membership = memberships.firstWhereOrNull(
      (m) =>
          m.callId == groupCallId &&
          m.application == 'm.call' &&
          m.scope == 'm.room',
    );

    if (membership == null) {
      Logs().w(
        'No matching membership found to send group call emoji reaction from ${client.userID!}',
      );
      return null;
    }

    return {
      'key': emoji,
      'name': name,
      'is_ephemeral': isEphemeral,
      'call_id': groupCallId,
      'device_id': client.deviceID!,
      'm.relates_to': {
        'rel_type': RelationshipTypes.reference,
        'event_id': membership.eventId!,
      },
    };
  }

  /// Send a reaction event to the group call
  ///
  /// [emoji] - The reaction emoji (e.g., '🖐️' for hand raise)
  /// [name] - The reaction name (e.g., 'hand raise')
  /// [isEphemeral] - Whether the reaction is ephemeral (default: true)
  ///
  /// Returns the event ID of the sent reaction event
  Future<String?> sendReactionEvent({
    required String emoji,
    required String name,
    bool isEphemeral = true,
  }) async {
    final reactionEvent = await _buildReactionEvent(
      emoji: emoji,
      name: name,
      isEphemeral: isEphemeral,
    );

    if (reactionEvent == null) return null;

    // Send reaction as unencrypted event to avoid decryption issues
    final txid = client.generateUniqueTransactionId();
    return await client.sendMessage(
      room.id,
      EventTypes.GroupCallMemberReaction,
      txid,
      reactionEvent,
    );
  }

  /// Remove a reaction event from the group call
  ///
  /// [emoji] - The reaction emoji (e.g., '🖐️' for hand raise)
  /// [name] - The reaction name (e.g., 'hand raise')
  ///
  /// Returns the event ID of the removed reaction event
  Future<String?> removeReactionEvent({
    required String emoji,
    required String name,
  }) async {
    final reactionEvent = await _buildReactionEvent(
      emoji: emoji,
      name: name,
      isEphemeral: false,
    );

    if (reactionEvent == null) return null;

    // Send reaction removal as unencrypted event to avoid decryption issues
    final txid = client.generateUniqueTransactionId();
    return await client.sendMessage(
      room.id,
      EventTypes.GroupCallMemberReactionRemoved,
      txid,
      reactionEvent,
    );
  }

  /// Get all reactions of a specific type for all participants in the call
  ///
  /// [emoji] - The reaction emoji to filter by (e.g., '🖐️')
  ///
  /// Returns a list of [MatrixEvent] objects representing the reactions
  Future<List<MatrixEvent>> getAllReactions({required String emoji}) async {
    final reactions = <MatrixEvent>[];

    for (final participant in participants) {
      final memberships = room.getCallMembershipsForUser(
        participant.userId,
        participant.deviceId ?? '',
        voip,
      );

      final membershipsForCurrentGroupCall = memberships
          .where(
            (m) =>
                m.callId == groupCallId &&
                m.application == application &&
                m.scope == scope &&
                m.roomId == room.id,
          )
          .toList();

      for (final membership in membershipsForCurrentGroupCall) {
        if (membership.eventId == null) {
          Logs().w(
            'Cannot find membership event for ${participant.userId}',
          );
          continue;
        }

        final events = await client.getRelatingEventsWithRelTypeAndEventType(
          room.id,
          membership.eventId!,
          RelationshipTypes.reference,
          EventTypes.GroupCallMemberReaction,
        );

        events.chunk.forEachIndexed((index, event) {
          final content = event.content;
          if (content['key'] == emoji) {
            Logs().d(
              'Reaction $index: ${event.senderId}, key: ${content['key']}',
            );
            reactions.add(event);
          }
        });
      }
    }

    return reactions;
  }
}
