// // import 'dart:async';
// // import 'dart:core';

// // import 'package:webrtc_interface/webrtc_interface.dart';

// // import 'package:matrix/matrix.dart';
// // import 'package:matrix/src/utils/cached_stream_controller.dart';
// // import 'package:matrix/src/rtc/models/call_options.dart';
// // import 'package:matrix/src/rtc/models/group_call_events.dart';
// // import 'package:matrix/src/rtc/models/webrtc_delegate.dart';
// // import 'package:matrix/src/rtc/utils/group_call_extension.dart';
// // import 'package:matrix/src/rtc/utils/stream_helper.dart';
// // import 'package:matrix/src/rtc/utils/types.dart';

// // /// VoIPManager
// // ///   room1 - VoipSession1
// // ///   room1 - VoipSession1
// // ///
// // ///   room2 - VoipSession1
// // ///   room2 - VoipSession1

// // everything uses message events, except encryption keys for you stream

// import 'dart:async';

// import 'package:matrix/matrix.dart';
// import 'package:matrix/src/rtc/models/call_membership.dart';
// import 'package:matrix/src/rtc/models/call_options.dart';
// import 'package:matrix/src/rtc/models/webrtc_delegate.dart';
// import 'package:matrix/src/rtc/rtc_session_manager.dart';
// import 'package:matrix/src/rtc/utils/call_helper.dart';
// import 'package:matrix/src/rtc/utils/ice_extension.dart';
// import 'package:matrix/src/rtc/utils/types.dart';
// import 'package:matrix/src/utils/cached_stream_controller.dart';
// import 'package:webrtc_interface/webrtc_interface.dart';

// /// holds the calls and groupCalls for each room.
// class RTCSession {
//   final Client client;
//   final Room room;
//   List<CallMembership> callMemberships;
//   final WebRTCDelegate delegate;

//   /// Holds all the calls for this particular RTCSession, eg: single `CallSession`
//   /// for p2p call or multiple individual `CallSession`s for a mesh group call.
//   Map<String, CallSession> calls = {};
//   Map<String, GroupCallSession> groupCalls = {};

//   RTCSession({
//     required this.client,
//     required this.room,
//     required this.callMemberships,
//     required this.delegate,
//   }) {
//     // prefetch and populate groupCalls here
//     // calls are not prefetched because they require a an explicit invite event
//   }

//   String? inviteSentWithCallId;
//   String? currentCID;
//   String? currentGroupCID;

//   final CachedStreamController<CallSession> onIncomingPeerCallInMesh =
//       CachedStreamController();

//   /// sets the call inside `calls` map.
//   CallSession createNewCall(CallOptions opts) {
//     final call = CallSession(opts);
//     calls[opts.callId] = call;
//     return call;
//   }

//   Future<void> onCallInvite(ToDeviceEvent event) async {
//     final senderId = event.senderId;
//     final content = event.content;

//     Logs().v(
//         '[VOIP] onCallInvite $senderId => ${client.userID}, \ncontent => ${content.toString()}');

//     final callId = content.tryGet<String>('call_id');
//     final partyId = content.tryGet<String>('party_id');
//     final invitee = content.tryGet<String>('invitee');
//     final lifetime = content.tryGet<int>('lifetime');

//     if (callId == null ||
//         partyId == null ||
//         lifetime == null ||
//         invitee == null) {
//       Logs().v('[VOIP] onCallInvite: Ignoring invite $callId, malformed data');
//       return;
//     }

//     // msc3401 group call invites send deviceId and senderSessionId in to device messages
//     final groupCallId = content.tryGet<String>('group_call_id');
//     final deviceId = content.tryGet<String>('device_id');
//     final senderSessionId = content.tryGet<String>('sender_session_id');

//     final call = calls[callId];

//     Logs().d(
//         '[glare] got new call $callId and currently invite was: $inviteSentWithCallId');

//     if (call != null && call.state == CallState.kEnded) {
//       // Session already exist.
//       Logs().v('[VOIP] onCallInvite: Session [$callId] already exist.');
//       return;
//     }

//     if (invitee != client.deviceID!) {
//       Logs().v('[VOIP] onCallInvite: Ignoring call invite $callId.');
//       return; // This invite was meant for another user in the room
//     }

//     if (content.tryGetMap<String, Object>('capabilities') != null) {
//       final capabilities = CallCapabilities.fromJson(
//           content.tryGetMap<String, Object>('capabilities')!);
//       Logs().v(
//           '[VOIP] CallCapabilities: dtmf => ${capabilities.dtmf}, transferee => ${capabilities.transferee}');
//     }

//     var callType = CallType.kVoice;
//     SDPStreamMetadata? sdpStreamMetadata;
//     final sdpMetaDataJson =
//         content.tryGetMap<String, Map<String, Object>>(sdpStreamMetadataKey);
//     final offerJson = content.tryGetMap<String, String>('offer');
//     final sdpString = offerJson?.tryGet<String>('sdp');
//     final typeString = offerJson?.tryGet<String>('type');

//     if (sdpMetaDataJson != null) {
//       sdpStreamMetadata = SDPStreamMetadata.fromJson(sdpMetaDataJson);
//       sdpStreamMetadata.sdpStreamMetadatas
//           .forEach((streamId, SDPStreamPurpose purpose) {
//         Logs().v(
//             '[VOIP] [$streamId] => purpose: ${purpose.purpose}, audioMuted: ${purpose.audio_muted}, videoMuted:  ${purpose.video_muted}');

//         if (!purpose.video_muted) {
//           callType = CallType.kVideo;
//         }
//       });
//     } else {
//       if (offerJson != null && sdpString != null) {
//         callType = getCallType(sdpString);
//       }
//     }

//     final opts = CallOptions(
//       rtcSession: this,
//       callId: callId,
//       groupCallId: groupCallId,
//       dir: CallDirection.kIncoming,
//       type: callType,
//       room: room,
//       localPartyId: client.deviceID!,
//       iceServers: await client.getIceSevers(),
//     );

//     final newCall = createNewCall(opts);
//     newCall.remotePartyId = partyId;
//     newCall.remoteUser = await room.requestUser(senderId);
//     newCall.opponentDeviceId = deviceId;
//     newCall.opponentSessionId = senderSessionId;
//     if (!delegate.canHandleNewCall) {
//       Logs().v(
//           '[VOIP] onCallInvite: Unable to handle new calls, maybe user is busy.');
//       await newCall.reject(reason: CallErrorCode.UserBusy, shouldEmit: false);
//       await delegate.handleMissedCall(newCall);
//       return;
//     }

//     final offer = RTCSessionDescription(sdpString, typeString);

//     /// play ringtone. We decided to play the ringtone before adding the call to
//     /// the incoming call stream because getUserMedia from initWithInvite fails
//     /// on firefox unless the tab is in focus. We should atleast be able to notify
//     /// the user about an incoming call
//     ///
//     /// Autoplay on firefox still needs interaction, without which all notifications
//     /// could be blocked.
//     if (groupCallId == null) {
//       // not a group call, playing ringtone
//       await delegate.playRingtone();
//     }

//     // When getUserMedia throws an exception, we handle it by terminating the call,
//     // and all this happens inside initWithInvite. If we set currentCID after
//     // initWithInvite, we might set it to callId even after it was reset to null
//     // by terminate.
//     // currentCID = callId;

//     await newCall.initWithInvite(callType, offer, sdpStreamMetadata, lifetime);

//     // Popup CallingPage for incoming call.
//     if (groupCallId == null && !newCall.callHasEnded) {
//       await delegate.handleNewCall(newCall);
//     }

//     if (groupCallId != null) {
//       // the stream is used to monitor incoming peer calls in a mesh call
//       onIncomingPeerCallInMesh.add(newCall);
//     }
//   }

//   Future<void> onCallAnswer(ToDeviceEvent event) async {
//     final senderId = event.senderId;
//     final content = event.content;
//     final roomId = room.id;

//     Logs().v('[VOIP] onCallAnswer => ${content.toString()}');
//     final callId = content.tryGet<String>('call_id');
//     final partyId = content.tryGet<String>('party_id');

//     final call = calls[callId];
//     if (call != null) {
//       if (senderId == client.userID) {
//         // Ignore messages to yourself.
//         if (!call.answeredByUs) {
//           await delegate.stopRingtone();
//         }
//         if (call.state == CallState.kRinging) {
//           await call.onAnsweredElsewhere();
//         }
//         return;
//       }
//       if (call.room.id != roomId) {
//         Logs().w(
//             'Ignoring call answer for room $roomId claiming to be for call in room ${call.room.id}');
//         return;
//       }
//       call.remotePartyId = partyId;
//       call.remoteUser = await call.room.requestUser(senderId);

//       final sdpMetaDataJson =
//           content.tryGetMap<String, Map<String, Object>>(sdpStreamMetadataKey);
//       final answerJson = content.tryGetMap<String, String>('answer');
//       final sdpString = answerJson?.tryGet<String>('sdp');
//       final typeString = answerJson?.tryGet<String>('type');

//       final answer = RTCSessionDescription(sdpString, typeString);

//       SDPStreamMetadata? metadata;
//       if (sdpMetaDataJson != null) {
//         metadata = SDPStreamMetadata.fromJson(sdpMetaDataJson);
//       }
//       await call.onAnswerReceived(answer, metadata);
//     } else {
//       Logs().v('[VOIP] onCallAnswer: Session [$callId] not found!');
//     }
//   }

//   Future<void> onCallCandidates(ToDeviceEvent event) async {
//     final content = event.content;
//     final roomId = room.id;

//     Logs().v('[VOIP] onCallCandidates => ${content.toString()}');
//     final callId = content.tryGet<String>('call_id');
//     final call = calls[callId];
//     if (call != null) {
//       if (call.room.id != roomId) {
//         Logs().w(
//             'Ignoring call candidates for room $roomId claiming to be for call in room ${call.room.id}');
//         return;
//       }

//       final candidates = content.tryGet<List>('candidates');
//       await call.onCandidatesReceived(candidates ?? []);
//     } else {
//       Logs().v('[VOIP] onCallCandidates: Session [$callId] not found!');
//     }
//   }

//   Future<void> onCallHangup(ToDeviceEvent event) async {
//     final content = event.content;
//     final roomId = room.id;

//     // stop play ringtone, if this is an incoming call
//     await delegate.stopRingtone();
//     Logs().v('[VOIP] onCallHangup => ${content.toString()}');
//     final callId = content.tryGet<String>('call_id');
//     final partyId = content.tryGet<String>('party_id');
//     final call = calls[callId];
//     if (call != null) {
//       if (call.room.id != roomId) {
//         Logs().w(
//             'Ignoring call hangup for room $roomId claiming to be for call in room ${call.room.id}');
//         return;
//       }
//       if (call.remotePartyId != null && call.remotePartyId != partyId) {
//         Logs().w(
//             'Ignoring call hangup from sender with a different party_id $partyId for call in room ${call.room.id}');
//         return;
//       }
//       // hangup in any case, either if the other party hung up or we did on another device
//       await call.terminate(CallParty.kRemote,
//           content.tryGet<String>('reason') ?? CallErrorCode.UserHangup, true);
//     } else {
//       Logs().v('[VOIP] onCallHangup: Session [$callId] not found!');
//     }
//   }

//   Future<void> onCallReject(ToDeviceEvent event) async {
//     final content = event.content;
//     final roomId = room.id;

//     final callId = content.tryGet<String>('call_id');
//     final partyId = content.tryGet<String>('party_id');
//     Logs().d('Reject received for call ID $callId');

//     final call = calls[callId];
//     if (call != null) {
//       if (call.room.id != roomId) {
//         Logs().w(
//             'Ignoring call reject for room $roomId claiming to be for call in room ${call.room.id}');
//         return;
//       }
//       if (call.remotePartyId != null && call.remotePartyId != partyId) {
//         Logs().w(
//             'Ignoring call reject from sender with a different party_id $partyId for call in room ${call.room.id}');
//         return;
//       }
//       await call.onRejectReceived(content.tryGet<String>('reason'));
//     } else {
//       Logs().v('[VOIP] onCallReject: Session [$callId] not found!');
//     }
//   }

//   Future<void> onCallReplaces(ToDeviceEvent event) async {
//     final content = event.content;
//     final roomId = room.id;

//     final callId = content.tryGet<String>('call_id');
//     Logs().d('onCallReplaces received for call ID $callId');
//     final call = calls[callId];
//     if (call != null) {
//       if (call.room.id != roomId) {
//         Logs().w(
//             'Ignoring call replace for room $roomId claiming to be for call in room ${call.room.id}');
//         return;
//       }
//       //TODO: handle replaces
//     }
//   }

//   Future<void> onCallSelectAnswer(ToDeviceEvent event) async {
//     final content = event.content;
//     final roomId = room.id;

//     final callId = content.tryGet<String>('call_id');
//     Logs().d('SelectAnswer received for call ID $callId');
//     final call = calls[callId];
//     final String? selectedPartyId = content.tryGet<String>('selected_party_id');

//     if (call != null) {
//       if (call.room.id != roomId) {
//         Logs().w(
//             'Ignoring call select answer for room $roomId claiming to be for call in room ${call.room.id}');
//         return;
//       }
//       await call.onSelectAnswerReceived(selectedPartyId);
//     }
//   }

//   Future<void> onSDPStreamMetadataChangedReceived(ToDeviceEvent event) async {
//     final content = event.content;
//     final roomId = room.id;

//     final callId = content.tryGet<String>('call_id');
//     Logs().d('SDP Stream metadata received for call ID $callId');
//     final call = calls[callId];
//     if (call != null) {
//       if (call.room.id != roomId) {
//         Logs().w(
//             'Ignoring call sdp metadata change for room $roomId claiming to be for call in room ${call.room.id}');
//         return;
//       }

//       if (content[sdpStreamMetadataKey] == null) {
//         Logs().d('SDP Stream metadata is null');
//         return;
//       }
//       final sdpMetaDataJson =
//           content.tryGetMap<String, Map<String, Object>>(sdpStreamMetadataKey);
//       if (sdpMetaDataJson != null) {
//         await call.onSDPStreamMetadataReceived(
//             SDPStreamMetadata.fromJson(sdpMetaDataJson));
//       }
//     }
//   }

//   Future<void> onAssertedIdentityReceived(ToDeviceEvent event) async {
//     final content = event.content;
//     final roomId = room.id;

//     final callId = content.tryGet<String>('call_id');
//     Logs().d('Asserted identity received for call ID $callId');
//     final call = calls[callId];
//     if (call != null) {
//       if (call.room.id != roomId) {
//         Logs().w(
//             'Ignoring call asserted identity for room $roomId claiming to be for call in room ${call.room.id}');
//         return;
//       }

//       if (content['asserted_identity'] == null) {
//         Logs().d('asserted_identity is null ');
//         return;
//       }
//       final assertedIdentityJson =
//           content.tryGetMap<String, Map<String, Object>>('asserted_identity');
//       if (assertedIdentityJson != null) {
//         call.onAssertedIdentityReceived(
//             AssertedIdentity.fromJson(assertedIdentityJson));
//       }
//     }
//   }

//   Future<void> onCallNegotiate(ToDeviceEvent event) async {
//     final content = event.content;
//     final roomId = room.id;

//     final callId = content.tryGet<String>('call_id');
//     final partyId = content.tryGet<String>('call_id');

//     Logs().d('Negotiate received for call ID $callId');
//     final call = calls[callId];
//     if (call != null) {
//       if (call.room.id != roomId) {
//         Logs().w(
//             'Ignoring call negotiation for room $roomId claiming to be for call in room ${call.room.id}');
//         return;
//       }
//       if (partyId != call.remotePartyId) {
//         Logs().w('Ignoring call negotiation, wrong partyId detected');
//         return;
//       }
//       if (partyId == call.localPartyId) {
//         Logs().w('Ignoring call negotiation echo');
//         return;
//       }

//       // ideally you also check the lifetime here and discard negotiation events
//       // if age of the event was older than the lifetime but as to device events
//       // do not have a unsigned age nor a origin_server_ts there's no easy way to
//       // override this one function atm

//       final sdpMetaDataJson =
//           content.tryGetMap<String, Map<String, Object>>(sdpStreamMetadataKey);
//       try {
//         SDPStreamMetadata? metadata;
//         if (sdpMetaDataJson != null) {
//           metadata = SDPStreamMetadata.fromJson(sdpMetaDataJson);
//         }
//         final descJson = content.tryGetMap<String, String>('description');
//         final sdpString = descJson?.tryGet<String>('sdp');
//         final typeString = descJson?.tryGet<String>('type');
//         await call.onNegotiateReceived(
//             metadata, RTCSessionDescription(sdpString, typeString));
//       } catch (e, s) {
//         Logs().e('Failed to complete negotiation', e, s);
//       }
//     }
//   }

//   /// Make a P2P call to room
//   ///
//   /// [roomId] The room id to call
//   ///
//   /// [type] The type of call to be made.
//   Future<CallSession> inviteToCall(String roomId, CallType type) async {
//     final callId = 'cid${DateTime.now().millisecondsSinceEpoch}';

//     final opts = CallOptions(
//       callId: callId,
//       type: type,
//       dir: CallDirection.kOutgoing,
//       room: room,
//       rtcSession: this,
//       localPartyId: client.deviceID!,
//       iceServers: await client.getIceSevers(),
//     );

//     final newCall = createNewCall(opts);
//     if (currentGroupCID == null) {
//       inviteSentWithCallId = callId;
//       currentCID = callId;
//     }
//     await newCall.initOutboundCall(type).then((_) {
//       delegate.handleNewCall(newCall);
//     });
//     return newCall;
//   }

//   /// Create a new group call in an existing room.
//   ///
//   /// [groupCallId] The room id to call
//   ///
//   /// [application] normal group call, thrirdroom, etc
//   ///
//   /// [scope] room, between specifc users, etc.
//   Future<GroupCallSession> _newGroupCall(
//     String groupCallId,
//     String? application,
//     String? scope,
//   ) async {
//     if (getGroupCallById(groupCallId) != null) {
//       Logs().e('[VOIP] [$groupCallId] already exists.');
//       return getGroupCallById(groupCallId)!;
//     }

//     final groupCall = GroupCallSession(
//       groupCallId: groupCallId,
//       client: client,
//       rtcSession: this,
//       application: application,
//       scope: scope,
//     );

//     groupCalls[groupCallId] = groupCall;

//     return groupCall;
//   }

//   /// Create a new group call in an existing room.
//   ///
//   /// [groupCallId] The room id to call
//   ///
//   /// [application] normal group call, thrirdroom, etc
//   ///
//   /// [scope] room, between specifc users, etc.
//   Future<GroupCallSession?> fetchOrCreateGroupCall(
//     String groupCallId,
//     String? application,
//     String? scope,
//   ) async {
//     final groupCall = getGroupCallById(groupCallId);

//     if (!room.groupCallsEnabled) {
//       await room.enableGroupCalls();
//     }

//     if (groupCall != null) {
//       if (!room.canJoinGroupCall) {
//         Logs().w('No permission to join group calls in room ${room.id}');
//         return null;
//       }
//       return groupCall;
//     }

//     if (room.canJoinGroupCall) {
//       // The call doesn't exist, but we can create it
//       final groupCall = await _newGroupCall(groupCallId, application, scope);
//       await groupCall.sendMemberStateEvent();

//       return groupCall;
//     }
//     return null;
//   }

//   /// global calls will be with roomId,
//   /// sub calls can have their own id
//   GroupCallSession? getGroupCallById(String groupCallId) {
//     return groupCalls[groupCallId];
//   }

//   Future<void> startGroupCalls() async {
//     final rooms = client.rooms;
//     for (final room in rooms) {
//       await createGroupCallForRoom(room);
//     }
//   }

//   Future<void> stopGroupCalls() async {
//     for (final groupCall in groupCalls.values) {
//       await groupCall.terminate();
//     }
//     groupCalls.clear();
//   }

//   /// Create a new group call in an existing room.
//   Future<void> createGroupCallForRoom(Room room) async {
//     final events = await client.getRoomState(room.id);
//     events.sort((a, b) => a.originServerTs.compareTo(b.originServerTs));

//     for (final event in events) {
//       if (event.type == EventTypes.GroupCallPrefix) {
//         if (event.content['m.terminated'] != null) {
//           return;
//         }
//         await createGroupCallFromRoomStateEvent(event);
//       }
//     }

//     return;
//   }

//   /// Create a new group call from a room state event.
//   Future<GroupCallSession?> createGroupCallFromRoomStateEvent(MatrixEvent event,
//       {bool emitHandleNewGroupCall = true}) async {
//     final roomId = event.roomId;
//     final content = event.content;

//     final groupCallId = event.stateKey;

//     final callType = content.tryGet<String>('m.type');

//     if (callType == null ||
//         callType != GroupCallType.Video && callType != GroupCallType.Voice) {
//       Logs().w('Received invalid group call type $callType for room $roomId.');
//       return null;
//     }

//     final callIntent = content.tryGet<String>('m.intent');

//     if (callIntent == null ||
//         callIntent != GroupCallIntent.Prompt &&
//             callIntent != GroupCallIntent.Room &&
//             callIntent != GroupCallIntent.Ring) {
//       Logs()
//           .w('Received invalid group call intent $callType for room $roomId.');
//       return null;
//     }

//     final groupCall = GroupCallSession(
//       client: client,
//       rtcSession: this,
//       groupCallId: groupCallId,
//     );

//     groupCalls[groupCallId!] = groupCall;
//     groupCalls[room.id] = groupCall;

//     if (emitHandleNewGroupCall) {
//       await delegate.handleNewGroupCall(groupCall);
//     }
//     return groupCall;
//   }

//   Future<void> onRoomStateChanged(MatrixEvent event) async {
//     final eventType = event.type;
//     final roomId = event.roomId;
//     if (eventType == EventTypes.GroupCallPrefix) {
//       final groupCallId = event.stateKey;
//       final content = event.content;
//       final currentGroupCall = groupCalls[groupCallId];
//       if (currentGroupCall == null && content['m.terminated'] == null) {
//         await createGroupCallFromRoomStateEvent(event);
//       } else if (currentGroupCall != null &&
//           currentGroupCall.groupCallId == groupCallId) {
//         if (content['m.terminated'] != null) {
//           await currentGroupCall.terminate(emitStateEvent: false);
//         }
//       } else if (currentGroupCall != null &&
//           currentGroupCall.groupCallId != groupCallId) {
//         // TODO: Handle new group calls and multiple group calls
//         Logs().w(
//             'Multiple group calls detected for room: $roomId. Multiple group calls are currently unsupported.');
//       }
//     } else if (eventType == EventTypes.GroupCallMemberPrefix) {
//       final groupCall = groupCalls[roomId];
//       if (groupCall == null) {
//         return;
//       }
//       await groupCall.onMemberStateChanged(event);
//     }
//   }
// }

// // /// The parent highlevel voip class, this trnslates matrix events to webrtc methods via
// // /// `CallSession` or `GroupCallSession` methods.
// // //
// // // Why is it calls voip and not webrtc? probably incase we switch the voip backend
// // // itself :3
// // class RTCSession {
// //   // used only for internal tests, all txids for call events will be overwritten to this
// //   static String? customTxid;

// //   Map<String, CallSession> calls = <String, CallSession>{};
// //   Map<String, GroupCallSession> groupCalls = <String, GroupCallSession>{};
// //   final CachedStreamController<CallSession> onIncomingCall =
// //       CachedStreamController();
// //   String? currentCID;
// //   String? currentGroupCID;
// //   String? get localPartyId => client.deviceID;
// //   final Client client;
// //   final WebRTCDelegate delegate;
// //   final StreamController<GroupCallSession> onIncomingGroupCall =
// //       StreamController();
// //   void _handleEvent(
// //           Event event,
// //           Function(String roomId, String senderId, Map<String, dynamic> content)
// //               func) =>
// //       func(event.roomId!, event.senderId, event.content);
// //   Map<String, String> incomingCallRoomId = {};

// //   RTCSession(this.client, this.delegate) : super() {
// //     // to populate groupCalls with already present calls
// //     for (final room in client.rooms) {
// //       if (room.activeGroupCallEvents.isNotEmpty) {
// //         for (final groupCall in room.activeGroupCallEvents) {
// //           // ignore: discarded_futures
// //           createGroupCallFromRoomStateEvent(groupCall,
// //               emitHandleNewGroupCall: false);
// //         }
// //       }
// //     }

// //     client.onCallInvite.stream
// //         .listen((event) => _handleEvent(event, onCallInvite));
// //     client.onCallAnswer.stream
// //         .listen((event) => _handleEvent(event, onCallAnswer));
// //     client.onCallCandidates.stream
// //         .listen((event) => _handleEvent(event, onCallCandidates));
// //     client.onCallHangup.stream
// //         .listen((event) => _handleEvent(event, onCallHangup));
// //     client.onCallReject.stream
// //         .listen((event) => _handleEvent(event, onCallReject));
// //     client.onCallNegotiate.stream
// //         .listen((event) => _handleEvent(event, onCallNegotiate));
// //     client.onCallReplaces.stream
// //         .listen((event) => _handleEvent(event, onCallReplaces));
// //     client.onCallSelectAnswer.stream
// //         .listen((event) => _handleEvent(event, onCallSelectAnswer));
// //     client.onSDPStreamMetadataChangedReceived.stream.listen(
// //         (event) => _handleEvent(event, onSDPStreamMetadataChangedReceived));
// //     client.onAssertedIdentityReceived.stream
// //         .listen((event) => _handleEvent(event, onAssertedIdentityReceived));

// //     client.onRoomState.stream.listen(
// //       (event) async {
// //         if ([
// //           EventTypes.GroupCallPrefix,
// //           EventTypes.GroupCallMemberPrefix,
// //         ].contains(event.type)) {
// //           Logs().v('[VOIP] onRoomState: type ${event.toJson()}.');
// //           await onRoomStateChanged(event);
// //         }
// //       },
// //     );

// //     client.onToDeviceEvent.stream.listen((event) async {
// //       Logs().v('[VOIP] onToDeviceEvent: type ${event.toJson()}.');

// //       if (event.type == 'org.matrix.call_duplicate_session') {
// //         Logs().v('[VOIP] onToDeviceEvent: duplicate session.');
// //         return;
// //       }

// //       final confId = event.content['group_call_id'];
// //       final groupCall = groupCalls[confId];
// //       if (groupCall == null) {
// //         Logs().d('[VOIP] onToDeviceEvent: groupCall is null.');
// //         return;
// //       }
// //       final roomId = groupCall.room.id;
// //       final senderId = event.senderId;
// //       final content = event.content;
// //       switch (event.type) {
// //         case EventTypes.CallInvite:
// //           await onCallInvite(roomId, senderId, content);
// //           break;
// //         case EventTypes.CallAnswer:
// //           await onCallAnswer(roomId, senderId, content);
// //           break;
// //         case EventTypes.CallCandidates:
// //           await onCallCandidates(roomId, senderId, content);
// //           break;
// //         case EventTypes.CallHangup:
// //           await onCallHangup(roomId, senderId, content);
// //           break;
// //         case EventTypes.CallReject:
// //           await onCallReject(roomId, senderId, content);
// //           break;
// //         case EventTypes.CallNegotiate:
// //           await onCallNegotiate(roomId, senderId, content);
// //           break;
// //         case EventTypes.CallReplaces:
// //           await onCallReplaces(roomId, senderId, content);
// //           break;
// //         case EventTypes.CallSelectAnswer:
// //           await onCallSelectAnswer(roomId, senderId, content);
// //           break;
// //         case EventTypes.CallSDPStreamMetadataChanged:
// //         case EventTypes.CallSDPStreamMetadataChangedPrefix:
// //           await onSDPStreamMetadataChangedReceived(roomId, senderId, content);
// //           break;
// //         case EventTypes.CallAssertedIdentity:
// //           await onAssertedIdentityReceived(roomId, senderId, content);
// //           break;
// //       }
// //     });

// //     delegate.mediaDevices.ondevicechange = _onDeviceChange;
// //   }

// //   Future<void> _onDeviceChange(dynamic _) async {
// //     Logs().v('[VOIP] _onDeviceChange');
// //     for (final call in calls.values) {
// //       if (call.state == CallState.kConnected && !call.isGroupCall) {
// //         await call.updateAudioDevice();
// //       }
// //     }
// //     for (final groupCall in groupCalls.values) {
// //       if (groupCall.state == GroupCallState.Entered) {
// //         await groupCall.updateAudioDevice();
// //       }
// //     }
// //   }

// //

// //   @Deprecated('Call `hasActiveGroupCall` on the room directly instead')
// //   bool hasActiveCall(Room room) => room.hasActiveGroupCall;
// // }

import 'dart:async';
import 'dart:core';

import 'package:matrix/src/rtc/models/call_options.dart';
import 'package:matrix/src/rtc/models/group_call_events.dart';
import 'package:matrix/src/rtc/models/webrtc_delegate.dart';
import 'package:matrix/src/rtc/utils/call_helper.dart';
import 'package:matrix/src/rtc/utils/group_call_extension.dart';
import 'package:matrix/src/rtc/utils/types.dart';

import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';

/// The parent highlevel voip class, this trnslates matrix events to webrtc methods via
/// `CallSession` or `GroupCallSession` methods
class VoIP {
  // used only for internal tests, all txids for call events will be overwritten to this
  static String? customTxid;

  Map<String, CallSession> calls = <String, CallSession>{};
  Map<String, GroupCallSession> groupCalls = <String, GroupCallSession>{};
  final CachedStreamController<CallSession> onIncomingCall =
      CachedStreamController();
  String? currentCID;
  String? currentGroupCID;
  String? get localPartyId => client.deviceID;
  final Client client;
  final WebRTCDelegate delegate;
  final StreamController<GroupCallSession> onIncomingGroupCall =
      StreamController();

  Map<String, String> incomingCallRoomId = {};

  VoIP(this.client, this.delegate) : super() {
    // to populate groupCalls with already present calls
    for (final room in client.rooms) {
      if (room.activeGroupCallEvents.isNotEmpty) {
        for (final groupCall in room.activeGroupCallEvents) {
          // ignore: discarded_futures
          createGroupCallFromRoomStateEvent(groupCall,
              emitHandleNewGroupCall: false);
        }
      }
    }

    // client.onCallInvite.stream
    //     .listen((event) => _handleEvent(event, onCallInvite));
    // client.onCallAnswer.stream
    //     .listen((event) => _handleEvent(event, onCallAnswer));
    // client.onCallCandidates.stream
    //     .listen((event) => _handleEvent(event, onCallCandidates));
    // client.onCallHangup.stream
    //     .listen((event) => _handleEvent(event, onCallHangup));
    // client.onCallReject.stream
    //     .listen((event) => _handleEvent(event, onCallReject));
    // client.onCallNegotiate.stream
    //     .listen((event) => _handleEvent(event, onCallNegotiate));
    // client.onCallReplaces.stream
    //     .listen((event) => _handleEvent(event, onCallReplaces));
    // client.onCallSelectAnswer.stream
    //     .listen((event) => _handleEvent(event, onCallSelectAnswer));
    // client.onSDPStreamMetadataChangedReceived.stream.listen(
    //     (event) => _handleEvent(event, onSDPStreamMetadataChangedReceived));
    // client.onAssertedIdentityReceived.stream
    //     .listen((event) => _handleEvent(event, onAssertedIdentityReceived));

    client.onRoomState.stream.listen(
      (event) async {
        if ([
          EventTypes.GroupCallPrefix,
          EventTypes.GroupCallMemberPrefix,
        ].contains(event.type)) {
          Logs().v('[VOIP] onRoomState: type ${event.toJson()}.');
          await onRoomStateChanged(event);
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

            if (roomId == null || callId == null) {
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
              await onCallInvite(event);
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

    delegate.mediaDevices.ondevicechange = _onDeviceChange;
  }

  Future<void> _onDeviceChange(dynamic _) async {
    Logs().v('[VOIP] _onDeviceChange');
    for (final call in calls.values) {
      if (call.state == CallState.kConnected && !call.isGroupCall) {
        await call.updateAudioDevice();
      }
    }
    for (final groupCall in groupCalls.values) {
      if (groupCall.state == GroupCallState.Entered) {
        await groupCall.updateAudioDevice();
      }
    }
  }

  CallSession createNewCall(CallOptions opts) {
    final call = CallSession(opts);
    calls[opts.callId] = call;
    return call;
  }

  Future<void> onCallInvite(ToDeviceEvent event) async {
    final senderId = event.senderId;
    final content = event.content;

    Logs().v(
        '[VOIP] onCallInvite $senderId => ${client.userID}, \ncontent => ${content.toString()}');

    final callId = content.tryGet<String>('call_id');
    final partyId = content.tryGet<String>('party_id');
    final invitee = content.tryGet<String>('invitee');
    final lifetime = content.tryGet<int>('lifetime');

    if (callId == null ||
        partyId == null ||
        lifetime == null ||
        invitee == null) {
      Logs().v('[VOIP] onCallInvite: Ignoring invite $callId, malformed data');
      return;
    }

    // msc3401 group call invites send deviceId and senderSessionId in to device messages
    final groupCallId = content.tryGet<String>('group_call_id');
    final deviceId = content.tryGet<String>('device_id');
    final senderSessionId = content.tryGet<String>('sender_session_id');

    final call = calls[callId];

    Logs().d(
        '[glare] got new call $callId and currently invite was: $inviteSentWithCallId');

    if (call != null && call.state == CallState.kEnded) {
      // Session already exist.
      Logs().v('[VOIP] onCallInvite: Session [$callId] already exist.');
      return;
    }

    if (invitee != client.deviceID!) {
      Logs().v('[VOIP] onCallInvite: Ignoring call invite $callId.');
      return; // This invite was meant for another user in the room
    }

    if (content.tryGetMap<String, Object>('capabilities') != null) {
      final capabilities = CallCapabilities.fromJson(
          content.tryGetMap<String, Object>('capabilities')!);
      Logs().v(
          '[VOIP] CallCapabilities: dtmf => ${capabilities.dtmf}, transferee => ${capabilities.transferee}');
    }

    var callType = CallType.kVoice;
    SDPStreamMetadata? sdpStreamMetadata;
    final sdpMetaDataJson =
        content.tryGetMap<String, Map<String, Object>>(sdpStreamMetadataKey);
    final offerJson = content.tryGetMap<String, String>('offer');
    final sdpString = offerJson?.tryGet<String>('sdp');
    final typeString = offerJson?.tryGet<String>('type');

    if (sdpMetaDataJson != null) {
      sdpStreamMetadata = SDPStreamMetadata.fromJson(sdpMetaDataJson);
      sdpStreamMetadata.sdpStreamMetadatas
          .forEach((streamId, SDPStreamPurpose purpose) {
        Logs().v(
            '[VOIP] [$streamId] => purpose: ${purpose.purpose}, audioMuted: ${purpose.audio_muted}, videoMuted:  ${purpose.video_muted}');

        if (!purpose.video_muted) {
          callType = CallType.kVideo;
        }
      });
    } else {
      if (offerJson != null && sdpString != null) {
        callType = getCallType(sdpString);
      }
    }

    final opts = CallOptions(
      voip: this,
      callId: callId,
      groupCallId: groupCallId,
      dir: CallDirection.kIncoming,
      type: callType,
      room: client.getRoomById(),
      localPartyId: client.deviceID!,
      iceServers: await client.getIceSevers(),
    );

    final newCall = createNewCall(opts);
    newCall.remotePartyId = partyId;
    newCall.remoteUser = await room.requestUser(senderId);
    newCall.opponentDeviceId = deviceId;
    newCall.opponentSessionId = senderSessionId;
    if (!delegate.canHandleNewCall) {
      Logs().v(
          '[VOIP] onCallInvite: Unable to handle new calls, maybe user is busy.');
      await newCall.reject(reason: CallErrorCode.UserBusy, shouldEmit: false);
      await delegate.handleMissedCall(newCall);
      return;
    }

    final offer = RTCSessionDescription(sdpString, typeString);

    /// play ringtone. We decided to play the ringtone before adding the call to
    /// the incoming call stream because getUserMedia from initWithInvite fails
    /// on firefox unless the tab is in focus. We should atleast be able to notify
    /// the user about an incoming call
    ///
    /// Autoplay on firefox still needs interaction, without which all notifications
    /// could be blocked.
    if (groupCallId == null) {
      // not a group call, playing ringtone
      await delegate.playRingtone();
    }

    // When getUserMedia throws an exception, we handle it by terminating the call,
    // and all this happens inside initWithInvite. If we set currentCID after
    // initWithInvite, we might set it to callId even after it was reset to null
    // by terminate.
    // currentCID = callId;

    await newCall.initWithInvite(callType, offer, sdpStreamMetadata, lifetime);

    // Popup CallingPage for incoming call.
    if (groupCallId == null && !newCall.callHasEnded) {
      await delegate.handleNewCall(newCall);
    }

    if (groupCallId != null) {
      // the stream is used to monitor incoming peer calls in a mesh call
      onIncomingPeerCallInMesh.add(newCall);
    }
  }

  Future<void> onCallAnswer(ToDeviceEvent event) async {
    final senderId = event.senderId;
    final content = event.content;
    final roomId = room.id;

    Logs().v('[VOIP] onCallAnswer => ${content.toString()}');
    final callId = content.tryGet<String>('call_id');
    final partyId = content.tryGet<String>('party_id');

    final call = calls[callId];
    if (call != null) {
      if (senderId == client.userID) {
        // Ignore messages to yourself.
        if (!call.answeredByUs) {
          await delegate.stopRingtone();
        }
        if (call.state == CallState.kRinging) {
          await call.onAnsweredElsewhere();
        }
        return;
      }
      if (call.room.id != roomId) {
        Logs().w(
            'Ignoring call answer for room $roomId claiming to be for call in room ${call.room.id}');
        return;
      }
      call.remotePartyId = partyId;
      call.remoteUser = await call.room.requestUser(senderId);

      final sdpMetaDataJson =
          content.tryGetMap<String, Map<String, Object>>(sdpStreamMetadataKey);
      final answerJson = content.tryGetMap<String, String>('answer');
      final sdpString = answerJson?.tryGet<String>('sdp');
      final typeString = answerJson?.tryGet<String>('type');

      final answer = RTCSessionDescription(sdpString, typeString);

      SDPStreamMetadata? metadata;
      if (sdpMetaDataJson != null) {
        metadata = SDPStreamMetadata.fromJson(sdpMetaDataJson);
      }
      await call.onAnswerReceived(answer, metadata);
    } else {
      Logs().v('[VOIP] onCallAnswer: Session [$callId] not found!');
    }
  }

  Future<void> onCallCandidates(ToDeviceEvent event) async {
    final content = event.content;
    final roomId = room.id;

    Logs().v('[VOIP] onCallCandidates => ${content.toString()}');
    final callId = content.tryGet<String>('call_id');
    final call = calls[callId];
    if (call != null) {
      if (call.room.id != roomId) {
        Logs().w(
            'Ignoring call candidates for room $roomId claiming to be for call in room ${call.room.id}');
        return;
      }

      final candidates = content.tryGet<List>('candidates');
      await call.onCandidatesReceived(candidates ?? []);
    } else {
      Logs().v('[VOIP] onCallCandidates: Session [$callId] not found!');
    }
  }

  Future<void> onCallHangup(ToDeviceEvent event) async {
    final content = event.content;
    final roomId = room.id;

    // stop play ringtone, if this is an incoming call
    await delegate.stopRingtone();
    Logs().v('[VOIP] onCallHangup => ${content.toString()}');
    final callId = content.tryGet<String>('call_id');
    final partyId = content.tryGet<String>('party_id');
    final call = calls[callId];
    if (call != null) {
      if (call.room.id != roomId) {
        Logs().w(
            'Ignoring call hangup for room $roomId claiming to be for call in room ${call.room.id}');
        return;
      }
      if (call.remotePartyId != null && call.remotePartyId != partyId) {
        Logs().w(
            'Ignoring call hangup from sender with a different party_id $partyId for call in room ${call.room.id}');
        return;
      }
      // hangup in any case, either if the other party hung up or we did on another device
      await call.terminate(CallParty.kRemote,
          content.tryGet<String>('reason') ?? CallErrorCode.UserHangup, true);
    } else {
      Logs().v('[VOIP] onCallHangup: Session [$callId] not found!');
    }
  }

  Future<void> onCallReject(ToDeviceEvent event) async {
    final content = event.content;
    final roomId = room.id;

    final callId = content.tryGet<String>('call_id');
    final partyId = content.tryGet<String>('party_id');
    Logs().d('Reject received for call ID $callId');

    final call = calls[callId];
    if (call != null) {
      if (call.room.id != roomId) {
        Logs().w(
            'Ignoring call reject for room $roomId claiming to be for call in room ${call.room.id}');
        return;
      }
      if (call.remotePartyId != null && call.remotePartyId != partyId) {
        Logs().w(
            'Ignoring call reject from sender with a different party_id $partyId for call in room ${call.room.id}');
        return;
      }
      await call.onRejectReceived(content.tryGet<String>('reason'));
    } else {
      Logs().v('[VOIP] onCallReject: Session [$callId] not found!');
    }
  }

  Future<void> onCallReplaces(ToDeviceEvent event) async {
    final content = event.content;
    final roomId = room.id;

    final callId = content.tryGet<String>('call_id');
    Logs().d('onCallReplaces received for call ID $callId');
    final call = calls[callId];
    if (call != null) {
      if (call.room.id != roomId) {
        Logs().w(
            'Ignoring call replace for room $roomId claiming to be for call in room ${call.room.id}');
        return;
      }
      //TODO: handle replaces
    }
  }

  Future<void> onCallSelectAnswer(ToDeviceEvent event) async {
    final content = event.content;
    final roomId = room.id;

    final callId = content.tryGet<String>('call_id');
    Logs().d('SelectAnswer received for call ID $callId');
    final call = calls[callId];
    final String? selectedPartyId = content.tryGet<String>('selected_party_id');

    if (call != null) {
      if (call.room.id != roomId) {
        Logs().w(
            'Ignoring call select answer for room $roomId claiming to be for call in room ${call.room.id}');
        return;
      }
      await call.onSelectAnswerReceived(selectedPartyId);
    }
  }

  Future<void> onSDPStreamMetadataChangedReceived(ToDeviceEvent event) async {
    final content = event.content;
    final roomId = room.id;

    final callId = content.tryGet<String>('call_id');
    Logs().d('SDP Stream metadata received for call ID $callId');
    final call = calls[callId];
    if (call != null) {
      if (call.room.id != roomId) {
        Logs().w(
            'Ignoring call sdp metadata change for room $roomId claiming to be for call in room ${call.room.id}');
        return;
      }

      if (content[sdpStreamMetadataKey] == null) {
        Logs().d('SDP Stream metadata is null');
        return;
      }
      final sdpMetaDataJson =
          content.tryGetMap<String, Map<String, Object>>(sdpStreamMetadataKey);
      if (sdpMetaDataJson != null) {
        await call.onSDPStreamMetadataReceived(
            SDPStreamMetadata.fromJson(sdpMetaDataJson));
      }
    }
  }

  Future<void> onAssertedIdentityReceived(ToDeviceEvent event) async {
    final content = event.content;
    final roomId = room.id;

    final callId = content.tryGet<String>('call_id');
    Logs().d('Asserted identity received for call ID $callId');
    final call = calls[callId];
    if (call != null) {
      if (call.room.id != roomId) {
        Logs().w(
            'Ignoring call asserted identity for room $roomId claiming to be for call in room ${call.room.id}');
        return;
      }

      if (content['asserted_identity'] == null) {
        Logs().d('asserted_identity is null ');
        return;
      }
      final assertedIdentityJson =
          content.tryGetMap<String, Map<String, Object>>('asserted_identity');
      if (assertedIdentityJson != null) {
        call.onAssertedIdentityReceived(
            AssertedIdentity.fromJson(assertedIdentityJson));
      }
    }
  }

  Future<void> onCallNegotiate(ToDeviceEvent event) async {
    final content = event.content;
    final roomId = room.id;

    final callId = content.tryGet<String>('call_id');
    final partyId = content.tryGet<String>('call_id');

    Logs().d('Negotiate received for call ID $callId');
    final call = calls[callId];
    if (call != null) {
      if (call.room.id != roomId) {
        Logs().w(
            'Ignoring call negotiation for room $roomId claiming to be for call in room ${call.room.id}');
        return;
      }
      if (partyId != call.remotePartyId) {
        Logs().w('Ignoring call negotiation, wrong partyId detected');
        return;
      }
      if (partyId == call.localPartyId) {
        Logs().w('Ignoring call negotiation echo');
        return;
      }

      // ideally you also check the lifetime here and discard negotiation events
      // if age of the event was older than the lifetime but as to device events
      // do not have a unsigned age nor a origin_server_ts there's no easy way to
      // override this one function atm

      final sdpMetaDataJson =
          content.tryGetMap<String, Map<String, Object>>(sdpStreamMetadataKey);
      try {
        SDPStreamMetadata? metadata;
        if (sdpMetaDataJson != null) {
          metadata = SDPStreamMetadata.fromJson(sdpMetaDataJson);
        }
        final descJson = content.tryGetMap<String, String>('description');
        final sdpString = descJson?.tryGet<String>('sdp');
        final typeString = descJson?.tryGet<String>('type');
        await call.onNegotiateReceived(
            metadata, RTCSessionDescription(sdpString, typeString));
      } catch (e, s) {
        Logs().e('Failed to complete negotiation', e, s);
      }
    }
  }

  /// Make a P2P call to room
  ///
  /// [roomId] The room id to call
  ///
  /// [type] The type of call to be made.
  Future<CallSession> inviteToCall(String roomId, CallType type) async {
    final callId = 'cid${DateTime.now().millisecondsSinceEpoch}';

    final opts = CallOptions(
      callId: callId,
      type: type,
      dir: CallDirection.kOutgoing,
      room: room,
      rtcSession: this,
      localPartyId: client.deviceID!,
      iceServers: await client.getIceSevers(),
    );

    final newCall = createNewCall(opts);
    if (currentGroupCID == null) {
      inviteSentWithCallId = callId;
      currentCID = callId;
    }
    await newCall.initOutboundCall(type).then((_) {
      delegate.handleNewCall(newCall);
    });
    return newCall;
  }

  /// Create a new group call in an existing room.
  ///
  /// [groupCallId] The room id to call
  ///
  /// [application] normal group call, thrirdroom, etc
  ///
  /// [scope] room, between specifc users, etc.
  Future<GroupCallSession> _newGroupCall(
    String groupCallId,
    String? application,
    String? scope,
  ) async {
    if (getGroupCallById(groupCallId) != null) {
      Logs().e('[VOIP] [$groupCallId] already exists.');
      return getGroupCallById(groupCallId)!;
    }

    final groupCall = GroupCallSession(
      groupCallId: groupCallId,
      client: client,
      rtcSession: this,
      application: application,
      scope: scope,
    );

    groupCalls[groupCallId] = groupCall;

    return groupCall;
  }

  Future<GroupCallSession?> fetchOrCreateGroupCall(String roomId) async {
    final groupCall = getGroupCallForRoom(roomId);
    final room = client.getRoomById(roomId);
    if (room == null) {
      Logs().w('Not found room id = $roomId');
      return null;
    }

    if (groupCall != null) {
      if (!room.canJoinGroupCall) {
        Logs().w('No permission to join group calls in room $roomId');
        return null;
      }
      return groupCall;
    }

    if (!room.groupCallsEnabled) {
      await room.enableGroupCalls();
    }

    if (room.canCreateGroupCall) {
      // The call doesn't exist, but we can create it

      final groupCall = await newGroupCall(
          roomId, GroupCallType.Video, GroupCallIntent.Prompt);
      if (groupCall != null) {
        await groupCall.sendMemberStateEvent();
      }
      return groupCall;
    }

    final completer = Completer<GroupCallSession?>();
    Timer? timer;
    final subscription =
        onIncomingGroupCall.stream.listen((GroupCallSession call) {
      if (call.room.id == roomId) {
        timer?.cancel();
        completer.complete(call);
      }
    });

    timer = Timer(Duration(seconds: 30), () {
      subscription.cancel();
      completer.completeError('timeout');
    });

    return completer.future;
  }

  GroupCallSession? getGroupCallForRoom(String roomId) {
    return groupCalls[roomId];
  }

  GroupCallSession? getGroupCallById(String groupCallId) {
    return groupCalls[groupCallId];
  }

  Future<void> startGroupCalls() async {
    final rooms = client.rooms;
    for (final room in rooms) {
      await createGroupCallForRoom(room);
    }
  }

  Future<void> stopGroupCalls() async {
    for (final groupCall in groupCalls.values) {
      await groupCall.terminate();
    }
    groupCalls.clear();
  }

  /// Create a new group call in an existing room.
  Future<void> createGroupCallForRoom(Room room) async {
    final events = await client.getRoomState(room.id);
    events.sort((a, b) => a.originServerTs.compareTo(b.originServerTs));

    for (final event in events) {
      if (event.type == EventTypes.GroupCallPrefix) {
        if (event.content['m.terminated'] != null) {
          return;
        }
        await createGroupCallFromRoomStateEvent(event);
      }
    }

    return;
  }

  /// Create a new group call from a room state event.
  Future<GroupCallSession?> createGroupCallFromRoomStateEvent(MatrixEvent event,
      {bool emitHandleNewGroupCall = true}) async {
    final roomId = event.roomId;
    final content = event.content;

    final room = client.getRoomById(roomId!);

    if (room == null) {
      Logs().w('Couldn\'t find room $roomId for GroupCallSession');
      return null;
    }

    final groupCallId = event.stateKey;

    final callType = content.tryGet<String>('m.type');

    if (callType == null ||
        callType != GroupCallType.Video && callType != GroupCallType.Voice) {
      Logs().w('Received invalid group call type $callType for room $roomId.');
      return null;
    }

    final callIntent = content.tryGet<String>('m.intent');

    if (callIntent == null ||
        callIntent != GroupCallIntent.Prompt &&
            callIntent != GroupCallIntent.Room &&
            callIntent != GroupCallIntent.Ring) {
      Logs()
          .w('Received invalid group call intent $callType for room $roomId.');
      return null;
    }

    final groupCall = GroupCallSession(
      client: client,
      voip: this,
      room: room,
      groupCallId: groupCallId,
      type: callType,
      intent: callIntent,
    );

    groupCalls[groupCallId!] = groupCall;
    groupCalls[room.id] = groupCall;

    onIncomingGroupCall.add(groupCall);
    if (emitHandleNewGroupCall) {
      await delegate.handleNewGroupCall(groupCall);
    }
    return groupCall;
  }

  Future<void> onRoomStateChanged(MatrixEvent event) async {
    final eventType = event.type;
    final roomId = event.roomId;
    if (eventType == EventTypes.GroupCallPrefix) {
      final groupCallId = event.stateKey;
      final content = event.content;
      final currentGroupCall = groupCalls[groupCallId];
      if (currentGroupCall == null && content['m.terminated'] == null) {
        await createGroupCallFromRoomStateEvent(event);
      } else if (currentGroupCall != null &&
          currentGroupCall.groupCallId == groupCallId) {
        if (content['m.terminated'] != null) {
          await currentGroupCall.terminate(emitStateEvent: false);
        } else if (content['m.type'] != currentGroupCall.type) {
          // TODO: Handle the callType changing when the room state changes
          Logs().w(
              'The group call type changed for room: $roomId. Changing the group call type is currently unsupported.');
        }
      } else if (currentGroupCall != null &&
          currentGroupCall.groupCallId != groupCallId) {
        // TODO: Handle new group calls and multiple group calls
        Logs().w(
            'Multiple group calls detected for room: $roomId. Multiple group calls are currently unsupported.');
      }
    } else if (eventType == EventTypes.GroupCallMemberPrefix) {
      final groupCall = groupCalls[roomId];
      if (groupCall == null) {
        return;
      }
      await groupCall.onMemberStateChanged(event);
    }
  }

  @Deprecated('Call `hasActiveGroupCall` on the room directly instead')
  bool hasActiveCall(Room room) => room.hasActiveGroupCall;
}
