import 'package:matrix/matrix.dart';
import 'package:matrix/src/voip/models/call_membership.dart';

extension FamedlyCallMemberEventsExtension on Room {
  /// a map of every users famedly call event, holds the memberships list
  Map<String, FamedlyCallMemberEvent> getFamedlyCallEvents() {
    final Map<String, FamedlyCallMemberEvent> mappedEvents = {};
    final famedlyCallMemberStates =
        states.tryGetMap<String, Event>(famedlyCallMemberEventType);

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
    final mems = event.content.tryGetList<Map<String, Object>>('memberships');
    return mems
            ?.map((e) =>
                CallMembership.fromJson(e, event.senderId, event.roomId!))
            .toList() ??
        [];
  }

  /// Gets the states from the server
  Future<List<MatrixEvent>> getAllFamedlyCallMemberStateEvents() async {
    final roomStates = await client.getRoomState(id);
    roomStates.sort((a, b) => a.originServerTs.compareTo(b.originServerTs));
    return roomStates
        .where((element) => element.type == famedlyCallMemberEventType)
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

  /// checks for stale calls in a room and sends `m.terminated` if all the
  /// expires_ts are expired. Called regularly on sync.
  Future<void> singleShotStaleCallCheckerOnRoom() async {
    if (partial) return;
    await updateFamedlyCallMemberStateEvent(null);
  }

  /// passing no `CallMembership` removes it from the state event.
  Future<void> updateFamedlyCallMemberStateEvent(
      CallMembership? newCallMembership) async {
    final ownMemberships = getCallMembershipsForUser(client.userID!);

    ownMemberships.removeWhere((element) => element.isExpired);

    ownMemberships.removeWhere((e) => e == newCallMembership);

    if (newCallMembership != null) {
      ownMemberships.add(newCallMembership);
    }

    final newContent = {
      'memberships': List.from(ownMemberships.map((e) => e.toJson()))
    };

    await client.setRoomStateWithKey(
      id,
      famedlyCallMemberEventType,
      client.userID!,
      newContent,
    );
  }
}

extension GroupCallClientUtils on Client {
  // call after sync
  Future<void> singleShotStaleCallChecker() async {
    if (lastStaleCallRun
        .add(FamedlyCallMemberEventsExtension.staleCallCheckerDuration)
        .isBefore(DateTime.now())) {
      await Future.wait(rooms
          .where((r) => r.membership == Membership.join)
          .map((r) => r.singleShotStaleCallCheckerOnRoom()));
    }
  }
}
