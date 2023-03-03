import 'dart:async';

import 'package:collection/collection.dart';

import 'package:matrix/matrix.dart';

extension GroupCallUtils on Room {
  /// returns the user count (not sessions, yet) for the group call with id: `groupCallId`.
  /// returns 0 if group call not found
  int? groupCallParticipantCount(String groupCallId) {
    int participantCount = 0;
    final groupCallMemberStates =
        states.tryGetMap<String, Event>(EventTypes.GroupCallMemberPrefix);
    if (groupCallMemberStates != null) {
      groupCallMemberStates.forEach((userId, memberStateEvent) {
        if (!callMemberStateIsExpired(memberStateEvent, groupCallId)) {
          participantCount++;
        }
      });
    }
    return participantCount;
  }

  bool get hasActiveGroupCall {
    if (activeGroupCallEvents.isNotEmpty) {
      return true;
    }
    return false;
  }

  /// list of active group calls
  List<Event> get activeGroupCallEvents {
    final groupCallStates =
        states.tryGetMap<String, Event>(EventTypes.GroupCallPrefix);
    if (groupCallStates != null) {
      groupCallStates.values
          .toList()
          .sort((a, b) => a.originServerTs.compareTo(b.originServerTs));
      return groupCallStates.values
          .where((element) => !element.content.containsKey('m.terminated'))
          .toList();
    }
    return [];
  }

  /// stops the stale call checker timer
  void stopStaleCallsChecker(String roomId) {
    if (staleGroupCallsTimer.tryGet(roomId) != null) {
      staleGroupCallsTimer[roomId]!.cancel();
      staleGroupCallsTimer.remove(roomId);
      Logs().d('stopped stale group calls checker for room $id');
    } else {
      Logs().w('[VOIP] no stale call checker for room found');
    }
  }

  static const staleCallCheckerDuration = Duration(seconds: 30);

  bool callMemberStateIsExpired(
      MatrixEvent groupCallMemberStateEvent, String groupCallId) {
    final callMemberState =
        IGroupCallRoomMemberState.fromJson(groupCallMemberStateEvent);
    final calls = callMemberState.calls;
    if (calls.isNotEmpty) {
      final call =
          calls.singleWhereOrNull((call) => call.call_id == groupCallId);
      if (call != null) {
        return call.devices.where((device) => device.expires_ts != null).every(
            (device) =>
                device.expires_ts! < DateTime.now().millisecondsSinceEpoch);
      }
    }
    return true;
  }

  /// checks for stale calls in a room and sends `m.terminated` if all the
  /// expires_ts are expired. Call when opening a room
  void startStaleCallsChecker(String roomId) async {
    stopStaleCallsChecker(roomId);
    await singleShotStaleCallCheckerOnRoom();
    staleGroupCallsTimer[roomId] = Timer.periodic(
      staleCallCheckerDuration,
      (timer) async => await singleShotStaleCallCheckerOnRoom(),
    );
  }

  Future<void> singleShotStaleCallCheckerOnRoom() async {
    Logs().d('checking for stale group calls in room $id');
    final copyGroupCallIds =
        states.tryGetMap<String, Event>(EventTypes.GroupCallPrefix);
    if (copyGroupCallIds == null) return;
    for (final groupCall in copyGroupCallIds.entries) {
      final groupCallId = groupCall.key;
      final groupCallEvent = groupCall.value;

      if (groupCallEvent.content.tryGet('m.intent') == 'm.room') return;
      if (!groupCallEvent.content.containsKey('m.terminated')) {
        Logs().i('found non terminated group call with id $groupCallId');
        // call is not empty but check for stale participants (gone offline)
        // with expire_ts
        bool callExpired = true; // assume call is expired
        final callMemberEvents =
            states.tryGetMap<String, Event>(EventTypes.GroupCallMemberPrefix);
        if (callMemberEvents != null) {
          for (var i = 0; i < callMemberEvents.length; i++) {
            final groupCallMemberEventMap =
                callMemberEvents.entries.toList()[i];

            final groupCallMemberEvent = groupCallMemberEventMap.value;
            callExpired =
                callMemberStateIsExpired(groupCallMemberEvent, groupCallId);
            // no need to iterate further even if one participant says call isn't expired
            if (!callExpired) break;
          }
        }

        if (callExpired) {
          Logs().i(
              'Group call with only expired timestamps detected, terminating');
          await sendGroupCallTerminateEvent(groupCallId);
        }
      }
    }
  }

  /// returns the event_id if successful
  Future<String?> sendGroupCallTerminateEvent(String groupCallId) async {
    try {
      Logs().d('[VOIP] running sendterminator');
      final existingStateEvent =
          getState(EventTypes.GroupCallPrefix, groupCallId);
      if (existingStateEvent == null) {
        Logs().e('could not find group call with id $groupCallId');
        return null;
      }

      final req = await client
          .setRoomStateWithKey(id, EventTypes.GroupCallPrefix, groupCallId, {
        ...existingStateEvent.content,
        'm.terminated': GroupCallTerminationReason.CallEnded,
      });

      Logs().i('[VOIP] Group call $groupCallId was killed uwu');
      return req;
    } catch (e) {
      Logs().e('killing stale call $groupCallId failed. reason: $e');
      return null;
    }
  }
}
