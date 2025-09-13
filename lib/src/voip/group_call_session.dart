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

  /// Send a generic reaction event to a participant's membership event
  ///
  /// [userId] - The user ID to send the reaction to
  /// [key] - The reaction key (e.g., '🖐️' for hand raise)
  /// [deviceId] - Optional device ID, defaults to empty string
  ///
  /// Returns the event ID of the sent reaction
  Future<String?> sendReactionEvent({
    required String userId,
    required String key,
    String? deviceId,
  }) async {
    final memberships = room.getCallMembershipsForUser(
      userId,
      deviceId ?? '',
      voip,
    );

    final membership = memberships.firstOrNull;
    if (membership?.eventId == null) {
      Logs().w('Cannot find membership event for user $userId');
      return null;
    }

    final parentEventId = membership!.eventId!;
    final content = {
      'm.relates_to': {
        'rel_type': RelationshipTypes.reaction,
        'event_id': parentEventId,
        'key': key,
      },
    };

    final eventId = await room.sendEvent(content, type: EventTypes.Reaction);
    Logs().d('Sent reaction event: $eventId with key: $key');

    return eventId;
  }

  /// Get all reactions of a specific type for all participants in the call
  ///
  /// [key] - The reaction key to filter by (e.g., '🖐️')
  ///
  /// Returns a list of MatrixEvent objects representing the reactions
  Future<List<MatrixEvent>> getAllReactions({String key = '🖐️'}) async {
    final reactions = <MatrixEvent>[];

    for (final participant in participants) {
      final memberships = room.getCallMembershipsForUser(
        participant.userId,
        participant.deviceId ?? '',
        voip,
      );

      for (final membership in memberships) {
        if (membership.eventId == null) {
          Logs().w(
            'Cannot find membership event for ${participant.userId}',
          );
          continue;
        }

        final events = await client.getRelatingEventsWithRelTypeAndEventType(
          room.id,
          membership.eventId!,
          RelationshipTypes.reaction,
          EventTypes.Reaction,
        );

        events.chunk.forEachIndexed((index, reaction) {
          final content = reaction.content;
          final relatesTo = content['m.relates_to'] as Map<String, dynamic>?;
          if (relatesTo?['key'] == key) {
            Logs().d(
              'Reaction $index: ${reaction.senderId}, relatesTo: $relatesTo, key: ${relatesTo?['key']}',
            );
            reactions.add(reaction);
          }
        });
      }
    }

    return reactions;
  }

  /// Remove a reaction event by redacting it
  ///
  /// [reactionId] - The event ID of the reaction to remove
  /// [reason] - Optional reason for the redaction
  ///
  /// Returns the event ID of the redaction event
  Future<String?> removeReactionEvent({
    required String reactionId,
    String? reason,
  }) async {
    final txnId = 'reaction-remove-${DateTime.now().millisecondsSinceEpoch}';
    final eventId =
        await client.redactEvent(room.id, reactionId, txnId, reason: reason);

    Logs().d('Removed reaction event: $eventId');

    return eventId;
  }

  /// Get reactions for a specific user and key
  ///
  /// [userId] - The user ID to get reactions for
  /// [key] - The reaction key to filter by
  /// [deviceId] - Optional device ID
  ///
  /// Returns a list of MatrixEvent objects representing the user's reactions
  Future<List<MatrixEvent>> getReactionsForUser({
    required String userId,
    String key = '🖐️',
    String? deviceId,
  }) async {
    final reactions = <MatrixEvent>[];

    final memberships = room.getCallMembershipsForUser(
      userId,
      deviceId ?? '',
      voip,
    );

    for (final membership in memberships) {
      if (membership.eventId == null) {
        Logs().w('Cannot find membership event for $userId');
        continue;
      }

      final events = await client.getRelatingEventsWithRelTypeAndEventType(
        room.id,
        membership.eventId!,
        RelationshipTypes.reaction,
        EventTypes.Reaction,
      );

      for (final reaction in events.chunk) {
        final content = reaction.content;
        final relatesTo = content['m.relates_to'] as Map<String, dynamic>?;
        if (relatesTo?['key'] == key && reaction.senderId == userId) {
          reactions.add(reaction);
        }
      }
    }

    return reactions;
  }

  /// Handle incoming reaction events from Matrix
  Future<void> onReactionReceived(
    BasicEventWithSender event,
    String reactionKey,
    String eventId,
  ) async {
    final participant = CallParticipant(
      voip,
      userId: event.senderId,
      deviceId: null, // We might not have device ID from the reaction
    );

    final reactionEvent = ReactionAddedEvent(
      participant: participant,
      reactionKey: reactionKey,
      eventId: (event is Event) ? event.eventId : '',
    );

    matrixRTCEventStream.add(reactionEvent);

    Logs().d(
      '[GroupCallSession] Reaction added: ${event.senderId} -> $reactionKey',
    );
  }

  /// Handle incoming reaction removal events from Matrix
  Future<void> onReactionRemoved(
    BasicEventWithSender event,
    String redactedEventId,
  ) async {
    final participant = CallParticipant(
      voip,
      userId: event.senderId,
      deviceId: null,
    );

    // We don't know the specific reaction key from redaction events
    // The listeners can filter based on their current state
    final reactionEvent = ReactionRemovedEvent(
      participant: participant,
      reactionKey: '',
      redactedEventId: redactedEventId,
    );

    matrixRTCEventStream.add(reactionEvent);

    Logs().d(
      '[GroupCallSession] Reaction removed: ${event.senderId}',
    );
  }
}
