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

import 'dart:async';
import 'dart:typed_data';

import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/matrix_api.dart';
import 'package:famedlysdk/src/client.dart';
import 'package:famedlysdk/src/utils/event_update.dart';
import 'package:famedlysdk/src/utils/logs.dart';
import 'package:famedlysdk/src/utils/room_update.dart';
import 'package:famedlysdk/src/utils/matrix_file.dart';
import 'package:olm/olm.dart' as olm;
import 'package:test/test.dart';

import 'fake_matrix_api.dart';
import 'fake_database.dart';

void main() {
  Client matrix;

  Future<List<RoomUpdate>> roomUpdateListFuture;
  Future<List<EventUpdate>> eventUpdateListFuture;
  Future<List<ToDeviceEvent>> toDeviceUpdateListFuture;

  // key @test:fakeServer.notExisting
  const pickledOlmAccount =
      'N2v1MkIFGcl0mQpo2OCwSopxPQJ0wnl7oe7PKiT4141AijfdTIhRu+ceXzXKy3Kr00nLqXtRv7kid6hU4a+V0rfJWLL0Y51+3Rp/ORDVnQy+SSeo6Fn4FHcXrxifJEJ0djla5u98fBcJ8BSkhIDmtXRPi5/oJAvpiYn+8zMjFHobOeZUAxYR0VfQ9JzSYBsSovoQ7uFkNks1M4EDUvHtuyg3RxViwdNxs3718fyAqQ/VSwbXsY0Nl+qQbF+nlVGHenGqk5SuNl1P6e1PzZxcR0IfXA94Xij1Ob5gDv5YH4UCn9wRMG0abZsQP0YzpDM0FLaHSCyo9i5JD/vMlhH+nZWrgAzPPCTNGYewNV8/h3c+VyJh8ZTx/fVi6Yq46Fv+27Ga2ETRZ3Qn+Oyx6dLBjnBZ9iUvIhqpe2XqaGA1PopOz8iDnaZitw';
  const identityKey = '7rvl3jORJkBiK4XX1e5TnGnqz068XfYJ0W++Ml63rgk';
  const fingerprintKey = 'gjL//fyaFHADt9KBADGag8g7F8Up78B/K1zXeiEPLJo';

  /// All Tests related to the Login
  group('Client', () {
    /// Check if all Elements get created

    matrix = Client('testclient', httpClient: FakeMatrixApi());

    roomUpdateListFuture = matrix.onRoomUpdate.stream.toList();
    eventUpdateListFuture = matrix.onEvent.stream.toList();
    toDeviceUpdateListFuture = matrix.onToDeviceEvent.stream.toList();
    var olmEnabled = true;
    try {
      olm.init();
      olm.Account();
    } catch (_) {
      olmEnabled = false;
      Logs.warning('[LibOlm] Failed to load LibOlm: ' + _.toString());
    }
    Logs.success('[LibOlm] Enabled: $olmEnabled');

    test('Login', () async {
      var presenceCounter = 0;
      var accountDataCounter = 0;
      matrix.onPresence.stream.listen((Presence data) {
        presenceCounter++;
      });
      matrix.onAccountData.stream.listen((BasicEvent data) {
        accountDataCounter++;
      });

      expect(matrix.homeserver, null);

      try {
        await matrix.checkHomeserver('https://fakeserver.wrongaddress');
      } on FormatException catch (exception) {
        expect(exception != null, true);
      }
      await matrix.checkHomeserver('https://fakeserver.notexisting');
      expect(matrix.homeserver.toString(), 'https://fakeserver.notexisting');

      final available = await matrix.usernameAvailable('testuser');
      expect(available, true);

      var loginStateFuture = matrix.onLoginStateChanged.stream.first;
      var firstSyncFuture = matrix.onFirstSync.stream.first;
      var syncFuture = matrix.onSync.stream.first;

      matrix.connect(
        newToken: 'abcd',
        newUserID: '@test:fakeServer.notExisting',
        newHomeserver: matrix.homeserver,
        newDeviceName: 'Text Matrix Client',
        newDeviceID: 'GHTYAJCE',
        newOlmAccount: pickledOlmAccount,
      );

      await Future.delayed(Duration(milliseconds: 50));

      var loginState = await loginStateFuture;
      var firstSync = await firstSyncFuture;
      var sync = await syncFuture;

      expect(loginState, LoginState.logged);
      expect(firstSync, true);
      expect(matrix.encryptionEnabled, olmEnabled);
      if (olmEnabled) {
        expect(matrix.identityKey, identityKey);
        expect(matrix.fingerprintKey, fingerprintKey);
      }
      expect(sync.nextBatch == matrix.prevBatch, true);

      expect(matrix.accountData.length, 9);
      expect(matrix.getDirectChatFromUserId('@bob:example.com'),
          '!726s6s6q:example.com');
      expect(matrix.rooms[1].directChatMatrixID, '@bob:example.com');
      expect(matrix.directChats, matrix.accountData['m.direct'].content);
      expect(matrix.presences.length, 1);
      expect(matrix.rooms[1].ephemerals.length, 2);
      expect(matrix.rooms[1].typingUsers.length, 1);
      expect(matrix.rooms[1].typingUsers[0].id, '@alice:example.com');
      expect(matrix.rooms[1].roomAccountData.length, 3);
      expect(matrix.rooms[1].encrypted, true);
      expect(matrix.rooms[1].encryptionAlgorithm,
          Client.supportedGroupEncryptionAlgorithms.first);
      expect(
          matrix.rooms[1].roomAccountData['m.receipt']
              .content['@alice:example.com']['ts'],
          1436451550453);
      expect(
          matrix.rooms[1].roomAccountData['m.receipt']
              .content['@alice:example.com']['event_id'],
          '7365636s6r6432:example.com');
      expect(matrix.rooms.length, 2);
      expect(matrix.rooms[1].canonicalAlias,
          "#famedlyContactDiscovery:${matrix.userID.split(":")[1]}");
      expect(matrix.presences['@alice:example.com'].presence.presence,
          PresenceType.online);
      expect(presenceCounter, 1);
      expect(accountDataCounter, 9);
      await Future.delayed(Duration(milliseconds: 50));
      expect(matrix.userDeviceKeys.length, 4);
      expect(matrix.userDeviceKeys['@alice:example.com'].outdated, false);
      expect(matrix.userDeviceKeys['@alice:example.com'].deviceKeys.length, 2);
      expect(
          matrix.userDeviceKeys['@alice:example.com'].deviceKeys['JLAFKJWSCS']
              .verified,
          false);

      await matrix.handleSync(SyncUpdate.fromJson({
        'device_lists': {
          'changed': [
            '@alice:example.com',
          ],
          'left': [
            '@bob:example.com',
          ],
        }
      }));
      await Future.delayed(Duration(milliseconds: 50));
      expect(matrix.userDeviceKeys.length, 3);
      expect(matrix.userDeviceKeys['@alice:example.com'].outdated, true);

      await matrix.handleSync(SyncUpdate.fromJson({
        'rooms': {
          'join': {
            '!726s6s6q:example.com': {
              'state': {
                'events': [
                  {
                    'sender': '@alice:example.com',
                    'type': 'm.room.canonical_alias',
                    'content': {'alias': ''},
                    'state_key': '',
                    'origin_server_ts': 1417731086799,
                    'event_id': '66697273743033:example.com'
                  }
                ]
              }
            }
          }
        }
      }));
      await Future.delayed(Duration(milliseconds: 50));

      expect(
          matrix.getRoomByAlias(
              "#famedlyContactDiscovery:${matrix.userID.split(":")[1]}"),
          null);
    });

    test('Logout', () async {
      var loginStateFuture = matrix.onLoginStateChanged.stream.first;
      await matrix.logout();

      expect(matrix.accessToken == null, true);
      expect(matrix.homeserver == null, true);
      expect(matrix.userID == null, true);
      expect(matrix.deviceID == null, true);
      expect(matrix.deviceName == null, true);
      expect(matrix.prevBatch == null, true);

      var loginState = await loginStateFuture;
      expect(loginState, LoginState.loggedOut);
    });

    test('Room Update Test', () async {
      await matrix.onRoomUpdate.close();

      var roomUpdateList = await roomUpdateListFuture;

      expect(roomUpdateList.length, 4);

      expect(roomUpdateList[0].id == '!726s6s6q:example.com', true);
      expect(roomUpdateList[0].membership == Membership.join, true);
      expect(roomUpdateList[0].prev_batch == 't34-23535_0_0', true);
      expect(roomUpdateList[0].limitedTimeline == true, true);
      expect(roomUpdateList[0].notification_count == 2, true);
      expect(roomUpdateList[0].highlight_count == 2, true);

      expect(roomUpdateList[1].id == '!696r7674:example.com', true);
      expect(roomUpdateList[1].membership == Membership.invite, true);
      expect(roomUpdateList[1].prev_batch == '', true);
      expect(roomUpdateList[1].limitedTimeline == false, true);
      expect(roomUpdateList[1].notification_count == 0, true);
      expect(roomUpdateList[1].highlight_count == 0, true);
    });

    test('Event Update Test', () async {
      await matrix.onEvent.close();

      var eventUpdateList = await eventUpdateListFuture;

      expect(eventUpdateList.length, 14);

      expect(eventUpdateList[0].eventType, 'm.room.member');
      expect(eventUpdateList[0].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[0].type, EventUpdateType.state);

      expect(eventUpdateList[1].eventType, 'm.room.canonical_alias');
      expect(eventUpdateList[1].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[1].type, EventUpdateType.state);

      expect(eventUpdateList[2].eventType, 'm.room.encryption');
      expect(eventUpdateList[2].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[2].type, EventUpdateType.state);

      expect(eventUpdateList[3].eventType, 'm.room.pinned_events');
      expect(eventUpdateList[3].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[3].type, EventUpdateType.state);

      expect(eventUpdateList[4].eventType, 'm.room.member');
      expect(eventUpdateList[4].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[4].type, EventUpdateType.timeline);

      expect(eventUpdateList[5].eventType, 'm.room.message');
      expect(eventUpdateList[5].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[5].type, EventUpdateType.timeline);

      expect(eventUpdateList[6].eventType, 'm.typing');
      expect(eventUpdateList[6].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[6].type, EventUpdateType.ephemeral);

      expect(eventUpdateList[7].eventType, 'm.receipt');
      expect(eventUpdateList[7].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[7].type, EventUpdateType.ephemeral);

      expect(eventUpdateList[8].eventType, 'm.receipt');
      expect(eventUpdateList[8].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[8].type, EventUpdateType.accountData);

      expect(eventUpdateList[9].eventType, 'm.tag');
      expect(eventUpdateList[9].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[9].type, EventUpdateType.accountData);

      expect(eventUpdateList[10].eventType, 'org.example.custom.room.config');
      expect(eventUpdateList[10].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[10].type, EventUpdateType.accountData);

      expect(eventUpdateList[11].eventType, 'm.room.name');
      expect(eventUpdateList[11].roomID, '!696r7674:example.com');
      expect(eventUpdateList[11].type, EventUpdateType.inviteState);

      expect(eventUpdateList[12].eventType, 'm.room.member');
      expect(eventUpdateList[12].roomID, '!696r7674:example.com');
      expect(eventUpdateList[12].type, EventUpdateType.inviteState);
    });

    test('To Device Update Test', () async {
      await matrix.onToDeviceEvent.close();

      var eventUpdateList = await toDeviceUpdateListFuture;

      expect(eventUpdateList.length, 2);

      expect(eventUpdateList[0].type, 'm.new_device');
      if (olmEnabled) {
        expect(eventUpdateList[1].type, 'm.room_key');
      } else {
        expect(eventUpdateList[1].type, 'm.room.encrypted');
      }
    });

    test('Login', () async {
      matrix = Client('testclient', httpClient: FakeMatrixApi());

      roomUpdateListFuture = matrix.onRoomUpdate.stream.toList();
      eventUpdateListFuture = matrix.onEvent.stream.toList();

      await matrix.checkHomeserver('https://fakeServer.notExisting');

      final loginResp = await matrix.login(user: 'test', password: '1234');

      expect(loginResp != null, true);
    });

    test('setAvatar', () async {
      final testFile = MatrixFile(bytes: Uint8List(0), name: 'file.jpeg');
      await matrix.setAvatar(testFile);
    });

    test('setMuteAllPushNotifications', () async {
      await matrix.setMuteAllPushNotifications(false);
    });

    test('get archive', () async {
      var archive = await matrix.archive;

      await Future.delayed(Duration(milliseconds: 50));
      expect(archive.length, 2);
      expect(archive[0].id, '!5345234234:example.com');
      expect(archive[0].membership, Membership.leave);
      expect(archive[0].name, 'The room name');
      expect(archive[0].lastMessage, 'This is an example text message');
      expect(archive[0].roomAccountData.length, 1);
      expect(archive[1].id, '!5345234235:example.com');
      expect(archive[1].membership, Membership.leave);
      expect(archive[1].name, 'The room name 2');
    });

    test('getProfileFromUserId', () async {
      final profile = await matrix.getProfileFromUserId('@getme:example.com',
          getFromRooms: false);
      expect(profile.avatarUrl.toString(), 'mxc://test');
      expect(profile.displayname, 'You got me');
      final aliceProfile =
          await matrix.getProfileFromUserId('@alice:example.com');
      expect(aliceProfile.avatarUrl.toString(),
          'mxc://example.org/SEsfnsuifSDFSSEF');
      expect(aliceProfile.displayname, 'Alice Margatroid');
    });
    var deviceKeys = DeviceKeys.fromJson({
      'user_id': '@alice:example.com',
      'device_id': 'JLAFKJWSCS',
      'algorithms': ['m.olm.v1.curve25519-aes-sha2', 'm.megolm.v1.aes-sha2'],
      'keys': {
        'curve25519:JLAFKJWSCS': '3C5BFWi2Y8MaVvjM8M22DBmh24PmgR0nPvJOIArzgyI',
        'ed25519:JLAFKJWSCS': 'lEuiRJBit0IG6nUf5pUzWTUEsRVVe/HJkoKuEww9ULI'
      },
      'signatures': {
        '@alice:example.com': {
          'ed25519:JLAFKJWSCS':
              'dSO80A01XiigH3uBiDVx/EjzaoycHcjq9lfQX0uWsqxl2giMIiSPR8a4d291W1ihKJL/a+myXS367WT6NAIcBA'
        }
      }
    }, matrix);
    test('sendToDeviceEncrypted', () async {
      await matrix.sendToDeviceEncrypted(
          [deviceKeys],
          'm.message',
          {
            'msgtype': 'm.text',
            'body': 'Hello world',
          });
    });
    test('Test the fake store api', () async {
      var client1 = Client('testclient', httpClient: FakeMatrixApi());
      client1.database = getDatabase();

      client1.connect(
        newToken: 'abc123',
        newUserID: '@test:fakeServer.notExisting',
        newHomeserver: Uri.parse('https://fakeServer.notExisting'),
        newDeviceName: 'Text Matrix Client',
        newDeviceID: 'GHTYAJCE',
        newOlmAccount: pickledOlmAccount,
      );

      await Future.delayed(Duration(milliseconds: 50));

      expect(client1.isLogged(), true);
      expect(client1.rooms.length, 2);

      var client2 = Client('testclient', httpClient: FakeMatrixApi());
      client2.database = client1.database;

      client2.connect();
      await Future.delayed(Duration(milliseconds: 100));

      expect(client2.isLogged(), true);
      expect(client2.accessToken, client1.accessToken);
      expect(client2.userID, client1.userID);
      expect(client2.homeserver, client1.homeserver);
      expect(client2.deviceID, client1.deviceID);
      expect(client2.deviceName, client1.deviceName);
      if (client2.encryptionEnabled) {
        expect(client2.encryption.pickledOlmAccount,
            client1.encryption.pickledOlmAccount);
        expect(client2.rooms[1].id, client1.rooms[1].id);
      }

      await client1.logout();
      await client2.logout();
    });
    test('changePassword', () async {
      await matrix.changePassword('1234', oldPassword: '123456');
    });
    test('ignoredUsers', () async {
      expect(matrix.ignoredUsers, []);
      matrix.accountData['m.ignored_user_list'] =
          BasicEvent(type: 'm.ignored_user_list', content: {
        'ignored_users': {
          '@charley:stupid.abc': {},
        },
      });
      expect(matrix.ignoredUsers, ['@charley:stupid.abc']);
    });
    test('ignoredUsers', () async {
      await matrix.ignoreUser('@charley2:stupid.abc');
      await matrix.unignoreUser('@charley:stupid.abc');
    });

    test('dispose', () async {
      await matrix.dispose(closeDatabase: true);
    });
  });
}
