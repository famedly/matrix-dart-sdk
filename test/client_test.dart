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

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:canonical_json/canonical_json.dart';
import 'package:collection/collection.dart';
import 'package:olm/olm.dart' as olm;
import 'package:test/test.dart';

import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/client_init_exception.dart';
import 'fake_client.dart';
import 'fake_database.dart';

void main() {
  late Client matrix;

  // key @test:fakeServer.notExisting
  const pickledOlmAccount =
      'N2v1MkIFGcl0mQpo2OCwSopxPQJ0wnl7oe7PKiT4141AijfdTIhRu+ceXzXKy3Kr00nLqXtRv7kid6hU4a+V0rfJWLL0Y51+3Rp/ORDVnQy+SSeo6Fn4FHcXrxifJEJ0djla5u98fBcJ8BSkhIDmtXRPi5/oJAvpiYn+8zMjFHobOeZUAxYR0VfQ9JzSYBsSovoQ7uFkNks1M4EDUvHtuyg3RxViwdNxs3718fyAqQ/VSwbXsY0Nl+qQbF+nlVGHenGqk5SuNl1P6e1PzZxcR0IfXA94Xij1Ob5gDv5YH4UCn9wRMG0abZsQP0YzpDM0FLaHSCyo9i5JD/vMlhH+nZWrgAzPPCTNGYewNV8/h3c+VyJh8ZTx/fVi6Yq46Fv+27Ga2ETRZ3Qn+Oyx6dLBjnBZ9iUvIhqpe2XqaGA1PopOz8iDnaZitw';
  const identityKey = '7rvl3jORJkBiK4XX1e5TnGnqz068XfYJ0W++Ml63rgk';
  const fingerprintKey = 'gjL//fyaFHADt9KBADGag8g7F8Up78B/K1zXeiEPLJo';

  /// All Tests related to the Login
  group('Client', tags: 'olm', () {
    Logs().level = Level.error;

    /// Check if all Elements get created

    setUp(() async {
      matrix = await getClient();
    });

    test('Login', () async {
      matrix = Client(
        'testclient',
        httpClient: FakeMatrixApi(),
        databaseBuilder: getDatabase,
      );
      final eventUpdateListFuture = matrix.onEvent.stream.toList();
      final toDeviceUpdateListFuture = matrix.onToDeviceEvent.stream.toList();
      var presenceCounter = 0;
      var accountDataCounter = 0;
      matrix.onPresenceChanged.stream.listen((CachedPresence data) {
        presenceCounter++;
      });
      // ignore: deprecated_member_use_from_same_package
      matrix.onAccountData.stream.listen((BasicEvent data) {
        accountDataCounter++;
      });

      expect(matrix.homeserver, null);

      try {
        await matrix
            .checkHomeserver(Uri.parse('https://fakeserver.wrongaddress'));
      } catch (exception) {
        expect(exception.toString().isNotEmpty, true);
      }
      await matrix.checkHomeserver(Uri.parse('https://fakeserver.notexisting'),
          checkWellKnown: false);
      expect(matrix.homeserver.toString(), 'https://fakeserver.notexisting');

      final available = await matrix.checkUsernameAvailability('testuser');
      expect(available, true);

      final loginStateFuture = matrix.onLoginStateChanged.stream.first;
      final syncFuture = matrix.onSync.stream.first;

      await matrix.init(
        newToken: 'abcd',
        newUserID: '@test:fakeServer.notExisting',
        newHomeserver: matrix.homeserver,
        newDeviceName: 'Text Matrix Client',
        newDeviceID: 'GHTYAJCE',
        newOlmAccount: pickledOlmAccount,
      );

      await Future.delayed(Duration(milliseconds: 50));

      final loginState = await loginStateFuture;
      final sync = await syncFuture;

      expect(loginState, LoginState.loggedIn);
      expect(matrix.onSync.value != null, true);
      expect(matrix.encryptionEnabled, true);
      expect(matrix.identityKey, identityKey);
      expect(matrix.fingerprintKey, fingerprintKey);

      expect(sync.nextBatch == matrix.prevBatch, true);

      expect(matrix.accountData.length, 10);
      expect(matrix.getDirectChatFromUserId('@bob:example.com'),
          '!726s6s6q:example.com');
      expect(matrix.rooms[2].directChatMatrixID, '@bob:example.com');
      expect(matrix.directChats, matrix.accountData['m.direct']?.content);
      // ignore: deprecated_member_use_from_same_package
      expect(matrix.presences.length, 1);
      expect(matrix.rooms[2].ephemerals.length, 2);
      expect(matrix.rooms[2].typingUsers.length, 1);
      expect(matrix.rooms[2].typingUsers[0].id, '@alice:example.com');
      expect(matrix.rooms[2].roomAccountData.length, 3);
      expect(matrix.rooms[2].encrypted, true);
      expect(matrix.rooms[2].encryptionAlgorithm,
          Client.supportedGroupEncryptionAlgorithms.first);
      expect(
          matrix.rooms[2].receiptState.global.otherUsers['@alice:example.com']
              ?.ts,
          1436451550453);
      expect(
          matrix.rooms[2].receiptState.global.otherUsers['@alice:example.com']
              ?.eventId,
          '\$7365636s6r6432:example.com');

      final inviteRoom = matrix.rooms
          .singleWhere((room) => room.membership == Membership.invite);
      expect(inviteRoom.name, 'My Room Name');
      expect(inviteRoom.states[EventTypes.RoomMember]?.length, 1);
      expect(matrix.rooms.length, 3);
      expect(matrix.rooms[2].canonicalAlias,
          "#famedlyContactDiscovery:${matrix.userID!.split(":")[1]}");
      // ignore: deprecated_member_use_from_same_package
      expect(matrix.presences['@alice:example.com']?.presence,
          PresenceType.online);
      expect(presenceCounter, 1);
      expect(accountDataCounter, 10);
      await Future.delayed(Duration(milliseconds: 50));
      expect(matrix.userDeviceKeys.keys.toSet(), {
        '@alice:example.com',
        '@othertest:fakeServer.notExisting',
        '@test:fakeServer.notExisting',
      });
      expect(matrix.userDeviceKeys['@alice:example.com']?.outdated, false);
      expect(matrix.userDeviceKeys['@alice:example.com']?.deviceKeys.length, 2);
      expect(
          matrix.userDeviceKeys['@alice:example.com']?.deviceKeys['JLAFKJWSCS']
              ?.verified,
          false);

      await matrix.handleSync(SyncUpdate.fromJson({
        'next_batch': 'fakesync',
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
      expect(matrix.userDeviceKeys['@alice:example.com']?.outdated, true);

      await matrix.handleSync(SyncUpdate.fromJson({
        'next_batch': 'fakesync',
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
              "#famedlyContactDiscovery:${matrix.userID!.split(":")[1]}"),
          null);

      await matrix.onEvent.close();

      final eventUpdateList = await eventUpdateListFuture;

      expect(eventUpdateList.length, 20);

      expect(eventUpdateList[0].content['type'], 'm.room.member');
      expect(eventUpdateList[0].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[0].type, EventUpdateType.state);

      expect(eventUpdateList[1].content['type'], 'm.room.canonical_alias');
      expect(eventUpdateList[1].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[1].type, EventUpdateType.state);

      expect(eventUpdateList[2].content['type'], 'm.room.encryption');
      expect(eventUpdateList[2].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[2].type, EventUpdateType.state);

      expect(eventUpdateList[3].content['type'], 'm.room.pinned_events');
      expect(eventUpdateList[3].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[3].type, EventUpdateType.state);

      expect(eventUpdateList[4].content['type'], 'm.room.member');
      expect(eventUpdateList[4].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[4].type, EventUpdateType.timeline);

      expect(eventUpdateList[5].content['type'], 'm.room.message');
      expect(eventUpdateList[5].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[5].type, EventUpdateType.timeline);

      expect(eventUpdateList[6].content['type'], 'm.typing');
      expect(eventUpdateList[6].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[6].type, EventUpdateType.ephemeral);

      expect(eventUpdateList[7].content['type'], 'm.receipt');
      expect(eventUpdateList[7].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[7].type, EventUpdateType.ephemeral);

      expect(eventUpdateList[8].content['type'], LatestReceiptState.eventType);
      expect(eventUpdateList[8].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[8].type, EventUpdateType.accountData);

      expect(eventUpdateList[9].content['type'], 'm.tag');
      expect(eventUpdateList[9].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[9].type, EventUpdateType.accountData);

      expect(eventUpdateList[10].content['type'],
          'org.example.custom.room.config');
      expect(eventUpdateList[10].roomID, '!726s6s6q:example.com');
      expect(eventUpdateList[10].type, EventUpdateType.accountData);

      expect(eventUpdateList[11].content['type'], 'm.room.member');
      expect(eventUpdateList[11].roomID, '!calls:example.com');
      expect(eventUpdateList[11].type, EventUpdateType.state);

      expect(eventUpdateList[12].content['type'], 'm.room.member');
      expect(eventUpdateList[12].roomID, '!calls:example.com');
      expect(eventUpdateList[12].type, EventUpdateType.state);

      await matrix.onToDeviceEvent.close();

      final deviceeventUpdateList = await toDeviceUpdateListFuture;

      expect(deviceeventUpdateList.length, 2);

      expect(deviceeventUpdateList[0].type, 'm.new_device');

      expect(deviceeventUpdateList[1].type, 'm.room_key');
    });

    test('recentEmoji', () async {
      final emojis = matrix.recentEmojis;

      expect(emojis.length, 2);

      expect(emojis['👍️'], 1);
      expect(emojis['🖇️'], 0);

      await matrix.addRecentEmoji('🦙');
      // To check if the emoji is properly added, we need to wait for a sync roundtrip
    });

    test('accountData', () async {
      final content = {
        'bla': 'blub',
      };

      final key = 'abc def!/_-';
      await matrix.setAccountData(matrix.userID!, key, content);
      final dbContent = await matrix.database?.getAccountData();

      expect(matrix.accountData[key]?.content, content);
      expect(dbContent?[key]?.content, content);
    });

    test('roomAccountData', () async {
      final content = {
        'bla': 'blub',
      };

      final key = 'abc def!/_-';
      final roomId = '!726s6s6q:example.com';
      await matrix.setAccountDataPerRoom(matrix.userID!, roomId, key, content);
      final roomFromList = (await matrix.database?.getRoomList(matrix))
          ?.firstWhere((room) => room.id == roomId);
      final roomFromDb = await matrix.database?.getSingleRoom(matrix, roomId);

      expect(
          matrix.getRoomById(roomId)?.roomAccountData[key]?.content, content);
      expect(roomFromList?.roomAccountData[key]?.content, content);
      expect(roomFromDb?.roomAccountData[key]?.content, content,
          skip: 'The single room function does not load account data');
    });

    test('Logout', () async {
      final loginStateFuture = matrix.onLoginStateChanged.stream.first;
      await matrix.logout();

      expect(matrix.accessToken == null, true);
      expect(matrix.homeserver == null, true);
      expect(matrix.userID == null, true);
      expect(matrix.deviceID == null, true);
      expect(matrix.deviceName == null, true);
      expect(matrix.prevBatch == null, true);

      final loginState = await loginStateFuture;
      expect(loginState, LoginState.loggedOut);
    });

    test('Login again but break server when trying to logout', () async {
      matrix = Client(
        'testclient',
        httpClient: FakeMatrixApi(),
        databaseBuilder: getDatabase,
      );

      expect(matrix.homeserver, null);

      try {
        await matrix
            .checkHomeserver(Uri.parse('https://fakeserver.wrongaddress'));
      } catch (exception) {
        expect(exception.toString().isNotEmpty, true);
      }
      await matrix.checkHomeserver(Uri.parse('https://fakeserver.notexisting'),
          checkWellKnown: false);
      expect(matrix.homeserver.toString(), 'https://fakeserver.notexisting');

      final available = await matrix.checkUsernameAvailability('testuser');
      expect(available, true);

      final loginStateFuture = matrix.onLoginStateChanged.stream.first;
      final syncFuture = matrix.onSync.stream.first;

      await matrix.init(
        newToken: 'abcd',
        newUserID: '@test:fakeServer.notExisting',
        newHomeserver: matrix.homeserver,
        newDeviceName: 'Text Matrix Client',
        newDeviceID: 'GHTYAJCE',
        newOlmAccount: pickledOlmAccount,
      );

      await Future.delayed(Duration(milliseconds: 50));

      final loginState = await loginStateFuture;
      final sync = await syncFuture;

      expect(loginState, LoginState.loggedIn);
      expect(matrix.onSync.value != null, true);
      expect(matrix.encryptionEnabled, true);

      expect(matrix.identityKey, identityKey);
      expect(matrix.fingerprintKey, fingerprintKey);

      expect(sync.nextBatch == matrix.prevBatch, true);
    });

    test('Logout but this time server is dead', () async {
      final oldapi = FakeMatrixApi.currentApi?.api;
      expect(
          (FakeMatrixApi.currentApi?.api['PUT']?.keys.where((element) =>
              element.startsWith('/client/v3/room_keys/keys?version')))?.length,
          1);
      // not a huge fan, open to ideas
      FakeMatrixApi.currentApi?.api = {};
      // random sanity test to test if the test to test the breaking server hack works.
      expect(
          (FakeMatrixApi.currentApi?.api['PUT']?.keys.where((element) =>
              element.startsWith('/client/v3/room_keys/keys?version')))?.length,
          null);
      try {
        await matrix.logout();
      } catch (e) {
        Logs().w(
            'Ignore red warnings for this test, test is to check if database is cleared even if server breaks ');
      }

      expect(matrix.accessToken == null, true);
      expect(matrix.homeserver == null, true);
      expect(matrix.userID == null, true);
      expect(matrix.deviceID == null, true);
      expect(matrix.deviceName == null, true);
      expect(matrix.prevBatch == null, true);

      FakeMatrixApi.currentApi?.api = oldapi!;
    });

    test('Login', () async {
      matrix = Client(
        'testclient',
        httpClient: FakeMatrixApi(),
        databaseBuilder: getDatabase,
      );

      await matrix.checkHomeserver(Uri.parse('https://fakeserver.notexisting'),
          checkWellKnown: false);

      final loginResp = await matrix.login(LoginType.mLoginPassword,
          identifier: AuthenticationUserIdentifier(user: 'test'),
          password: '1234');

      expect(loginResp.userId.isNotEmpty, true);
    });

    test('setAvatar', () async {
      final testFile = MatrixFile(bytes: Uint8List(0), name: 'file.jpeg');
      await matrix.setAvatar(testFile);
    });

    test('setMuteAllPushNotifications', () async {
      await matrix.setMuteAllPushNotifications(false);
    });

    test('createSpace', () async {
      await matrix.createSpace(
        name: 'space',
        topic: 'My test space',
        spaceAliasName: '#myspace:example.invalid',
        invite: ['@alice:example.invalid'],
        roomVersion: '3',
      );
    });

    test('sync state event in-memory handling', () async {
      final roomId = '!726s6s6q:example.com';
      final room = matrix.getRoomById(roomId)!;
      // put an important state event in-memory
      await matrix.handleSync(SyncUpdate.fromJson({
        'next_batch': 'fakesync',
        'rooms': {
          'join': {
            roomId: {
              'state': {
                'events': [
                  <String, dynamic>{
                    'sender': '@alice:example.com',
                    'type': 'm.room.name',
                    'content': <String, dynamic>{'name': 'foxies'},
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
      expect(room.getState('m.room.name')?.content['name'], 'foxies');

      // drop an unimportant state event from in-memory handling
      await matrix.handleSync(SyncUpdate.fromJson({
        'next_batch': 'fakesync',
        'rooms': {
          'join': {
            roomId: {
              'state': {
                'events': [
                  <String, dynamic>{
                    'sender': '@alice:example.com',
                    'type': 'com.famedly.custom',
                    'content': <String, dynamic>{'name': 'foxies'},
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
      expect(room.getState('com.famedly.custom'), null);

      // persist normal room messages
      await matrix.handleSync(SyncUpdate.fromJson({
        'next_batch': 'fakesync',
        'rooms': {
          'join': {
            roomId: {
              'timeline': {
                'events': [
                  <String, dynamic>{
                    'sender': '@alice:example.com',
                    'type': 'm.room.message',
                    'content': <String, dynamic>{
                      'msgtype': 'm.text',
                      'body': 'meow'
                    },
                    'origin_server_ts': 1417731086799,
                    'event_id': '\$last:example.com'
                  }
                ]
              }
            }
          }
        }
      }));
      expect(room.lastEvent!.content['body'], 'meow');

      // ignore edits
      await matrix.handleSync(SyncUpdate.fromJson({
        'next_batch': 'fakesync',
        'rooms': {
          'join': {
            roomId: {
              'timeline': {
                'events': [
                  <String, dynamic>{
                    'sender': '@alice:example.com',
                    'type': 'm.room.message',
                    'content': <String, dynamic>{
                      'msgtype': 'm.text',
                      'body': '* floooof',
                      'm.new_content': <String, dynamic>{
                        'msgtype': 'm.text',
                        'body': 'floooof',
                      },
                      'm.relates_to': <String, dynamic>{
                        'rel_type': 'm.replace',
                        'event_id': '\$other:example.com'
                      },
                    },
                    'origin_server_ts': 1417731086799,
                    'event_id': '\$edit:example.com'
                  }
                ]
              }
            }
          }
        }
      }));
      expect(room.lastEvent!.content['body'], 'meow');

      // accept edits to the last event
      await matrix.handleSync(SyncUpdate.fromJson({
        'next_batch': 'fakesync',
        'rooms': {
          'join': {
            roomId: {
              'timeline': {
                'events': [
                  <String, dynamic>{
                    'sender': '@alice:example.com',
                    'type': 'm.room.message',
                    'content': <String, dynamic>{
                      'msgtype': 'm.text',
                      'body': '* floooof',
                      'm.new_content': <String, dynamic>{
                        'msgtype': 'm.text',
                        'body': 'floooof',
                      },
                      'm.relates_to': <String, dynamic>{
                        'rel_type': 'm.replace',
                        'event_id': '\$last:example.com'
                      },
                    },
                    'origin_server_ts': 1417731086799,
                    'event_id': '\$edit:example.com'
                  }
                ]
              }
            }
          }
        }
      }));
      expect(room.lastEvent!.content['body'], '* floooof');

      // accepts a consecutive edit
      await matrix.handleSync(SyncUpdate.fromJson({
        'next_batch': 'fakesync',
        'rooms': {
          'join': {
            roomId: {
              'timeline': {
                'events': [
                  <String, dynamic>{
                    'sender': '@alice:example.com',
                    'type': 'm.room.message',
                    'content': <String, dynamic>{
                      'msgtype': 'm.text',
                      'body': '* foxies',
                      'm.new_content': <String, dynamic>{
                        'msgtype': 'm.text',
                        'body': 'foxies',
                      },
                      'm.relates_to': <String, dynamic>{
                        'rel_type': 'm.replace',
                        'event_id': '\$last:example.com'
                      },
                    },
                    'origin_server_ts': 1417731086799,
                    'event_id': '\$edit2:example.com'
                  }
                ]
              }
            }
          }
        }
      }));
      expect(room.lastEvent!.content['body'], '* foxies');
    });

    test('getProfileFromUserId', () async {
      final profile = await matrix.getProfileFromUserId('@getme:example.com',
          getFromRooms: false);
      expect(profile.avatarUrl.toString(), 'mxc://test');
      expect(profile.displayName, 'You got me');
      final aliceProfile =
          await matrix.getProfileFromUserId('@alice:example.com');
      expect(aliceProfile.avatarUrl.toString(),
          'mxc://example.org/SEsfnsuifSDFSSEF');
      expect(aliceProfile.displayName, 'Alice Margatroid');
    });
    test('joinAfterInviteMembership', () async {
      final client = await getClient();
      await client.abortSync();
      client.rooms.clear();
      await client.database?.clearCache();

      await client.handleSync(SyncUpdate.fromJson(jsonDecode(
          '{"next_batch":"s198510_227245_8_1404_23586_11_51065_267416_0_2639","rooms":{"invite":{"!bWEUQDujMKwjxkCXYr:tim-alpha.staging.famedly.de":{"invite_state":{"events":[{"type":"m.room.create","content":{"type":"de.gematik.tim.roomtype.default.v1","room_version":"10","creator":"@toboggen_veronika_freifrau:tim-alpha.staging.famedly.de"},"sender":"@toboggen_veronika_freifrau:tim-alpha.staging.famedly.de","state_key":""},{"type":"m.room.encryption","content":{"algorithm":"m.megolm.v1.aes-sha2"},"sender":"@toboggen_veronika_freifrau:tim-alpha.staging.famedly.de","state_key":""},{"type":"m.room.join_rules","content":{"join_rule":"invite"},"sender":"@toboggen_veronika_freifrau:tim-alpha.staging.famedly.de","state_key":""},{"type":"m.room.member","content":{"membership":"join","displayname":"Tóboggen, Veronika Freifrau"},"sender":"@toboggen_veronika_freifrau:tim-alpha.staging.famedly.de","state_key":"@toboggen_veronika_freifrau:tim-alpha.staging.famedly.de"},{"type":"m.room.member","content":{"is_direct":true,"membership":"invite","displayname":"Düsterbehn-Hardenbergshausen, Michael von"},"sender":"@toboggen_veronika_freifrau:tim-alpha.staging.famedly.de","state_key":"@duesterbehn-hardenbergshausen_michael_von:tim-alpha.staging.famedly.de"}]}}}},"presence":{"events":[{"type":"m.presence","content":{"presence":"online","last_active_ago":5948,"currently_active":true},"sender":"@duesterbehn-hardenbergshausen_michael_von:tim-alpha.staging.famedly.de"}]},"device_one_time_keys_count":{"signed_curve25519":66},"device_unused_fallback_key_types":["signed_curve25519"],"org.matrix.msc2732.device_unused_fallback_key_types":["signed_curve25519"]}')));
      await client.handleSync(SyncUpdate.fromJson(jsonDecode(
          '{"next_batch":"s198511_227245_8_1404_23588_11_51066_267416_0_2639","account_data":{"events":[{"type":"m.direct","content":{"@toboggen_veronika_freifrau:tim-alpha.staging.famedly.de":["!bWEUQDujMKwjxkCXYr:tim-alpha.staging.famedly.de"]}}]},"device_one_time_keys_count":{"signed_curve25519":65},"device_unused_fallback_key_types":["signed_curve25519"],"org.matrix.msc2732.device_unused_fallback_key_types":["signed_curve25519"]}')));
      await client.handleSync(SyncUpdate.fromJson(jsonDecode(
          '{"next_batch":"s198512_227245_8_1404_23588_11_51066_267416_0_2639","rooms":{"join":{"!bWEUQDujMKwjxkCXYr:tim-alpha.staging.famedly.de":{"summary":{"m.heroes":["@toboggen_veronika_freifrau:tim-alpha.staging.famedly.de"],"m.joined_member_count":2,"m.invited_member_count":0},"state":{"events":[{"type":"m.room.create","content":{"type":"de.gematik.tim.roomtype.default.v1","room_version":"10","creator":"@toboggen_veronika_freifrau:tim-alpha.staging.famedly.de"},"sender":"@toboggen_veronika_freifrau:tim-alpha.staging.famedly.de","state_key":"","event_id":"\$qSgXGXjly6p5Kwbdb_PMBC_EF7nzHDbM23mvJFVeoiE","origin_server_ts":1709565579735,"unsigned":{"age":2255}}]},"timeline":{"events":[{"type":"m.room.member","content":{"membership":"join","displayname":"Tóboggen, Veronika Freifrau"},"sender":"@toboggen_veronika_freifrau:tim-alpha.staging.famedly.de","state_key":"@toboggen_veronika_freifrau:tim-alpha.staging.famedly.de","event_id":"\$rQzxxTrSd9Y0koxIGlkalPAV_lwu94jLOA-8PSunY24","origin_server_ts":1709565579871,"unsigned":{"age":2119,"com.famedly.famedlysdk.message_sending_status":2}},{"type":"m.room.power_levels","content":{"users":{"@toboggen_veronika_freifrau:tim-alpha.staging.famedly.de":100,"@duesterbehn-hardenbergshausen_michael_von:tim-alpha.staging.famedly.de":100},"users_default":0,"events":{"m.room.name":50,"m.room.power_levels":100,"m.room.history_visibility":100,"m.room.canonical_alias":50,"m.room.avatar":50,"m.room.tombstone":100,"m.room.server_acl":100,"m.room.encryption":100},"events_default":0,"state_default":50,"ban":50,"kick":50,"redact":50,"invite":0,"historical":100},"sender":"@toboggen_veronika_freifrau:tim-alpha.staging.famedly.de","state_key":"","event_id":"\$d6sgGs8PmkAbC3Iw3CkPT1QSub2zFTTvytegOxkPYPs","origin_server_ts":1709565579966,"unsigned":{"age":2024,"com.famedly.famedlysdk.message_sending_status":2}},{"type":"m.room.join_rules","content":{"join_rule":"invite"},"sender":"@toboggen_veronika_freifrau:tim-alpha.staging.famedly.de","state_key":"","event_id":"\$EnA2Podch5181X4G1ZX34zaFGS_V4ZCZzLkBEfS_qyg","origin_server_ts":1709565579979,"unsigned":{"age":2011,"com.famedly.famedlysdk.message_sending_status":2}},{"type":"m.room.history_visibility","content":{"history_visibility":"shared"},"sender":"@toboggen_veronika_freifrau:tim-alpha.staging.famedly.de","state_key":"","event_id":"\$6tNNo6ZkpZZrHrn8ZjXhMqI0CNv-VNNBw4R0h3_O-Tc","origin_server_ts":1709565579979,"unsigned":{"age":2011,"com.famedly.famedlysdk.message_sending_status":2}},{"type":"m.room.guest_access","content":{"guest_access":"can_join"},"sender":"@toboggen_veronika_freifrau:tim-alpha.staging.famedly.de","state_key":"","event_id":"\$ViuL_LpN1sY9oYcGwycNjtp6FcGj__smUg8mzj3oa2o","origin_server_ts":1709565579980,"unsigned":{"age":2010,"com.famedly.famedlysdk.message_sending_status":2}},{"type":"m.room.encryption","content":{"algorithm":"m.megolm.v1.aes-sha2"},"sender":"@toboggen_veronika_freifrau:tim-alpha.staging.famedly.de","state_key":"","event_id":"\$_e0az7OP7D78QU7DItiRAtlHlZmA07B5wenR93x5V1E","origin_server_ts":1709565579981,"unsigned":{"age":2009,"com.famedly.famedlysdk.message_sending_status":2}},{"type":"m.room.member","content":{"is_direct":true,"membership":"invite","displayname":"Düsterbehn-Hardenbergshausen, Michael von"},"sender":"@toboggen_veronika_freifrau:tim-alpha.staging.famedly.de","state_key":"@duesterbehn-hardenbergshausen_michael_von:tim-alpha.staging.famedly.de","event_id":"\$4sZ3CF67SUh0n5WG0ZKS47Epj9B_d842RJjnrQmUKQo","origin_server_ts":1709565580185,"unsigned":{"age":1805,"com.famedly.famedlysdk.message_sending_status":2}},{"type":"m.room.notsoencrypted","content":{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"AwgAEpACEZw8Ymg99Yfl7VsXRIdczlQ3+YSJ6te3o6ka/XXP0h4ZsgR2bu1Q8puQ77fOpwX5dPnrrCi5SQg9Zv5/u+0QbFV4FKE/k03Vxao/tiswb6wST14x9kYkwViOrZe7fzg7VF9tCi8U88TqxGsPDDOVjO+WNxG8I9ldP1zvPsxYzVSyGPhaB5E+q6llwlXcQ56wvpf7Ke7gX4Ly2Dlxa8Bmy7aUSCBoWAt/xFRdzCOsE9qI8oxzuvk4RF0H/7bY+4DkGTsP1rIYgA7Q0JueIFb47Yu6pK26BCKo1yPAR8qvpe8vGBICm4slMbKaJN4RqBHtR0zc12E5DXud91o3mArqTksv1NEbI1F4XgDREl76WBw8a7MafDSuun09JuWpGxzPHvLVOUVny6tTJPRutsZLkmnTeMTiXnsPexUiY7UTYlzOMeeoUSTDuJXJz6CM+gSc52CiKoHK/gE","device_id":"TNLOYXJFXM","sender_key":"e9W0gpUcSEKOQ8P/xIdroHUpP7yG4EjQfueiAngESRk","session_id":"hhZ8TBs9Xp0dmuvC6XpDBYsAKnTqb8WiBhZMzHcbBXI"},"sender":"@toboggen_veronika_freifrau:tim-alpha.staging.famedly.de","event_id":"\$KKIZX8cuB3S3uzS7CDtRlTkcaJRW73e2HW2NuW6OTEg","origin_server_ts":1709565580991,"unsigned":{"age":999,"com.famedly.famedlysdk.message_sending_status":2}},{"type":"m.room.member","content":{"membership":"join","displayname":"Düsterbehn-Hardenbergshausen, Michael von"},"sender":"@duesterbehn-hardenbergshausen_michael_von:tim-alpha.staging.famedly.de","state_key":"@duesterbehn-hardenbergshausen_michael_von:tim-alpha.staging.famedly.de","event_id":"\$UNSLEyhC_93oQlt0tWoai4CCd3LH2GJJexM0WN2wxCA","origin_server_ts":1709565581813,"unsigned":{"replaces_state":"\$4sZ3CF67SUh0n5WG0ZKS47Epj9B_d842RJjnrQmUKQo","prev_content":{"is_direct":true,"membership":"invite","displayname":"Düsterbehn-Hardenbergshausen, Michael von"},"prev_sender":"@toboggen_veronika_freifrau:tim-alpha.staging.famedly.de","age":177,"com.famedly.famedlysdk.message_sending_status":2}},{"type":"m.room.member","content":{"membership":"join","displayname":"Düsterbehn-Hardenbergshausen, Michael von"},"sender":"@duesterbehn-hardenbergshausen_michael_von:tim-alpha.staging.famedly.de","state_key":"@duesterbehn-hardenbergshausen_michael_von:tim-alpha.staging.famedly.de","event_id":"\$UNSLEyhC_93oQlt0tWoai4CCd3LH2GJJexM0WN2wxCA","origin_server_ts":1709565581813,"unsigned":{"replaces_state":"\$4sZ3CF67SUh0n5WG0ZKS47Epj9B_d842RJjnrQmUKQo","prev_content":{"is_direct":true,"membership":"invite","displayname":"Düsterbehn-Hardenbergshausen, Michael von"},"prev_sender":"@toboggen_veronika_freifrau:tim-alpha.staging.famedly.de","age":177,"com.famedly.famedlysdk.message_sending_status":2}}],"limited":true,"prev_batch":"s198503_227245_8_1404_23588_11_51066_267416_0_2639"},"ephemeral":{"events":[]},"account_data":{"events":[]},"unread_notifications":{"highlight_count":0,"notification_count":0}}}},"presence":{"events":[{"type":"m.presence","content":{"presence":"online","last_active_ago":843,"currently_active":true},"sender":"@toboggen_veronika_freifrau:tim-alpha.staging.famedly.de"}]},"device_lists":{"changed":["@duesterbehn-hardenbergshausen_michael_von:tim-alpha.staging.famedly.de","@toboggen_veronika_freifrau:tim-alpha.staging.famedly.de"],"left":[]},"device_one_time_keys_count":{"signed_curve25519":65},"device_unused_fallback_key_types":["signed_curve25519"],"org.matrix.msc2732.device_unused_fallback_key_types":["signed_curve25519"]}')));
      //await client.handleSync(SyncUpdate.fromJson(jsonDecode('')));
      final room = client
          .getRoomById('!bWEUQDujMKwjxkCXYr:tim-alpha.staging.famedly.de')!;
      await room.postLoad();
      final participants = await room.requestParticipants();

      expect(
          participants.where((u) => u.membership == Membership.join).length, 2);

      await client.abortSync();
      client.rooms.clear();
      await client.database?.clearCache();
      await client.dispose(closeDatabase: true);
    });
    test('ownProfile', () async {
      final client = await getClient();
      await client.abortSync();
      client.rooms.clear();
      await client.database?.clearCache();
      await client.handleSync(SyncUpdate.fromJson(jsonDecode(
          '{"next_batch":"s82_571_2_6_39_1_2_34_1","account_data":{"events":[{"type":"m.push_rules","content":{"global":{"underride":[{"conditions":[{"kind":"event_match","key":"type","pattern":"m.call.invite"}],"actions":["notify",{"set_tweak":"sound","value":"ring"},{"set_tweak":"highlight","value":false}],"rule_id":".m.rule.call","default":true,"enabled":true},{"conditions":[{"kind":"room_member_count","is":"2"},{"kind":"event_match","key":"type","pattern":"m.room.message"}],"actions":["notify",{"set_tweak":"sound","value":"default"},{"set_tweak":"highlight","value":false}],"rule_id":".m.rule.room_one_to_one","default":true,"enabled":true},{"conditions":[{"kind":"room_member_count","is":"2"},{"kind":"event_match","key":"type","pattern":"m.room.encrypted"}],"actions":["notify",{"set_tweak":"sound","value":"default"},{"set_tweak":"highlight","value":false}],"rule_id":".m.rule.encrypted_room_one_to_one","default":true,"enabled":true},{"conditions":[{"kind":"event_match","key":"type","pattern":"m.room.message"}],"actions":["notify",{"set_tweak":"highlight","value":false}],"rule_id":".m.rule.message","default":true,"enabled":true},{"conditions":[{"kind":"event_match","key":"type","pattern":"m.room.encrypted"}],"actions":["notify",{"set_tweak":"highlight","value":false}],"rule_id":".m.rule.encrypted","default":true,"enabled":true},{"conditions":[{"kind":"event_match","key":"type","pattern":"im.vector.modular.widgets"},{"kind":"event_match","key":"content.type","pattern":"jitsi"},{"kind":"event_match","key":"state_key","pattern":"*"}],"actions":["notify",{"set_tweak":"highlight","value":false}],"rule_id":".im.vector.jitsi","default":true,"enabled":true}],"sender":[],"room":[],"content":[{"actions":["notify",{"set_tweak":"sound","value":"default"},{"set_tweak":"highlight"}],"pattern":"056d6976-fb61-47cf-86f0-147387461565","rule_id":".m.rule.contains_user_name","default":true,"enabled":true}],"override":[{"conditions":[],"actions":["dont_notify"],"rule_id":".m.rule.master","default":true,"enabled":false},{"conditions":[{"kind":"event_match","key":"content.msgtype","pattern":"m.notice"}],"actions":["dont_notify"],"rule_id":".m.rule.suppress_notices","default":true,"enabled":true},{"conditions":[{"kind":"event_match","key":"type","pattern":"m.room.member"},{"kind":"event_match","key":"content.membership","pattern":"invite"},{"kind":"event_match","key":"state_key","pattern":"@056d6976-fb61-47cf-86f0-147387461565:c3d35860-36fe-45d1-8e16-936cf50513fb.gedisa-staging.famedly.de"}],"actions":["notify",{"set_tweak":"sound","value":"default"},{"set_tweak":"highlight","value":false}],"rule_id":".m.rule.invite_for_me","default":true,"enabled":true},{"conditions":[{"kind":"event_match","key":"type","pattern":"m.room.member"}],"actions":["dont_notify"],"rule_id":".m.rule.member_event","default":true,"enabled":true},{"conditions":[{"kind":"contains_display_name"}],"actions":["notify",{"set_tweak":"sound","value":"default"},{"set_tweak":"highlight"}],"rule_id":".m.rule.contains_display_name","default":true,"enabled":true},{"conditions":[{"kind":"event_match","key":"content.body","pattern":"@room"},{"kind":"sender_notification_permission","key":"room"}],"actions":["notify",{"set_tweak":"highlight","value":true}],"rule_id":".m.rule.roomnotif","default":true,"enabled":true},{"conditions":[{"kind":"event_match","key":"type","pattern":"m.room.tombstone"},{"kind":"event_match","key":"state_key","pattern":""}],"actions":["notify",{"set_tweak":"highlight","value":true}],"rule_id":".m.rule.tombstone","default":true,"enabled":true},{"conditions":[{"kind":"event_match","key":"type","pattern":"m.reaction"}],"actions":["dont_notify"],"rule_id":".m.rule.reaction","default":true,"enabled":true}]},"device":{}}}]},"presence":{"events":[{"type":"m.presence","sender":"@056d6976-fb61-47cf-86f0-147387461565:c3d35860-36fe-45d1-8e16-936cf50513fb.gedisa-staging.famedly.de","content":{"presence":"online","last_active_ago":43,"currently_active":true}}]},"device_one_time_keys_count":{"signed_curve25519":66},"org.matrix.msc2732.device_unused_fallback_key_types":["signed_curve25519"],"device_unused_fallback_key_types":["signed_curve25519"],"rooms":{"join":{"!MEgZosbiZqjSjbHFqI:c3d35860-36fe-45d1-8e16-936cf50513fb.gedisa-staging.famedly.de":{"timeline":{"events":[{"type":"m.room.member","sender":"@8640f1e6-a824-4f9c-9924-2d8fc40bc030:c3d35860-36fe-45d1-8e16-936cf50513fb.gedisa-staging.famedly.de","content":{"membership":"join","displayname":"Lars Kaiser"},"state_key":"@8640f1e6-a824-4f9c-9924-2d8fc40bc030:c3d35860-36fe-45d1-8e16-936cf50513fb.gedisa-staging.famedly.de","origin_server_ts":1647296944593,"unsigned":{"age":545455},"event_id":"\$mk9kFUEAKBZJgarWApLyYqOZQQocLIVV8tWp_gJEZFU"},{"type":"m.room.power_levels","sender":"@8640f1e6-a824-4f9c-9924-2d8fc40bc030:c3d35860-36fe-45d1-8e16-936cf50513fb.gedisa-staging.famedly.de","content":{"users":{"@8640f1e6-a824-4f9c-9924-2d8fc40bc030:c3d35860-36fe-45d1-8e16-936cf50513fb.gedisa-staging.famedly.de":100},"users_default":0,"events":{"m.room.name":50,"m.room.power_levels":100,"m.room.history_visibility":100,"m.room.canonical_alias":50,"m.room.avatar":50,"m.room.tombstone":100,"m.room.server_acl":100,"m.room.encryption":100},"events_default":0,"state_default":50,"ban":50,"kick":50,"redact":50,"invite":50,"historical":100},"state_key":"","origin_server_ts":1647296944690,"unsigned":{"age":545358},"event_id":"\$3wL2YgVNQzgfl8y_ksi3BPMqRs94jb_m0WRonL1HNpY"},{"type":"m.room.canonical_alias","sender":"@8640f1e6-a824-4f9c-9924-2d8fc40bc030:c3d35860-36fe-45d1-8e16-936cf50513fb.gedisa-staging.famedly.de","content":{"alias":"#user-discovery:c3d35860-36fe-45d1-8e16-936cf50513fb.gedisa-staging.famedly.de"},"state_key":"","origin_server_ts":1647296944806,"unsigned":{"age":545242},"event_id":"\$yXaVETL9F4jSN9rpRNyT_kUoctzD07n5Z4AIHziP7DQ"},{"type":"m.room.join_rules","sender":"@8640f1e6-a824-4f9c-9924-2d8fc40bc030:c3d35860-36fe-45d1-8e16-936cf50513fb.gedisa-staging.famedly.de","content":{"join_rule":"public"},"state_key":"","origin_server_ts":1647296944894,"unsigned":{"age":545154},"event_id":"\$jBDHhgpNqr125eWUsGVw4r7ZG2hgr0BTzzR77S-ubvY"},{"type":"m.room.history_visibility","sender":"@8640f1e6-a824-4f9c-9924-2d8fc40bc030:c3d35860-36fe-45d1-8e16-936cf50513fb.gedisa-staging.famedly.de","content":{"history_visibility":"shared"},"state_key":"","origin_server_ts":1647296944965,"unsigned":{"age":545083},"event_id":"\$kMessP7gAphUKW7mzOLlJT6NT8IsVGPmGir3_1uBNCE"},{"type":"m.room.name","sender":"@8640f1e6-a824-4f9c-9924-2d8fc40bc030:c3d35860-36fe-45d1-8e16-936cf50513fb.gedisa-staging.famedly.de","content":{"name":"User Discovery"},"state_key":"","origin_server_ts":1647296945062,"unsigned":{"age":544986},"event_id":"\$Bo9Ut_0vcr3FuxCRye4IHEMxUxIIcSwc-ePnMzx-hYU"},{"type":"m.room.member","sender":"@test:fakeServer.notExisting","content":{"membership":"join","displayname":"1c2e5c2b-f958-45a5-9fcb-eef3969c31df"},"state_key":"@test:fakeServer.notExisting","origin_server_ts":1647296989893,"unsigned":{"age":500155},"event_id":"\$fYCf2qtlHwzcdLgwjHb2EOdStv3isAlIUy2Esh5qfVE"},{"type":"m.room.member","sender":"@test:fakeServer.notExisting","content":{"membership":"join","displayname":"Some First Name Some Last Name"},"state_key":"@test:fakeServer.notExisting","origin_server_ts":1647296990076,"unsigned":{"replaces_state":"\$fYCf2qtlHwzcdLgwjHb2EOdStv3isAlIUy2Esh5qfVE","prev_content":{"membership":"join","displayname":"1c2e5c2b-f958-45a5-9fcb-eef3969c31df"},"prev_sender":"@test:fakeServer.notExisting","age":499972},"event_id":"\$3Ut97nFBgOtsrnRPW-pqr28z7ETNMttj7GcjkIv4zWw"},{"type":"m.room.member","sender":"@056d6976-fb61-47cf-86f0-147387461565:c3d35860-36fe-45d1-8e16-936cf50513fb.gedisa-staging.famedly.de","content":{"membership":"join","displayname":"056d6976-fb61-47cf-86f0-147387461565"},"state_key":"@056d6976-fb61-47cf-86f0-147387461565:c3d35860-36fe-45d1-8e16-936cf50513fb.gedisa-staging.famedly.de","origin_server_ts":1647297489154,"unsigned":{"age":894},"event_id":"\$6EsjHSLQDVDW9WDH1c5Eu57VaPGZmOPtNRjCjtWPLV0"},{"type":"m.room.member","sender":"@056d6976-fb61-47cf-86f0-147387461565:c3d35860-36fe-45d1-8e16-936cf50513fb.gedisa-staging.famedly.de","content":{"membership":"join","displayname":"Another User"},"state_key":"@056d6976-fb61-47cf-86f0-147387461565:c3d35860-36fe-45d1-8e16-936cf50513fb.gedisa-staging.famedly.de","origin_server_ts":1647297489290,"unsigned":{"replaces_state":"\$6EsjHSLQDVDW9WDH1c5Eu57VaPGZmOPtNRjCjtWPLV0","prev_content":{"membership":"join","displayname":"056d6976-fb61-47cf-86f0-147387461565"},"prev_sender":"@056d6976-fb61-47cf-86f0-147387461565:c3d35860-36fe-45d1-8e16-936cf50513fb.gedisa-staging.famedly.de","age":758},"event_id":"\$dtQblqCbjr3TGc3WmrQ4YTkHaXJ2PcO0TAYDr9K7iQc"}],"prev_batch":"t2-62_571_2_6_39_1_2_34_1","limited":true},"state":{"events":[{"type":"m.room.create","sender":"@8640f1e6-a824-4f9c-9924-2d8fc40bc030:c3d35860-36fe-45d1-8e16-936cf50513fb.gedisa-staging.famedly.de","content":{"m.federate":false,"room_version":"9","creator":"@8640f1e6-a824-4f9c-9924-2d8fc40bc030:c3d35860-36fe-45d1-8e16-936cf50513fb.gedisa-staging.famedly.de"},"state_key":"","origin_server_ts":1647296944511,"unsigned":{"age":545537},"event_id":"\$PAWKKULBVOLnqfrAAtXZz8tHEPXXjgRVbJJLifwQWbE"}]},"account_data":{"events":[]},"ephemeral":{"events":[]},"unread_notifications":{"notification_count":0,"highlight_count":0},"summary":{"m.joined_member_count":3,"m.invited_member_count":0},"org.matrix.msc2654.unread_count":0}}}}')));
      final profile = await client.fetchOwnProfile();
      expect(profile.displayName, 'Some First Name Some Last Name');
      await client.dispose(closeDatabase: true);
    });
    test('sendToDeviceEncrypted', () async {
      FakeMatrixApi.calledEndpoints.clear();

      await matrix.sendToDeviceEncrypted(
          matrix.userDeviceKeys['@alice:example.com']!.deviceKeys.values
              .toList(),
          'm.message',
          {
            'msgtype': 'm.text',
            'body': 'Hello world',
          });
      expect(
          FakeMatrixApi.calledEndpoints.keys.any(
              (k) => k.startsWith('/client/v3/sendToDevice/m.room.encrypted')),
          true);
    });
    test('sendToDeviceEncryptedChunked', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await matrix.sendToDeviceEncryptedChunked(
          matrix.userDeviceKeys['@alice:example.com']!.deviceKeys.values
              .toList(),
          'm.message',
          {
            'msgtype': 'm.text',
            'body': 'Hello world',
          });
      await Future.delayed(Duration(milliseconds: 100));
      expect(
          FakeMatrixApi.calledEndpoints.keys
              .where((k) =>
                  k.startsWith('/client/v3/sendToDevice/m.room.encrypted'))
              .length,
          1);

      final deviceKeys = <DeviceKeys>[];
      for (var i = 0; i < 30; i++) {
        final account = olm.Account();
        account.create();
        final keys = json.decode(account.identity_keys());
        final userId = '@testuser:example.org';
        final deviceId = 'DEVICE$i';
        final keyObj = {
          'user_id': userId,
          'device_id': deviceId,
          'algorithms': [
            'm.olm.v1.curve25519-aes-sha2',
            'm.megolm.v1.aes-sha2',
          ],
          'keys': {
            'curve25519:$deviceId': keys['curve25519'],
            'ed25519:$deviceId': keys['ed25519'],
          },
        };
        final signature =
            account.sign(String.fromCharCodes(canonicalJson.encode(keyObj)));
        keyObj['signatures'] = {
          userId: {
            'ed25519:$deviceId': signature,
          },
        };
        account.free();
        deviceKeys.add(DeviceKeys.fromJson(keyObj, matrix));
      }
      FakeMatrixApi.calledEndpoints.clear();
      await matrix.sendToDeviceEncryptedChunked(deviceKeys, 'm.message', {
        'msgtype': 'm.text',
        'body': 'Hello world',
      });
      // it should send the first chunk right away
      expect(
          FakeMatrixApi.calledEndpoints.keys
              .where((k) =>
                  k.startsWith('/client/v3/sendToDevice/m.room.encrypted'))
              .length,
          1);
      await Future.delayed(Duration(milliseconds: 100));
      expect(
          FakeMatrixApi.calledEndpoints.keys
              .where((k) =>
                  k.startsWith('/client/v3/sendToDevice/m.room.encrypted'))
              .length,
          2);
    });
    test('send to_device queue', () async {
      // we test:
      // send fox --> fail
      // send raccoon --> fox & raccoon sent
      // send bunny --> only bunny sent
      final client = await getClient();
      FakeMatrixApi.failToDevice = true;
      final foxContent = {
        '@fox:example.org': {
          '*': {
            'fox': 'hole',
          },
        },
      };
      final raccoonContent = {
        '@fox:example.org': {
          '*': {
            'raccoon': 'mask',
          },
        },
      };
      final bunnyContent = {
        '@fox:example.org': {
          '*': {
            'bunny': 'burrow',
          },
        },
      };
      await client
          .sendToDevice('foxies', 'floof_txnid', foxContent)
          .catchError((e) => null); // ignore the error
      FakeMatrixApi.failToDevice = false;
      FakeMatrixApi.calledEndpoints.clear();
      await client.sendToDevice('raccoon', 'raccoon_txnid', raccoonContent);
      expect(
          json.decode(FakeMatrixApi
                  .calledEndpoints['/client/v3/sendToDevice/foxies/floof_txnid']
              ?[0])['messages'],
          foxContent);
      expect(
          json.decode(FakeMatrixApi.calledEndpoints[
              '/client/v3/sendToDevice/raccoon/raccoon_txnid']?[0])['messages'],
          raccoonContent);
      FakeMatrixApi.calledEndpoints.clear();
      await client.sendToDevice('bunny', 'bunny_txnid', bunnyContent);
      expect(
          FakeMatrixApi
              .calledEndpoints['/client/v3/sendToDevice/foxies/floof_txnid'],
          null);
      expect(
          FakeMatrixApi
              .calledEndpoints['/client/v3/sendToDevice/raccoon/raccoon_txnid'],
          null);
      expect(
          json.decode(FakeMatrixApi
                  .calledEndpoints['/client/v3/sendToDevice/bunny/bunny_txnid']
              ?[0])['messages'],
          bunnyContent);
      await client.dispose(closeDatabase: true);
    });
    test('send to_device queue multiple', () async {
      // we test:
      // send fox --> fail
      // send raccoon --> fail
      // send bunny --> all sent
      final client = await getClient();
      await client.abortSync();

      FakeMatrixApi.failToDevice = true;
      final foxContent = {
        '@fox:example.org': {
          '*': {
            'fox': 'hole',
          },
        },
      };
      final raccoonContent = {
        '@fox:example.org': {
          '*': {
            'raccoon': 'mask',
          },
        },
      };
      final bunnyContent = {
        '@fox:example.org': {
          '*': {
            'bunny': 'burrow',
          },
        },
      };
      await client
          .sendToDevice('foxies', 'floof_txnid', foxContent)
          .catchError((e) => null); // ignore the error

      await FakeMatrixApi.firstWhereValue(
          '/client/v3/sendToDevice/foxies/floof_txnid');
      FakeMatrixApi.calledEndpoints.clear();

      await client
          .sendToDevice('raccoon', 'raccoon_txnid', raccoonContent)
          .catchError((e) => null);

      await FakeMatrixApi.firstWhereValue(
          '/client/v3/sendToDevice/foxies/floof_txnid');

      FakeMatrixApi.calledEndpoints.clear();
      FakeMatrixApi.failToDevice = false;

      await client.sendToDevice('bunny', 'bunny_txnid', bunnyContent);

      await FakeMatrixApi.firstWhereValue(
          '/client/v3/sendToDevice/foxies/floof_txnid');
      await FakeMatrixApi.firstWhereValue(
          '/client/v3/sendToDevice/bunny/bunny_txnid');
      final foxcall = FakeMatrixApi
          .calledEndpoints['/client/v3/sendToDevice/foxies/floof_txnid']?[0];
      expect(foxcall != null, true);
      expect(json.decode(foxcall)['messages'], foxContent);

      final racooncall = FakeMatrixApi
          .calledEndpoints['/client/v3/sendToDevice/raccoon/raccoon_txnid']?[0];
      expect(racooncall != null, true);
      expect(json.decode(racooncall)['messages'], raccoonContent);

      final bunnycall = FakeMatrixApi
          .calledEndpoints['/client/v3/sendToDevice/bunny/bunny_txnid']?[0];
      expect(bunnycall != null, true);
      expect(json.decode(bunnycall)['messages'], bunnyContent);

      await client.dispose(closeDatabase: true);
    });
    test('startDirectChat', () async {
      await matrix.startDirectChat('@alice:example.com', waitForSync: false);
    });

    test('createGroupChat', () async {
      await matrix.createGroupChat(groupName: 'Testgroup', waitForSync: false);

      expect(
        json.decode(
            FakeMatrixApi.calledEndpoints['/client/v3/createRoom']?.last),
        {
          'initial_state': [
            {
              'content': {'algorithm': 'm.megolm.v1.aes-sha2'},
              'type': 'm.room.encryption'
            }
          ],
          'name': 'Testgroup',
          'preset': 'private_chat'
        },
      );

      await matrix.createGroupChat(
          groupName: 'Testgroup',
          waitForSync: false,
          groupCall: true,
          powerLevelContentOverride: {'events_default': 12});

      expect(
        json.decode(
            FakeMatrixApi.calledEndpoints['/client/v3/createRoom']?.last),
        {
          'initial_state': [
            {
              'content': {'algorithm': 'm.megolm.v1.aes-sha2'},
              'type': 'm.room.encryption'
            }
          ],
          'name': 'Testgroup',
          'power_level_content_override': {
            'events_default': 12,
            'events': {'com.famedly.call.member': 12}
          },
          'preset': 'private_chat'
        },
      );

      await matrix.createGroupChat(
          groupName: 'Testgroup',
          waitForSync: false,
          groupCall: true,
          powerLevelContentOverride: {
            'events_default': 12,
            'events': {'com.famedly.call.member': 14}
          });

      expect(
        json.decode(
            FakeMatrixApi.calledEndpoints['/client/v3/createRoom']?.last),
        {
          'initial_state': [
            {
              'content': {'algorithm': 'm.megolm.v1.aes-sha2'},
              'type': 'm.room.encryption'
            }
          ],
          'name': 'Testgroup',
          'power_level_content_override': {
            'events_default': 12,
            'events': {'com.famedly.call.member': 14}
          },
          'preset': 'private_chat'
        },
      );

      await matrix.createGroupChat(
        groupName: 'Testgroup',
        waitForSync: false,
        groupCall: true,
      );

      expect(
        json.decode(
            FakeMatrixApi.calledEndpoints['/client/v3/createRoom']?.last),
        {
          'initial_state': [
            {
              'content': {'algorithm': 'm.megolm.v1.aes-sha2'},
              'type': 'm.room.encryption'
            }
          ],
          'name': 'Testgroup',
          'power_level_content_override': {
            'events': {'com.famedly.call.member': 0}
          },
          'preset': 'private_chat'
        },
      );
    });
    test('Test the fake store api', () async {
      final database = await getDatabase(null);
      final client1 = Client(
        'testclient',
        httpClient: FakeMatrixApi(),
        databaseBuilder: (_) => database,
      );

      await client1.init(
        newToken: 'abc123',
        newUserID: '@test:fakeServer.notExisting',
        newHomeserver: Uri.parse('https://fakeServer.notExisting'),
        newDeviceName: 'Text Matrix Client',
        newDeviceID: 'GHTYAJCE',
        newOlmAccount: pickledOlmAccount,
      );

      await Future.delayed(Duration(milliseconds: 500));

      expect(client1.isLogged(), true);
      expect(client1.rooms.length, 3);

      final client2 = Client(
        'testclient',
        httpClient: FakeMatrixApi(),
        databaseBuilder: (_) => database,
      );

      await client2.init();
      await Future.delayed(Duration(milliseconds: 500));

      expect(client2.isLogged(), true);
      expect(client2.accessToken, client1.accessToken);
      expect(client2.userID, client1.userID);
      expect(client2.homeserver, client1.homeserver);
      expect(client2.deviceID, client1.deviceID);
      expect(client2.deviceName, client1.deviceName);
      expect(client2.rooms.length, 3);
      if (client2.encryptionEnabled) {
        expect(client2.encryption?.fingerprintKey,
            client1.encryption?.fingerprintKey);
        expect(
            client2.encryption?.identityKey, client1.encryption?.identityKey);
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
      await matrix.ignoreUser('@charley2:stupid.abc');
      await matrix.unignoreUser('@charley:stupid.abc');
    });
    test('upload', () async {
      final client = await getClient();
      final response =
          await client.uploadContent(Uint8List(0), filename: 'file.jpeg');
      expect(response.toString(), 'mxc://example.com/AQwafuaFswefuhsfAFAgsw');
      expect(await client.database?.getFile(response) != null,
          client.database?.supportsFileStoring);
      await client.dispose(closeDatabase: true);
    });

    test('refreshAccessToken', () async {
      final client = await getClient();
      expect(client.accessToken, 'abcd');
      await client.refreshAccessToken();
      expect(client.accessToken, 'a_new_token');
    });

    test('handleSoftLogout', () async {
      final client = await getClient();
      expect(client.accessToken, 'abcd');
      var softLoggedOut = 0;
      client.onSoftLogout = (client) {
        softLoggedOut++;
        return client.refreshAccessToken();
      };
      FakeMatrixApi.expectedAccessToken = 'a_new_token';
      await client.oneShotSync();
      await client.oneShotSync();
      FakeMatrixApi.expectedAccessToken = null;
      expect(client.accessToken, 'a_new_token');
      expect(softLoggedOut, 1);
      final storedClient = await client.database?.getClient(client.clientName);
      expect(storedClient?.tryGet<String>('token'), 'a_new_token');
      expect(
        storedClient?.tryGet<String>('refresh_token'),
        'another_new_token',
      );
    });

    test('object equality', () async {
      final time1 = DateTime.fromMillisecondsSinceEpoch(1);
      final time2 = DateTime.fromMillisecondsSinceEpoch(0);
      final user1 =
          User('@user1:example.org', room: Room(id: '!room1', client: matrix));
      final user2 =
          User('@user2:example.org', room: Room(id: '!room1', client: matrix));
      // receipts
      expect(Receipt(user1, time1) == Receipt(user1, time1), true);
      expect(Receipt(user1, time1) == Receipt(user1, time2), false);
      expect(Receipt(user1, time1) == Receipt(user2, time1), false);
      // ignore: unrelated_type_equality_checks
      expect(Receipt(user1, time1) == 'beep', false);
      // users
      expect(user1 == user1, true);
      expect(user1 == user2, false);
      expect(
          user1 ==
              User('@user1:example.org',
                  room: Room(id: '!room2', client: matrix)),
          false);
      expect(
          user1 ==
              User('@user1:example.org',
                  room: Room(id: '!room1', client: matrix),
                  membership: 'leave'),
          false);
      // ignore: unrelated_type_equality_checks
      expect(user1 == 'beep', false);
      // rooms
      expect(
          Room(id: '!room1', client: matrix) ==
              Room(id: '!room1', client: matrix),
          true);
      expect(
          Room(id: '!room1', client: matrix) ==
              Room(id: '!room2', client: matrix),
          false);
      // ignore: unrelated_type_equality_checks
      expect(Room(id: '!room1', client: matrix) == 'beep', false);
    });

    test('clearCache', () async {
      final client = await getClient();
      client.backgroundSync = true;
      await client.clearCache();
    });

    test('dispose', () async {
      await matrix.dispose(closeDatabase: true);
    });

    test('Database Migration', () async {
      final database = await getDatabase(null);
      final moorClient = Client(
        'testclient',
        httpClient: FakeMatrixApi(),
        databaseBuilder: (_) => database,
      );
      FakeMatrixApi.client = moorClient;
      await moorClient.checkHomeserver(
          Uri.parse('https://fakeServer.notExisting'),
          checkWellKnown: false);
      await moorClient.init(
        newToken: 'abcd',
        newUserID: '@test:fakeServer.notExisting',
        newHomeserver: moorClient.homeserver,
        newDeviceName: 'Text Matrix Client',
        newDeviceID: 'GHTYAJCE',
        newOlmAccount: pickledOlmAccount,
      );
      await Future.delayed(Duration(milliseconds: 200));
      await moorClient.dispose(closeDatabase: false);

      final hiveClient = Client(
        'testclient',
        httpClient: FakeMatrixApi(),
        databaseBuilder: getDatabase,
        legacyDatabaseBuilder: (_) => database,
      );
      await hiveClient.init();
      await Future.delayed(Duration(milliseconds: 200));
      expect(hiveClient.isLogged(), true);
    });

    test('getEventByPushNotification', () async {
      final client = Client(
        'testclient',
        httpClient: FakeMatrixApi(),
        databaseBuilder: getDatabase,
      )
        ..accessToken = '1234'
        ..baseUri = Uri.parse('https://fakeserver.notexisting');
      Event? event;
      event = await client
          .getEventByPushNotification(PushNotification(devices: []));
      expect(event, null);

      event = await client.getEventByPushNotification(
        PushNotification(
          devices: [],
          eventId: '123',
          roomId: '!localpart2:server.abc',
          content: {
            'msgtype': 'm.text',
            'body': 'Hello world',
          },
          roomAlias: '#testalias:blaaa',
          roomName: 'TestRoomName',
          sender: '@alicyy:example.com',
          senderDisplayName: 'AlicE',
          type: 'm.room.message',
        ),
      );
      expect(event?.eventId, '123');
      expect(event?.body, 'Hello world');
      expect(event?.senderId, '@alicyy:example.com');
      expect(event?.senderFromMemoryOrFallback.calcDisplayname(), 'AlicE');
      expect(event?.type, 'm.room.message');
      expect(event?.messageType, 'm.text');
      expect(event?.room.id, '!localpart2:server.abc');
      expect(event?.room.name, 'TestRoomName');
      expect(event?.room.canonicalAlias, '#testalias:blaaa');
      final storedEvent =
          await client.database?.getEventById('123', event!.room);
      expect(storedEvent?.eventId, event?.eventId);

      event = await client.getEventByPushNotification(
        PushNotification(
          devices: [],
          eventId: '1234',
          roomId: '!localpart:server.abc',
        ),
      );
      expect(event?.eventId, '143273582443PhrSn:example.org');
      expect(event?.room.id, '!localpart:server.abc');
      expect(event?.body, 'This is an example text message');
      expect(event?.messageType, 'm.text');
      expect(event?.type, 'm.room.message');
      final storedEvent2 = await client.database
          ?.getEventById('143273582443PhrSn:example.org', event!.room);
      expect(storedEvent2?.eventId, event?.eventId);
    });

    test('Rooms and archived rooms getter', () async {
      final client = await getClient();
      await Future.delayed(Duration(milliseconds: 50));

      expect(client.rooms.length, 3,
          reason:
              'Count of invited+joined before loadArchive() rooms does not match');
      expect(client.archivedRooms.length, 0,
          reason:
              'Count of archived rooms before loadArchive() does not match');

      await client.loadArchive();

      expect(client.rooms.length, 3,
          reason: 'Count of invited+joined rooms does not match');
      expect(client.archivedRooms.length, 2,
          reason: 'Count of archived rooms does not match');

      expect(
          client.archivedRooms.firstWhereOrNull(
                  (r) => r.room.id == '!5345234234:example.com') !=
              null,
          true,
          reason: '!5345234234:example.com not found as archived room');
      expect(
          client.archivedRooms.firstWhereOrNull(
                  (r) => r.room.id == '!5345234235:example.com') !=
              null,
          true,
          reason: '!5345234235:example.com not found as archived room');
    });

    test(
      'Client Init Exception',
      () async {
        final customClient = Client(
          'failclient',
          databaseBuilder: getMatrixSdkDatabase,
        );
        try {
          await customClient.init(
            newToken: 'testtoken',
            newDeviceID: 'testdeviceid',
            newDeviceName: 'testdevicename',
            newHomeserver: Uri.parse('https://test.server'),
            newOlmAccount: 'abcd',
            newUserID: '@user:server',
          );
          throw Exception('No exception?');
        } on ClientInitException catch (error) {
          expect(error.accessToken, 'testtoken');
          expect(error.deviceId, 'testdeviceid');
          expect(error.deviceName, 'testdevicename');
          expect(error.homeserver, Uri.parse('https://test.server'));
          expect(error.olmAccount, 'abcd');
          expect(error.userId, '@user:server');
          expect(error.toString(), 'Exception: BAD_ACCOUNT_KEY');
        }
      },
    );

    tearDown(() async {
      await matrix.dispose(closeDatabase: true);
    });
  });
}
