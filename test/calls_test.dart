import 'package:test/test.dart';
import 'package:webrtc_interface/webrtc_interface.dart';

import 'package:matrix/matrix.dart';
import 'package:matrix/src/voip/models/call_membership.dart';
import 'package:matrix/src/voip/models/call_options.dart';
import 'package:matrix/src/voip/models/voip_id.dart';
import 'fake_client.dart';
import 'webrtc_stub.dart';

void main() {
  late Client matrix;
  late Room room;
  late VoIP voip;
  group('Call tests', () {
    Logs().level = Level.info;
    setUp(() async {
      matrix = await getClient();
      await matrix.abortSync();

      voip = VoIP(matrix, MockWebRTCDelegate());
      VoIP.customTxid = '1234';
      final id = '!calls:example.com';
      room = matrix.getRoomById(id)!;
    });

    test('Test call methods', () async {
      final call = CallSession(
        CallOptions(
          callId: '1234',
          type: CallType.kVoice,
          dir: CallDirection.kOutgoing,
          localPartyId: '4567',
          voip: voip,
          room: room,
          iceServers: [],
        ),
      );
      await call.sendInviteToCall(
        room,
        '1234',
        1234,
        '4567',
        'sdp',
        txid: '1234',
      );
      await call.sendAnswerCall(room, '1234', 'sdp', '4567', txid: '1234');
      await call.sendCallCandidates(room, '1234', '4567', [], txid: '1234');
      await call.sendSelectCallAnswer(
        room,
        '1234',
        '4567',
        '6789',
        txid: '1234',
      );
      await call.sendCallReject(room, '1234', '4567', txid: '1234');
      await call.sendCallNegotiate(
        room,
        '1234',
        1234,
        '4567',
        'sdp',
        txid: '1234',
      );
      await call.sendHangupCall(
        room,
        '1234',
        '4567',
        'userHangup',
        txid: '1234',
      );
      await call.sendAssertedIdentity(
        room,
        '1234',
        '4567',
        AssertedIdentity()
          ..displayName = 'name'
          ..id = 'some_id',
        txid: '1234',
      );
      await call.sendCallReplaces(
        room,
        '1234',
        '4567',
        CallReplaces(),
        txid: '1234',
      );
      await call.sendSDPStreamMetadataChanged(
        room,
        '1234',
        '4567',
        SDPStreamMetadata({}),
        txid: '1234',
      );
    });

    test('Call lifetime and age', () async {
      expect(voip.currentCID, null);
      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent(
                      type: 'm.call.invite',
                      content: {
                        'lifetime': 60000,
                        'call_id': '1702472924955oq1uQbNAfU7wAaEA',
                        'party_id': 'DPCIPPBGPO',
                        'offer': {'type': 'offer', 'sdp': 'sdp'},
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'newevent',
                      originServerTs: DateTime.utc(1969),
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );
      await Future.delayed(Duration(seconds: 2));
      // confirm that no call got created after 3 seconds, which is
      // expected in this case because the originTs was old asf
      expect(voip.currentCID, null);

      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent(
                      unsigned: {'age': 60001},
                      type: 'm.call.invite',
                      content: {
                        'lifetime': 60000,
                        'call_id': 'unsignedTsInvalidCall',
                        'party_id': 'DPCIPPBGPO',
                        'offer': {'type': 'offer', 'sdp': 'sdp'},
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'newevent',
                      originServerTs: DateTime.now(),
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );
      await Future.delayed(Duration(seconds: 2));
      // confirm that no call got created after 3 seconds, which is
      // expected in this case because age was older than lifetime
      expect(voip.currentCID, null);
    });
    test('Call connection and hanging up', () async {
      expect(voip.currentCID, null);
      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent(
                      type: 'm.call.invite',
                      content: {
                        'lifetime': 60000,
                        'call_id': 'originTsValidCall',
                        'party_id': 'GHTYAJCE_caller',
                        'version': '1',
                        'offer': {'type': 'offer', 'sdp': 'sdp'},
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'callerInviteEvent',
                      originServerTs: DateTime.now(),
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );
      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent(
                      type: 'm.call.candidates',
                      content: {
                        'call_id': 'originTsValidCall',
                        'party_id': 'GHTYAJCE_caller',
                        'version': '1',
                        'candidates': [
                          {
                            'candidate':
                                'candidate:01UDP2122252543uwu50184typhost',
                            'sdpMid': '0',
                            'sdpMLineIndex': 0,
                          },
                          {
                            'candidate':
                                'candidate:31TCP2105524479uwu9typhosttcptypeactive',
                            'sdpMid': '0',
                            'sdpMLineIndex': 0,
                          }
                        ],
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'callerCallCandidatesEvent',
                      originServerTs: DateTime.now(),
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );
      while (voip.currentCID !=
          VoipId(roomId: room.id, callId: 'originTsValidCall')) {
        // call invite looks valid, call should be created now :D
        await Future.delayed(Duration(milliseconds: 50));
        Logs().d('Waiting for currentCID to update');
      }
      expect(
        voip.currentCID,
        VoipId(roomId: room.id, callId: 'originTsValidCall'),
      );
      final call = voip.calls[voip.currentCID]!;
      expect(call.state, CallState.kRinging);
      await call.answer(txid: '1234');

      call.pc!.onIceGatheringState!
          .call(RTCIceGatheringState.RTCIceGatheringStateComplete);
      // we send them manually anyway because our stub sends empty list of
      // candidates
      await call.sendCallCandidates(
        room,
        'originTsValidCall',
        'GHTYAJCE',
        [
          {
            'candidate': 'candidate:0 1 UDP 2122252543 uwu 50184 typ host',
            'sdpMid': '0',
            'sdpMLineIndex': 0,
          },
          {
            'candidate':
                'candidate:3 1 TCP 2105524479 uwu 9 typ host tcptype active',
            'sdpMid': '0',
            'sdpMLineIndex': 0,
          }
        ],
        txid: '1234',
      );

      expect(call.state, CallState.kConnecting);

      // caller sends select answer
      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent(
                      type: 'm.call.select_answer',
                      content: {
                        'call_id': 'originTsValidCall',
                        'party_id': 'GHTYAJCE_caller',
                        'version': '1',
                        'lifetime': 10000,
                        'selected_party_id': 'GHTYAJCE',
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'callerSelectAnswerEvent',
                      originServerTs: DateTime.now(),
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );

      call.pc!.onIceConnectionState!
          .call(RTCIceConnectionState.RTCIceConnectionStateChecking);
      call.pc!.onIceConnectionState!
          .call(RTCIceConnectionState.RTCIceConnectionStateConnected);
      // just to make sure there are no errors after running functions
      // that are supposed to run once iceConnectionState is connected
      await Future.delayed(Duration(seconds: 2));

      expect(call.state, CallState.kConnected);

      await call.hangup(reason: CallErrorCode.userHangup);
      expect(call.state, CallState.kEnded);
      expect(voip.currentCID, null);
    });

    test('Call answered elsewhere', () async {
      expect(voip.currentCID, null);
      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent(
                      type: 'm.call.invite',
                      content: {
                        'lifetime': 60000,
                        'call_id': 'answer_elseWhere',
                        'party_id': 'GHTYAJCE_caller',
                        'version': '1',
                        'offer': {'type': 'offer', 'sdp': 'sdp'},
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'callerInviteEvent',
                      originServerTs: DateTime.now(),
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );
      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent(
                      type: 'm.call.candidates',
                      content: {
                        'call_id': 'answer_elseWhere',
                        'party_id': 'GHTYAJCE_caller',
                        'version': '1',
                        'candidates': [
                          {
                            'candidate':
                                'candidate:01UDP2122252543uwu50184typhost',
                            'sdpMid': '0',
                            'sdpMLineIndex': 0,
                          },
                          {
                            'candidate':
                                'candidate:31TCP2105524479uwu9typhosttcptypeactive',
                            'sdpMid': '0',
                            'sdpMLineIndex': 0,
                          }
                        ],
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'callerCallCandidatesEvent',
                      originServerTs: DateTime.now(),
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );
      while (voip.currentCID !=
          VoipId(roomId: room.id, callId: 'answer_elseWhere')) {
        // call invite looks valid, call should be created now :D
        await Future.delayed(Duration(milliseconds: 50));
        Logs().d('Waiting for currentCID to update');
      }
      expect(
        voip.currentCID,
        VoipId(roomId: room.id, callId: 'answer_elseWhere'),
      );
      final call = voip.calls[voip.currentCID]!;
      expect(call.state, CallState.kRinging);

      // caller sends select answer
      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent(
                      type: 'm.call.select_answer',
                      content: {
                        'call_id': 'answer_elseWhere',
                        'party_id': 'GHTYAJCE_caller',
                        'version': '1',
                        'lifetime': 10000,
                        'selected_party_id':
                            'not_us', // selected some other device for answer
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'callerSelectAnswerEvent',
                      originServerTs: DateTime.now(),
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );
      // wait for select answer to end the call
      await Future.delayed(Duration(seconds: 2));
      // call ended because answered elsewhere
      expect(call.state, CallState.kEnded);
      expect(voip.currentCID, null);
    });

    test('Reject incoming call', () async {
      expect(voip.currentCID, null);
      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent(
                      type: 'm.call.invite',
                      content: {
                        'lifetime': 60000,
                        'call_id': 'reject_call',
                        'party_id': 'GHTYAJCE_caller',
                        'version': '1',
                        'offer': {'type': 'offer', 'sdp': 'sdp'},
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'callerInviteEvent',
                      originServerTs: DateTime.now(),
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );
      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent(
                      type: 'm.call.candidates',
                      content: {
                        'call_id': 'reject_call',
                        'party_id': 'GHTYAJCE_caller',
                        'version': '1',
                        'candidates': [
                          {
                            'candidate':
                                'candidate:01UDP2122252543uwu50184typhost',
                            'sdpMid': '0',
                            'sdpMLineIndex': 0,
                          },
                          {
                            'candidate':
                                'candidate:31TCP2105524479uwu9typhosttcptypeactive',
                            'sdpMid': '0',
                            'sdpMLineIndex': 0,
                          }
                        ],
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'callerCallCandidatesEvent',
                      originServerTs: DateTime.now(),
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );
      while (
          voip.currentCID != VoipId(roomId: room.id, callId: 'reject_call')) {
        // call invite looks valid, call should be created now :D
        await Future.delayed(Duration(milliseconds: 50));
        Logs().d('Waiting for currentCID to update');
      }
      expect(voip.currentCID, VoipId(roomId: room.id, callId: 'reject_call'));
      final call = voip.calls[voip.currentCID]!;
      expect(call.state, CallState.kRinging);

      await call.reject();

      // call ended because answered elsewhere
      expect(call.state, CallState.kEnded);
      expect(voip.currentCID, null);
    });

    test('Glare after invite was sent', () async {
      expect(voip.currentCID, null);
      final firstCall = await voip.inviteToCall(
        room,
        CallType.kVoice,
        userId: '@alice:testing.com',
      );
      await firstCall.pc!.onRenegotiationNeeded!.call();
      expect(firstCall.state, CallState.kInviteSent);
      // KABOOM YOU JUST GLARED
      await Future.delayed(Duration(seconds: 3));
      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent(
                      type: 'm.call.invite',
                      content: {
                        'lifetime': 60000,
                        'call_id': 'zzzz_glare_2nd_call',
                        'party_id': 'GHTYAJCE_caller',
                        'version': '1',
                        'offer': {'type': 'offer', 'sdp': 'sdp'},
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'callerInviteEvent',
                      originServerTs: DateTime.now(),
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );
      await Future.delayed(Duration(seconds: 3));
      expect(
        voip.currentCID,
        VoipId(roomId: room.id, callId: firstCall.callId),
      );
      await firstCall.hangup(reason: CallErrorCode.userBusy);
    });
    test('Glare before invite was sent', () async {
      expect(voip.currentCID, null);
      final firstCall = await voip.inviteToCall(
        room,
        CallType.kVoice,
        userId: '@alice:testing.com',
      );
      expect(firstCall.state, CallState.kCreateOffer);
      // KABOOM YOU JUST GLARED, but this tiem you were still preparing your call
      // so just cancel that instead
      await Future.delayed(Duration(seconds: 3));
      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent(
                      type: 'm.call.invite',
                      content: {
                        'lifetime': 60000,
                        'call_id': 'zzzz_glare_2nd_call',
                        'party_id': 'GHTYAJCE_caller',
                        'version': '1',
                        'offer': {'type': 'offer', 'sdp': 'sdp'},
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'callerInviteEvent',
                      originServerTs: DateTime.now(),
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );
      await Future.delayed(Duration(seconds: 3));
      expect(
        voip.currentCID,
        VoipId(roomId: room.id, callId: 'zzzz_glare_2nd_call'),
      );
    });

    test('getFamedlyCallEvents sort order', () {
      room.setState(
        Event(
          content: {
            'memberships': [
              CallMembership(
                userId: '@test1:example.com',
                callId: '1111',
                backend: MeshBackend(),
                deviceId: '1111',
                expiresTs: DateTime.now()
                    .add(Duration(hours: 12))
                    .millisecondsSinceEpoch,
                roomId: room.id,
                membershipId: voip.currentSessionId,
              ).toJson(),
            ],
          },
          type: EventTypes.GroupCallMember,
          eventId: 'asdfasdf',
          senderId: '@test1:example.com',
          originServerTs: DateTime.now().add(Duration(hours: 12)),
          room: room,
          stateKey: '@test1:example.com',
        ),
      );
      room.setState(
        Event(
          content: {
            'memberships': [
              CallMembership(
                userId: '@test2:example.com',
                callId: '1111',
                backend: MeshBackend(),
                deviceId: '1111',
                expiresTs: DateTime.now().millisecondsSinceEpoch,
                roomId: room.id,
                membershipId: voip.currentSessionId,
              ).toJson(),
            ],
          },
          type: EventTypes.GroupCallMember,
          eventId: 'asdfasdf',
          senderId: '@test2:example.com',
          originServerTs: DateTime.now(),
          room: room,
          stateKey: '@test2:example.com',
        ),
      );
      room.setState(
        Event(
          content: {
            'memberships': [
              CallMembership(
                userId: '@test2.0:example.com',
                callId: '1111',
                backend: MeshBackend(),
                deviceId: '1111',
                expiresTs: DateTime.now().millisecondsSinceEpoch,
                roomId: room.id,
                membershipId: voip.currentSessionId,
              ).toJson(),
            ],
          },
          type: EventTypes.GroupCallMember,
          eventId: 'asdfasdf',
          senderId: '@test2.0:example.com',
          originServerTs: DateTime.now(),
          room: room,
          stateKey: '@test2.0:example.com',
        ),
      );
      room.setState(
        Event(
          content: {
            'memberships': [
              CallMembership(
                userId: '@test3:example.com',
                callId: '1111',
                backend: MeshBackend(),
                deviceId: '1111',
                expiresTs: DateTime.now()
                    .subtract(Duration(hours: 1))
                    .millisecondsSinceEpoch,
                roomId: room.id,
                membershipId: voip.currentSessionId,
              ).toJson(),
            ],
          },
          type: EventTypes.GroupCallMember,
          eventId: 'asdfasdf',
          senderId: '@test3:example.com',
          originServerTs: DateTime.now().subtract(Duration(hours: 1)),
          room: room,
          stateKey: '@test3:example.com',
        ),
      );
      expect(
        room.getFamedlyCallEvents().entries.elementAt(0).key,
        '@test3:example.com',
      );
      expect(
        room.getFamedlyCallEvents().entries.elementAt(1).key,
        '@test2:example.com',
      );
      expect(
        room.getFamedlyCallEvents().entries.elementAt(2).key,
        '@test2.0:example.com',
      );
      expect(
        room.getFamedlyCallEvents().entries.elementAt(3).key,
        '@test1:example.com',
      );
      expect(
        room.getCallMembershipsFromRoom().entries.elementAt(0).key,
        '@test3:example.com',
      );
      expect(
        room.getCallMembershipsFromRoom().entries.elementAt(1).key,
        '@test2:example.com',
      );
      expect(
        room.getCallMembershipsFromRoom().entries.elementAt(2).key,
        '@test2.0:example.com',
      );
      expect(
        room.getCallMembershipsFromRoom().entries.elementAt(3).key,
        '@test1:example.com',
      );
    });

    test('Enabling group calls', () async {
      // users default is 0 and so group calls not enabled
      room.setState(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.power_levels',
          room: room,
          eventId: '123a',
          content: {
            'events': {EventTypes.GroupCallMember: 100},
            'state_default': 50,
            'users_default': 0,
          },
          originServerTs: DateTime.now(),
          stateKey: '',
        ),
      );
      expect(room.canJoinGroupCall, false);
      expect(room.groupCallsEnabledForEveryone, false);

      room.setState(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.power_levels',
          room: room,
          eventId: '123a',
          content: {
            'events': {EventTypes.GroupCallMember: 27},
            'state_default': 50,
            'users_default': 49,
          },
          originServerTs: DateTime.now(),
          stateKey: '',
        ),
      );
      expect(room.canJoinGroupCall, true);
      expect(room.groupCallsEnabledForEveryone, true);

      // state_default 50 and user_default 0, use enableGroupCall
      room.setState(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.power_levels',
          room: room,
          eventId: '123',
          content: {
            'state_default': 50,
            'users': {'@test:fakeServer.notExisting': 100},
            'users_default': 0,
          },
          originServerTs: DateTime.now(),
          stateKey: '',
        ),
      );
      expect(room.canJoinGroupCall, true); // because admin
      expect(room.groupCallsEnabledForEveryone, false);
      await room.enableGroupCalls();
      expect(room.canJoinGroupCall, true);
      expect(room.groupCallsEnabledForEveryone, true);

      // state_default 50 and user_default unspecified, use enableGroupCall
      room.setState(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.power_levels',
          room: room,
          eventId: '123',
          content: {
            'state_default': 50,
            'users': {'@test:fakeServer.notExisting': 100},
          },
          originServerTs: DateTime.now(),
          stateKey: '',
        ),
      );

      expect(room.canJoinGroupCall, true); // because admin
      expect(room.groupCallsEnabledForEveryone, false);
      await room.enableGroupCalls();
      expect(room.canJoinGroupCall, true);
      expect(room.groupCallsEnabledForEveryone, true);

      // state_default is 0 so users should be able to send state events
      room.setState(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.power_levels',
          room: room,
          eventId: '123',
          content: {
            'state_default': 0,
            'users': {'@test:fakeServer.notExisting': 100},
          },
          originServerTs: DateTime.now(),
          stateKey: '',
        ),
      );
      expect(room.canJoinGroupCall, true);
      expect(room.groupCallsEnabledForEveryone, true);
    });

    test('group call participants count', () {
      room.setState(
        Event(
          senderId: '@test1:example.com',
          type: EventTypes.GroupCallMember,
          room: room,
          eventId: '1234177',
          content: {
            'memberships': [
              CallMembership(
                userId: '@test1:example.com',
                callId: 'participants_count',
                backend: MeshBackend(),
                deviceId: '1111',
                expiresTs: DateTime.now()
                    .subtract(Duration(hours: 1))
                    .millisecondsSinceEpoch,
                roomId: room.id,
                membershipId: voip.currentSessionId,
              ).toJson(),
            ],
          },
          originServerTs: DateTime.now(),
          stateKey: '@test1:example.com',
        ),
      );

      expect(room.groupCallParticipantCount('participants_count'), 0);
      expect(room.hasActiveGroupCall, false);

      room.setState(
        Event(
          senderId: '@test2:example.com',
          type: EventTypes.GroupCallMember,
          room: room,
          eventId: '1234177',
          content: {
            'memberships': [
              CallMembership(
                userId: '@test2:example.com',
                callId: 'participants_count',
                backend: MeshBackend(),
                deviceId: '1111',
                expiresTs: DateTime.now()
                    .add(Duration(hours: 1))
                    .millisecondsSinceEpoch,
                roomId: room.id,
                membershipId: voip.currentSessionId,
              ).toJson(),
            ],
          },
          originServerTs: DateTime.now(),
          stateKey: '@test2:example.com',
        ),
      );
      expect(room.groupCallParticipantCount('participants_count'), 1);
      expect(room.hasActiveGroupCall, true);

      room.setState(
        Event(
          senderId: '@test3:example.com',
          type: EventTypes.GroupCallMember,
          room: room,
          eventId: '1231234124123',
          content: {
            'memberships': [
              CallMembership(
                userId: '@test3:example.com',
                callId: 'participants_count',
                backend: MeshBackend(),
                deviceId: '1111',
                expiresTs: DateTime.now().millisecondsSinceEpoch,
                roomId: room.id,
                membershipId: voip.currentSessionId,
              ).toJson(),
            ],
          },
          originServerTs: DateTime.now(),
          stateKey: '@test3:example.com',
        ),
      );

      expect(room.groupCallParticipantCount('participants_count'), 2);
      expect(room.hasActiveGroupCall, true);
    });
  });
}
