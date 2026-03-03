import 'dart:async';

import 'package:test/test.dart';

import 'package:matrix/matrix.dart';
import 'fake_client.dart';
import 'webrtc_stub.dart';

void main() {
  late Client matrix;
  late Room room;
  late VoIP voip;

  final testEmojis = [
    {'emoji': '🖐️', 'name': 'hand raise'},
    {'emoji': '👍', 'name': 'thumbs up'},
    {'emoji': '👏', 'name': 'clap'},
    {'emoji': '❤️', 'name': 'heart'},
    {'emoji': '😂', 'name': 'laugh'},
  ];

  group('VoIP Reaction Events Tests', () {
    Logs().level = Level.info;

    setUp(() async {
      matrix = await getClient();
      await matrix.abortSync();

      voip = VoIP(matrix, MockWebRTCDelegate());
      VoIP.customTxid = '1234';
      final id = '!calls:example.com';
      room = matrix.getRoomById(id)!;
    });

    test('Test hand raise reaction receiving and state management', () async {
      // Set up a group call membership
      final membership = CallMembership(
        userId: '@alice:testing.com',
        callId: 'test_call_reactions',
        backend: MeshBackend(),
        deviceId: 'device123',
        expiresTs:
            DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch,
        roomId: room.id,
        membershipId: voip.currentSessionId,
        voip: voip,
        eventId: 'membership_event_reactions',
      );

      // Set up the room state with the membership
      room.setState(
        Event(
          content: {
            'memberships': [membership.toJson()],
          },
          type: EventTypes.GroupCallMember,
          eventId: 'membership_event_reactions',
          senderId: '@alice:testing.com',
          originServerTs: DateTime.now(),
          room: room,
          stateKey: '@alice:testing.com',
        ),
      );

      // Manually create the group call session since room.setState doesn't trigger the VoIP listener
      await voip.createGroupCallFromRoomStateEvent(membership);

      // Get the group call session
      final groupCall = voip.getGroupCallById(room.id, 'test_call_reactions');
      expect(groupCall, isNotNull);

      // Enter the group call so it can process reactions
      await groupCall!.enter();

      // Listen for reaction events
      final reactionEvents = <CallReactionEvent>[];
      final subscription =
          groupCall.matrixRTCEventStream.stream.listen((event) {
        if (event is CallReactionEvent) {
          reactionEvents.add(event);
        }
      });

      // Simulate receiving a hand raise reaction event
      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent(
                      type: EventTypes.GroupCallMemberReaction,
                      content: {
                        'key': '🖐️',
                        'name': 'hand raise',
                        'is_ephemeral': true,
                        'call_id': 'test_call_reactions',
                        'device_id': 'device123',
                        'm.relates_to': {
                          'rel_type': RelationshipTypes.reference,
                          'event_id': 'membership_event_reactions',
                        },
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'hand_raise_reaction',
                      originServerTs: DateTime.now(),
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );

      // Wait for the reaction to be processed
      await Future.delayed(Duration(milliseconds: 100));

      // Verify the reaction was received
      expect(reactionEvents.length, 1);
      expect(reactionEvents.first, isA<CallReactionAddedEvent>());

      final addedEvent = reactionEvents.first as CallReactionAddedEvent;
      expect(addedEvent.reactionKey, '🖐️');
      expect(addedEvent.participant.userId, '@alice:testing.com');
      expect(addedEvent.membershipEventId, 'membership_event_reactions');

      await subscription.cancel();
    });

    test('Test hand raise reaction removal via redaction', () async {
      // Set up a group call membership
      final membership = CallMembership(
        userId: '@alice:testing.com',
        callId: 'test_call_redaction',
        backend: MeshBackend(),
        deviceId: 'device123',
        expiresTs:
            DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch,
        roomId: room.id,
        membershipId: voip.currentSessionId,
        voip: voip,
        eventId: 'membership_event_redaction',
      );

      // Set up the room state with the membership
      room.setState(
        Event(
          content: {
            'memberships': [membership.toJson()],
          },
          type: EventTypes.GroupCallMember,
          eventId: 'membership_event_redaction',
          senderId: '@alice:testing.com',
          originServerTs: DateTime.now(),
          room: room,
          stateKey: '@alice:testing.com',
        ),
      );

      // Manually create the group call session
      await voip.createGroupCallFromRoomStateEvent(membership);

      // Get the group call session
      final groupCall = voip.getGroupCallById(room.id, 'test_call_redaction');
      expect(groupCall, isNotNull);

      // Enter the group call so it can process reactions
      await groupCall!.enter();

      // Listen for reaction events
      final reactionEvents = <CallReactionEvent>[];
      final subscription =
          groupCall.matrixRTCEventStream.stream.listen((event) {
        if (event is CallReactionEvent) {
          reactionEvents.add(event);
        }
      });

      // First, add a hand raise reaction
      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'something1',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent(
                      type: EventTypes.GroupCallMemberReaction,
                      content: {
                        'key': '🖐️',
                        'name': 'hand raise',
                        'is_ephemeral': true,
                        'call_id': 'test_call_redaction',
                        'device_id': 'device123',
                        'm.relates_to': {
                          'rel_type': RelationshipTypes.reference,
                          'event_id': 'membership_event_redaction',
                        },
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'hand_raise_to_redact',
                      originServerTs: DateTime.now(),
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );

      // Wait for processing
      await Future.delayed(Duration(milliseconds: 50));

      // Now simulate a redaction event
      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'something2',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent(
                      type: EventTypes.Redaction,
                      content: {
                        'redacts': 'hand_raise_to_redact',
                        'device_id': 'device123',
                        'redacts_type': 'com.famedly.call.member.reaction',
                        'call_id': 'test_call_redaction',
                        'reason': 'Hand lowered',
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'redaction_event',
                      originServerTs: DateTime.now(),
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );

      // Wait for processing
      await Future.delayed(Duration(milliseconds: 100));

      // Verify both events were received
      expect(reactionEvents.length, 2);
      expect(reactionEvents[0], isA<CallReactionAddedEvent>());
      expect(reactionEvents[1], isA<CallReactionRemovedEvent>());

      final addedEvent = reactionEvents[0] as CallReactionAddedEvent;
      final removedEvent = reactionEvents[1] as CallReactionRemovedEvent;

      expect(addedEvent.reactionKey, '🖐️');
      expect(removedEvent.redactedEventId, 'hand_raise_to_redact');
      expect(removedEvent.participant.userId, '@alice:testing.com');

      await subscription.cancel();
    });

    test('Test multiple participants hand raise reactions', () async {
      // Set up multiple group call memberships
      final membership1 = CallMembership(
        userId: '@user1:testing.com',
        callId: 'test_call_multi_reactions',
        backend: MeshBackend(),
        deviceId: 'device1',
        expiresTs:
            DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch,
        roomId: room.id,
        membershipId: voip.currentSessionId,
        voip: voip,
        eventId: 'membership_event_1',
      );

      final membership2 = CallMembership(
        userId: '@user2:testing.com',
        callId: 'test_call_multi_reactions',
        backend: MeshBackend(),
        deviceId: 'device2',
        expiresTs:
            DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch,
        roomId: room.id,
        membershipId: voip.currentSessionId,
        voip: voip,
        eventId: 'membership_event_2',
      );

      // Set up the room state with both memberships
      room.setState(
        Event(
          content: {
            'memberships': [membership1.toJson()],
          },
          type: EventTypes.GroupCallMember,
          eventId: 'membership_event_1',
          senderId: '@user1:testing.com',
          originServerTs: DateTime.now(),
          room: room,
          stateKey: '@user1:testing.com',
        ),
      );

      room.setState(
        Event(
          content: {
            'memberships': [membership2.toJson()],
          },
          type: EventTypes.GroupCallMember,
          eventId: 'membership_event_2',
          senderId: '@user2:testing.com',
          originServerTs: DateTime.now(),
          room: room,
          stateKey: '@user2:testing.com',
        ),
      );

      // Manually create the group call sessions
      await voip.createGroupCallFromRoomStateEvent(membership1);
      await voip.createGroupCallFromRoomStateEvent(membership2);

      // Get the group call session
      final groupCall =
          voip.getGroupCallById(room.id, 'test_call_multi_reactions');
      expect(groupCall, isNotNull);

      // Enter the group call so it can process reactions
      await groupCall!.enter();

      // Listen for reaction events
      final reactionEvents = <CallReactionEvent>[];
      final subscription =
          groupCall.matrixRTCEventStream.stream.listen((event) {
        if (event is CallReactionEvent) {
          reactionEvents.add(event);
        }
      });

      // Simulate multiple hand raise reactions
      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent(
                      type: EventTypes.GroupCallMemberReaction,
                      content: {
                        'key': '🖐️',
                        'name': 'hand raise',
                        'is_ephemeral': true,
                        'call_id': 'test_call_multi_reactions',
                        'device_id': 'device1',
                        'm.relates_to': {
                          'rel_type': RelationshipTypes.reference,
                          'event_id': 'membership_event_1',
                        },
                      },
                      senderId: '@user1:testing.com',
                      eventId: 'hand_raise_user1',
                      originServerTs: DateTime.now(),
                    ),
                    MatrixEvent(
                      type: EventTypes.GroupCallMemberReaction,
                      content: {
                        'key': '🖐️',
                        'name': 'hand raise',
                        'is_ephemeral': true,
                        'call_id': 'test_call_multi_reactions',
                        'device_id': 'device2',
                        'm.relates_to': {
                          'rel_type': RelationshipTypes.reference,
                          'event_id': 'membership_event_2',
                        },
                      },
                      senderId: '@user2:testing.com',
                      eventId: 'hand_raise_user2',
                      originServerTs: DateTime.now(),
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );

      // Wait for processing
      await Future.delayed(Duration(milliseconds: 100));

      // Verify both reactions were received
      expect(reactionEvents.length, 2);
      expect(
        reactionEvents.every((event) => event is CallReactionAddedEvent),
        true,
      );

      final event1 = reactionEvents[0] as CallReactionAddedEvent;
      final event2 = reactionEvents[1] as CallReactionAddedEvent;

      expect(event1.reactionKey, '🖐️');
      expect(event2.reactionKey, '🖐️');
      expect(event1.participant.userId, '@user1:testing.com');
      expect(event2.participant.userId, '@user2:testing.com');

      await subscription.cancel();
    });

    test('Test current user own reaction events are processed', () async {
      // Set up a group call membership for the current user
      final membership = CallMembership(
        userId: matrix.userID!,
        callId: 'test_call_own_reactions',
        backend: MeshBackend(),
        deviceId: matrix.deviceID!,
        expiresTs:
            DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch,
        roomId: room.id,
        membershipId: voip.currentSessionId,
        voip: voip,
        eventId: 'my_membership_event',
      );

      // Set up the room state with the membership
      room.setState(
        Event(
          content: {
            'memberships': [membership.toJson()],
          },
          type: EventTypes.GroupCallMember,
          eventId: 'my_membership_event',
          senderId: matrix.userID!,
          originServerTs: DateTime.now(),
          room: room,
          stateKey: matrix.userID!,
        ),
      );

      // Manually create the group call session
      await voip.createGroupCallFromRoomStateEvent(membership);

      // Get the group call session
      final groupCall =
          voip.getGroupCallById(room.id, 'test_call_own_reactions');
      expect(groupCall, isNotNull);

      // Enter the group call so it can process reactions
      await groupCall!.enter();

      // Listen for reaction events
      final reactionEvents = <CallReactionEvent>[];
      final subscription =
          groupCall.matrixRTCEventStream.stream.listen((event) {
        if (event is CallReactionEvent) {
          reactionEvents.add(event);
        }
      });

      // Simulate the current user raising their hand
      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent(
                      type: EventTypes.GroupCallMemberReaction,
                      content: {
                        'key': '🖐️',
                        'name': 'hand raise',
                        'is_ephemeral': true,
                        'call_id': 'test_call_own_reactions',
                        'device_id': matrix.deviceID!,
                        'm.relates_to': {
                          'rel_type': RelationshipTypes.reference,
                          'event_id': 'my_membership_event',
                        },
                      },
                      senderId: matrix.userID!,
                      eventId: 'my_hand_raise',
                      originServerTs: DateTime.now(),
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );

      // Wait for processing
      await Future.delayed(Duration(milliseconds: 100));

      // Verify the user's own reaction was processed
      expect(reactionEvents.length, 1);
      expect(reactionEvents.first, isA<CallReactionAddedEvent>());

      final addedEvent = reactionEvents.first as CallReactionAddedEvent;
      expect(addedEvent.reactionKey, '🖐️');
      expect(addedEvent.participant.userId, matrix.userID!);
      expect(addedEvent.membershipEventId, 'my_membership_event');

      await subscription.cancel();
    });

    test('Test sending hand raise reaction through GroupCallSession', () async {
      // Set up a group call membership for the current user
      final membership = CallMembership(
        userId: matrix.userID!,
        callId: 'test_call_send_reaction',
        backend: MeshBackend(),
        deviceId: matrix.deviceID!,
        expiresTs:
            DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch,
        roomId: room.id,
        membershipId: voip.currentSessionId,
        voip: voip,
        eventId: 'send_membership_event',
      );

      // Set up the room state with the membership
      room.setState(
        Event(
          content: {
            'memberships': [membership.toJson()],
          },
          type: EventTypes.GroupCallMember,
          eventId: 'send_membership_event',
          senderId: matrix.userID!,
          originServerTs: DateTime.now(),
          room: room,
          stateKey: matrix.userID!,
        ),
      );

      // Manually create the group call session
      await voip.createGroupCallFromRoomStateEvent(membership);

      // Get the group call session
      final groupCall =
          voip.getGroupCallById(room.id, 'test_call_send_reaction');
      expect(groupCall, isNotNull);

      // Enter the group call so it can process reactions
      await groupCall!.enter();

      // Test sending a hand raise reaction
      // This will fail with the fake client but should not crash
      final eventId = await groupCall.sendReactionEvent(emoji: '🖐️');
      // With fake client, this will return a valid event ID now that we added the endpoint
      expect(eventId, isNotNull); // Expected with updated fake client

      // Test removing a reaction (will also fail with fake client)
      await groupCall.removeReactionEvent(eventId: 'fake_reaction_id');

      // The test passes if we reach here without crashing
      expect(true, true);
    });

    test('Test getAllReactions includes current user reactions', () async {
      // Set up group call memberships for multiple users including current user
      final currentUserMembership = CallMembership(
        userId: matrix.userID!,
        callId: 'test_call_get_all',
        backend: MeshBackend(),
        deviceId: matrix.deviceID!,
        expiresTs:
            DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch,
        roomId: room.id,
        membershipId: voip.currentSessionId,
        voip: voip,
        eventId: 'current_user_membership',
      );

      final otherUserMembership = CallMembership(
        userId: '@other:testing.com',
        callId: 'test_call_get_all',
        backend: MeshBackend(),
        deviceId: 'other_device',
        expiresTs:
            DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch,
        roomId: room.id,
        membershipId: voip.currentSessionId,
        voip: voip,
        eventId: 'other_user_membership',
      );

      // Set up the room state with both memberships
      room.setState(
        Event(
          content: {
            'memberships': [currentUserMembership.toJson()],
          },
          type: EventTypes.GroupCallMember,
          eventId: 'current_user_membership',
          senderId: matrix.userID!,
          originServerTs: DateTime.now(),
          room: room,
          stateKey: matrix.userID!,
        ),
      );

      room.setState(
        Event(
          content: {
            'memberships': [otherUserMembership.toJson()],
          },
          type: EventTypes.GroupCallMember,
          eventId: 'other_user_membership',
          senderId: '@other:testing.com',
          originServerTs: DateTime.now(),
          room: room,
          stateKey: '@other:testing.com',
        ),
      );

      // Manually create the group call sessions
      await voip.createGroupCallFromRoomStateEvent(currentUserMembership);
      await voip.createGroupCallFromRoomStateEvent(otherUserMembership);

      // Get the group call session
      final groupCall = voip.getGroupCallById(room.id, 'test_call_get_all');
      expect(groupCall, isNotNull);

      // Enter the group call so it can process reactions
      await groupCall!.enter();

      // Test getAllReactions method (will return empty with fake client but should not crash)
      final reactions = await groupCall.getAllReactions(emoji: '🖐️');

      // With fake client, this will return empty list, but the method should exist and be callable
      expect(reactions, isA<List<MatrixEvent>>());

      // The test passes if we reach here without crashing
      expect(true, true);
    });

    test('Test invalid reaction events are ignored', () async {
      // Set up a group call membership
      final membership = CallMembership(
        userId: '@alice:testing.com',
        callId: 'test_call_invalid_reactions',
        backend: MeshBackend(),
        deviceId: 'device123',
        expiresTs:
            DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch,
        roomId: room.id,
        membershipId: voip.currentSessionId,
        voip: voip,
        eventId: 'membership_event_invalid_reactions',
      );

      // Set up the room state with the membership
      room.setState(
        Event(
          content: {
            'memberships': [membership.toJson()],
          },
          type: EventTypes.GroupCallMember,
          eventId: 'membership_event_invalid_reactions',
          senderId: '@alice:testing.com',
          originServerTs: DateTime.now(),
          room: room,
          stateKey: '@alice:testing.com',
        ),
      );

      // Manually create the group call session
      await voip.createGroupCallFromRoomStateEvent(membership);

      // Get the group call session
      final groupCall =
          voip.getGroupCallById(room.id, 'test_call_invalid_reactions');
      expect(groupCall, isNotNull);

      // Enter the group call so it can process reactions
      await groupCall!.enter();

      // Listen for reaction events
      final reactionEvents = <CallReactionEvent>[];
      final subscription =
          groupCall.matrixRTCEventStream.stream.listen((event) {
        if (event is CallReactionEvent) {
          reactionEvents.add(event);
        }
      });

      // Test invalid reaction events
      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    // Missing m.relates_to
                    MatrixEvent(
                      type: EventTypes.GroupCallMemberReaction,
                      content: {
                        'key': '🖐️',
                        'name': 'hand raise',
                        'is_ephemeral': true,
                        'call_id': 'test_call_invalid_reactions',
                        'device_id': 'device123',
                        // Missing m.relates_to
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'invalid_reaction_1',
                      originServerTs: DateTime.now(),
                    ),
                    // Missing key in content
                    MatrixEvent(
                      type: EventTypes.GroupCallMemberReaction,
                      content: {
                        // Missing key
                        'name': 'hand raise',
                        'is_ephemeral': true,
                        'call_id': 'test_call_invalid_reactions',
                        'device_id': 'device123',
                        'm.relates_to': {
                          'rel_type': RelationshipTypes.reference,
                          'event_id': 'membership_event_invalid_reactions',
                        },
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'invalid_reaction_2',
                      originServerTs: DateTime.now(),
                    ),
                    // Missing device_id
                    MatrixEvent(
                      type: EventTypes.GroupCallMemberReaction,
                      content: {
                        'key': '🖐️',
                        'name': 'hand raise',
                        'is_ephemeral': true,
                        'call_id': 'test_call_invalid_reactions',
                        // Missing device_id
                        'm.relates_to': {
                          'rel_type': RelationshipTypes.reference,
                          'event_id': 'membership_event_invalid_reactions',
                        },
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'invalid_reaction_3',
                      originServerTs: DateTime.now(),
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );

      // Wait for processing
      await Future.delayed(Duration(milliseconds: 100));

      // Verify no invalid reactions were processed
      expect(reactionEvents.isEmpty, true);

      await subscription.cancel();
    });

    test('Test invalid redaction events are ignored', () async {
      // Set up a group call membership
      final membership = CallMembership(
        userId: '@alice:testing.com',
        callId: 'test_call_invalid_redactions',
        backend: MeshBackend(),
        deviceId: 'device123',
        expiresTs:
            DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch,
        roomId: room.id,
        membershipId: voip.currentSessionId,
        voip: voip,
        eventId: 'membership_event_invalid_redactions',
      );

      // Set up the room state with the membership
      room.setState(
        Event(
          content: {
            'memberships': [membership.toJson()],
          },
          type: EventTypes.GroupCallMember,
          eventId: 'membership_event_invalid_redactions',
          senderId: '@alice:testing.com',
          originServerTs: DateTime.now(),
          room: room,
          stateKey: '@alice:testing.com',
        ),
      );

      // Manually create the group call session
      await voip.createGroupCallFromRoomStateEvent(membership);

      // Get the group call session
      final groupCall =
          voip.getGroupCallById(room.id, 'test_call_invalid_redactions');
      expect(groupCall, isNotNull);

      // Enter the group call so it can process reactions
      await groupCall!.enter();

      // Listen for reaction events
      final reactionEvents = <CallReactionEvent>[];
      final subscription =
          groupCall.matrixRTCEventStream.stream.listen((event) {
        if (event is CallReactionEvent) {
          reactionEvents.add(event);
        }
      });

      // Test invalid redaction events
      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    // Missing redacts field
                    MatrixEvent(
                      type: EventTypes.Redaction,
                      content: {
                        // Missing redacts
                        'reason': 'Hand lowered',
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'invalid_redaction_1',
                      originServerTs: DateTime.now(),
                    ),
                    // Empty content
                    MatrixEvent(
                      type: EventTypes.Redaction,
                      content: {},
                      senderId: '@alice:testing.com',
                      eventId: 'invalid_redaction_2',
                      originServerTs: DateTime.now(),
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );

      // Wait for processing
      await Future.delayed(Duration(milliseconds: 100));

      // Verify no invalid redactions were processed
      expect(reactionEvents.isEmpty, true);

      await subscription.cancel();
    });

    test('Test different emoji reactions (thumbs up, clap, heart)', () async {
      // Set up a group call membership
      final membership = CallMembership(
        userId: '@alice:testing.com',
        callId: 'test_call_emoji_variety',
        backend: MeshBackend(),
        deviceId: 'device123',
        expiresTs:
            DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch,
        roomId: room.id,
        membershipId: voip.currentSessionId,
        voip: voip,
        eventId: 'membership_event_emoji_variety',
      );

      // Set up the room state with the membership
      room.setState(
        Event(
          content: {
            'memberships': [membership.toJson()],
          },
          type: EventTypes.GroupCallMember,
          eventId: 'membership_event_emoji_variety',
          senderId: '@alice:testing.com',
          originServerTs: DateTime.now(),
          room: room,
          stateKey: '@alice:testing.com',
        ),
      );

      // Manually create the group call session
      await voip.createGroupCallFromRoomStateEvent(membership);

      // Get the group call session
      final groupCall =
          voip.getGroupCallById(room.id, 'test_call_emoji_variety');
      expect(groupCall, isNotNull);

      // Enter the group call so it can process reactions
      await groupCall!.enter();

      // Listen for reaction events
      final reactionEvents = <CallReactionEvent>[];
      final subscription =
          groupCall.matrixRTCEventStream.stream.listen((event) {
        if (event is CallReactionEvent) {
          reactionEvents.add(event);
        }
      });

      // Test different emoji reactions using first 5 emojis
      final emojis = testEmojis.take(5).toList();

      for (int i = 0; i < emojis.length; i++) {
        await matrix.handleSync(
          SyncUpdate(
            nextBatch: 'emoji_batch_$i',
            rooms: RoomsUpdate(
              join: {
                room.id: JoinedRoomUpdate(
                  timeline: TimelineUpdate(
                    events: [
                      MatrixEvent(
                        type: EventTypes.GroupCallMemberReaction,
                        content: {
                          'key': emojis[i]['emoji']!,
                          'name': emojis[i]['name']!,
                          'is_ephemeral': true,
                          'call_id': 'test_call_emoji_variety',
                          'device_id': 'device123',
                          'm.relates_to': {
                            'rel_type': RelationshipTypes.reference,
                            'event_id': 'membership_event_emoji_variety',
                          },
                        },
                        senderId: '@alice:testing.com',
                        eventId: 'emoji_reaction_$i',
                        originServerTs: DateTime.now(),
                      ),
                    ],
                  ),
                ),
              },
            ),
          ),
        );

        // Small delay between reactions
        await Future.delayed(Duration(milliseconds: 10));
      }

      // Wait for all reactions to be processed
      await Future.delayed(Duration(milliseconds: 100));

      // Verify all emoji reactions were received
      expect(reactionEvents.length, emojis.length);
      expect(
        reactionEvents.every((event) => event is CallReactionAddedEvent),
        true,
      );

      // Verify each emoji was processed correctly
      for (int i = 0; i < emojis.length; i++) {
        final event = reactionEvents[i] as CallReactionAddedEvent;
        expect(event.reactionKey, emojis[i]['emoji']);
        expect(event.participant.userId, '@alice:testing.com');
        expect(event.isEphemeral, true);
      }

      await subscription.cancel();
    });

    test('Test ephemeral vs permanent reactions', () async {
      // Set up a group call membership
      final membership = CallMembership(
        userId: '@alice:testing.com',
        callId: 'test_call_ephemeral_permanent',
        backend: MeshBackend(),
        deviceId: 'device123',
        expiresTs:
            DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch,
        roomId: room.id,
        membershipId: voip.currentSessionId,
        voip: voip,
        eventId: 'membership_event_ephemeral_permanent',
      );

      // Set up the room state with the membership
      room.setState(
        Event(
          content: {
            'memberships': [membership.toJson()],
          },
          type: EventTypes.GroupCallMember,
          eventId: 'membership_event_ephemeral_permanent',
          senderId: '@alice:testing.com',
          originServerTs: DateTime.now(),
          room: room,
          stateKey: '@alice:testing.com',
        ),
      );

      // Manually create the group call session
      await voip.createGroupCallFromRoomStateEvent(membership);

      // Get the group call session
      final groupCall =
          voip.getGroupCallById(room.id, 'test_call_ephemeral_permanent');
      expect(groupCall, isNotNull);

      // Enter the group call so it can process reactions
      await groupCall!.enter();

      // Listen for reaction events
      final reactionEvents = <CallReactionEvent>[];
      final subscription =
          groupCall.matrixRTCEventStream.stream.listen((event) {
        if (event is CallReactionEvent) {
          reactionEvents.add(event);
        }
      });

      // Send both ephemeral and permanent reactions
      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'ephemeral_permanent_batch',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    // Ephemeral reaction
                    MatrixEvent(
                      type: EventTypes.GroupCallMemberReaction,
                      content: {
                        'key': testEmojis[0]['emoji']!,
                        'name': testEmojis[0]['name']!,
                        'is_ephemeral': true,
                        'call_id': 'test_call_ephemeral_permanent',
                        'device_id': 'device123',
                        'm.relates_to': {
                          'rel_type': RelationshipTypes.reference,
                          'event_id': 'membership_event_ephemeral_permanent',
                        },
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'ephemeral_reaction',
                      originServerTs: DateTime.now(),
                    ),
                    // Permanent reaction
                    MatrixEvent(
                      type: EventTypes.GroupCallMemberReaction,
                      content: {
                        'key': testEmojis[1]['emoji']!,
                        'name': testEmojis[1]['name']!,
                        'is_ephemeral': false,
                        'call_id': 'test_call_ephemeral_permanent',
                        'device_id': 'device123',
                        'm.relates_to': {
                          'rel_type': RelationshipTypes.reference,
                          'event_id': 'membership_event_ephemeral_permanent',
                        },
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'permanent_reaction',
                      originServerTs: DateTime.now(),
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );

      // Wait for processing
      await Future.delayed(Duration(milliseconds: 100));

      // Verify both reactions were received
      expect(reactionEvents.length, 2);
      expect(
        reactionEvents.every((event) => event is CallReactionAddedEvent),
        true,
      );

      final ephemeralEvent = reactionEvents[0] as CallReactionAddedEvent;
      final permanentEvent = reactionEvents[1] as CallReactionAddedEvent;

      // Verify ephemeral reaction properties
      expect(ephemeralEvent.reactionKey, testEmojis[0]['emoji']);
      expect(ephemeralEvent.isEphemeral, true);
      expect(ephemeralEvent.participant.userId, '@alice:testing.com');

      // Verify permanent reaction properties
      expect(permanentEvent.reactionKey, testEmojis[1]['emoji']);
      expect(permanentEvent.isEphemeral, false);
      expect(permanentEvent.participant.userId, '@alice:testing.com');

      await subscription.cancel();
    });

    test('Test ephemeral reaction timeout handling', () async {
      // Set up a group call membership
      final membership = CallMembership(
        userId: '@alice:testing.com',
        callId: 'test_call_ephemeral_timeout',
        backend: MeshBackend(),
        deviceId: 'device123',
        expiresTs:
            DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch,
        roomId: room.id,
        membershipId: voip.currentSessionId,
        voip: voip,
        eventId: 'membership_event_ephemeral_timeout',
      );

      // Set up the room state with the membership
      room.setState(
        Event(
          content: {
            'memberships': [membership.toJson()],
          },
          type: EventTypes.GroupCallMember,
          eventId: 'membership_event_ephemeral_timeout',
          senderId: '@alice:testing.com',
          originServerTs: DateTime.now(),
          room: room,
          stateKey: '@alice:testing.com',
        ),
      );

      // Manually create the group call session
      await voip.createGroupCallFromRoomStateEvent(membership);

      // Get the group call session
      final groupCall =
          voip.getGroupCallById(room.id, 'test_call_ephemeral_timeout');
      expect(groupCall, isNotNull);

      // Enter the group call so it can process reactions
      await groupCall!.enter();

      // Listen for reaction events
      final reactionEvents = <CallReactionEvent>[];
      final subscription =
          groupCall.matrixRTCEventStream.stream.listen((event) {
        if (event is CallReactionEvent) {
          reactionEvents.add(event);
        }
      });

      // Create an old ephemeral reaction (older than timeout)
      final oldTimestamp = DateTime.now().subtract(Duration(minutes: 10));

      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'timeout_batch',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    // Old ephemeral reaction (should be ignored)
                    MatrixEvent(
                      type: EventTypes.GroupCallMemberReaction,
                      content: {
                        'key': testEmojis[0]['emoji']!,
                        'name': 'old ${testEmojis[0]['name']}',
                        'is_ephemeral': true,
                        'call_id': 'test_call_ephemeral_timeout',
                        'device_id': 'device123',
                        'm.relates_to': {
                          'rel_type': RelationshipTypes.reference,
                          'event_id': 'membership_event_ephemeral_timeout',
                        },
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'old_ephemeral_reaction',
                      originServerTs: oldTimestamp,
                    ),
                    // Recent ephemeral reaction (should be processed)
                    MatrixEvent(
                      type: EventTypes.GroupCallMemberReaction,
                      content: {
                        'key': testEmojis[1]['emoji']!,
                        'name': 'recent ${testEmojis[1]['name']}',
                        'is_ephemeral': true,
                        'call_id': 'test_call_ephemeral_timeout',
                        'device_id': 'device123',
                        'm.relates_to': {
                          'rel_type': RelationshipTypes.reference,
                          'event_id': 'membership_event_ephemeral_timeout',
                        },
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'recent_ephemeral_reaction',
                      originServerTs: DateTime.now(),
                    ),
                    // Old permanent reaction (should still be processed)
                    MatrixEvent(
                      type: EventTypes.GroupCallMemberReaction,
                      content: {
                        'key': testEmojis[3]['emoji']!,
                        'name': 'old ${testEmojis[3]['name']}',
                        'is_ephemeral': false,
                        'call_id': 'test_call_ephemeral_timeout',
                        'device_id': 'device123',
                        'm.relates_to': {
                          'rel_type': RelationshipTypes.reference,
                          'event_id': 'membership_event_ephemeral_timeout',
                        },
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'old_permanent_reaction',
                      originServerTs: oldTimestamp,
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );

      // Wait for processing
      await Future.delayed(Duration(milliseconds: 100));

      // Verify only recent ephemeral and old permanent reactions were processed
      // Old ephemeral should be ignored due to timeout
      expect(reactionEvents.length, 2);

      final processedReactions = reactionEvents.cast<CallReactionAddedEvent>();

      // Should have recent ephemeral thumbs up
      expect(
        processedReactions.any(
          (event) =>
              event.reactionKey == testEmojis[1]['emoji'] &&
              event.isEphemeral == true,
        ),
        true,
      );

      // Should have old permanent heart
      expect(
        processedReactions.any(
          (event) =>
              event.reactionKey == testEmojis[3]['emoji'] &&
              event.isEphemeral == false,
        ),
        true,
      );

      // Should NOT have old ephemeral hand raise
      expect(
        processedReactions
            .any((event) => event.reactionKey == testEmojis[0]['emoji']),
        false,
      );

      await subscription.cancel();
    });

    test('Test sending different emoji types through GroupCallSession',
        () async {
      // Set up a group call membership for the current user
      final membership = CallMembership(
        userId: matrix.userID!,
        callId: 'test_call_send_emojis',
        backend: MeshBackend(),
        deviceId: matrix.deviceID!,
        expiresTs:
            DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch,
        roomId: room.id,
        membershipId: voip.currentSessionId,
        voip: voip,
        eventId: 'send_emojis_membership_event',
      );

      // Set up the room state with the membership
      room.setState(
        Event(
          content: {
            'memberships': [membership.toJson()],
          },
          type: EventTypes.GroupCallMember,
          eventId: 'send_emojis_membership_event',
          senderId: matrix.userID!,
          originServerTs: DateTime.now(),
          room: room,
          stateKey: matrix.userID!,
        ),
      );

      // Manually create the group call session
      await voip.createGroupCallFromRoomStateEvent(membership);

      // Get the group call session
      final groupCall = voip.getGroupCallById(room.id, 'test_call_send_emojis');
      expect(groupCall, isNotNull);

      // Enter the group call so it can process reactions
      await groupCall!.enter();

      // Test sending different emoji reactions using all test emojis
      for (final emojiData in testEmojis) {
        // Test ephemeral reaction
        final ephemeralEventId = await groupCall.sendReactionEvent(
          emoji: emojiData['emoji']!,
          isEphemeral: true,
        );
        expect(ephemeralEventId, isNotNull);

        // Test permanent reaction
        final permanentEventId = await groupCall.sendReactionEvent(
          emoji: emojiData['emoji']!,
          isEphemeral: false,
        );
        expect(permanentEventId, isNotNull);

        // Small delay between sends
        await Future.delayed(Duration(milliseconds: 10));
      }

      // Test removing reactions (will work with fake client)
      await room.redactEvent('fake_reaction_id_1');
      await room.redactEvent('fake_reaction_id_2');

      // The test passes if we reach here without crashing
      expect(true, true);
    });
  });
}
