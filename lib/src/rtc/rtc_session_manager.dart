import 'package:matrix/matrix.dart';
import 'package:matrix/src/rtc/models/call_membership.dart';
import 'package:matrix/src/rtc/models/webrtc_delegate.dart';
import 'package:matrix/src/rtc/utils/constants.dart';
import 'package:matrix/src/rtc/utils/ice_extension.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';

final famedlyCallMembershipStateEventType = 'com.famedly.call.member';

class RTCSessionManager {
  final Client client;
  final WebRTCDelegate delegate;

  // roomId:RTCSession
  final Map<String, RTCSession> rtcSessions = {};

  RTCSessionManager({required this.client, required this.delegate}) {
    for (final room in client.rooms) {
      rtcSessions.addAll({room.id: getEventsAndCreateRTCSessions(room)});
    }
    client.onRoomState.stream.listen(
      (event) async {
        if (event.type == famedlyCallMembershipStateEventType) {
          Logs().v('[VOIP] onRoomState: type ${event.toJson()}.');
          final callMembershipUpdate = getCallMembershipFromEvent(event);
          if (rtcSessions[event.roomId] != null) {
            rtcSessions[event.roomId]!.callMemberships = callMembershipUpdate;
          } else {
            rtcSessions.addAll(
                {event.room.id: getEventsAndCreateRTCSessions(event.room)});
          }
        }
      },
    );

    client.onToDeviceEventChunk.stream.listen(
      (List<ToDeviceEvent> events) async {
        for (final event in events) {
          if (event.type.startsWith('com.famedly.toDevice.call.')) {
            Logs().v('[VOIP] onToDeviceEvent: type ${event.toJson()}.');
            final roomId = event.content.tryGet<String>('room_id');
            final callId = event.content.tryGet<String>('call_id');
            final rtcSessionsForRoom = rtcSessions[roomId];

            if (roomId == null ||
                callId == null ||
                rtcSessionsForRoom == null) {
              Logs().w('Ignoring event something was null');
              return;
            }

            // you almost never need to send a message to your own device
            final deviceId = event.content.tryGet<String>('device_id');
            if (deviceId == client.deviceID) {
              return;
            }

            if (event.type == 'com.famedly.toDevice.call.invite' &&
                events
                    .where((event) =>
                        event.type == 'com.famedly.toDevice.call.ended')
                    .isEmpty) {
              await rtcSessionsForRoom.onCallInvite(event);
            }
            // TODO make this
            // switch (event.type) {
            //   case EventTypes.CallInvite:
            //     await rtcSession.onCallInvite(event);
            //     break;
            //   case EventTypes.CallAnswer:
            //     await rtcSession.onCallAnswer(event);
            //     break;
            //   case EventTypes.CallCandidates:
            //     await rtcSession.onCallCandidates(event);
            //     break;
            //   case EventTypes.CallHangup:
            //     await rtcSession.onCallHangup(event);
            //     break;
            //   case EventTypes.CallReject:
            //     await rtcSession.onCallReject(event);
            //     break;
            //   case EventTypes.CallNegotiate:
            //     await rtcSession.onCallNegotiate(event);
            //     break;
            //   case EventTypes.CallReplaces:
            //     await rtcSession.onCallReplaces(event);
            //     break;
            //   case EventTypes.CallSelectAnswer:
            //     await rtcSession.onCallSelectAnswer(event);
            //     break;
            //   case EventTypes.CallSDPStreamMetadataChanged:
            //   case EventTypes.CallSDPStreamMetadataChangedPrefix:
            //     await rtcSession.onSDPStreamMetadataChangedReceived(event);
            //     break;
            //   case EventTypes.CallAssertedIdentity:
            //     await rtcSession.onAssertedIdentityReceived(event);
            //     break;
            // }
          }
        }
      },
    );

    // Calling events can be omitted if they are outdated from the same sync. So
    // we collect them first before we handle them.
    //   final callEvents = <Event>{};

    //   client.onFamedlyCallEvent.stream.listen((update) {
    //     final callEvent = Event.fromJson(update.event.content, update.room);
    //     final callId = callEvent.content.tryGet<String>('call_id');
    //     callEvents.add(callEvent);

    //     // Call Invites should be omitted for a call that is already answered,
    //     // has ended, is rejectd or replaced.
    //     if (callEndedEventTypes.contains(callEvent.type)) {
    //       callEvents.removeWhere((event) {
    //         if (ommitWhenCallEndedTypes.contains(event.type) &&
    //             event.content.tryGet<String>('call_id') == callId) {
    //           Logs().v(
    //               'Ommit "${event.type}" event for an already terminated call');
    //           return true;
    //         }
    //         return false;
    //       });
    //     }

    //     final age = callEvent.unsigned?.tryGet<int>('age') ??
    //         (DateTime.now().millisecondsSinceEpoch -
    //             callEvent.originServerTs.millisecondsSinceEpoch);

    //     callEvents.removeWhere((element) {
    //       if (callEvent.type == EventTypes.CallInvite &&
    //           age >
    //               (callEvent.content.tryGet<int>('lifetime') ??
    //                   CallTimeouts.callInviteLifetime.inMilliseconds)) {
    //         Logs().v(
    //             'Ommiting invite event ${callEvent.eventId} as age was older than lifetime');
    //         return true;
    //       }
    //       return false;
    //     });
    //   });
    //   callEvents.forEach(_callStreamByCallEvent);
    // }

    // void _callStreamByCallEvent(Event event) async {
    //   final roomId = event.content.tryGet<String>('room_id');
    //   final callId = event.content.tryGet<String>('call_id');
    //   final rtcSessionsForRoom = rtcSessions[roomId];

    //   if (roomId == null || callId == null || rtcSessionsForRoom == null) {
    //     Logs().w('Ignoring event something was null');
    //     return;
    //   }
    //   final rtcSession = rtcSessionsForRoom.singleWhere(
    //       (rtcSession) => rtcSession.callMembership.callId == callId);
    //   if (event.type == EventTypes.CallInvite) {
    //     await rtcSession.onCallInvite(event);
    //   } else if (event.type == EventTypes.CallHangup) {
    //     await rtcSession.onCallHangup(event);
    //   } else if (event.type == EventTypes.CallAnswer) {
    //     await rtcSession.onCallAnswer(event);
    //   } else if (event.type == EventTypes.CallCandidates) {
    //     await rtcSession.onCallCandidates(event);
    //   } else if (event.type == EventTypes.CallSelectAnswer) {
    //     await rtcSession.onCallSelectAnswer(event);
    //   } else if (event.type == EventTypes.CallReject) {
    //     await rtcSession.onCallReject(event);
    //   } else if (event.type == EventTypes.CallNegotiate) {
    //     await rtcSession.onCallNegotiate(event);
    //   } else if (event.type == EventTypes.CallReplaces) {
    //     await rtcSession.onCallReplaces(event);
    //   } else if (event.type == EventTypes.CallAssertedIdentity ||
    //       event.type == EventTypes.CallAssertedIdentityPrefix) {
    //     await rtcSession.onAssertedIdentityReceived(event);
    //   } else if (event.type == EventTypes.CallSDPStreamMetadataChanged ||
    //       event.type == EventTypes.CallSDPStreamMetadataChangedPrefix) {
    //     await rtcSession.onSDPStreamMetadataChangedReceived(event);
    //   } else if (event.type == EventTypes.GroupCallMemberPrefix) {
    //     await rtcSession.asdfasdf(event);
    //   }
  }

  RTCSession getEventsAndCreateRTCSessions(Room room) {
    final events = room.states
        .tryGetMap<String, Event>(famedlyCallMembershipStateEventType);

    final List<CallMembership> callMembershipsInRoom = [];

    for (final event in events?.values.toList() ?? []) {
      callMembershipsInRoom.addAll(getCallMembershipFromEvent(event));
    }

    return RTCSession(
      client: client,
      room: room,
      callMemberships: callMembershipsInRoom,
      delegate: delegate,
    );
  }

  List<CallMembership> getCallMembershipFromEvent(Event event) {
    final List<CallMembership> callMembershipsInEvent = [];

    final memberships =
        event.content.tryGetList<Map<String, Object>>('memberships');
    for (final membership in memberships ?? []) {
      callMembershipsInEvent.add(
        CallMembership.fromJson(
          membership,
          event.senderId,
        ),
      );
    }

    return callMembershipsInEvent;
  }
}




// class FamedlyCallEvent {
//   final BasicEvent event;
//   final Room room;

//   FamedlyCallEvent({
//     required this.event,
//     required this.room,
//   });
// }
