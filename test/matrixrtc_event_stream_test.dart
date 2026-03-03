import 'dart:async';

import 'package:test/test.dart';

import 'package:matrix/matrix.dart';
import 'package:matrix/src/voip/models/call_options.dart';
import 'fake_client.dart';
import 'webrtc_stub.dart';

void main() {
  late Client matrix;
  late Room room;
  late VoIP voip;
  late MeshBackend backend;
  late GroupCallSession groupCall;

  group('MatrixRTC Event Stream Tests', () {
    Logs().level = Level.info;

    setUp(() async {
      matrix = await getClient();
      await matrix.abortSync();

      voip = VoIP(matrix, MockWebRTCDelegate());
      final id = '!calls:example.com';
      room = matrix.getRoomById(id)!;
      backend = MeshBackend();
    });

    tearDown(() async {
      if (voip.groupCalls.isNotEmpty) {
        for (final groupCall in voip.groupCalls.values.toList()) {
          try {
            await groupCall.leave();
          } catch (e) {
            // ignore errors during cleanup
          }
        }
      }
    });

    group('GroupCallStateChanged Events', () {
      test('emits GroupCallStateChanged when transitioning through all states',
          () async {
        groupCall = GroupCallSession.withAutoGenId(
          room,
          voip,
          backend,
          'm.call',
          'm.room',
          'test-group-call-2',
        );

        final events = <GroupCallStateChanged>[];
        groupCall.matrixRTCEventStream.stream
            .where((event) => event is GroupCallStateChanged)
            .cast<GroupCallStateChanged>()
            .listen((event) {
          events.add(event);
        });

        // Trigger state changes
        groupCall.setState(GroupCallState.initializingLocalCallFeed);
        groupCall.setState(GroupCallState.localCallFeedInitialized);
        groupCall.setState(GroupCallState.entered);

        await pumpEventQueue();

        expect(events.length, 3);
        expect(
          events[0].state,
          GroupCallState.initializingLocalCallFeed,
        );
        expect(
          events[1].state,
          GroupCallState.localCallFeedInitialized,
        );
        expect(events[2].state, GroupCallState.entered);
      });
    });

    group('ParticipantsJoinEvent and ParticipantsLeftEvent', () {
      test('emits ParticipantsJoinEvent when participants join', () async {
        groupCall = GroupCallSession.withAutoGenId(
          room,
          voip,
          backend,
          'm.call',
          'm.room',
          'test-group-call-4',
        );

        await backend.initLocalStream(groupCall);
        groupCall.setState(GroupCallState.entered);

        room.setState(
          Event(
            room: room,
            eventId: '123',
            originServerTs: DateTime.now(),
            type: EventTypes.GroupCallMember,
            content: {
              'memberships': [
                CallMembership(
                  userId: matrix.userID!,
                  roomId: room.id,
                  callId: groupCall.groupCallId,
                  application: groupCall.application,
                  scope: groupCall.scope,
                  backend: backend,
                  deviceId: matrix.deviceID!,
                  expiresTs: DateTime.now()
                      .add(Duration(hours: 1))
                      .millisecondsSinceEpoch,
                  membershipId: voip.currentSessionId,
                  feeds: [],
                  voip: voip,
                ).toJson(),
              ],
            },
            senderId: matrix.userID!,
            stateKey: matrix.userID!,
          ),
        );

        await groupCall.onMemberStateChanged();
        await pumpEventQueue();

        final events = <ParticipantsJoinEvent>[];
        groupCall.matrixRTCEventStream.stream
            .where((event) => event is ParticipantsJoinEvent)
            .cast<ParticipantsJoinEvent>()
            .listen((event) {
          events.add(event);
        });

        room.setState(
          Event(
            room: room,
            eventId: '1234',
            originServerTs: DateTime.now(),
            type: EventTypes.GroupCallMember,
            content: {
              'memberships': [
                CallMembership(
                  userId: '@remoteuser:example.com',
                  roomId: room.id,
                  callId: groupCall.groupCallId,
                  application: groupCall.application,
                  scope: groupCall.scope,
                  backend: backend,
                  deviceId: 'DEVICE123',
                  expiresTs: DateTime.now()
                      .add(Duration(hours: 1))
                      .millisecondsSinceEpoch,
                  membershipId: 'remote-session-id',
                  feeds: [],
                  voip: voip,
                ).toJson(),
              ],
            },
            senderId: '@remoteuser:example.com',
            stateKey: '@remoteuser:example.com',
          ),
        );

        await groupCall.onMemberStateChanged();
        await pumpEventQueue();

        expect(events.length, 1);
        expect(events[0].participants.length, 1);
        expect(events[0].participants[0].userId, '@remoteuser:example.com');
        expect(events[0].participants[0].deviceId, 'DEVICE123');
      });

      test('emits ParticipantsLeftEvent when participants leave', () async {
        groupCall = GroupCallSession.withAutoGenId(
          room,
          voip,
          backend,
          'm.call',
          'm.room',
          'test-group-call-5',
        );

        // Initialize local stream
        await backend.initLocalStream(groupCall);
        groupCall.setState(GroupCallState.entered);

        // Add a participant first
        room.setState(
          Event(
            room: room,
            eventId: '1234',
            originServerTs: DateTime.now(),
            type: EventTypes.GroupCallMember,
            senderId: '@remoteuser:example.com',
            stateKey: '@remoteuser:example.com',
            content: {
              'memberships': [
                CallMembership(
                  userId: '@remoteuser:example.com',
                  roomId: room.id,
                  callId: groupCall.groupCallId,
                  application: groupCall.application,
                  scope: groupCall.scope,
                  backend: backend,
                  deviceId: 'DEVICE123',
                  expiresTs: DateTime.now()
                      .add(Duration(hours: 1))
                      .millisecondsSinceEpoch,
                  membershipId: 'remote-session-id',
                  feeds: [],
                  voip: voip,
                ).toJson(),
              ],
            },
          ),
        );

        await groupCall.onMemberStateChanged();

        final events = <ParticipantsLeftEvent>[];
        groupCall.matrixRTCEventStream.stream
            .where((event) => event is ParticipantsLeftEvent)
            .cast<ParticipantsLeftEvent>()
            .listen((event) {
          events.add(event);
        });

        // Remove the participant
        room.setState(
          Event(
            room: room,
            eventId: '1234',
            originServerTs: DateTime.now(),
            type: EventTypes.GroupCallMember,
            senderId: '@remoteuser:example.com',
            stateKey: '@remoteuser:example.com',
            content: {
              'memberships': [],
            },
          ),
        );

        await groupCall.onMemberStateChanged();
        await pumpEventQueue();

        expect(events.length, 1);
        expect(events[0].participants.length, 1);
        expect(events[0].participants[0].userId, '@remoteuser:example.com');
        expect(events[0].participants[0].deviceId, 'DEVICE123');
      });
    });

    group('CallAddedEvent, CallRemovedEvent, and CallReplacedEvent', () {
      test('emits CallAddedEvent when a call is added', () async {
        groupCall = GroupCallSession.withAutoGenId(
          room,
          voip,
          backend,
          'm.call',
          'm.room',
          'test-group-call-7',
        );

        final events = <CallAddedEvent>[];
        groupCall.matrixRTCEventStream.stream
            .where((event) => event is CallAddedEvent)
            .cast<CallAddedEvent>()
            .listen((event) {
          events.add(event);
        });

        await backend.initLocalStream(groupCall);
        groupCall.setState(GroupCallState.entered);

        room.setState(
          Event(
            room: room,
            eventId: 'local-123',
            originServerTs: DateTime.now(),
            type: EventTypes.GroupCallMember,
            content: {
              'memberships': [
                CallMembership(
                  userId: matrix.userID!,
                  roomId: room.id,
                  callId: groupCall.groupCallId,
                  application: groupCall.application,
                  scope: groupCall.scope,
                  backend: backend,
                  deviceId: matrix.deviceID!,
                  expiresTs: DateTime.now()
                      .add(Duration(hours: 1))
                      .millisecondsSinceEpoch,
                  membershipId: voip.currentSessionId,
                  feeds: [],
                  voip: voip,
                ).toJson(),
              ],
            },
            senderId: matrix.userID!,
            stateKey: matrix.userID!,
          ),
        );

        await groupCall.onMemberStateChanged();
        await pumpEventQueue();

        room.setState(
          Event(
            room: room,
            eventId: 'remote-call-add-123',
            originServerTs: DateTime.now(),
            type: EventTypes.GroupCallMember,
            senderId: '@zane:example.com',
            stateKey: '@zane:example.com',
            content: {
              'memberships': [
                CallMembership(
                  userId: '@zane:example.com',
                  roomId: room.id,
                  callId: groupCall.groupCallId,
                  application: groupCall.application,
                  scope: groupCall.scope,
                  backend: backend,
                  deviceId: 'ZANEDEVICE',
                  expiresTs: DateTime.now()
                      .add(Duration(hours: 1))
                      .millisecondsSinceEpoch,
                  membershipId: 'zane-session-id',
                  feeds: [],
                  voip: voip,
                ).toJson(),
              ],
            },
          ),
        );

        await groupCall.onMemberStateChanged();
        await pumpEventQueue();

        expect(events.length, 1);
        expect(events[0].call.remoteUserId, '@zane:example.com');
        expect(events[0].call.remoteDeviceId, 'ZANEDEVICE');
        expect(events[0].call.groupCallId, groupCall.groupCallId);
      });

      test('emits CallRemovedEvent when a call is removed', () async {
        groupCall = GroupCallSession.withAutoGenId(
          room,
          voip,
          backend,
          'm.call',
          'm.room',
          'test-group-call-8',
        );

        await backend.initLocalStream(groupCall);
        groupCall.setState(GroupCallState.entered);

        room.setState(
          Event(
            room: room,
            eventId: 'local-456',
            originServerTs: DateTime.now(),
            type: EventTypes.GroupCallMember,
            content: {
              'memberships': [
                CallMembership(
                  userId: matrix.userID!,
                  roomId: room.id,
                  callId: groupCall.groupCallId,
                  application: groupCall.application,
                  scope: groupCall.scope,
                  backend: backend,
                  deviceId: matrix.deviceID!,
                  expiresTs: DateTime.now()
                      .add(Duration(hours: 1))
                      .millisecondsSinceEpoch,
                  membershipId: voip.currentSessionId,
                  feeds: [],
                  voip: voip,
                ).toJson(),
              ],
            },
            senderId: matrix.userID!,
            stateKey: matrix.userID!,
          ),
        );

        await groupCall.onMemberStateChanged();
        await pumpEventQueue();

        room.setState(
          Event(
            room: room,
            eventId: 'remote-call-remove-456',
            originServerTs: DateTime.now(),
            type: EventTypes.GroupCallMember,
            senderId: '@zoe:example.com',
            stateKey: '@zoe:example.com',
            content: {
              'memberships': [
                CallMembership(
                  userId: '@zoe:example.com',
                  roomId: room.id,
                  callId: groupCall.groupCallId,
                  application: groupCall.application,
                  scope: groupCall.scope,
                  backend: backend,
                  deviceId: 'ZOEDEVICE',
                  expiresTs: DateTime.now()
                      .add(Duration(hours: 1))
                      .millisecondsSinceEpoch,
                  membershipId: 'zoe-session-id',
                  feeds: [],
                  voip: voip,
                ).toJson(),
              ],
            },
          ),
        );

        await groupCall.onMemberStateChanged();
        await pumpEventQueue();

        final events = <CallRemovedEvent>[];
        groupCall.matrixRTCEventStream.stream
            .where((event) => event is CallRemovedEvent)
            .cast<CallRemovedEvent>()
            .listen((event) {
          events.add(event);
        });

        final call = voip.calls.values.firstWhere(
          (c) =>
              c.remoteUserId == '@zoe:example.com' &&
              c.groupCallId == groupCall.groupCallId,
        );

        await call.hangup(reason: CallErrorCode.userHangup);
        await pumpEventQueue();

        expect(events.length, 1);
        expect(events[0].call.remoteUserId, '@zoe:example.com');
        expect(events[0].call.remoteDeviceId, 'ZOEDEVICE');
      });

      test('emits CallReplacedEvent when a call is replaced', () async {
        groupCall = GroupCallSession.withAutoGenId(
          room,
          voip,
          backend,
          'm.call',
          'm.room',
          'test-group-call-9',
        );

        final events = <CallReplacedEvent>[];
        groupCall.matrixRTCEventStream.stream
            .where((event) => event is CallReplacedEvent)
            .cast<CallReplacedEvent>()
            .listen((event) {
          events.add(event);
        });

        await backend.initLocalStream(groupCall);
        groupCall.setState(GroupCallState.entered);

        room.setState(
          Event(
            room: room,
            eventId: 'local-789',
            originServerTs: DateTime.now(),
            type: EventTypes.GroupCallMember,
            content: {
              'memberships': [
                CallMembership(
                  userId: matrix.userID!,
                  roomId: room.id,
                  callId: groupCall.groupCallId,
                  application: groupCall.application,
                  scope: groupCall.scope,
                  backend: backend,
                  deviceId: matrix.deviceID!,
                  expiresTs: DateTime.now()
                      .add(Duration(hours: 1))
                      .millisecondsSinceEpoch,
                  membershipId: voip.currentSessionId,
                  feeds: [],
                  voip: voip,
                ).toJson(),
              ],
            },
            senderId: matrix.userID!,
            stateKey: matrix.userID!,
          ),
        );

        await groupCall.onMemberStateChanged();
        await pumpEventQueue();

        room.setState(
          Event(
            room: room,
            eventId: 'remote-call-replace-789',
            originServerTs: DateTime.now(),
            type: EventTypes.GroupCallMember,
            senderId: '@zara:example.com',
            stateKey: '@zara:example.com',
            content: {
              'memberships': [
                CallMembership(
                  userId: '@zara:example.com',
                  roomId: room.id,
                  callId: groupCall.groupCallId,
                  application: groupCall.application,
                  scope: groupCall.scope,
                  backend: backend,
                  deviceId: 'ZARADEVICE',
                  expiresTs: DateTime.now()
                      .add(Duration(hours: 1))
                      .millisecondsSinceEpoch,
                  membershipId: 'zara-session-id-1',
                  feeds: [],
                  voip: voip,
                ).toJson(),
              ],
            },
          ),
        );

        await groupCall.onMemberStateChanged();
        await pumpEventQueue();

        final existingCall = voip.calls.values.firstWhere(
          (c) =>
              c.remoteUserId == '@zara:example.com' &&
              c.groupCallId == groupCall.groupCallId,
        );

        final replacementCall = voip.createNewCall(
          CallOptions(
            callId: VoIP.customTxid ?? 'replacement-call-id',
            room: room,
            voip: voip,
            dir: CallDirection.kOutgoing,
            localPartyId: voip.currentSessionId,
            groupCallId: groupCall.groupCallId,
            type: CallType.kVideo,
            iceServers: [],
          ),
        );
        replacementCall.remoteUserId = '@zara:example.com';
        replacementCall.remoteDeviceId = 'ZARADEVICE';

        existingCall.onCallReplaced.add(replacementCall);
        await pumpEventQueue();

        expect(events.length, 1);
        expect(events[0].existingCall.callId, existingCall.callId);
        expect(events[0].replacementCall.callId, replacementCall.callId);
        expect(events[0].existingCall.remoteUserId, '@zara:example.com');
        expect(events[0].replacementCall.remoteUserId, '@zara:example.com');
      });
    });

    group('GroupCallStreamAdded, Removed, and Replaced Events', () {
      test('emits GroupCallStreamAdded when user media stream is added',
          () async {
        groupCall = GroupCallSession.withAutoGenId(
          room,
          voip,
          backend,
          'm.call',
          'm.room',
          'test-group-call-10',
        );

        final events = <GroupCallStreamAdded>[];
        groupCall.matrixRTCEventStream.stream
            .where((event) => event is GroupCallStreamAdded)
            .cast<GroupCallStreamAdded>()
            .listen((event) {
          events.add(event);
        });

        await backend.initLocalStream(groupCall);
        await pumpEventQueue();

        expect(events.length, 1);
        expect(events[0].type, GroupCallStreamType.userMedia);
      });

      test('emits GroupCallStreamAdded when screenshare stream is added',
          () async {
        groupCall = GroupCallSession.withAutoGenId(
          room,
          voip,
          backend,
          'm.call',
          'm.room',
          'test-group-call-11',
        );

        final events = <GroupCallStreamAdded>[];
        groupCall.matrixRTCEventStream.stream
            .where((event) => event is GroupCallStreamAdded)
            .cast<GroupCallStreamAdded>()
            .listen((event) {
          events.add(event);
        });

        await backend.initLocalStream(groupCall);
        groupCall.setState(GroupCallState.entered);

        await backend.setScreensharingEnabled(groupCall, true, '');
        await pumpEventQueue();

        expect(events.last.type, GroupCallStreamType.screenshare);
      });

      test('emits GroupCallStreamRemoved when stream is removed', () async {
        groupCall = GroupCallSession.withAutoGenId(
          room,
          voip,
          backend,
          'm.call',
          'm.room',
          'test-group-call-12',
        );

        final addedEvents = <GroupCallStreamAdded>[];
        final removedEvents = <GroupCallStreamRemoved>[];

        groupCall.matrixRTCEventStream.stream
            .where((event) => event is GroupCallStreamAdded)
            .cast<GroupCallStreamAdded>()
            .listen((event) {
          addedEvents.add(event);
        });

        groupCall.matrixRTCEventStream.stream
            .where((event) => event is GroupCallStreamRemoved)
            .cast<GroupCallStreamRemoved>()
            .listen((event) {
          removedEvents.add(event);
        });

        await backend.initLocalStream(groupCall);
        groupCall.setState(GroupCallState.entered);

        await backend.setScreensharingEnabled(groupCall, true, '');
        await pumpEventQueue();

        await backend.setScreensharingEnabled(groupCall, false, '');
        await pumpEventQueue();

        expect(removedEvents.last.type, GroupCallStreamType.screenshare);
      });
    });

    group('GroupCallActiveSpeakerChanged Event', () {
      test('emits GroupCallActiveSpeakerChanged when active speaker changes',
          () async {
        groupCall = GroupCallSession.withAutoGenId(
          room,
          voip,
          backend,
          'm.call',
          'm.room',
          'test-group-call-14',
        );

        final events = <GroupCallActiveSpeakerChanged>[];
        groupCall.matrixRTCEventStream.stream
            .where((event) => event is GroupCallActiveSpeakerChanged)
            .cast<GroupCallActiveSpeakerChanged>()
            .listen((event) {
          events.add(event);
        });

        room.setState(
          Event(
            room: room,
            eventId: 'local-membership',
            originServerTs: DateTime.now(),
            type: EventTypes.GroupCallMember,
            senderId: room.client.userID!,
            stateKey: room.client.userID!,
            content: {
              'memberships': [
                CallMembership(
                  userId: room.client.userID!,
                  roomId: room.id,
                  callId: groupCall.groupCallId,
                  application: groupCall.application,
                  scope: groupCall.scope,
                  backend: backend,
                  deviceId: room.client.deviceID!,
                  expiresTs: DateTime.now()
                      .add(Duration(hours: 1))
                      .millisecondsSinceEpoch,
                  membershipId: 'local-session-id',
                  feeds: [],
                  voip: voip,
                ).toJson(),
              ],
            },
          ),
        );

        final remoteUserId = '@zach:example.com';
        final remoteDeviceId = 'ZACHDEVICE';

        room.setState(
          Event(
            room: room,
            eventId: 'remote-member-1',
            originServerTs: DateTime.now(),
            type: EventTypes.GroupCallMember,
            senderId: remoteUserId,
            stateKey: remoteUserId,
            content: {
              'memberships': [
                CallMembership(
                  userId: remoteUserId,
                  roomId: room.id,
                  callId: groupCall.groupCallId,
                  application: groupCall.application,
                  scope: groupCall.scope,
                  backend: backend,
                  deviceId: remoteDeviceId,
                  expiresTs: DateTime.now()
                      .add(Duration(hours: 1))
                      .millisecondsSinceEpoch,
                  membershipId: 'remote-session-id-1',
                  feeds: [],
                  voip: voip,
                ).toJson(),
              ],
            },
          ),
        );

        await groupCall.enter();
        await pumpEventQueue();

        final call = voip.calls.values.firstWhere(
          (c) =>
              c.remoteUserId == remoteUserId &&
              c.groupCallId == groupCall.groupCallId,
        );

        await call.onSDPStreamMetadataReceived(
          SDPStreamMetadata({
            'remote-stream-id': SDPStreamPurpose(
              purpose: SDPStreamMetadataPurpose.Usermedia,
              audio_muted: false,
              video_muted: false,
            ),
          }),
        );

        final mockRemoteStream = MockMediaStream('remote-stream-id', 'remote');
        final mockPeerConnection = call.pc as MockRTCPeerConnection;
        mockPeerConnection.mockAudioLevel = 0.8;

        if (mockPeerConnection.onTrack != null) {
          mockPeerConnection.onTrack!(
            MockRTCTrackEvent(
              track: MockMediaStreamTrack(),
              streams: [mockRemoteStream],
            ),
          );
        }

        await pumpEventQueue();
        // Keep the 6-second delay as it's likely testing timer-based active speaker detection
        await Future.delayed(Duration(seconds: 6));

        expect(events.length, 1);
        expect(events[0].participant.userId, remoteUserId);
        expect(events[0].participant.deviceId, remoteDeviceId);
      });
    });

    group('GroupCallLocalMutedChanged Event', () {
      test('emits GroupCallLocalMutedChanged for audio and video mute/unmute',
          () async {
        groupCall = GroupCallSession.withAutoGenId(
          room,
          voip,
          backend,
          'm.call',
          'm.room',
          'test-group-call-15',
        );

        final events = <GroupCallLocalMutedChanged>[];
        groupCall.matrixRTCEventStream.stream
            .where((event) => event is GroupCallLocalMutedChanged)
            .cast<GroupCallLocalMutedChanged>()
            .listen((event) {
          events.add(event);
        });

        await backend.initLocalStream(groupCall);
        groupCall.setState(GroupCallState.entered);

        // Test audio muting
        await backend.setDeviceMuted(
          groupCall,
          true,
          MediaInputKind.audioinput,
        );
        await pumpEventQueue();

        expect(events.length, 1);
        expect(events[0].muted, true);
        expect(events[0].kind, MediaInputKind.audioinput);

        // Test video muting
        await backend.setDeviceMuted(
          groupCall,
          true,
          MediaInputKind.videoinput,
        );
        await pumpEventQueue();

        expect(events.length, 2);
        expect(events[1].muted, true);
        expect(events[1].kind, MediaInputKind.videoinput);

        // Test audio unmuting
        await backend.setDeviceMuted(
          groupCall,
          false,
          MediaInputKind.audioinput,
        );
        await pumpEventQueue();

        expect(events.length, 3);
        expect(events[2].muted, false);
        expect(events[2].kind, MediaInputKind.audioinput);

        // Test video unmuting
        await backend.setDeviceMuted(
          groupCall,
          false,
          MediaInputKind.videoinput,
        );
        await pumpEventQueue();

        expect(events.length, 4);
        expect(events[3].muted, false);
        expect(events[3].kind, MediaInputKind.videoinput);

        // Verify all events have correct MediaInputKind
        final audioEvents =
            events.where((e) => e.kind == MediaInputKind.audioinput).toList();
        final videoEvents =
            events.where((e) => e.kind == MediaInputKind.videoinput).toList();

        expect(audioEvents.length, 2);
        expect(videoEvents.length, 2);
        expect(audioEvents[0].muted, true);
        expect(audioEvents[1].muted, false);
        expect(videoEvents[0].muted, true);
        expect(videoEvents[1].muted, false);
      });
    });

    group('GroupCallLocalScreenshareStateChanged Event', () {
      test(
          'emits GroupCallLocalScreenshareStateChanged when screenshare is enabled and disabled',
          () async {
        groupCall = GroupCallSession.withAutoGenId(
          room,
          voip,
          backend,
          'm.call',
          'm.room',
          'test-group-call-19',
        );

        final events = <GroupCallLocalScreenshareStateChanged>[];
        groupCall.matrixRTCEventStream.stream
            .where((event) => event is GroupCallLocalScreenshareStateChanged)
            .cast<GroupCallLocalScreenshareStateChanged>()
            .listen((event) {
          events.add(event);
        });

        await backend.initLocalStream(groupCall);
        groupCall.setState(GroupCallState.entered);

        await backend.setScreensharingEnabled(groupCall, true, '');
        await pumpEventQueue();

        expect(events.length, 1);
        expect(events[0].screensharing, true);

        await backend.setScreensharingEnabled(groupCall, false, '');
        await pumpEventQueue();

        expect(events.length, 2);
        expect(events[1].screensharing, false);
      });
    });

    group('Event Stream Integration Tests', () {
      test('multiple event types can be emitted in sequence', () async {
        groupCall = GroupCallSession.withAutoGenId(
          room,
          voip,
          backend,
          'm.call',
          'm.room',
          'test-group-call-23',
        );

        final allEvents = <MatrixRTCCallEvent>[];
        groupCall.matrixRTCEventStream.stream.listen((event) {
          allEvents.add(event);
        });

        await backend.initLocalStream(groupCall);
        groupCall.setState(GroupCallState.entered);
        await backend.setDeviceMuted(
          groupCall,
          true,
          MediaInputKind.audioinput,
        );
        await backend.setDeviceMuted(
          groupCall,
          true,
          MediaInputKind.videoinput,
        );
        await pumpEventQueue();

        expect(allEvents.length, 6);

        final stateChangedEvents =
            allEvents.whereType<GroupCallStateChanged>().toList();
        final streamAddedEvents =
            allEvents.whereType<GroupCallStreamAdded>().toList();
        final mutedChangedEvents =
            allEvents.whereType<GroupCallLocalMutedChanged>().toList();

        expect(stateChangedEvents.length, 3);
        expect(streamAddedEvents.length, 1);
        expect(mutedChangedEvents.length, 2);

        expect(allEvents[0], isA<GroupCallStateChanged>());
        expect(
          (allEvents[0] as GroupCallStateChanged).state,
          GroupCallState.initializingLocalCallFeed,
        );
        expect(allEvents[1], isA<GroupCallStreamAdded>());
        expect(
          (allEvents[1] as GroupCallStreamAdded).type,
          GroupCallStreamType.userMedia,
        );
        expect(allEvents[2], isA<GroupCallStateChanged>());
        expect(
          (allEvents[2] as GroupCallStateChanged).state,
          GroupCallState.localCallFeedInitialized,
        );
        expect(allEvents[3], isA<GroupCallStateChanged>());
        expect(
          (allEvents[3] as GroupCallStateChanged).state,
          GroupCallState.entered,
        );
        expect(allEvents[4], isA<GroupCallLocalMutedChanged>());
        expect(
          (allEvents[4] as GroupCallLocalMutedChanged).kind,
          MediaInputKind.audioinput,
        );
        expect((allEvents[4] as GroupCallLocalMutedChanged).muted, true);
        expect(allEvents[5], isA<GroupCallLocalMutedChanged>());
        expect(
          (allEvents[5] as GroupCallLocalMutedChanged).kind,
          MediaInputKind.videoinput,
        );
        expect((allEvents[5] as GroupCallLocalMutedChanged).muted, true);
      });

      test(
          'event stream supports multiple listeners and filtering by event type',
          () async {
        groupCall = GroupCallSession.withAutoGenId(
          room,
          voip,
          backend,
          'm.call',
          'm.room',
          'test-group-call-24',
        );

        final allEvents1 = <MatrixRTCCallEvent>[];
        final allEvents2 = <MatrixRTCCallEvent>[];
        final stateChangedEvents = <GroupCallStateChanged>[];
        final streamAddedEvents = <GroupCallStreamAdded>[];
        final mutedChangedEvents = <GroupCallLocalMutedChanged>[];

        groupCall.matrixRTCEventStream.stream.listen(allEvents1.add);
        groupCall.matrixRTCEventStream.stream.listen(allEvents2.add);

        groupCall.matrixRTCEventStream.stream
            .where((e) => e is GroupCallStateChanged)
            .cast<GroupCallStateChanged>()
            .listen(stateChangedEvents.add);
        groupCall.matrixRTCEventStream.stream
            .where((e) => e is GroupCallStreamAdded)
            .cast<GroupCallStreamAdded>()
            .listen(streamAddedEvents.add);
        groupCall.matrixRTCEventStream.stream
            .where((e) => e is GroupCallLocalMutedChanged)
            .cast<GroupCallLocalMutedChanged>()
            .listen(mutedChangedEvents.add);

        await backend.initLocalStream(groupCall);
        groupCall.setState(GroupCallState.entered);
        await backend.setDeviceMuted(
          groupCall,
          true,
          MediaInputKind.audioinput,
        );
        await pumpEventQueue();

        expect(allEvents1.length, 5);
        expect(allEvents2.length, 5);
        expect(stateChangedEvents.length, 3);
        expect(streamAddedEvents.length, 1);
        expect(mutedChangedEvents.length, 1);

        expect(
          stateChangedEvents.length +
              streamAddedEvents.length +
              mutedChangedEvents.length,
          allEvents1.length,
        );

        expect(
          stateChangedEvents.map((e) => e.state).toList(),
          [
            GroupCallState.initializingLocalCallFeed,
            GroupCallState.localCallFeedInitialized,
            GroupCallState.entered,
          ],
        );
        expect(streamAddedEvents[0].type, GroupCallStreamType.userMedia);
        expect(mutedChangedEvents[0].kind, MediaInputKind.audioinput);
        expect(mutedChangedEvents[0].muted, true);
      });
    });
  });
}
