// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/space_child.dart';
import 'package:test/test.dart';

import 'fake_database.dart';
import 'webrtc_stub.dart';

void main() {
  final alice = UserId('@alice:example.com');
  final bob = UserId('@bob:example.com');
  final roomId = RoomId('!testroom:example.com');
  final childRoomId = RoomId('!child:example.com');
  final eventId = EventId(r'$call_event:example.com');
  final deviceId = DeviceId('DEVICE_ABC');

  group('CallMembership typed API', () {
    late Client client;
    late VoIP voip;

    setUp(() async {
      client = Client('test-voip-client', database: await getDatabase());
      addTearDown(client.dispose);
      voip = VoIP(client, MockWebRTCDelegate());
    });

    test(
      'CallMembership.typed constructs with typed IDs and exposes getters',
      () {
        final membership = CallMembership.typed(
          user: alice,
          callId: 'call-123',
          backend: MeshBackend(),
          device: deviceId,
          event: eventId,
          expiresTs: 1700000000000,
          room: roomId,
          membershipId: 'mem-456',
          voip: voip,
        );

        expect(membership.userIdentifier, equals(alice));
        expect(membership.userId, equals(alice.value));
        expect(membership.deviceIdentifier, equals(deviceId));
        expect(membership.deviceId, equals(deviceId.value));
        expect(membership.eventIdentifier, equals(eventId));
        expect(membership.eventId, equals(eventId.value));
        expect(membership.roomIdentifier, equals(roomId));
        expect(membership.roomId, equals(roomId.value));
      },
    );

    test('CallMembership default constructor exposes parsed typed getters', () {
      final membership = CallMembership(
        userId: bob.value,
        callId: 'call-bob',
        backend: MeshBackend(),
        deviceId: 'DEV_BOB',
        expiresTs: 1700000000000,
        roomId: roomId.value,
        membershipId: 'mem-bob',
        voip: voip,
      );

      expect(membership.userIdentifier, equals(bob));
      expect(membership.deviceIdentifier, equals(DeviceId('DEV_BOB')));
      expect(membership.roomIdentifier, equals(roomId));
      expect(membership.eventIdentifier, isNull);
    });
  });

  group('SpaceChild and SpaceParent typed API', () {
    test('SpaceChild exposes roomIdentifier as RoomId', () {
      final stateEvent = StrippedStateEvent(
        type: EventTypes.SpaceChild,
        stateKey: childRoomId.value,
        senderId: alice.value,
        content: {
          'via': ['example.com'],
          'order': 'a',
        },
      );

      final child = SpaceChild.fromState(stateEvent);
      expect(child.roomIdentifier, equals(childRoomId));
      expect(child.roomId, equals(childRoomId.value));
    });

    test('SpaceParent exposes roomIdentifier as RoomId', () {
      final stateEvent = StrippedStateEvent(
        type: EventTypes.SpaceParent,
        stateKey: roomId.value,
        senderId: alice.value,
        content: {
          'via': ['example.com'],
          'canonical': true,
        },
      );

      final parent = SpaceParent.fromState(stateEvent);
      expect(parent.roomIdentifier, equals(roomId));
      expect(parent.roomId, equals(roomId.value));
    });
  });

  group('Room power levels and user management typed API', () {
    late Client client;
    late Room room;

    setUp(() async {
      client = Client('test-room-power-client', database: await getDatabase());
      addTearDown(client.dispose);
      room = Room.typed(roomId: roomId, client: client);
    });

    test('getPowerLevelForUser returns PowerLevel for typed UserId', () {
      final power = room.getPowerLevelForUser(alice);
      expect(power, isNotNull);
      expect(power.level, equals(0));
    });

    test(
      'fetchCurrentPresenceForUser returns presence for typed UserId',
      () async {
        final presence = await client.fetchCurrentPresenceForUser(
          alice,
          fetchOnlyFromCached: true,
        );
        expect(presence.presence, equals(PresenceType.offline));
      },
    );

    test('requestUserById returns user from memory for typed UserId', () async {
      final member = User.typed(alice, room: room, displayName: 'Alice');
      room.setState(member);
      final user = await room.requestUserById(
        alice,
        requestState: false,
        requestProfile: false,
      );
      expect(user, isNotNull);
      expect(user!.userId, equals(alice));
      expect(user.displayName, equals('Alice'));
    });
  });

  group('Room typed delegation methods with MockClient', () {
    test('inviteUserById, redactEventById, and setPowerForUser forward typed parameters', () async {
      final requests = <http.Request>[];
      final mockClient = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'event_id': r'$fake_event_response',
            'filter_id': 'mock_filter_id',
          }),
          200,
        );
      });

      final client = Client(
        'test-mock-delegation',
        httpClient: mockClient,
        database: await getDatabase(),
      );
      await client.init(
        newToken: 'mock_token',
        newUserID: '@me:example.com',
        newHomeserver: Uri.parse('https://example.com'),
        newDeviceID: 'MOCKDEV',
      );
      await client.abortSync();
      addTearDown(client.dispose);

      final testRoom = Room.typed(
        roomId: RoomId('!mockroom:example.com'),
        client: client,
      );

      await testRoom.inviteUserById(bob, reason: 'Join the team');
      final inviteReq = requests.firstWhere(
        (r) => r.url.path.contains('/invite'),
      );
      expect(
        inviteReq.url.path,
        '/_matrix/client/v3/rooms/${Uri.encodeComponent("!mockroom:example.com")}/invite',
      );
      final inviteBody = jsonDecode(inviteReq.body) as Map<String, dynamic>;
      expect(inviteBody['user_id'], equals(bob.value));
      expect(inviteBody['reason'], equals('Join the team'));

      await testRoom.redactEventById(eventId, reason: 'Spam cleanup');
      final redactReq = requests.firstWhere(
        (r) => r.url.path.contains('/redact/'),
      );
      expect(
        redactReq.url.path,
        contains(
          '/_matrix/client/v3/rooms/${Uri.encodeComponent("!mockroom:example.com")}/redact/',
        ),
      );
      final redactBody = jsonDecode(redactReq.body) as Map<String, dynamic>;
      expect(redactBody['reason'], equals('Spam cleanup'));

      await testRoom.setPowerForUser(bob, 75);
      final powerReq = requests.firstWhere(
        (r) => r.url.path.contains('/state/m.room.power_levels/'),
      );
      expect(
        powerReq.url.path,
        '/_matrix/client/v3/rooms/${Uri.encodeComponent("!mockroom:example.com")}/state/m.room.power_levels/',
      );
      final powerLevelsBody = jsonDecode(powerReq.body) as Map<String, dynamic>;
      final users = powerLevelsBody['users'] as Map<String, dynamic>;
      expect(users[bob.value], equals(75));
    });
  });

  group('Secondary model malformed identifier resilience', () {
    late Client client;
    late VoIP voip;

    setUp(() async {
      client = Client('test-voip-resilience', database: await getDatabase());
      addTearDown(client.dispose);
      voip = VoIP(client, MockWebRTCDelegate());
    });

    test(
      'CallMembership safely returns null on malformed identifier strings',
      () {
        final membership = CallMembership(
          userId: 'malformed_user',
          callId: 'call-1',
          backend: MeshBackend(),
          deviceId: 'BAD\x00DEVICE',
          roomId: 'malformed_room',
          eventId: 'malformed_event',
          expiresTs: 1700000000000,
          membershipId: 'mem-1',
          voip: voip,
        );

        expect(membership.userIdentifier, isNull);
        expect(membership.deviceIdentifier, isNull);
        expect(membership.roomIdentifier, isNull);
        expect(membership.eventIdentifier, isNull);
      },
    );

    test('SpaceChild and SpaceParent return null for malformed room IDs', () {
      final childEvent = StrippedStateEvent(
        type: EventTypes.SpaceChild,
        stateKey: 'malformed_room',
        senderId: alice.value,
        content: {
          'via': ['example.com'],
        },
      );
      final child = SpaceChild.fromState(childEvent);
      expect(child.roomIdentifier, isNull);

      final parentEvent = StrippedStateEvent(
        type: EventTypes.SpaceParent,
        stateKey: 'malformed_parent',
        senderId: alice.value,
        content: {
          'via': ['example.com'],
        },
      );
      final parent = SpaceParent.fromState(parentEvent);
      expect(parent.roomIdentifier, isNull);
    });
  });
}
