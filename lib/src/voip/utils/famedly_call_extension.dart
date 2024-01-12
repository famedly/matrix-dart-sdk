import 'package:matrix/matrix.dart';
import 'package:matrix/src/voip/models/call_membership.dart';

extension FamedlyCallMemberEventsExtension on Room {
  /// a map of every users famedly call event, holds the memberships list
  Map<String, FamedlyCallMemberEvent> getFamedlyCallEvents() {
    final Map<String, FamedlyCallMemberEvent> mappedEvents = {};
    final famedlyCallMemberStates =
        states.tryGetMap<String, Event>(VoIPEventTypes.FamedlyCallMemberEvent);

    for (final element in famedlyCallMemberStates?.entries.toList() ?? []) {
      mappedEvents.addAll(
          {element.key: FamedlyCallMemberEvent.fromJson(element.value)});
    }
    return mappedEvents;
  }

  /// extracts memberships list form a famedly call event and maps it to a userid
  Map<String, List<CallMembership>> getCallMembershipsFromRoom() {
    final parsedMemberEvents = getFamedlyCallEvents();
    final Map<String, List<CallMembership>> memberships = {};
    for (final element in parsedMemberEvents.entries) {
      memberships.addAll({element.key: element.value.memberships});
    }
    return memberships;
  }

  /// returns a list of memberships in the room for `user`
  List<CallMembership> getCallMembershipsForUser(String userId) {
    final parsedMemberEvents = getCallMembershipsFromRoom();
    final mem = parsedMemberEvents.tryGet<List<CallMembership>>(userId);
    return mem ?? [];
  }

  /// returns a list of memberships from a famedly call matrix event
  List<CallMembership> getCallMembershipsFromEvent(MatrixEvent event) {
    if (event.roomId != id) return [];
    return getCallMembershipsFromEventContent(
        event.content, event.senderId, event.roomId!);
  }

  /// returns a list of memberships from a famedly call matrix event
  List<CallMembership> getCallMembershipsFromEventContent(
      Map<String, Object?> content, String senderId, String roomId) {
    final mems = content.tryGetList('memberships');
    return mems
            ?.map((e) => CallMembership.fromJson(e, senderId, roomId))
            .toList() ??
        [];
  }

  /// Gets the states from the server
  Future<List<MatrixEvent>> getAllFamedlyCallMemberStateEvents() async {
    final roomStates = await client.getRoomState(id);
    roomStates.sort((a, b) => a.originServerTs.compareTo(b.originServerTs));
    return roomStates
        .where(
            (element) => element.type == VoIPEventTypes.FamedlyCallMemberEvent)
        .toList();
  }

  /// returns the user count (not sessions, yet) for the group call with id: `groupCallId`.
  /// returns 0 if group call not found
  int? groupCallParticipantCount(String groupCallId) {
    int participantCount = 0;
    // userid:membership
    final memberships = getCallMembershipsFromRoom();

    memberships.forEach((key, value) {
      for (final membership in value) {
        if (membership.callId == groupCallId && !membership.isExpired) {
          participantCount++;
        }
      }
    });

    return participantCount;
  }

  bool get hasActiveGroupCall {
    if (activeGroupCallIds.isNotEmpty) {
      return true;
    }
    return false;
  }

  /// list of active group call ids
  List<String> get activeGroupCallIds {
    final List<String> ids = [];
    final memberships = getCallMembershipsFromRoom();

    memberships.forEach((key, value) {
      for (final mem in value) {
        if (!ids.contains(mem.callId) && !mem.isExpired) {
          ids.add(mem.callId);
        }
      }
    });
    return ids;
  }

  static const staleCallCheckerDuration = Duration(seconds: 30);

  /// passing no `CallMembership` removes it from the state event.
  Future<void> updateFamedlyCallMemberStateEvent(
      CallMembership callMembership) async {
    final ownMemberships = getCallMembershipsForUser(client.userID!);

    ownMemberships.removeWhere((element) => element.isExpired);

    ownMemberships.removeWhere((e) => e == callMembership);

    ownMemberships.add(callMembership);

    final newContent = {
      'memberships': List.from(ownMemberships.map((e) => e.toJson()))
    };

    await setFamedlyCallMemberEvent(newContent);
  }

  Future<void> removeExpiredFamedlyCallMemberEvents() async {
    if (partial) return;
    final ownMemberships = getCallMembershipsForUser(client.userID!);
    ownMemberships.removeWhere((element) => element.isExpired);

    final newContent = {
      'memberships': List.from(ownMemberships.map((e) => e.toJson()))
    };

    await setFamedlyCallMemberEvent(newContent);
  }

  Future<void> removeFamedlyCallMemberEvent(
    String groupCallId,
    String deviceId, {
    String? application = 'm.call',
    String? scope = 'm.room',
  }) async {
    final ownMemberships = getCallMembershipsForUser(client.userID!);

    ownMemberships.removeWhere((mem) =>
        mem.callId == groupCallId &&
        mem.deviceId == deviceId &&
        mem.application == application &&
        mem.scope == scope);

    final newContent = {
      'memberships': List.from(ownMemberships.map((e) => e.toJson()))
    };
    await setFamedlyCallMemberEvent(newContent);
  }

  Future<void> setFamedlyCallMemberEvent(Map<String, List> newContent) async {
    if (canJoinGroupCall) {
      await client.setRoomStateWithKey(
        id,
        VoIPEventTypes.FamedlyCallMemberEvent,
        client.userID!,
        newContent,
      );
    } else {
      throw Exception(
          '[VOIP] cannot send $VoIPEventTypes.FamedlyCallMemberEvent events in room: $id, fix your PLs');
    }
  }
}

extension GroupCallClientUtils on Client {
  /// checks for stale calls in a room and sends `m.terminated` if all the
  /// expires_ts are expired. Called regularly on sync.
  Future<void> singleShotStaleCallChecker() async {
    if (lastStaleCallRun
        .add(FamedlyCallMemberEventsExtension.staleCallCheckerDuration)
        .isBefore(DateTime.now())) {
      lastStaleCallRun = DateTime.now();
      await Future.wait(rooms
          .where((r) => r.membership == Membership.join && r.canJoinGroupCall)
          .map((r) => r.removeExpiredFamedlyCallMemberEvents()));
    }
  }
}
