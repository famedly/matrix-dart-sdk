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

  group('LiveKitBackend encryption key retry', () {
    Logs().level = Level.info;

    setUp(() async {
      matrix = await getClient();
      await matrix.abortSync();

      voip = VoIP(matrix, MockWebRTCDelegate());
      VoIP.customTxid = '1234';
      room = matrix.getRoomById('!calls:example.com')!;

      backend = LiveKitBackend(
        livekitServiceUrl: 'https://livekit.example.com',
        livekitAlias: 'test_alias',
      );

      Logs().outputEvents.clear();
    });

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
      final groupCall = voip.getGroupCallById(room.id, callId)!;
      await groupCall.enter();
      return groupCall;
    }

    int countKeyRequests(String userId) => Logs()
        .outputEvents
        .where(
          (e) =>
              e.title.contains('requesting stream encryption keys') &&
              e.title.contains(userId),
        )
        .length;

    test(
        'retries keys periodically until received and receiving keys cancels retry for that participant only',
        () async {
      final groupCall = await createGroupCall('test1');
      final p1 = CallParticipant(voip, userId: '@alice:x.com', deviceId: 'D1');
      final p2 = CallParticipant(voip, userId: '@bob:x.com', deviceId: 'D2');

      Logs().outputEvents.clear();
      Logs().level = Level.verbose;

      await backend.requestEncrytionKey(groupCall, [p1]);
      await backend.requestEncrytionKey(groupCall, [p2]);

      // Receive keys for p1 only
      await backend.onCallEncryption(groupCall, '@alice:x.com', 'D1', {
        'keys': [
          {
            'key': base64Encode([1, 2, 3, 4]),
            'index': 0,
          }
        ],
        'call_id': 'test1',
      });

      final countP1 = countKeyRequests('@alice:x.com');
      final countP2 = countKeyRequests('@bob:x.com');

      await Future.delayed(Duration(milliseconds: 2100));

      // p1 stopped, p2 continues
      expect(countKeyRequests('@alice:x.com'), countP1);
      expect(countKeyRequests('@bob:x.com'), greaterThan(countP2));

      await backend.dispose(groupCall);
    });

    test('can start fresh retry cycle after receiving keys', () async {
      final groupCall = await createGroupCall('test2');
      final p = CallParticipant(voip, userId: '@bob:x.com', deviceId: 'D1');

      Logs().outputEvents.clear();
      Logs().level = Level.verbose;

      // Request -> receive keys -> timer cancelled
      await backend.requestEncrytionKey(groupCall, [p]);
      await backend.onCallEncryption(groupCall, '@bob:x.com', 'D1', {
        'keys': [
          {
            'key': base64Encode([1, 2, 3, 4]),
            'index': 0,
          }
        ],
        'call_id': 'test2',
      });

      final countAfterReceive = countKeyRequests('@bob:x.com');

      // New request starts fresh cycle
      await backend.requestEncrytionKey(groupCall, [p]);
      expect(countKeyRequests('@bob:x.com'), countAfterReceive + 1);

      // New timer works
      await Future.delayed(Duration(milliseconds: 2100));
      expect(
        countKeyRequests('@bob:x.com'),
        greaterThan(countAfterReceive + 1),
      );

      await backend.dispose(groupCall);
    });

    test(
      'stops after 5 retries',
      () async {
        final groupCall = await createGroupCall('test3');
        final p = CallParticipant(voip, userId: '@bob:x.com', deviceId: 'D1');

        Logs().outputEvents.clear();
        Logs().level = Level.verbose;

        await backend.requestEncrytionKey(groupCall, [p]);

        // Wait for 5 retries (5 * 2s = 10s)
        await Future.delayed(Duration(milliseconds: 10500));

        final hasMaxRetryLog = Logs()
            .outputEvents
            .any((e) => e.title.contains('Max retries (5) reached'));
        expect(hasMaxRetryLog, true);

        // No more retries after max
        final countAtMax = countKeyRequests('@bob:x.com');
        await Future.delayed(Duration(milliseconds: 2100));
        expect(countKeyRequests('@bob:x.com'), countAtMax);

        await backend.dispose(groupCall);
      },
      timeout: Timeout(Duration(seconds: 20)),
    );
  });
}
