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

    // Last 30 seconds to get yourself together.
    // This saves us from accidentally killing calls which were just created and
    // whose state event we haven't recieved yet in sync.
    // (option 2 was local echo member state events, but reverting them if anything
    // fails sounds pain)

    final expiredfr = groupCallMemberStateEvent.originServerTs
            .add(staleCallCheckerDuration)
            .millisecondsSinceEpoch <
        DateTime.now().millisecondsSinceEpoch;
    if (!expiredfr) {
      Logs().d(
          '[VOIP] Last 30 seconds for state event from ${groupCallMemberStateEvent.senderId}');
    }
    return expiredfr;
  }

  /// checks for stale calls in a room and sends `m.terminated` if all the
  /// expires_ts are expired. Called regularly on sync.
  Future<void> singleShotStaleCallCheckerOnRoom() async {
    if (partial) return;

    final copyGroupCallIds =
        states.tryGetMap<String, Event>(EventTypes.GroupCallPrefix);
    if (copyGroupCallIds == null) return;

    Logs().d('[VOIP] checking for stale group calls in room $id');

    for (final groupCall in copyGroupCallIds.entries) {
      final groupCallId = groupCall.key;
      final groupCallEvent = groupCall.value;

      if (groupCallEvent.content.tryGet('m.intent') == 'm.room') return;
      if (!groupCallEvent.content.containsKey('m.terminated')) {
        Logs().i('[VOIP] found non terminated group call with id $groupCallId');
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
              '[VOIP] Group call with only expired timestamps detected, terminating');
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
        Logs().e('[VOIP] could not find group call with id $groupCallId');
        return null;
      }

      final req = await client
          .setRoomStateWithKey(id, EventTypes.GroupCallPrefix, groupCallId, {
        ...existingStateEvent.content,
        'm.terminated': GroupCallTerminationReason.CallEnded,
      });

      Logs().i('[VOIP] Group call $groupCallId was killed uwu');
      return req;
    } catch (e, s) {
      Logs().e('[VOIP] killing stale call $groupCallId failed', e, s);
      return null;
    }
  }
}

extension GroupCallClientUtils on Client {
  // call after sync
  Future<void> singleShotStaleCallChecker() async {
    if (lastStaleCallRun
        .add(GroupCallUtils.staleCallCheckerDuration)
        .isBefore(DateTime.now())) {
      await Future.wait(rooms
          .where((r) => r.membership == Membership.join)
          .map((r) => r.singleShotStaleCallCheckerOnRoom()));
    }
  }
}
