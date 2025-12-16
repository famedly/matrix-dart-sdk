import 'dart:async';

import 'package:collection/collection.dart';

import 'package:matrix/matrix.dart';

String? _delayedLeaveEventId;

Timer? _restartDelayedLeaveEventTimer;

extension FamedlyCallMemberEventsExtension on Room {
  /// a map of every users famedly call event, holds the memberships list
  /// returns sorted according to originTs (oldest to newest)
  Map<String, FamedlyCallMemberEvent> getFamedlyCallEvents(VoIP voip) {
    final Map<String, FamedlyCallMemberEvent> mappedEvents = {};
    final famedlyCallMemberStates =
        states.tryGetMap<String, Event>(EventTypes.GroupCallMember);

    if (famedlyCallMemberStates == null) return {};
    final sortedEvents = famedlyCallMemberStates.values
        .sorted((a, b) => a.originServerTs.compareTo(b.originServerTs));

    for (final element in sortedEvents) {
      mappedEvents.addAll(
        {element.stateKey!: FamedlyCallMemberEvent.fromJson(element, voip)},
      );
    }
    return mappedEvents;
  }

  /// extracts memberships list form a famedly call event and maps it to a userid
  /// returns sorted (oldest to newest)
  Map<String, List<CallMembership>> getCallMembershipsFromRoom(VoIP voip) {
    final parsedMemberEvents = getFamedlyCallEvents(voip);
    final Map<String, List<CallMembership>> memberships = {};
    for (final element in parsedMemberEvents.entries) {
      memberships.addAll({element.key: element.value.memberships});
    }
    return memberships;
  }

  /// returns a list of memberships in the room for `user`
  /// if room version is org.matrix.msc3757.11 it also uses the deviceId
  List<CallMembership> getCallMembershipsForUser(
    String userId,
    String deviceId,
    VoIP voip,
  ) {
    final useMSC3757 = (roomVersion?.contains('msc3757') ?? false);
    final stateKey = voip.useUnprotectedPerDeviceStateKeys
        ? '${deviceId}_$userId'
        : useMSC3757
            ? '${userId}_$deviceId'
            : userId;
    final parsedMemberEvents = getCallMembershipsFromRoom(voip);
    final mem = parsedMemberEvents.tryGet<List<CallMembership>>(stateKey);
    return mem ?? [];
  }

  /// returns the user count (not sessions, yet) for the group call with id: `groupCallId`.
  /// returns 0 if group call not found
  int groupCallParticipantCount(
    String groupCallId,
    VoIP voip,
  ) {
    int participantCount = 0;
    // userid:membership
    final memberships = getCallMembershipsFromRoom(voip);

    memberships.forEach((key, value) {
      for (final membership in value) {
        if (membership.callId == groupCallId && !membership.isExpired) {
          participantCount++;
        }
      }
    });

    return participantCount;
  }

  bool hasActiveGroupCall(VoIP voip) {
    if (activeGroupCallIds(voip).isNotEmpty) {
      return true;
    }
    return false;
  }

  /// list of active group call ids
  List<String> activeGroupCallIds(VoIP voip) {
    final Set<String> ids = {};
    final memberships = getCallMembershipsFromRoom(voip);

    memberships.forEach((key, value) {
      for (final mem in value) {
        if (!mem.isExpired) ids.add(mem.callId);
      }
    });
    return ids.toList();
  }

  /// passing no `CallMembership` removes it from the state event.
  /// Returns the event ID of the new membership state event.
  Future<String?> updateFamedlyCallMemberStateEvent(
    CallMembership callMembership,
  ) async {
    final ownMemberships = getCallMembershipsForUser(
      client.userID!,
      client.deviceID!,
      callMembership.voip,
    );

    // do not bother removing other deviceId expired events because we have no
    // ownership over them
    ownMemberships
        .removeWhere((element) => client.deviceID! == element.deviceId);

    ownMemberships.removeWhere((e) => e == callMembership);

    ownMemberships.add(callMembership);

    final newContent = {
      'memberships': List.from(ownMemberships.map((e) => e.toJson())),
    };

    return await setFamedlyCallMemberEvent(
      newContent,
      callMembership.voip,
      callMembership.callId,
      application: callMembership.application,
      scope: callMembership.scope,
    );
  }

  Future<void> removeFamedlyCallMemberEvent(
    String groupCallId,
    VoIP voip, {
    String? application = 'm.call',
    String? scope = 'm.room',
  }) async {
    final ownMemberships = getCallMembershipsForUser(
      client.userID!,
      client.deviceID!,
      voip,
    );

    ownMemberships.removeWhere(
      (mem) =>
          mem.callId == groupCallId &&
          mem.deviceId == client.deviceID! &&
          mem.application == application &&
          mem.scope == scope,
    );

    final newContent = {
      'memberships': List.from(ownMemberships.map((e) => e.toJson())),
    };
    await setFamedlyCallMemberEvent(
      newContent,
      voip,
      groupCallId,
      application: application,
      scope: scope,
    );

    _restartDelayedLeaveEventTimer?.cancel();
    if (_delayedLeaveEventId != null) {
      await client.manageDelayedEvent(
        _delayedLeaveEventId!,
        DelayedEventAction.cancel,
      );
      _delayedLeaveEventId = null;
    }
  }

  Future<String?> setFamedlyCallMemberEvent(
    Map<String, List> newContent,
    VoIP voip,
    String groupCallId, {
    String? application = 'm.call',
    String? scope = 'm.room',
  }) async {
    final useMSC3757 = (roomVersion?.contains('msc3757') ?? false);

    if (canJoinGroupCall) {
      final stateKey = voip.useUnprotectedPerDeviceStateKeys
          ? '${client.deviceID!}_${client.userID!}'
          : useMSC3757
              ? '${client.userID!}_${client.deviceID!}'
              : client.userID!;

      final useDelayedEvents = (await client.versionsResponse)
              .unstableFeatures?['org.matrix.msc4140'] ??
          false;

      /// can use delayed events and haven't used it yet
      if (useDelayedEvents && _delayedLeaveEventId == null) {
        // get existing ones and cancel them
        final List<ScheduledDelayedEvent> alreadyScheduledEvents = [];
        String? nextBatch;
        final sEvents = await client.getScheduledDelayedEvents();
        alreadyScheduledEvents.addAll(sEvents.scheduledEvents);
        nextBatch = sEvents.nextBatch;
        while (nextBatch != null || (nextBatch?.isNotEmpty ?? false)) {
          final res = await client.getScheduledDelayedEvents();
          alreadyScheduledEvents.addAll(
            res.scheduledEvents,
          );
          nextBatch = res.nextBatch;
        }

        final toCancelEvents = alreadyScheduledEvents.where(
          (element) => element.stateKey == stateKey,
        );

        for (final toCancelEvent in toCancelEvents) {
          await client.manageDelayedEvent(
            toCancelEvent.delayId,
            DelayedEventAction.cancel,
          );
        }

        Map<String, List> newContent;
        if (useMSC3757) {
          // scoped to deviceIds so clear the whole mems list
          newContent = {
            'memberships': [],
          };
        } else {
          // only clear our own deviceId
          final ownMemberships = getCallMembershipsForUser(
            client.userID!,
            client.deviceID!,
            voip,
          );

          ownMemberships.removeWhere(
            (mem) =>
                mem.callId == groupCallId &&
                mem.deviceId == client.deviceID! &&
                mem.application == application &&
                mem.scope == scope,
          );

          newContent = {
            'memberships': List.from(ownMemberships.map((e) => e.toJson())),
          };
        }

        _delayedLeaveEventId = await client.setRoomStateWithKeyWithDelay(
          id,
          EventTypes.GroupCallMember,
          stateKey,
          voip.timeouts!.delayedEventApplyLeave.inMilliseconds,
          newContent,
        );

        _restartDelayedLeaveEventTimer = Timer.periodic(
          voip.timeouts!.delayedEventRestart,
          ((timer) async {
            Logs()
                .v('[_restartDelayedLeaveEventTimer] heartbeat delayed event');
            await client.manageDelayedEvent(
              _delayedLeaveEventId!,
              DelayedEventAction.restart,
            );
          }),
        );
      }

      return await client.setRoomStateWithKey(
        id,
        EventTypes.GroupCallMember,
        stateKey,
        newContent,
      );
    } else {
      throw MatrixSDKVoipException(
        '''
        User ${client.userID}:${client.deviceID} is not allowed to join famedly calls in room $id,
        canJoinGroupCall: $canJoinGroupCall,
        groupCallsEnabledForEveryone: $groupCallsEnabledForEveryone,
        needed: ${powerForChangingStateEvent(EventTypes.GroupCallMember)},
        own: $ownPowerLevel}
        plMap: ${getState(EventTypes.RoomPowerLevels)?.content}
        ''',
      );
    }
  }

  /// returns a list of memberships from a famedly call matrix event
  List<CallMembership> getCallMembershipsFromEvent(
    MatrixEvent event,
    VoIP voip,
  ) {
    if (event.roomId != id) return [];
    return getCallMembershipsFromEventContent(
      event.content,
      event.senderId,
      event.roomId!,
      event.eventId,
      voip,
    );
  }

  /// returns a list of memberships from a famedly call matrix event
  List<CallMembership> getCallMembershipsFromEventContent(
    Map<String, Object?> content,
    String senderId,
    String roomId,
    String? eventId,
    VoIP voip,
  ) {
    final mems = content.tryGetList<Map>('memberships');
    final callMems = <CallMembership>[];
    for (final m in mems ?? []) {
      final mem = CallMembership.fromJson(m, senderId, roomId, eventId, voip);
      if (mem != null) callMems.add(mem);
    }
    return callMems;
  }
}

bool isValidMemEvent(Map<String, Object?> event) {
  if (event['call_id'] is String &&
      event['device_id'] is String &&
      event['expires_ts'] is num &&
      event['foci_active'] is List) {
    return true;
  } else {
    Logs()
        .v('[VOIP] FamedlyCallMemberEvent ignoring unclean membership $event');
    return false;
  }
}

class MatrixSDKVoipException implements Exception {
  final String cause;
  final StackTrace? stackTrace;

  MatrixSDKVoipException(this.cause, {this.stackTrace});

  @override
  String toString() => '[VOIP] $cause, ${super.toString()}, $stackTrace';
}
