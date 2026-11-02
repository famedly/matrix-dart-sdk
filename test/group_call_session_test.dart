// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:matrix/matrix.dart';
import 'package:matrix/src/voip/models/delayed_event_canceller.dart';
import 'package:test/test.dart';

import 'fake_client.dart';
import 'webrtc_stub.dart';

class CountingPreShareKeyBackend extends MeshBackend {
  int preShareKeyCalls = 0;

  @override
  Future<void> preShareKey(GroupCallSession groupCall) async {
    preShareKeyCalls++;
  }
}

class ThrowOncePreShareKeyBackend extends MeshBackend {
  int preShareKeyCalls = 0;

  @override
  Future<void> preShareKey(GroupCallSession groupCall) async {
    preShareKeyCalls++;
    if (preShareKeyCalls == 1) {
      throw Exception('preShareKey failed');
    }
  }
}

class MockConcurrentForceRejoinBackend extends MeshBackend {
  final firstOnNewParticipantStarted = Completer<void>();
  final secondOnNewParticipantStarted = Completer<void>();
  final releaseOnNewParticipant = Completer<void>();
  final firstPreShareKeyStarted = Completer<void>();
  final secondPreShareKeyStarted = Completer<void>();
  final releasePreShareKey = Completer<void>();
  int onNewParticipantCalls = 0;
  int preShareKeyCalls = 0;

  @override
  Future<void> onNewParticipant(
    GroupCallSession groupCall,
    List<CallParticipant> participants,
  ) async {
    onNewParticipantCalls++;
    if (onNewParticipantCalls == 1 &&
        !firstOnNewParticipantStarted.isCompleted) {
      firstOnNewParticipantStarted.complete();
    }
    if (onNewParticipantCalls == 2 &&
        !secondOnNewParticipantStarted.isCompleted) {
      secondOnNewParticipantStarted.complete();
    }
    await releaseOnNewParticipant.future;
  }

  @override
  Future<void> preShareKey(GroupCallSession groupCall) async {
    preShareKeyCalls++;
    if (preShareKeyCalls == 1 && !firstPreShareKeyStarted.isCompleted) {
      firstPreShareKeyStarted.complete();
    }
    if (preShareKeyCalls == 2 && !secondPreShareKeyStarted.isCompleted) {
      secondPreShareKeyStarted.complete();
    }
    await releasePreShareKey.future;
  }
}

class StaggeredConcurrentForceRejoinBackend extends MeshBackend {
  final firstOnNewParticipantStarted = Completer<void>();
  final secondOnNewParticipantStarted = Completer<void>();
  final releaseFirstOnNewParticipant = Completer<void>();
  final releaseSecondOnNewParticipant = Completer<void>();
  int onNewParticipantCalls = 0;
  int preShareKeyCalls = 0;

  @override
  Future<void> onNewParticipant(
    GroupCallSession groupCall,
    List<CallParticipant> participants,
  ) async {
    onNewParticipantCalls++;
    if (onNewParticipantCalls == 1) {
      firstOnNewParticipantStarted.complete();
      await releaseFirstOnNewParticipant.future;
    } else if (onNewParticipantCalls == 2) {
      secondOnNewParticipantStarted.complete();
      await releaseSecondOnNewParticipant.future;
    }
  }

  @override
  Future<void> preShareKey(GroupCallSession groupCall) async {
    preShareKeyCalls++;
  }
}

class ThrowingConcurrentForceRejoinBackend extends MeshBackend {
  final firstOnNewParticipantStarted = Completer<void>();
  final secondOnNewParticipantStarted = Completer<void>();
  final releaseOnNewParticipant = Completer<void>();
  final preShareKeyStarted = Completer<void>();
  final releasePreShareKey = Completer<void>();
  int onNewParticipantCalls = 0;
  int preShareKeyCalls = 0;

  @override
  Future<void> onNewParticipant(
    GroupCallSession groupCall,
    List<CallParticipant> participants,
  ) async {
    onNewParticipantCalls++;
    if (onNewParticipantCalls == 1 &&
        !firstOnNewParticipantStarted.isCompleted) {
      firstOnNewParticipantStarted.complete();
    }
    if (onNewParticipantCalls == 2 &&
        !secondOnNewParticipantStarted.isCompleted) {
      secondOnNewParticipantStarted.complete();
    }
    await releaseOnNewParticipant.future;
  }

  @override
  Future<void> preShareKey(GroupCallSession groupCall) async {
    preShareKeyCalls++;
    if (!preShareKeyStarted.isCompleted) {
      preShareKeyStarted.complete();
    }
    await releasePreShareKey.future;
    throw Exception('preShareKey failed');
  }
}

void main() {
  late Client matrix;
  late Room room;
  late VoIP voip;
  late CountingPreShareKeyBackend backend;
  late GroupCallSession groupCall;

  CallMembership buildMembership({
    required CallBackend backend,
    required GroupCallSession groupCall,
    String? userId,
    String? deviceId,
    String? membershipId,
  }) {
    return CallMembership(
      userId: userId ?? matrix.userID!,
      roomId: room.id,
      callId: groupCall.groupCallId,
      application: groupCall.application,
      scope: groupCall.scope,
      backend: backend,
      deviceId: deviceId ?? matrix.deviceID!,
      expiresTs: DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch,
      membershipId: membershipId ?? voip.currentSessionId,
      feeds: [],
      voip: voip,
    );
  }

  void setGroupCallMemberState({
    required GroupCallSession groupCall,
    required String eventId,
    required String senderId,
    required String stateKey,
    List<CallMembership> memberships = const [],
  }) {
    room.setState(
      Event(
        room: room,
        eventId: eventId,
        originServerTs: DateTime.now(),
        type: EventTypes.GroupCallMember,
        content: {
          'memberships': memberships
              .map((membership) => membership.toJson())
              .toList(),
        },
        senderId: senderId,
        stateKey: stateKey,
      ),
    );
  }

  group('GroupCallSession tests', () {
    Logs().level = Level.info;

    setUp(() async {
      matrix = await getClient();
      await matrix.abortSync();

      voip = VoIP(matrix, MockWebRTCDelegate());
      const id = '!calls:example.com';
      room = matrix.getRoomById(id)!;
      backend = CountingPreShareKeyBackend();
      groupCall = GroupCallSession.withAutoGenId(
        room,
        voip,
        backend,
        'm.call',
        'm.room',
        'test_force_rejoin_clears_stale_local_participant',
      );
      groupCall.setState(GroupCallState.entered);
    });

    tearDown(() async {
      await groupCall.removeMemberStateEvent();
    });

    test(
      'force rejoin clears stale local participant until room state catches up',
      () async {
        setGroupCallMemberState(
          groupCall: groupCall,
          eventId: 'local_mem_before_repair',
          senderId: matrix.userID!,
          stateKey: matrix.userID!,
          memberships: [
            buildMembership(backend: backend, groupCall: groupCall),
          ],
        );

        await groupCall.onMemberStateChanged();
        expect(groupCall.hasLocalParticipant(), isTrue);

        setGroupCallMemberState(
          groupCall: groupCall,
          eventId: 'local_mem_removed_during_repair',
          senderId: matrix.userID!,
          stateKey: matrix.userID!,
        );

        await groupCall.onMemberStateChanged();

        expect(
          groupCall.hasLocalParticipant(),
          isFalse,
          reason:
              'The local participant cache must be cleared while waiting for the resent membership event to come back from room state.',
        );
        expect(backend.preShareKeyCalls, 1);

        await groupCall.onMemberStateChanged();

        expect(groupCall.hasLocalParticipant(), isFalse);
        expect(
          backend.preShareKeyCalls,
          1,
          reason:
              'Once the stale local participant is cleared, repeated member-state updates before room state catches up must not trigger another force rejoin.',
        );
      },
    );

    test('force rejoin clears an existing delayed event canceller', () async {
      final cancellerKey =
          '${room.id}|${groupCall.groupCallId}|${groupCall.scope}';
      final restartTimer = Timer.periodic(Duration(hours: 1), (_) {});

      voip.delayedEventCancellers[cancellerKey] = DelayedEventCanceller(
        delayedEventId: 'existing-delayed-event',
        restartTimer: restartTimer,
      );

      setGroupCallMemberState(
        groupCall: groupCall,
        eventId: 'local_mem_before_rejoin_with_canceller',
        senderId: matrix.userID!,
        stateKey: matrix.userID!,
        memberships: [buildMembership(backend: backend, groupCall: groupCall)],
      );

      await groupCall.onMemberStateChanged();
      expect(groupCall.hasLocalParticipant(), isTrue);
      expect(voip.delayedEventCancellers.containsKey(cancellerKey), isTrue);
      expect(restartTimer.isActive, isTrue);

      setGroupCallMemberState(
        groupCall: groupCall,
        eventId: 'local_mem_removed_with_canceller',
        senderId: matrix.userID!,
        stateKey: matrix.userID!,
      );

      await groupCall.onMemberStateChanged();

      expect(backend.preShareKeyCalls, 1);
      expect(groupCall.hasLocalParticipant(), isFalse);
      expect(voip.delayedEventCancellers.containsKey(cancellerKey), isFalse);
      expect(restartTimer.isActive, isFalse);
    });

    test(
      'force rejoin failure keeps local participant eligible for retry',
      () async {
        final backend = ThrowOncePreShareKeyBackend();
        final groupCall = GroupCallSession.withAutoGenId(
          room,
          voip,
          backend,
          'm.call',
          'm.room',
          'test_force_rejoin_retry_after_failure',
        );

        groupCall.setState(GroupCallState.entered);

        setGroupCallMemberState(
          groupCall: groupCall,
          eventId: 'local_mem_before_failed_repair',
          senderId: matrix.userID!,
          stateKey: matrix.userID!,
          memberships: [
            buildMembership(backend: backend, groupCall: groupCall),
          ],
        );

        await groupCall.onMemberStateChanged();
        expect(groupCall.hasLocalParticipant(), isTrue);

        setGroupCallMemberState(
          groupCall: groupCall,
          eventId: 'local_mem_removed_before_failed_repair',
          senderId: matrix.userID!,
          stateKey: matrix.userID!,
        );

        await expectLater(groupCall.onMemberStateChanged(), throwsException);

        expect(
          groupCall.hasLocalParticipant(),
          isTrue,
          reason:
              'A failed force rejoin must restore the local participant cache so later diffs still detect that we need to retry.',
        );
        expect(backend.preShareKeyCalls, 1);

        await groupCall.onMemberStateChanged();

        expect(backend.preShareKeyCalls, 2);
        expect(groupCall.hasLocalParticipant(), isFalse);
      },
    );

    test('does not attempt multiple concurrent force rejoins', () async {
      final backend = MockConcurrentForceRejoinBackend();
      final groupCall = GroupCallSession.withAutoGenId(
        room,
        voip,
        backend,
        'm.call',
        'm.room',
        'test_reentrant_preshare',
      );

      groupCall.setState(GroupCallState.entered);

      setGroupCallMemberState(
        groupCall: groupCall,
        eventId: 'local_mem_before_repair',
        senderId: matrix.userID!,
        stateKey: matrix.userID!,
        memberships: [buildMembership(backend: backend, groupCall: groupCall)],
      );

      await groupCall.onMemberStateChanged();
      expect(groupCall.hasLocalParticipant(), isTrue);

      setGroupCallMemberState(
        groupCall: groupCall,
        eventId: 'local_mem_removed_during_remote_join',
        senderId: matrix.userID!,
        stateKey: matrix.userID!,
      );

      setGroupCallMemberState(
        groupCall: groupCall,
        eventId: 'remote_mem_after_local_disappeared',
        senderId: '@alice:testing.com',
        stateKey: '@alice:testing.com',
        memberships: [
          buildMembership(
            backend: backend,
            groupCall: groupCall,
            userId: '@alice:testing.com',
            deviceId: 'ALICEDEVICE',
            membershipId: 'alice-membership',
          ),
        ],
      );

      final firstUpdate = groupCall.onMemberStateChanged();
      await backend.firstOnNewParticipantStarted.future.timeout(
        Duration(seconds: 1),
      );

      final secondUpdate = groupCall.onMemberStateChanged();
      await backend.secondOnNewParticipantStarted.future.timeout(
        Duration(seconds: 1),
      );

      if (!backend.releaseOnNewParticipant.isCompleted) {
        backend.releaseOnNewParticipant.complete();
      }
      await backend.firstPreShareKeyStarted.future.timeout(
        Duration(seconds: 1),
      );

      try {
        await expectLater(
          backend.secondPreShareKeyStarted.future.timeout(
            Duration(milliseconds: 100),
          ),
          throwsA(isA<TimeoutException>()),
        );
      } finally {
        if (!backend.releasePreShareKey.isCompleted) {
          backend.releasePreShareKey.complete();
        }
        await Future.wait([firstUpdate, secondUpdate]);
      }

      expect(backend.preShareKeyCalls, 1);
    });

    test(
      'it does not rejoin from a stale snapshot after another rejoin completes',
      () async {
        final backend = StaggeredConcurrentForceRejoinBackend();
        final groupCall = GroupCallSession.withAutoGenId(
          room,
          voip,
          backend,
          'm.call',
          'm.room',
          'test_stale_snapshot_rejoin',
        );

        groupCall.setState(GroupCallState.entered);

        setGroupCallMemberState(
          groupCall: groupCall,
          eventId: 'local_mem_before_stale_snapshot',
          senderId: matrix.userID!,
          stateKey: matrix.userID!,
          memberships: [
            buildMembership(backend: backend, groupCall: groupCall),
          ],
        );

        await groupCall.onMemberStateChanged();
        expect(groupCall.hasLocalParticipant(), isTrue);

        setGroupCallMemberState(
          groupCall: groupCall,
          eventId: 'local_mem_removed_before_stale_snapshot',
          senderId: matrix.userID!,
          stateKey: matrix.userID!,
        );

        setGroupCallMemberState(
          groupCall: groupCall,
          eventId: 'remote_mem_for_stale_snapshot',
          senderId: '@alice:testing.com',
          stateKey: '@alice:testing.com',
          memberships: [
            buildMembership(
              backend: backend,
              groupCall: groupCall,
              userId: '@alice:testing.com',
              deviceId: 'ALICEDEVICE',
              membershipId: 'alice-membership',
            ),
          ],
        );
        FakeMatrixApi.calledEndpoints.clear();

        final firstUpdate = groupCall.onMemberStateChanged();
        await backend.firstOnNewParticipantStarted.future.timeout(
          Duration(seconds: 1),
        );

        final secondUpdate = groupCall.onMemberStateChanged();
        await backend.secondOnNewParticipantStarted.future.timeout(
          Duration(seconds: 1),
        );

        backend.releaseFirstOnNewParticipant.complete();
        await firstUpdate.timeout(Duration(seconds: 1));
        expect(backend.preShareKeyCalls, 1);

        backend.releaseSecondOnNewParticipant.complete();
        await secondUpdate.timeout(Duration(seconds: 1));

        final memberStateEventCalls = FakeMatrixApi.calledEndpoints.entries
            .where(
              (entry) => entry.key.contains('/state/com.famedly.call.member/'),
            )
            .fold<int>(0, (sum, entry) => sum + entry.value.length);

        expect(memberStateEventCalls, 1);
        expect(
          backend.preShareKeyCalls,
          1,
          reason:
              'A caller with a stale anyLeft snapshot must not rejoin after the first caller has cleared the local participant cache.',
        );
      },
    );

    test('concurrent force rejoin waiters observe the same failure', () async {
      final backend = ThrowingConcurrentForceRejoinBackend();
      final groupCall = GroupCallSession.withAutoGenId(
        room,
        voip,
        backend,
        'm.call',
        'm.room',
        'test_reentrant_preshare_failure',
      );

      groupCall.setState(GroupCallState.entered);

      setGroupCallMemberState(
        groupCall: groupCall,
        eventId: 'local_mem_before_failed_rejoin',
        senderId: matrix.userID!,
        stateKey: matrix.userID!,
        memberships: [buildMembership(backend: backend, groupCall: groupCall)],
      );

      await groupCall.onMemberStateChanged();
      expect(groupCall.hasLocalParticipant(), isTrue);

      setGroupCallMemberState(
        groupCall: groupCall,
        eventId: 'local_mem_removed_during_failed_remote_join',
        senderId: matrix.userID!,
        stateKey: matrix.userID!,
      );

      setGroupCallMemberState(
        groupCall: groupCall,
        eventId: 'remote_mem_after_failed_local_disappeared',
        senderId: '@alice:testing.com',
        stateKey: '@alice:testing.com',
        memberships: [
          buildMembership(
            backend: backend,
            groupCall: groupCall,
            userId: '@alice:testing.com',
            deviceId: 'ALICEDEVICE',
            membershipId: 'alice-membership',
          ),
        ],
      );

      final firstUpdate = groupCall.onMemberStateChanged();
      await backend.firstOnNewParticipantStarted.future.timeout(
        Duration(seconds: 1),
      );

      final secondUpdate = groupCall.onMemberStateChanged();
      await backend.secondOnNewParticipantStarted.future.timeout(
        Duration(seconds: 1),
      );

      if (!backend.releaseOnNewParticipant.isCompleted) {
        backend.releaseOnNewParticipant.complete();
      }
      await backend.preShareKeyStarted.future.timeout(Duration(seconds: 1));

      if (!backend.releasePreShareKey.isCompleted) {
        backend.releasePreShareKey.complete();
      }

      final results = await Future.wait([
        firstUpdate.then<Object?>((_) => null).catchError((error) => error),
        secondUpdate.then<Object?>((_) => null).catchError((error) => error),
      ]);

      expect(results, hasLength(2));
      expect(results[0], isA<Exception>());
      expect(results[1], isA<Exception>());
      expect(backend.preShareKeyCalls, 1);
      expect(groupCall.hasLocalParticipant(), isTrue);
    });
  });
}
