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

void main() {
  /// All Tests related to the Event
  group('Member', () {
    Logs().level = Level.error;
    final client = Client('testclient', httpClient: FakeMatrixApi());
    final room = Room(id: '!localpart:server.abc', client: client);
    final member1 = Member(
      '@alice:example.com',
      membership: 'join',
      displayName: 'Alice M',
      avatarUrl: 'mxc://bla',
      room: room,
    );
    final member2 = Member(
      '@bob:example.com',
      membership: 'join',
      displayName: 'Bob',
      avatarUrl: 'mxc://bla',
      room: room,
    );
    room.setState(member1);
    room.setState(member2);
    setUp(() async {
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
      expect(member1.powerLevel, 0);
      expect(member1.stateKey, '@alice:example.com');
      expect(member1.id, '@alice:example.com');
      expect(member1.membership, Membership.join);
      expect(member1.avatarUrl.toString(), 'mxc://bla');
      expect(member1.displayName, 'Alice M');
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
      final member1 = Member('@alice:example.com', room: room);
      final member2 = Member('@SuperAlice:example.com', room: room);
      final user3 = Member('@alice_mep:example.com', room: room);
      expect(member1.calcDisplayname(), 'Alice');
      expect(member2.calcDisplayname(), 'SuperAlice');
      expect(user3.calcDisplayname(), 'Alice Mep');
      expect(user3.calcDisplayname(formatLocalpart: false), 'alice_mep');
      expect(
        user3.calcDisplayname(mxidLocalPartFallback: false),
        'Unknown user',
      );
    });
    test('kick', () async {
      await member1.kick();
    });
    test('ban', () async {
      await member1.ban();
    });
    test('unban', () async {
      await member1.unban();
    });
    test('setPower', () async {
      await member1.setPower(50);
    });
    test('startDirectChat', () async {
      await member1.startDirectChat(waitForSync: false);
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
        (await member1.fetchCurrentPresence()).presence,
        PresenceType.online,
      );
    });
    test('canBan', () async {
      expect(member1.canBan, false);
    });
    test('canKick', () async {
      expect(member1.canKick, false);
    });
    test('canChangePowerLevel', () async {
      expect(member1.canChangeUserPowerLevel, false);
    });
    test('mention', () async {
      expect(member1.mention, '@[Alice M]');
      expect(member2.mention, '@Bob');
      member1.content['displayname'] = '[Alice M]';
      expect(member1.mention, '@alice:example.com');
      member1.content['displayname'] = 'Alice:M';
      expect(member1.mention, '@alice:example.com');
      member1.content['displayname'] = 'Alice M';
      member2.content['displayname'] = 'Alice M';
      expect(member1.mention, '@[Alice M]#1745');
      member1.content['displayname'] = 'Bob';
      member2.content['displayname'] = 'Bob';
      expect(member1.mention, '@Bob#1745');
      member1.content['displayname'] = 'Alice M';
    });
    test('mentionFragments', () async {
      expect(member1.mentionFragments, {'@[Alice M]', '@[Alice M]#1745'});
      expect(member2.mentionFragments, {'@Bob', '@Bob#1542'});
    });
    test('dispose client', () async {
      await Future.delayed(Duration(milliseconds: 50));
      await client.dispose(closeDatabase: true);
    });
  });
}
