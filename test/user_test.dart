/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:test/test.dart';

import 'package:matrix/matrix.dart';
import 'fake_database.dart';

void main() async {
  /// All Tests related to the Event
  group('User', () {
    late Client client;
    late Room room;
    late User user1, user2;
    setUp(() async {
      client = Client(
        'testclient',
        httpClient: FakeMatrixApi(),
        database: await getDatabase(),
      );
      room = Room(id: '!localpart:server.abc', client: client);
      user1 = User(
        '@alice:example.com',
        membership: 'join',
        displayName: 'Alice M',
        avatarUrl: 'mxc://bla',
        room: room,
      );
      user2 = User(
        '@bob:example.com',
        membership: 'join',
        displayName: 'Bob',
        avatarUrl: 'mxc://bla',
        room: room,
      );
      room.setState(user1);
      room.setState(user2);
      await client.checkHomeserver(
        Uri.parse('https://fakeserver.notexisting'),
        checkWellKnown: false,
      );
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: 'test'),
        password: '1234',
      );
      await client.abortSync();
    });
    tearDown(() async {
      await client.logout();
    });
    test('create', () async {
      expect(user1.powerLevel, 0);
      expect(user1.stateKey, '@alice:example.com');
      expect(user1.id, '@alice:example.com');
      expect(user1.membership, Membership.join);
      expect(user1.avatarUrl.toString(), 'mxc://bla');
      expect(user1.displayName, 'Alice M');
    });
    test('Create from json', () async {
      final id = '@alice:server.abc';
      final membership = Membership.join;
      final displayName = 'Alice';
      final avatarUrl = '';

      final jsonObj = {
        'content': {
          'membership': 'join',
          'avatar_url': avatarUrl,
          'displayname': displayName,
        },
        'type': 'm.room.member',
        'event_id': '143273582443PhrSn:example.org',
        'room_id': '!636q39766251:example.com',
        'sender': id,
        'origin_server_ts': 1432735824653,
        'unsigned': {'age': 1234},
        'state_key': id,
      };

      final user = Event.fromJson(jsonObj, room).asUser;

      expect(user.id, id);
      expect(user.membership, membership);
      expect(user.displayName, displayName);
      expect(user.avatarUrl.toString(), avatarUrl);
      expect(user.calcDisplayname(), displayName);
    });

    test('calcDisplayname', () async {
      final user1 = User('@alice:example.com', room: room);
      final user2 = User('@SuperAlice:example.com', room: room);
      final user3 = User('@alice_mep:example.com', room: room);
      expect(user1.calcDisplayname(), 'Alice');
      expect(user2.calcDisplayname(), 'SuperAlice');
      expect(user3.calcDisplayname(), 'Alice Mep');
      expect(user3.calcDisplayname(formatLocalpart: false), 'alice_mep');
      expect(
        user3.calcDisplayname(mxidLocalPartFallback: false),
        'Unknown user',
      );
    });
    test('kick', () async {
      await user1.kick();
    });
    test('ban', () async {
      await user1.ban();
    });
    test('unban', () async {
      await user1.unban();
    });
    test('setPower', () async {
      await user1.setPower(50);
    });
    test('startDirectChat', () async {
      await user1.startDirectChat(waitForSync: false);
    });
    test('getPresence', () async {
      await client.handleSync(
        SyncUpdate.fromJson({
          'next_batch': 'fake',
          'presence': {
            'events': [
              {
                'sender': '@alice:example.com',
                'type': 'm.presence',
                'content': {'presence': 'online'},
              }
            ],
          },
        }),
      );
      expect(
        (await user1.fetchCurrentPresence()).presence,
        PresenceType.online,
      );
    });
    test('canBan', () async {
      expect(user1.canBan, false);
    });
    test('canKick', () async {
      expect(user1.canKick, false);
    });
    test('canChangePowerLevel', () async {
      expect(user1.canChangeUserPowerLevel, false);
    });
    test('mention', () async {
      expect(user1.mention, '@[Alice M]');
      expect(user2.mention, '@Bob');
      user1.content['displayname'] = '[Alice M]';
      expect(user1.mention, '@alice:example.com');
      user1.content['displayname'] = 'Alice:M';
      expect(user1.mention, '@alice:example.com');
      user1.content['displayname'] = 'Alice M';
      user2.content['displayname'] = 'Alice M';
      expect(user1.mention, '@[Alice M]#1745');
      user1.content['displayname'] = 'Bob';
      user2.content['displayname'] = 'Bob';
      expect(user1.mention, '@Bob#1745');
      user1.content['displayname'] = 'Alice M';
    });
    test('mentionFragments', () async {
      expect(user1.mentionFragments, {'@[Alice M]', '@[Alice M]#1745'});
      expect(user2.mentionFragments, {'@Bob', '@Bob#1542'});
    });
    test('dispose client', () async {
      await Future.delayed(Duration(milliseconds: 50));
      await client.dispose(closeDatabase: true);
    });
  });
}
