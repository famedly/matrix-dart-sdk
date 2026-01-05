import 'dart:convert';

import 'package:test/test.dart';

import 'package:matrix/matrix.dart';
import 'fake_client.dart';
import 'webrtc_stub.dart';

void main() {
  late Client matrix;
  late Room room;
  late VoIP voip;
  late LiveKitBackend backend;

  group('LiveKitBackend encryption key request retry tests', () {
    Logs().level = Level.info;

    setUp(() async {
      matrix = await getClient();
      await matrix.abortSync();

      voip = VoIP(matrix, MockWebRTCDelegate());
      VoIP.customTxid = '1234';
      final id = '!calls:example.com';
      room = matrix.getRoomById(id)!;

      backend = LiveKitBackend(
        livekitServiceUrl: 'https://livekit.example.com',
        livekitAlias: 'test_alias',
      );

      // Clear logs before each test to avoid interference
      Logs().outputEvents.clear();
    });

    /// Helper to create a group call session for testing
    Future<GroupCallSession> createGroupCall(String callId) async {
      final membership = CallMembership(
        userId: matrix.userID!,
        callId: callId,
        backend: backend,
        deviceId: matrix.deviceID!,
        expiresTs:
            DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch,
        roomId: room.id,
        membershipId: voip.currentSessionId,
        voip: voip,
        eventId: 'membership_event_$callId',
      );

      room.setState(
        Event(
          content: {
            'memberships': [membership.toJson()],
          },
          type: EventTypes.GroupCallMember,
          eventId: 'membership_event_$callId',
          senderId: matrix.userID!,
          originServerTs: DateTime.now(),
          room: room,
          stateKey: matrix.userID!,
        ),
      );

      await voip.createGroupCallFromRoomStateEvent(membership);
      final groupCall = voip.getGroupCallById(room.id, callId);
      await groupCall!.enter();
      return groupCall;
    }

    /// Helper to count key request log messages for a specific participant
    int countKeyRequestsFor(String participantId) {
      return Logs()
          .outputEvents
          .where(
            (event) =>
                event.title
                    .contains('requesting stream encryption keys from') &&
                event.title.contains(participantId),
          )
          .length;
    }

    test(
      'retry mechanism automatically re-requests keys when initial request fails',
      () async {
        // This test verifies: without retry, a failed key request leaves the call
        // in an unrecoverable state. With retry, requests are automatically retried.

        final groupCall = await createGroupCall('test_retry_mechanism');

        const remoteUserId = '@retry_test_user:example.com';
        const remoteDeviceId = 'RETRY_TEST_DEVICE';
        final remoteParticipant = CallParticipant(
          voip,
          userId: remoteUserId,
          deviceId: remoteDeviceId,
        );

        Logs().outputEvents.clear();
        Logs().level = Level.verbose;

        // Step 1: Initial key request (simulates framecryptor detecting missingKey)
        await backend.requestEncrytionKey(groupCall, [remoteParticipant]);
        expect(countKeyRequestsFor(remoteUserId), 1);

        // Step 2: Wait for retry timer (2 second interval)
        // WITHOUT retry: count stays at 1 (STUCK!)
        // WITH retry: count increases (RECOVERY!)
        await Future.delayed(Duration(milliseconds: 2100));

        expect(
          countKeyRequestsFor(remoteUserId),
          greaterThan(1),
          reason: 'Retry mechanism should automatically re-request keys. '
              'Without retry, the call would be stuck in an unrecoverable state.',
        );

        await backend.dispose(groupCall);
      },
    );

    test(
      'each participant has independent retry - receiving keys for one does not affect another',
      () async {
        final groupCall = await createGroupCall('test_independent_retries');

        const user1 = '@independent_user1:example.com';
        const device1 = 'DEVICE_1';
        const user2 = '@independent_user2:example.com';
        const device2 = 'DEVICE_2';

        final participant1 =
            CallParticipant(voip, userId: user1, deviceId: device1);
        final participant2 =
            CallParticipant(voip, userId: user2, deviceId: device2);

        Logs().outputEvents.clear();
        Logs().level = Level.verbose;

        // Request keys from both participants
        await backend.requestEncrytionKey(groupCall, [participant1]);
        await backend.requestEncrytionKey(groupCall, [participant2]);

        expect(countKeyRequestsFor(user1), 1);
        expect(countKeyRequestsFor(user2), 1);

        // Wait for retry
        await Future.delayed(Duration(milliseconds: 2100));
        expect(countKeyRequestsFor(user1), greaterThan(1));
        expect(countKeyRequestsFor(user2), greaterThan(1));

        // Receive keys ONLY from participant 1
        await backend.onCallEncryption(
          groupCall,
          user1,
          device1,
          {
            'keys': [
              {
                'key': base64Encode([1, 2, 3, 4, 5, 6, 7, 8]),
                'index': 0,
              },
            ],
            'call_id': 'test_independent_retries',
          },
        );

        final countUser1AfterKeys = countKeyRequestsFor(user1);
        final countUser2AfterKeys = countKeyRequestsFor(user2);

        // Wait another retry interval
        await Future.delayed(Duration(milliseconds: 2100));

        // User 1's retry should have stopped (received keys)
        expect(
          countKeyRequestsFor(user1),
          countUser1AfterKeys,
          reason: 'User 1 retry should stop after receiving keys.',
        );

        // User 2's retry should continue (no keys received)
        expect(
          countKeyRequestsFor(user2),
          greaterThan(countUser2AfterKeys),
          reason: 'User 2 retry should continue since no keys were received.',
        );

        await backend.dispose(groupCall);
      },
    );
  });
}
