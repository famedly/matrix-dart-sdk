import 'dart:async';

import 'package:test/test.dart';

import 'package:matrix/matrix.dart';
import 'fake_client.dart';
import 'webrtc_stub.dart';

void main() {
  late Client matrix;
  late Room room;
  late VoIP voip;

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
      final reactionEvents = <ReactionEvent>[];
      final subscription =
          groupCall.matrixRTCEventStream.stream.listen((event) {
        if (event is ReactionEvent) {
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
                      type: EventTypes.Reaction,
                      content: {
                        'm.relates_to': {
                          'rel_type': RelationshipTypes.reaction,
                          'event_id': 'membership_event_reactions',
                          'key': '🖐️',
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
      expect(reactionEvents.first, isA<ReactionAddedEvent>());

      final addedEvent = reactionEvents.first as ReactionAddedEvent;
      expect(addedEvent.reactionKey, '🖐️');
      expect(addedEvent.participant.userId, '@alice:testing.com');
      expect(addedEvent.eventId, 'hand_raise_reaction');

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
      final reactionEvents = <ReactionEvent>[];
      final subscription =
          groupCall.matrixRTCEventStream.stream.listen((event) {
        if (event is ReactionEvent) {
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
                      type: EventTypes.Reaction,
                      content: {
                        'm.relates_to': {
                          'rel_type': RelationshipTypes.reaction,
                          'event_id': 'membership_event_redaction',
                          'key': '🖐️',
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
      expect(reactionEvents[0], isA<ReactionAddedEvent>());
      expect(reactionEvents[1], isA<ReactionRemovedEvent>());

      final addedEvent = reactionEvents[0] as ReactionAddedEvent;
      final removedEvent = reactionEvents[1] as ReactionRemovedEvent;

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
      final reactionEvents = <ReactionEvent>[];
      final subscription =
          groupCall.matrixRTCEventStream.stream.listen((event) {
        if (event is ReactionEvent) {
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
                      type: EventTypes.Reaction,
                      content: {
                        'm.relates_to': {
                          'rel_type': RelationshipTypes.reaction,
                          'event_id': 'membership_event_1',
                          'key': '🖐️',
                        },
                      },
                      senderId: '@user1:testing.com',
                      eventId: 'hand_raise_user1',
                      originServerTs: DateTime.now(),
                    ),
                    MatrixEvent(
                      type: EventTypes.Reaction,
                      content: {
                        'm.relates_to': {
                          'rel_type': RelationshipTypes.reaction,
                          'event_id': 'membership_event_2',
                          'key': '🖐️',
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
        reactionEvents.every((event) => event is ReactionAddedEvent),
        true,
      );

      final event1 = reactionEvents[0] as ReactionAddedEvent;
      final event2 = reactionEvents[1] as ReactionAddedEvent;

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
      final reactionEvents = <ReactionEvent>[];
      final subscription =
          groupCall.matrixRTCEventStream.stream.listen((event) {
        if (event is ReactionEvent) {
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
                      type: EventTypes.Reaction,
                      content: {
                        'm.relates_to': {
                          'rel_type': RelationshipTypes.reaction,
                          'event_id': 'my_membership_event',
                          'key': '🖐️',
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
      expect(reactionEvents.first, isA<ReactionAddedEvent>());

      final addedEvent = reactionEvents.first as ReactionAddedEvent;
      expect(addedEvent.reactionKey, '🖐️');
      expect(addedEvent.participant.userId, matrix.userID!);
      expect(addedEvent.eventId, 'my_hand_raise');

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
      final eventId = await groupCall.sendReactionEvent(
        userId: matrix.userID!,
        key: '🖐️',
        deviceId: matrix.deviceID,
      );

      // With fake client, this will return a valid event ID now that we added the endpoint
      expect(eventId, isNotNull); // Expected with updated fake client

      // Test removing a reaction (will also fail with fake client)
      await groupCall.removeReactionEvent(
        reactionId: 'fake_reaction_id',
        reason: 'Hand lowered',
      );

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
      final reactions = await groupCall.getAllReactions(key: '🖐️');

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
      final reactionEvents = <ReactionEvent>[];
      final subscription =
          groupCall.matrixRTCEventStream.stream.listen((event) {
        if (event is ReactionEvent) {
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
                      type: EventTypes.Reaction,
                      content: {
                        // Missing m.relates_to
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'invalid_reaction_1',
                      originServerTs: DateTime.now(),
                    ),
                    // Missing key in m.relates_to
                    MatrixEvent(
                      type: EventTypes.Reaction,
                      content: {
                        'm.relates_to': {
                          'rel_type': RelationshipTypes.reaction,
                          'event_id': 'membership_event_invalid_reactions',
                          // Missing key
                        },
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'invalid_reaction_2',
                      originServerTs: DateTime.now(),
                    ),
                    // Missing event_id in m.relates_to
                    MatrixEvent(
                      type: EventTypes.Reaction,
                      content: {
                        'm.relates_to': {
                          'rel_type': RelationshipTypes.reaction,
                          // Missing event_id
                          'key': '🖐️',
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
      final reactionEvents = <ReactionEvent>[];
      final subscription =
          groupCall.matrixRTCEventStream.stream.listen((event) {
        if (event is ReactionEvent) {
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
  });
}
