// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';
import 'package:test/test.dart';

import 'fake_database.dart';

void main() {
  final alice = UserId('@alice:example.com');
  final bob = UserId('@bob:example.com');

  group('BasicEventWithSender typed API', () {
    test('constructs with typed sender and exposes senderUserId', () {
      final event = BasicEventWithSender.typed(
        type: 'm.room.message',
        content: {'body': 'hello'},
        senderUserId: alice,
      );

      expect(event.senderUserId, equals(alice));
      expect(event.senderId, equals(alice.value));
      expect(event.toJson()['sender'], equals(alice.value));

      event.senderUserId = bob;
      expect(event.senderUserId, equals(bob));
      expect(event.senderId, equals(bob.value));
    });

    test('exposes senderUserId on json-deserialized event', () {
      final json = <String, Object?>{
        'type': 'm.room.message',
        'content': <String, Object?>{'body': 'hi'},
        'sender': alice.value,
      };
      final event = BasicEventWithSender.fromJson(json);
      expect(event.senderUserId, equals(alice));
      expect(event.senderId, equals(alice.value));

      final invalidEvent = BasicEventWithSender.fromJson(<String, Object?>{
        'type': 'm.room.message',
        'content': <String, Object?>{},
        'sender': 'not-a-user-id',
      });
      expect(invalidEvent.senderUserId, isNull);
      expect(invalidEvent.senderId, equals('not-a-user-id'));
    });
  });

  group('StrippedStateEvent typed API', () {
    test('constructs with typed sender and stateKey', () {
      final event = StrippedStateEvent.typed(
        type: EventTypes.RoomMember,
        content: {'membership': 'join'},
        senderUserId: alice,
        stateKey: alice.value,
      );

      expect(event.senderUserId, equals(alice));
      expect(event.senderId, equals(alice.value));
      expect(event.stateKey, equals(alice.value));
      expect(event.toJson()['sender'], equals(alice.value));
      expect(event.toJson()['state_key'], equals(alice.value));
    });
  });

  group('RoomSummary heroes typed API', () {
    test('exposes parsed heroes as List<UserId>', () {
      final summary = RoomSummary.fromJson({
        'm.heroes': [alice.value, bob.value, 'invalid-user'],
        'm.joined_member_count': 2,
      });

      expect(summary.heroes, equals([alice, bob]));
      expect(summary.mHeroes, equals([alice.value, bob.value, 'invalid-user']));
    });

    test('heroes is null when mHeroes is null', () {
      final summary = RoomSummary.fromJson({});
      expect(summary.heroes, isNull);
    });
  });

  group('User typed API', () {
    late Client client;
    late Room room;

    setUp(() async {
      client = Client('test-user-model', database: await getDatabase());
      addTearDown(client.dispose);
      room = Room(id: '!room:example.com', client: client);
    });

    test('User.typed creates room user and exposes userId and id', () {
      final user = User.typed(
        alice,
        room: room,
        displayName: 'Alice M',
        membership: 'join',
      );

      expect(user.userId, equals(alice));
      // ignore: deprecated_member_use_from_same_package
      expect(user.id, equals(alice.value));
      expect(user.displayName, equals('Alice M'));
      expect(user.membership, equals(Membership.join));
      expect(user.senderUserId, equals(alice));
    });

    test('User legacy factory forwards to typed state', () {
      // ignore: deprecated_member_use_from_same_package
      final user = User(alice.value, room: room, displayName: 'Alice');
      expect(user.userId, equals(alice));
      // ignore: deprecated_member_use_from_same_package
      expect(user.id, equals(alice.value));
    });
  });

  group('Event userMentions typed API', () {
    late Client client;
    late Room room;

    setUp(() async {
      client = Client('test-event-mentions', database: await getDatabase());
      addTearDown(client.dispose);
      room = Room(id: '!room:example.com', client: client);
    });

    test('extracts userMentions as List<UserId>', () {
      final event = Event(
        room: room,
        eventId: r'$event:example.com',
        senderId: alice.value,
        type: 'm.room.message',
        originServerTs: DateTime.now(),
        content: {
          'body': 'hey @bob:example.com',
          'm.mentions': {
            'user_ids': [bob.value, 'invalid-user'],
            'room': false,
          },
        },
      );

      expect(event.userMentions, equals([bob]));
      expect(event.senderUserId, equals(alice));
    });
  });

  group('Client typed accessors', () {
    test('userId and deviceId reflect client state', () async {
      final client = Client('test-typed-client', database: await getDatabase());
      addTearDown(client.dispose);

      expect(client.userId, isNull);
      expect(client.deviceId, isNull);

      client.setUserId(alice.value);
      client.setDeviceId('DEVICE_XYZ');

      expect(client.userId, equals(alice));
      expect(client.deviceId, equals(DeviceId('DEVICE_XYZ')));
    });

    test('direct chat resolution and startDirectChatWithUser', () async {
      final client = Client(
        'test-typed-dm-client',
        database: await getDatabase(),
      );
      addTearDown(client.dispose);

      final dmRoom = Room(id: '!direct:example.com', client: client);
      dmRoom.membership = Membership.join;
      client.rooms.add(dmRoom);

      client.accountData['m.direct'] = BasicEvent(
        type: 'm.direct',
        content: {
          alice.value: [dmRoom.id],
        },
      );

      expect(client.getDirectChatForUser(alice), equals(dmRoom.id));
      expect(
        client.getDirectChatRoomIdForUser(alice),
        equals(RoomId('!direct:example.com')),
      );
      expect(client.getDirectChatForUser(bob), isNull);
      expect(client.getDirectChatRoomIdForUser(bob), isNull);

      final chatId = await client.startDirectChatWithUser(alice);
      expect(chatId, equals(dmRoom.id));
    });

    test(
      'ignoreUserByUserId and unignoreUserByUserId update ignore list',
      () async {
        final client = Client(
          'test-ignore-client',
          httpClient: FakeMatrixApi(),
          database: await getDatabase(),
        );
        FakeMatrixApi.client = client;
        await client.checkHomeserver(
          Uri.parse('https://fakeServer.notExisting'),
          checkWellKnown: false,
        );
        await client.init(
          newToken: 'abcd',
          newUserID: '@test:fakeServer.notExisting',
          newHomeserver: client.homeserver,
          newDeviceID: 'GHTYAJCE',
        );
        addTearDown(client.dispose);

        client.accountData['m.ignored_user_list'] = BasicEvent(
          type: 'm.ignored_user_list',
          content: {'ignored_users': <String, Object?>{}},
        );

        await client.ignoreUserByUserId(bob, leaveRooms: false);
        expect(client.ignoredUsers, contains(bob.value));

        await client.unignoreUserByUserId(bob);
        expect(client.ignoredUsers, isNot(contains(bob.value)));
      },
    );
  });
}
