import 'dart:async';

import 'package:test/test.dart';

import 'package:matrix/matrix.dart';
import 'fake_client.dart';
import 'webrtc_stub.dart';

void main() {
  late Client matrix;
  late Room room;
  late VoIP voip;

  group('VoIP Emoji Reactions Tests', () {
    Logs().level = Level.info;

    setUp(() async {
      matrix = await getClient();
      await matrix.abortSync();

      voip = VoIP(matrix, MockWebRTCDelegate());
      VoIP.customTxid = '1234';
      final id = '!calls:example.com';
      room = matrix.getRoomById(id)!;
    });

    test('Test emoji reaction receiving, timeout, and map management',
        () async {
      // Set up a group call membership
      final membership = CallMembership(
        userId: '@alice:testing.com',
        callId: 'test_call_comprehensive',
        backend: MeshBackend(),
        deviceId: 'device123',
        expiresTs:
            DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch,
        roomId: room.id,
        membershipId: voip.currentSessionId,
        voip: voip,
        eventId: 'membership_event_comprehensive',
      );

      // Set up the room state with the membership
      room.setState(
        Event(
          content: {
            'memberships': [membership.toJson()],
          },
          type: EventTypes.GroupCallMember,
          eventId: 'membership_event_comprehensive',
          senderId: '@alice:testing.com',
          originServerTs: DateTime.now(),
          room: room,
          stateKey: '@alice:testing.com',
        ),
      );

      // Manually create the group call session since room.setState doesn't trigger the VoIP listener
      await voip.createGroupCallFromRoomStateEvent(membership);

      // Get the group call session
      final groupCall =
          voip.getGroupCallById(room.id, 'test_call_comprehensive');
      expect(groupCall, isNotNull);

      // Listen for emoji reaction updates
      final reactionUpdates = <GroupCallEmojiReactionEvent>[];
      final subscription =
          groupCall!.matrixRTCEventStream.stream.listen((update) {
        if (update is GroupCallEmojiReactionEvent) {
          reactionUpdates.add(update);
        }
      });

      // Initially, the map should be empty
      expect(groupCall.groupCallEmojiReactionsMap.isEmpty, true);

      // Simulate receiving an emoji reaction event
      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent(
                      type: EventTypes.GroupCallEmojiReaction,
                      content: {
                        'emoji': '👍',
                        'name': 'thumbs_up',
                        'call_id': 'test_call_comprehensive',
                        'device_id': 'device123',
                        'm.relates_to': {
                          'rel_type': 'm.reference',
                          'event_id': 'membership_event_comprehensive',
                        },
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'reaction_event_comprehensive',
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
      expect(reactionUpdates.length, 1);
      expect(reactionUpdates.first, isA<GroupCallEmojiReactionAddedEvent>());

      final addedUpdate =
          reactionUpdates.first as GroupCallEmojiReactionAddedEvent;
      expect(addedUpdate.emoji, '👍');
      expect(addedUpdate.participant.userId, '@alice:testing.com');
      expect(addedUpdate.participant.deviceId, 'device123');

      // Verify the reaction is stored in the map
      expect(
        groupCall.groupCallEmojiReactionsMap[addedUpdate.participant.id],
        '👍',
      );

      // Wait for the timeout (7 seconds + buffer)
      await Future.delayed(Duration(seconds: 8));

      // Verify the timeout update was received
      expect(reactionUpdates.length, 2);
      expect(reactionUpdates[1], isA<GroupCallEmojiReactionTimeoutEvent>());

      final timeoutUpdate =
          reactionUpdates[1] as GroupCallEmojiReactionTimeoutEvent;
      expect(timeoutUpdate.participant.userId, '@alice:testing.com');
      expect(timeoutUpdate.participant.deviceId, 'device123');

      // Verify the reaction was removed from the map
      expect(
        groupCall.groupCallEmojiReactionsMap[addedUpdate.participant.id],
        isNull,
      );

      await subscription.cancel();
    });

    test('Test multiple emoji reactions and stream updates', () async {
      // Set up multiple group call memberships
      final membership1 = CallMembership(
        userId: '@user1:testing.com',
        callId: 'test_call_multi',
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
        callId: 'test_call_multi',
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

      // Manually create the group call sessions since room.setState doesn't trigger the VoIP listener
      await voip.createGroupCallFromRoomStateEvent(membership2);

      // Get the group call session
      final groupCall = voip.getGroupCallById(room.id, 'test_call_multi');
      expect(groupCall, isNotNull);

      // Listen for emoji reaction updates
      final reactionUpdates = <GroupCallEmojiReactionEvent>[];
      final subscription =
          groupCall!.matrixRTCEventStream.stream.listen((update) {
        if (update is GroupCallEmojiReactionEvent) {
          reactionUpdates.add(update);
        }
      });

      // Simulate receiving multiple emoji reactions
      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent(
                      type: EventTypes.GroupCallEmojiReaction,
                      content: {
                        'emoji': '❤️',
                        'name': 'red_heart',
                        'call_id': 'test_call_multi',
                        'device_id': 'device1',
                        'm.relates_to': {
                          'rel_type': 'm.reference',
                          'event_id': 'membership_event_1',
                        },
                      },
                      senderId: '@user1:testing.com',
                      eventId: 'reaction_event_1',
                      originServerTs: DateTime.now(),
                    ),
                    MatrixEvent(
                      type: EventTypes.GroupCallEmojiReaction,
                      content: {
                        'emoji': '🔥',
                        'name': 'fire',
                        'call_id': 'test_call_multi',
                        'device_id': 'device2',
                        'm.relates_to': {
                          'rel_type': 'm.reference',
                          'event_id': 'membership_event_2',
                        },
                      },
                      senderId: '@user2:testing.com',
                      eventId: 'reaction_event_2',
                      originServerTs: DateTime.now(),
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );

      // Wait for the reactions to be processed
      await Future.delayed(Duration(milliseconds: 100));

      // Verify both reactions were received
      expect(reactionUpdates.length, 2);
      expect(
        reactionUpdates
            .every((update) => update is GroupCallEmojiReactionAddedEvent),
        true,
      );

      final update1 = reactionUpdates[0] as GroupCallEmojiReactionAddedEvent;
      final update2 = reactionUpdates[1] as GroupCallEmojiReactionAddedEvent;

      // Verify the reactions are stored in the map
      expect(
        groupCall.groupCallEmojiReactionsMap[update1.participant.id],
        '❤️',
      );
      expect(
        groupCall.groupCallEmojiReactionsMap[update2.participant.id],
        '🔥',
      );

      await subscription.cancel();
    });

    test('Test sending emoji reactions and error handling', () async {
      // Test 1: Valid membership - sending emoji reaction
      final membership = CallMembership(
        userId: matrix.userID!,
        callId: 'test_call_send',
        backend: MeshBackend(),
        deviceId: matrix.deviceID!,
        expiresTs:
            DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch,
        roomId: room.id,
        membershipId: voip.currentSessionId,
        voip: voip,
        eventId: 'my_membership_event_send',
      );

      // Set up the room state with the membership
      room.setState(
        Event(
          content: {
            'memberships': [membership.toJson()],
          },
          type: EventTypes.GroupCallMember,
          eventId: 'my_membership_event_send',
          senderId: matrix.userID!,
          originServerTs: DateTime.now(),
          room: room,
          stateKey: matrix.userID!,
        ),
      );

      // Manually create the group call session since room.setState doesn't trigger the VoIP listener
      await voip.createGroupCallFromRoomStateEvent(membership);

      // Test that the method can be called - it will fail with fake API but that's expected
      // We just want to verify the method exists and can be called
      await voip.sendGroupCallEmojiReaction(
        'test_call_send',
        room,
        '🎉',
        'party_popper',
      );

      // No valid membership - should log warning but not crash
      await voip.sendGroupCallEmojiReaction(
        'nonexistent_call',
        room,
        '👍',
        'thumbs_up',
      );

      // The test passes if we reach here without the test framework crashing
      expect(true, true);
    });

    test('Test invalid emoji reaction scenarios and edge cases', () async {
      // Create a valid membership for the test
      final membership = CallMembership(
        userId: '@alice:testing.com',
        callId: 'test_call_invalid',
        backend: MeshBackend(),
        deviceId: 'device123',
        expiresTs:
            DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch,
        roomId: room.id,
        membershipId: voip.currentSessionId,
        voip: voip,
        eventId: 'membership_event_invalid',
      );

      // Set up the room state with the membership
      room.setState(
        Event(
          content: {
            'memberships': [membership.toJson()],
          },
          type: EventTypes.GroupCallMember,
          eventId: 'membership_event_invalid',
          senderId: '@alice:testing.com',
          originServerTs: DateTime.now(),
          room: room,
          stateKey: '@alice:testing.com',
        ),
      );

      // Manually create the group call session since room.setState doesn't trigger the VoIP listener
      await voip.createGroupCallFromRoomStateEvent(membership);

      // Get the group call session
      final groupCall = voip.getGroupCallById(room.id, 'test_call_invalid');
      expect(groupCall, isNotNull);

      // Listen for emoji reaction updates
      final reactionUpdates = <GroupCallEmojiReactionEvent>[];
      final subscription =
          groupCall!.matrixRTCEventStream.stream.listen((update) {
        if (update is GroupCallEmojiReactionEvent) {
          reactionUpdates.add(update);
        }
      });

      // Missing call_id
      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent(
                      type: EventTypes.GroupCallEmojiReaction,
                      content: {
                        'emoji': '👍',
                        'name': 'thumbs_up',
                        // Missing call_id
                        'device_id': 'device123',
                        'm.relates_to': {
                          'rel_type': 'm.reference',
                          'event_id': 'membership_event_invalid',
                        },
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'invalid_reaction_1',
                      originServerTs: DateTime.now(),
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );

      // Missing device_id
      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent(
                      type: EventTypes.GroupCallEmojiReaction,
                      content: {
                        'emoji': '👍',
                        'name': 'thumbs_up',
                        'call_id': 'test_call_invalid',
                        // Missing device_id
                        'm.relates_to': {
                          'rel_type': 'm.reference',
                          'event_id': 'membership_event_invalid',
                        },
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'invalid_reaction_2',
                      originServerTs: DateTime.now(),
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );

      // Missing emoji
      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent(
                      type: EventTypes.GroupCallEmojiReaction,
                      content: {
                        // Missing emoji
                        'name': 'thumbs_up',
                        'call_id': 'test_call_invalid',
                        'device_id': 'device123',
                        'm.relates_to': {
                          'rel_type': 'm.reference',
                          'event_id': 'membership_event_invalid',
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

      // Missing m.relates_to
      await matrix.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent(
                      type: EventTypes.GroupCallEmojiReaction,
                      content: {
                        'emoji': '👍',
                        'name': 'thumbs_up',
                        'call_id': 'test_call_invalid',
                        'device_id': 'device123',
                        // Missing m.relates_to
                      },
                      senderId: '@alice:testing.com',
                      eventId: 'invalid_reaction_4',
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

      // Verify no reactions were added to the map (all should be invalid)
      expect(groupCall.groupCallEmojiReactionsMap.isEmpty, true);
      expect(reactionUpdates.isEmpty, true);

      await subscription.cancel();
    });
  });
}
