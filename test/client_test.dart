/*
 * Copyright (c) 2019 Zender & Kurtz GbR.
 *
 * Authors:
 *   Christian Pauly <krille@famedly.com>
 *   Marcel Radzio <mtrnord@famedly.com>
 *
 * This file is part of famedlysdk.
 *
 * famedlysdk is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * famedlysdk is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with famedlysdk.  If not, see <http://www.gnu.org/licenses/>.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/src/account_data.dart';
import 'package:famedlysdk/src/client.dart';
import 'package:famedlysdk/src/presence.dart';
import 'package:famedlysdk/src/user.dart';
import 'package:famedlysdk/src/sync/event_update.dart';
import 'package:famedlysdk/src/sync/room_update.dart';
import 'package:famedlysdk/src/sync/user_update.dart';
import 'package:famedlysdk/src/utils/matrix_exception.dart';
import 'package:famedlysdk/src/utils/matrix_file.dart';
import 'package:olm/olm.dart' as olm;
import 'package:test/test.dart';

import 'fake_matrix_api.dart';
import 'fake_store.dart';

void main() {
  Client matrix;

  Future<List<RoomUpdate>> roomUpdateListFuture;
  Future<List<EventUpdate>> eventUpdateListFuture;
  Future<List<UserUpdate>> userUpdateListFuture;
  Future<List<ToDeviceEvent>> toDeviceUpdateListFuture;

  const pickledOlmAccount =
      'N2v1MkIFGcl0mQpo2OCwSopxPQJ0wnl7oe7PKiT4141AijfdTIhRu+ceXzXKy3Kr00nLqXtRv7kid6hU4a+V0rfJWLL0Y51+3Rp/ORDVnQy+SSeo6Fn4FHcXrxifJEJ0djla5u98fBcJ8BSkhIDmtXRPi5/oJAvpiYn+8zMjFHobOeZUAxYR0VfQ9JzSYBsSovoQ7uFkNks1M4EDUvHtuweStA+EKZvvHZO0SnwRp0Hw7sv8UMYvXw';
  const identityKey = '7rvl3jORJkBiK4XX1e5TnGnqz068XfYJ0W++Ml63rgk';
  const fingerprintKey = 'gjL//fyaFHADt9KBADGag8g7F8Up78B/K1zXeiEPLJo';

  /// All Tests related to the Login
  group('FluffyMatrix', () {
    /// Check if all Elements get created

    matrix = Client('testclient', debug: true);
    matrix.httpClient = FakeMatrixApi();

    roomUpdateListFuture = matrix.onRoomUpdate.stream.toList();
    eventUpdateListFuture = matrix.onEvent.stream.toList();
    userUpdateListFuture = matrix.onUserEvent.stream.toList();
    toDeviceUpdateListFuture = matrix.onToDeviceEvent.stream.toList();
    var olmEnabled = true;
    try {
      olm.init();
      olm.Account();
    } catch (_) {
      olmEnabled = false;
      print('[LibOlm] Failed to load LibOlm: ' + _.toString());
    }
    print('[LibOlm] Enabled: $olmEnabled');

    test('Login', () async {
      var presenceCounter = 0;
      var accountDataCounter = 0;
      matrix.onPresence.stream.listen((Presence data) {
        presenceCounter++;
      });
      matrix.onAccountData.stream.listen((AccountData data) {
        accountDataCounter++;
      });

      expect(matrix.homeserver, null);
      expect(matrix.matrixVersions, null);

      try {
        await matrix.checkServer('https://fakeserver.wrongaddress');
      } on FormatException catch (exception) {
        expect(exception != null, true);
      }
      await matrix.checkServer('https://fakeserver.notexisting');
      expect(matrix.homeserver, 'https://fakeserver.notexisting');
      expect(matrix.matrixVersions,
          ['r0.0.1', 'r0.1.0', 'r0.2.0', 'r0.3.0', 'r0.4.0', 'r0.5.0']);

      final resp = await matrix
          .jsonRequest(type: HTTPType.POST, action: '/client/r0/login', data: {
        'type': 'm.login.password',
        'user': 'test',
        'password': '1234',
        'initial_device_display_name': 'Fluffy Matrix Client'
      });

      final available = await matrix.usernameAvailable('testuser');
      expect(available, true);

      Map registerResponse = await matrix.register(username: 'testuser');
      expect(registerResponse['user_id'], '@testuser:example.com');
      registerResponse =
          await matrix.register(username: 'testuser', kind: 'user');
      expect(registerResponse['user_id'], '@testuser:example.com');
      registerResponse =
          await matrix.register(username: 'testuser', kind: 'guest');
      expect(registerResponse['user_id'], '@testuser:example.com');

      var loginStateFuture = matrix.onLoginStateChanged.stream.first;
      var firstSyncFuture = matrix.onFirstSync.stream.first;
      var syncFuture = matrix.onSync.stream.first;

      matrix.connect(
        newToken: resp['access_token'],
        newUserID: resp['user_id'],
        newHomeserver: matrix.homeserver,
        newDeviceName: 'Text Matrix Client',
        newDeviceID: resp['device_id'],
        newMatrixVersions: matrix.matrixVersions,
        newOlmAccount: pickledOlmAccount,
      );

      await Future.delayed(Duration(milliseconds: 50));

      expect(matrix.accessToken == resp['access_token'], true);
      expect(matrix.deviceName == 'Text Matrix Client', true);
      expect(matrix.deviceID == resp['device_id'], true);
      expect(matrix.userID == resp['user_id'], true);

      var loginState = await loginStateFuture;
      var firstSync = await firstSyncFuture;
      dynamic sync = await syncFuture;

      expect(loginState, LoginState.logged);
      expect(firstSync, true);
      expect(matrix.encryptionEnabled, olmEnabled);
      if (olmEnabled) {
        expect(matrix.pickledOlmAccount, pickledOlmAccount);
        expect(matrix.identityKey, identityKey);
        expect(matrix.fingerprintKey, fingerprintKey);
      }
      expect(sync['next_batch'] == matrix.prevBatch, true);

      expect(matrix.accountData.length, 3);
      expect(matrix.getDirectChatFromUserId('@bob:example.com'),
          '!726s6s6q:example.com');
      expect(matrix.rooms[1].directChatMatrixID, '@bob:example.com');
      expect(matrix.directChats, matrix.accountData['m.direct'].content);
      expect(matrix.presences.length, 1);
      expect(matrix.rooms[1].ephemerals.length, 2);
      expect(matrix.rooms[1].sessionKeys.length, 1);
      expect(
          matrix
              .rooms[1]
              .sessionKeys['ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU']
              .content['session_key'],
          'AgAAAAAQcQ6XrFJk6Prm8FikZDqfry/NbDz8Xw7T6e+/9Yf/q3YHIPEQlzv7IZMNcYb51ifkRzFejVvtphS7wwG2FaXIp4XS2obla14iKISR0X74ugB2vyb1AydIHE/zbBQ1ic5s3kgjMFlWpu/S3FQCnCrv+DPFGEt3ERGWxIl3Bl5X53IjPyVkz65oljz2TZESwz0GH/QFvyOOm8ci0q/gceaF3S7Dmafg3dwTKYwcA5xkcc+BLyrLRzB6Hn+oMAqSNSscnm4mTeT5zYibIhrzqyUTMWr32spFtI9dNR/RFSzfCw');
      if (olmEnabled) {
        expect(
            matrix
                    .rooms[1]
                    .sessionKeys['ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU']
                    .inboundGroupSession !=
                null,
            true);
      }
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
      final contacts = await matrix.loadFamedlyContacts();
      expect(contacts.length, 1);
      expect(contacts[0].senderId, '@alice:example.com');
      expect(
          matrix.presences['@alice:example.com'].presence, PresenceType.online);
      expect(presenceCounter, 1);
      expect(accountDataCounter, 3);
      await Future.delayed(Duration(milliseconds: 50));
      expect(matrix.userDeviceKeys.length, 2);
      expect(matrix.userDeviceKeys['@alice:example.com'].outdated, false);
      expect(matrix.userDeviceKeys['@alice:example.com'].deviceKeys.length, 1);
      expect(
          matrix.userDeviceKeys['@alice:example.com'].deviceKeys['JLAFKJWSCS']
              .verified,
          false);

      matrix.handleSync({
        'device_lists': {
          'changed': [
            '@alice:example.com',
          ],
          'left': [
            '@bob:example.com',
          ],
        }
      });
      await Future.delayed(Duration(milliseconds: 50));
      expect(matrix.userDeviceKeys.length, 2);
      expect(matrix.userDeviceKeys['@alice:example.com'].outdated, true);

      matrix.handleSync({
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
      });
      await Future.delayed(Duration(milliseconds: 50));

      expect(
          matrix.getRoomByAlias(
              "#famedlyContactDiscovery:${matrix.userID.split(":")[1]}"),
          null);
      final altContacts = await matrix.loadFamedlyContacts();
      altContacts.forEach((u) => print(u.id));
      expect(altContacts.length, 2);
      expect(altContacts[0].senderId, '@alice:example.com');
    });

    test('Try to get ErrorResponse', () async {
      MatrixException expectedException;
      try {
        await matrix.jsonRequest(
            type: HTTPType.PUT, action: '/non/existing/path');
      } on MatrixException catch (exception) {
        expectedException = exception;
      }
      expect(expectedException.error, MatrixError.M_UNRECOGNIZED);
    });

    test('Logout', () async {
      await matrix.jsonRequest(
          type: HTTPType.POST, action: '/client/r0/logout');

      var loginStateFuture = matrix.onLoginStateChanged.stream.first;

      matrix.clear();

      expect(matrix.accessToken == null, true);
      expect(matrix.homeserver == null, true);
      expect(matrix.userID == null, true);
      expect(matrix.deviceID == null, true);
      expect(matrix.deviceName == null, true);
      expect(matrix.matrixVersions == null, true);
      expect(matrix.prevBatch == null, true);

      var loginState = await loginStateFuture;
      expect(loginState, LoginState.loggedOut);
    });

    test('Room Update Test', () async {
      await matrix.onRoomUpdate.close();

      var roomUpdateList = await roomUpdateListFuture;

      expect(roomUpdateList.length, 3);

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

      expect(eventUpdateList.length, 13);

      expect(eventUpdateList[0].eventType, 'm.room.member');
      expect(eventUpdateList[0].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[0].type, 'state');

      expect(eventUpdateList[1].eventType, 'm.room.canonical_alias');
      expect(eventUpdateList[1].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[1].type, 'state');

      expect(eventUpdateList[2].eventType, 'm.room.encryption');
      expect(eventUpdateList[2].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[2].type, 'state');

      expect(eventUpdateList[3].eventType, 'm.room.member');
      expect(eventUpdateList[3].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[3].type, 'timeline');

      expect(eventUpdateList[4].eventType, 'm.room.message');
      expect(eventUpdateList[4].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[4].type, 'timeline');

      expect(eventUpdateList[5].eventType, 'm.typing');
      expect(eventUpdateList[5].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[5].type, 'ephemeral');

      expect(eventUpdateList[6].eventType, 'm.receipt');
      expect(eventUpdateList[6].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[6].type, 'ephemeral');

      expect(eventUpdateList[7].eventType, 'm.receipt');
      expect(eventUpdateList[7].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[7].type, 'account_data');

      expect(eventUpdateList[8].eventType, 'm.tag');
      expect(eventUpdateList[8].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[8].type, 'account_data');

      expect(eventUpdateList[9].eventType, 'org.example.custom.room.config');
      expect(eventUpdateList[9].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[9].type, 'account_data');

      expect(eventUpdateList[10].eventType, 'm.room.name');
      expect(eventUpdateList[10].roomID, '!696r7674:example.com');
      expect(eventUpdateList[10].type, 'invite_state');

      expect(eventUpdateList[11].eventType, 'm.room.member');
      expect(eventUpdateList[11].roomID, '!696r7674:example.com');
      expect(eventUpdateList[11].type, 'invite_state');
    });

    test('User Update Test', () async {
      await matrix.onUserEvent.close();

      var eventUpdateList = await userUpdateListFuture;

      expect(eventUpdateList.length, 4);

      expect(eventUpdateList[0].eventType, 'm.presence');
      expect(eventUpdateList[0].type, 'presence');

      expect(eventUpdateList[1].eventType, 'm.push_rules');
      expect(eventUpdateList[1].type, 'account_data');

      expect(eventUpdateList[2].eventType, 'org.example.custom.config');
      expect(eventUpdateList[2].type, 'account_data');
    });

    test('To Device Update Test', () async {
      await matrix.onToDeviceEvent.close();

      var eventUpdateList = await toDeviceUpdateListFuture;

      expect(eventUpdateList.length, 2);

      expect(eventUpdateList[0].type, 'm.new_device');
      expect(eventUpdateList[1].type, 'm.room_key');
    });

    test('Login', () async {
      matrix = Client('testclient', debug: true);
      matrix.httpClient = FakeMatrixApi();

      roomUpdateListFuture = matrix.onRoomUpdate.stream.toList();
      eventUpdateListFuture = matrix.onEvent.stream.toList();
      userUpdateListFuture = matrix.onUserEvent.stream.toList();
      final checkResp =
          await matrix.checkServer('https://fakeServer.notExisting');

      final loginResp = await matrix.login('test', '1234');

      expect(checkResp, true);
      expect(loginResp, true);
    });

    test('createRoom', () async {
      final openId = await matrix.requestOpenIdCredentials();
      expect(openId.accessToken, 'SomeT0kenHere');
      expect(openId.tokenType, 'Bearer');
      expect(openId.matrixServerName, 'example.com');
      expect(openId.expiresIn, 3600);
    });

    test('createRoom', () async {
      final users = [
        User('@alice:fakeServer.notExisting'),
        User('@bob:fakeServer.notExisting')
      ];
      final newID = await matrix.createRoom(invite: users);
      expect(newID, '!1234:fakeServer.notExisting');
    });

    test('setAvatar', () async {
      final testFile =
          MatrixFile(bytes: Uint8List(0), path: 'fake/path/file.jpeg');
      await matrix.setAvatar(testFile);
    });

    test('setPushers', () async {
      await matrix.setPushers('abcdefg', 'http', 'com.famedly.famedlysdk',
          'famedlySDK', 'GitLabCi', 'en', 'https://examplepushserver.com',
          format: 'event_id_only');
    });

    test('joinRoomById', () async {
      final roomID = '1234';
      final Map<String, dynamic> resp = await matrix.joinRoomById(roomID);
      expect(resp['room_id'], roomID);
    });

    test('requestUserDevices', () async {
      final userDevices = await matrix.requestUserDevices();
      expect(userDevices.length, 1);
      expect(userDevices.first.deviceId, 'QBUAZIFURK');
      expect(userDevices.first.displayName, 'android');
      expect(userDevices.first.lastSeenIp, '1.2.3.4');
      expect(
          userDevices.first.lastSeenTs.millisecondsSinceEpoch, 1474491775024);
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
      final profile = await matrix.getProfileFromUserId('@getme:example.com');
      expect(profile.avatarUrl.toString(), 'mxc://test');
      expect(profile.displayname, 'You got me');
      expect(profile.content['avatar_url'], profile.avatarUrl.toString());
      expect(profile.content['displayname'], profile.displayname);
    });

    test('signJson', () {
      if (matrix.encryptionEnabled) {
        expect(matrix.fingerprintKey.isNotEmpty, true);
        expect(matrix.identityKey.isNotEmpty, true);
        var payload = <String, dynamic>{
          'unsigned': {
            'foo': 'bar',
          },
          'auth': {
            'success': true,
            'mxid': '@john.doe:example.com',
            'profile': {
              'display_name': 'John Doe',
              'three_pids': [
                {'medium': 'email', 'address': 'john.doe@example.org'},
                {'medium': 'msisdn', 'address': '123456789'}
              ]
            }
          }
        };
        var payloadWithoutUnsigned = Map<String, dynamic>.from(payload);
        payloadWithoutUnsigned.remove('unsigned');

        expect(
            matrix.checkJsonSignature(
                matrix.fingerprintKey, payload, matrix.userID, matrix.deviceID),
            false);
        expect(
            matrix.checkJsonSignature(matrix.fingerprintKey,
                payloadWithoutUnsigned, matrix.userID, matrix.deviceID),
            false);
        payload = matrix.signJson(payload);
        payloadWithoutUnsigned = matrix.signJson(payloadWithoutUnsigned);
        expect(payload['signatures'], payloadWithoutUnsigned['signatures']);
        print(payload['signatures']);
        expect(
            matrix.checkJsonSignature(
                matrix.fingerprintKey, payload, matrix.userID, matrix.deviceID),
            true);
        expect(
            matrix.checkJsonSignature(matrix.fingerprintKey,
                payloadWithoutUnsigned, matrix.userID, matrix.deviceID),
            true);
      }
    });
    test('Track oneTimeKeys', () async {
      if (matrix.encryptionEnabled) {
        var last = matrix.lastTimeKeysUploaded ?? DateTime.now();
        matrix.handleSync({
          'device_one_time_keys_count': {'signed_curve25519': 49}
        });
        await Future.delayed(Duration(milliseconds: 50));
        expect(
            matrix.lastTimeKeysUploaded.millisecondsSinceEpoch >
                last.millisecondsSinceEpoch,
            true);
      }
    });
    test('Test invalidate outboundGroupSessions', () async {
      if (matrix.encryptionEnabled) {
        expect(matrix.rooms[1].outboundGroupSession == null, true);
        await matrix.rooms[1].createOutboundGroupSession();
        expect(matrix.rooms[1].outboundGroupSession != null, true);
        matrix.handleSync({
          'device_lists': {
            'changed': [
              '@alice:example.com',
            ],
            'left': [
              '@bob:example.com',
            ],
          }
        });
        await Future.delayed(Duration(milliseconds: 50));
        expect(matrix.rooms[1].outboundGroupSession != null, true);
      }
    });
    test('Test invalidate outboundGroupSessions', () async {
      if (matrix.encryptionEnabled) {
        await matrix.rooms[1].clearOutboundGroupSession(wipe: true);
        expect(matrix.rooms[1].outboundGroupSession == null, true);
        await matrix.rooms[1].createOutboundGroupSession();
        expect(matrix.rooms[1].outboundGroupSession != null, true);
        matrix.handleSync({
          'rooms': {
            'join': {
              '!726s6s6q:example.com': {
                'state': {
                  'events': [
                    {
                      'content': {'membership': 'leave'},
                      'event_id': '143273582443PhrSn:example.org',
                      'origin_server_ts': 1432735824653,
                      'room_id': '!726s6s6q:example.com',
                      'sender': '@alice:example.com',
                      'state_key': '@alice:example.com',
                      'type': 'm.room.member'
                    }
                  ]
                }
              }
            }
          }
        });
        await Future.delayed(Duration(milliseconds: 50));
        expect(matrix.rooms[1].outboundGroupSession != null, true);
      }
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
    });
    test('startOutgoingOlmSessions', () async {
      expect(matrix.olmSessions.length, 0);
      if (olmEnabled) {
        await matrix
            .startOutgoingOlmSessions([deviceKeys], checkSignature: false);
        expect(matrix.olmSessions.length, 1);
        expect(matrix.olmSessions.entries.first.key,
            '3C5BFWi2Y8MaVvjM8M22DBmh24PmgR0nPvJOIArzgyI');
      }
    });
    test('sendToDevice', () async {
      await matrix.sendToDevice(
          [deviceKeys],
          'm.message',
          {
            'msgtype': 'm.text',
            'body': 'Hello world',
          });
    });
    test('Logout when token is unknown', () async {
      var loginStateFuture = matrix.onLoginStateChanged.stream.first;

      try {
        await matrix.jsonRequest(
            type: HTTPType.DELETE, action: '/unknown/token');
      } on MatrixException catch (exception) {
        expect(exception.error, MatrixError.M_UNKNOWN_TOKEN);
      }

      var state = await loginStateFuture;
      expect(state, LoginState.loggedOut);
      expect(matrix.isLogged(), false);
    });
    test('Test the fake store api', () async {
      var client1 = Client('testclient', debug: true);
      client1.httpClient = FakeMatrixApi();
      var fakeStore = FakeStore(client1, {});
      client1.storeAPI = fakeStore;

      client1.connect(
        newToken: 'abc123',
        newUserID: '@test:fakeServer.notExisting',
        newHomeserver: 'https://fakeServer.notExisting',
        newDeviceName: 'Text Matrix Client',
        newDeviceID: 'GHTYAJCE',
        newMatrixVersions: [
          'r0.0.1',
          'r0.1.0',
          'r0.2.0',
          'r0.3.0',
          'r0.4.0',
          'r0.5.0'
        ],
        newOlmAccount: pickledOlmAccount,
      );

      await Future.delayed(Duration(milliseconds: 50));

      String sessionKey;
      if (client1.encryptionEnabled) {
        await client1.rooms[1].createOutboundGroupSession();

        sessionKey = client1.rooms[1].outboundGroupSession.session_key();
      }

      expect(client1.isLogged(), true);
      expect(client1.rooms.length, 2);

      var client2 = Client('testclient', debug: true);
      client2.httpClient = FakeMatrixApi();
      client2.storeAPI = FakeStore(client2, fakeStore.storeMap);

      await Future.delayed(Duration(milliseconds: 100));

      expect(client2.isLogged(), true);
      expect(client2.accessToken, client1.accessToken);
      expect(client2.userID, client1.userID);
      expect(client2.homeserver, client1.homeserver);
      expect(client2.deviceID, client1.deviceID);
      expect(client2.deviceName, client1.deviceName);
      expect(client2.matrixVersions, client1.matrixVersions);
      if (client2.encryptionEnabled) {
        expect(client2.pickledOlmAccount, client1.pickledOlmAccount);
        expect(json.encode(client2.rooms[1].sessionKeys[sessionKey]),
            json.encode(client1.rooms[1].sessionKeys[sessionKey]));
        expect(client2.rooms[1].id, client1.rooms[1].id);
        expect(client2.rooms[1].outboundGroupSession.session_key(), sessionKey);
      }
    });
  });
}
