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
    if (onNewParticipantCalls == 1 && !firstOnNewParticipantStarted.isCompleted) {
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
    if (onNewParticipantCalls == 1 && !firstOnNewParticipantStarted.isCompleted) {
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
        room.setState(
          Event(
            room: room,
            eventId: 'local_mem_before_repair',
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
            stateKey: matrix.userID,
          ),
        );

        await groupCall.onMemberStateChanged();
        expect(groupCall.hasLocalParticipant(), isTrue);

        room.setState(
          Event(
            room: room,
            eventId: 'local_mem_removed_during_repair',
            originServerTs: DateTime.now(),
            type: EventTypes.GroupCallMember,
            content: {'memberships': []},
            senderId: matrix.userID!,
            stateKey: matrix.userID,
          ),
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
      final cancellerKey = '${room.id}|${groupCall.groupCallId}|${groupCall.scope}';
      final restartTimer = Timer.periodic(Duration(hours: 1), (_) {});

      voip.delayedEventCancellers[cancellerKey] = DelayedEventCanceller(
        delayedEventId: 'existing-delayed-event',
        restartTimer: restartTimer,
      );

      room.setState(
        Event(
          room: room,
          eventId: 'local_mem_before_rejoin_with_canceller',
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
          stateKey: matrix.userID,
        ),
      );

      await groupCall.onMemberStateChanged();
      expect(groupCall.hasLocalParticipant(), isTrue);
      expect(voip.delayedEventCancellers.containsKey(cancellerKey), isTrue);
      expect(restartTimer.isActive, isTrue);

      room.setState(
        Event(
          room: room,
          eventId: 'local_mem_removed_with_canceller',
          originServerTs: DateTime.now(),
          type: EventTypes.GroupCallMember,
          content: {'memberships': []},
          senderId: matrix.userID!,
          stateKey: matrix.userID,
        ),
      );

      await groupCall.onMemberStateChanged();

      expect(backend.preShareKeyCalls, 1);
      expect(groupCall.hasLocalParticipant(), isFalse);
      expect(voip.delayedEventCancellers.containsKey(cancellerKey), isFalse);
      expect(restartTimer.isActive, isFalse);
    });

    test('force rejoin failure keeps local participant eligible for retry', () async {
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

      room.setState(
        Event(
          room: room,
          eventId: 'local_mem_before_failed_repair',
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
          stateKey: matrix.userID,
        ),
      );

      await groupCall.onMemberStateChanged();
      expect(groupCall.hasLocalParticipant(), isTrue);

      room.setState(
        Event(
          room: room,
          eventId: 'local_mem_removed_before_failed_repair',
          originServerTs: DateTime.now(),
          type: EventTypes.GroupCallMember,
          content: {'memberships': []},
          senderId: matrix.userID!,
          stateKey: matrix.userID,
        ),
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
    });

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

      room.setState(
        Event(
          room: room,
          eventId: 'local_mem_before_repair',
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
          stateKey: matrix.userID,
        ),
      );

      await groupCall.onMemberStateChanged();
      expect(groupCall.hasLocalParticipant(), isTrue);

      room.setState(
        Event(
          room: room,
          eventId: 'local_mem_removed_during_remote_join',
          originServerTs: DateTime.now(),
          type: EventTypes.GroupCallMember,
          content: {'memberships': []},
          senderId: matrix.userID!,
          stateKey: matrix.userID,
        ),
      );

      room.setState(
        Event(
          room: room,
          eventId: 'remote_mem_after_local_disappeared',
          originServerTs: DateTime.now(),
          type: EventTypes.GroupCallMember,
          content: {
            'memberships': [
              CallMembership(
                userId: '@alice:testing.com',
                roomId: room.id,
                callId: groupCall.groupCallId,
                application: groupCall.application,
                scope: groupCall.scope,
                backend: backend,
                deviceId: 'ALICEDEVICE',
                expiresTs: DateTime.now()
                    .add(Duration(hours: 1))
                    .millisecondsSinceEpoch,
                membershipId: 'alice-membership',
                feeds: [],
                voip: voip,
              ).toJson(),
            ],
          },
          senderId: '@alice:testing.com',
          stateKey: '@alice:testing.com',
        ),
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
      await backend.firstPreShareKeyStarted.future.timeout(Duration(seconds: 1));

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

      room.setState(
        Event(
          room: room,
          eventId: 'local_mem_before_failed_rejoin',
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
          stateKey: matrix.userID,
        ),
      );

      await groupCall.onMemberStateChanged();
      expect(groupCall.hasLocalParticipant(), isTrue);

      room.setState(
        Event(
          room: room,
          eventId: 'local_mem_removed_during_failed_remote_join',
          originServerTs: DateTime.now(),
          type: EventTypes.GroupCallMember,
          content: {'memberships': []},
          senderId: matrix.userID!,
          stateKey: matrix.userID,
        ),
      );

      room.setState(
        Event(
          room: room,
          eventId: 'remote_mem_after_failed_local_disappeared',
          originServerTs: DateTime.now(),
          type: EventTypes.GroupCallMember,
          content: {
            'memberships': [
              CallMembership(
                userId: '@alice:testing.com',
                roomId: room.id,
                callId: groupCall.groupCallId,
                application: groupCall.application,
                scope: groupCall.scope,
                backend: backend,
                deviceId: 'ALICEDEVICE',
                expiresTs: DateTime.now()
                    .add(Duration(hours: 1))
                    .millisecondsSinceEpoch,
                membershipId: 'alice-membership',
                feeds: [],
                voip: voip,
              ).toJson(),
            ],
          },
          senderId: '@alice:testing.com',
          stateKey: '@alice:testing.com',
        ),
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