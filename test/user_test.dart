/*
 *   Ansible inventory script used at Famedly GmbH for managing many hosts
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

import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/matrix_api.dart';
import 'package:famedlysdk/src/event.dart';
import 'package:famedlysdk/src/user.dart';
import 'package:test/test.dart';

import 'fake_matrix_api.dart';

void main() {
  /// All Tests related to the Event
  group('User', () {
    var client = Client('testclient', httpClient: FakeMatrixApi());
    final user1 = User(
      '@alice:example.com',
      membership: 'join',
      displayName: 'Alice M',
      avatarUrl: 'mxc://bla',
      room: Room(id: '!localpart:server.abc', client: client),
    );
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
          'displayname': displayName
        },
        'type': 'm.room.member',
        'event_id': '143273582443PhrSn:example.org',
        'room_id': '!636q39766251:example.com',
        'sender': id,
        'origin_server_ts': 1432735824653,
        'unsigned': {'age': 1234},
        'state_key': id
      };

      var user = Event.fromJson(jsonObj, null).asUser;

      expect(user.id, id);
      expect(user.membership, membership);
      expect(user.displayName, displayName);
      expect(user.avatarUrl.toString(), avatarUrl);
      expect(user.calcDisplayname(), displayName);
    });

    test('calcDisplayname', () async {
      final user1 = User('@alice:example.com');
      final user2 = User('@SuperAlice:example.com');
      final user3 = User('@alice_mep:example.com');
      expect(user1.calcDisplayname(), 'Alice');
      expect(user2.calcDisplayname(), 'SuperAlice');
      expect(user3.calcDisplayname(), 'Alice Mep');
      expect(user3.calcDisplayname(formatLocalpart: false), 'alice_mep');
      expect(
          user3.calcDisplayname(mxidLocalPartFallback: false), 'Unknown user');
    });
    test('kick', () async {
      await client.checkHomeserver('https://fakeserver.notexisting');
      await user1.kick();
    });
    test('ban', () async {
      await client.checkHomeserver('https://fakeserver.notexisting');
      await user1.ban();
    });
    test('unban', () async {
      await client.checkHomeserver('https://fakeserver.notexisting');
      await user1.unban();
    });
    test('setPower', () async {
      await client.checkHomeserver('https://fakeserver.notexisting');
      await user1.setPower(50);
    });
    test('startDirectChat', () async {
      await client.checkHomeserver('https://fakeserver.notexisting');
      await client.login(user: 'test', password: '1234');
      await user1.startDirectChat();
    });
    test('getPresence', () async {
      await client.checkHomeserver('https://fakeserver.notexisting');
      await client.handleSync(SyncUpdate.fromJson({
        'presence': {
          'events': [
            {
              'sender': '@alice:example.com',
              'type': 'm.presence',
              'content': {'presence': 'online'}
            }
          ]
        }
      }));
      expect(user1.presence.presence.presence, PresenceType.online);
    });
    test('canBan', () async {
      await client.checkHomeserver('https://fakeserver.notexisting');
      expect(user1.canBan, false);
    });
    test('canKick', () async {
      await client.checkHomeserver('https://fakeserver.notexisting');
      expect(user1.canKick, false);
    });
    test('canChangePowerLevel', () async {
      await client.checkHomeserver('https://fakeserver.notexisting');
      expect(user1.canChangePowerLevel, false);
    });
    test('dispose client', () async {
      await client.dispose(closeDatabase: true);
    });
  });
}
