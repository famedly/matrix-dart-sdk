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
        if (!callMemberStateForIdIsExpired(memberStateEvent, groupCallId)) {
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
          .where((element) =>
              !element.content.containsKey('m.terminated') &&
              callMemberStateIsExpired(element))
          .toList();
    }
    return [];
  }

  static const staleCallCheckerDuration = Duration(seconds: 30);

  /// checks if a member event has any existing non-expired callId
  bool callMemberStateIsExpired(MatrixEvent event) {
    final callMemberState = IGroupCallRoomMemberState.fromJson(event);
    final calls = callMemberState.calls;
    return calls
        .where((call) => call.devices.any((d) =>
            (d.expires_ts ?? 0) +
                staleCallCheckerDuration
                    .inMilliseconds > // buffer for sync glare
            DateTime.now().millisecondsSinceEpoch))
        .isEmpty;
  }

  /// checks if the member event has `groupCallId` unexpired, if not it checks if
  /// the whole event is expired or not
  bool callMemberStateForIdIsExpired(
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
                (device.expires_ts ?? 0) +
                    staleCallCheckerDuration
                        .inMilliseconds < // buffer for sync glare
                DateTime.now().millisecondsSinceEpoch);
      } else {
        Logs().d(
            '[VOIP] Did not find $groupCallId in member events, probably sync glare');
        return false;
      }
    } else {
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
  }
}
