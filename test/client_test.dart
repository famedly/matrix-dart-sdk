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

import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/src/account_data.dart';
import 'package:famedlysdk/src/client.dart';
import 'package:famedlysdk/src/presence.dart';
import 'package:famedlysdk/src/room.dart';
import 'package:famedlysdk/src/user.dart';
import 'package:famedlysdk/src/sync/event_update.dart';
import 'package:famedlysdk/src/sync/room_update.dart';
import 'package:famedlysdk/src/sync/user_update.dart';
import 'package:famedlysdk/src/utils/matrix_exception.dart';
import 'package:famedlysdk/src/utils/matrix_file.dart';
import 'package:famedlysdk/src/utils/profile.dart';
import 'package:test/test.dart';

import 'fake_matrix_api.dart';

void main() {
  Client matrix;

  Future<List<RoomUpdate>> roomUpdateListFuture;
  Future<List<EventUpdate>> eventUpdateListFuture;
  Future<List<UserUpdate>> userUpdateListFuture;

  /// All Tests related to the Login
  group("FluffyMatrix", () {
    /// Check if all Elements get created

    matrix = Client("testclient", debug: true);
    matrix.httpClient = FakeMatrixApi();

    roomUpdateListFuture = matrix.onRoomUpdate.stream.toList();
    eventUpdateListFuture = matrix.onEvent.stream.toList();
    userUpdateListFuture = matrix.onUserEvent.stream.toList();

    test('Login', () async {
      int presenceCounter = 0;
      int accountDataCounter = 0;
      matrix.onPresence.stream.listen((Presence data) {
        presenceCounter++;
      });
      matrix.onAccountData.stream.listen((AccountData data) {
        accountDataCounter++;
      });

      expect(matrix.homeserver, null);
      expect(matrix.matrixVersions, null);

      try {
        await matrix.checkServer("https://fakeserver.wrongaddress");
      } on FormatException catch (exception) {
        expect(exception != null, true);
      }
      await matrix.checkServer("https://fakeserver.notexisting");
      expect(matrix.homeserver, "https://fakeserver.notexisting");
      expect(matrix.matrixVersions,
          ["r0.0.1", "r0.1.0", "r0.2.0", "r0.3.0", "r0.4.0", "r0.5.0"]);

      final Map<String, dynamic> resp = await matrix
          .jsonRequest(type: HTTPType.POST, action: "/client/r0/login", data: {
        "type": "m.login.password",
        "user": "test",
        "password": "1234",
        "initial_device_display_name": "Fluffy Matrix Client"
      });

      final bool available = await matrix.usernameAvailable("testuser");
      expect(available, true);

      Map registerResponse = await matrix.register(username: "testuser");
      expect(registerResponse["user_id"], "@testuser:example.com");
      registerResponse =
          await matrix.register(username: "testuser", kind: "user");
      expect(registerResponse["user_id"], "@testuser:example.com");
      registerResponse =
          await matrix.register(username: "testuser", kind: "guest");
      expect(registerResponse["user_id"], "@testuser:example.com");

      Future<LoginState> loginStateFuture =
          matrix.onLoginStateChanged.stream.first;
      Future<bool> firstSyncFuture = matrix.onFirstSync.stream.first;
      Future<dynamic> syncFuture = matrix.onSync.stream.first;

      matrix.connect(
          newToken: resp["access_token"],
          newUserID: resp["user_id"],
          newHomeserver: matrix.homeserver,
          newDeviceName: "Text Matrix Client",
          newDeviceID: resp["device_id"],
          newMatrixVersions: matrix.matrixVersions,
          newLazyLoadMembers: matrix.lazyLoadMembers);
      await Future.delayed(Duration(milliseconds: 50));

      expect(matrix.accessToken == resp["access_token"], true);
      expect(matrix.deviceName == "Text Matrix Client", true);
      expect(matrix.deviceID == resp["device_id"], true);
      expect(matrix.userID == resp["user_id"], true);

      LoginState loginState = await loginStateFuture;
      bool firstSync = await firstSyncFuture;
      dynamic sync = await syncFuture;

      expect(loginState, LoginState.logged);
      expect(firstSync, true);
      expect(sync["next_batch"] == matrix.prevBatch, true);

      expect(matrix.accountData.length, 3);
      expect(matrix.getDirectChatFromUserId("@bob:example.com"),
          "!726s6s6q:example.com");
      expect(matrix.rooms[1].directChatMatrixID, "@bob:example.com");
      expect(matrix.directChats, matrix.accountData["m.direct"].content);
      expect(matrix.presences.length, 1);
      expect(matrix.rooms[1].ephemerals.length, 2);
      expect(matrix.rooms[1].typingUsers.length, 1);
      expect(matrix.rooms[1].typingUsers[0].id, "@alice:example.com");
      expect(matrix.rooms[1].roomAccountData.length, 3);
      expect(matrix.rooms[1].encrypted, true);
      expect(matrix.rooms[1].encryptionAlgorithm,
          Client.supportedGroupEncryptionAlgorithms.first);
      expect(
          matrix.rooms[1].roomAccountData["m.receipt"]
              .content["@alice:example.com"]["ts"],
          1436451550453);
      expect(
          matrix.rooms[1].roomAccountData["m.receipt"]
              .content["@alice:example.com"]["event_id"],
          "7365636s6r6432:example.com");
      expect(matrix.rooms.length, 2);
      expect(matrix.rooms[1].canonicalAlias,
          "#famedlyContactDiscovery:${matrix.userID.split(":")[1]}");
      final List<User> contacts = await matrix.loadFamedlyContacts();
      expect(contacts.length, 1);
      expect(contacts[0].senderId, "@alice:example.com");
      expect(
          matrix.presences["@alice:example.com"].presence, PresenceType.online);
      expect(presenceCounter, 1);
      expect(accountDataCounter, 3);
      await Future.delayed(Duration(milliseconds: 50));
      expect(matrix.userDeviceKeys.length, 2);
      expect(matrix.userDeviceKeys["@alice:example.com"].outdated, false);
      expect(matrix.userDeviceKeys["@alice:example.com"].deviceKeys.length, 1);
      expect(
          matrix.userDeviceKeys["@alice:example.com"].deviceKeys["JLAFKJWSCS"]
              .verified,
          false);

      matrix.handleSync({
        "device_lists": {
          "changed": [
            "@alice:example.com",
          ],
          "left": [
            "@bob:example.com",
          ],
        }
      });
      await Future.delayed(Duration(milliseconds: 50));
      expect(matrix.userDeviceKeys.length, 2);
      expect(matrix.userDeviceKeys["@alice:example.com"].outdated, true);

      matrix.handleSync({
        "rooms": {
          "join": {
            "!726s6s6q:example.com": {
              "state": {
                "events": [
                  {
                    "sender": "@alice:example.com",
                    "type": "m.room.canonical_alias",
                    "content": {"alias": ""},
                    "state_key": "",
                    "origin_server_ts": 1417731086799,
                    "event_id": "66697273743033:example.com"
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
      final List<User> altContacts = await matrix.loadFamedlyContacts();
      altContacts.forEach((u) => print(u.id));
      expect(altContacts.length, 2);
      expect(altContacts[0].senderId, "@alice:example.com");
    });

    test('Try to get ErrorResponse', () async {
      MatrixException expectedException;
      try {
        await matrix.jsonRequest(
            type: HTTPType.PUT, action: "/non/existing/path");
      } on MatrixException catch (exception) {
        expectedException = exception;
      }
      expect(expectedException.error, MatrixError.M_UNRECOGNIZED);
    });

    test('Logout', () async {
      await matrix.jsonRequest(
          type: HTTPType.POST, action: "/client/r0/logout");

      Future<LoginState> loginStateFuture =
          matrix.onLoginStateChanged.stream.first;

      matrix.clear();

      expect(matrix.accessToken == null, true);
      expect(matrix.homeserver == null, true);
      expect(matrix.userID == null, true);
      expect(matrix.deviceID == null, true);
      expect(matrix.deviceName == null, true);
      expect(matrix.matrixVersions == null, true);
      expect(matrix.lazyLoadMembers == null, true);
      expect(matrix.prevBatch == null, true);

      LoginState loginState = await loginStateFuture;
      expect(loginState, LoginState.loggedOut);
    });

    test('Room Update Test', () async {
      await matrix.onRoomUpdate.close();

      List<RoomUpdate> roomUpdateList = await roomUpdateListFuture;

      expect(roomUpdateList.length, 3);

      expect(roomUpdateList[0].id == "!726s6s6q:example.com", true);
      expect(roomUpdateList[0].membership == Membership.join, true);
      expect(roomUpdateList[0].prev_batch == "t34-23535_0_0", true);
      expect(roomUpdateList[0].limitedTimeline == true, true);
      expect(roomUpdateList[0].notification_count == 2, true);
      expect(roomUpdateList[0].highlight_count == 2, true);

      expect(roomUpdateList[1].id == "!696r7674:example.com", true);
      expect(roomUpdateList[1].membership == Membership.invite, true);
      expect(roomUpdateList[1].prev_batch == "", true);
      expect(roomUpdateList[1].limitedTimeline == false, true);
      expect(roomUpdateList[1].notification_count == 0, true);
      expect(roomUpdateList[1].highlight_count == 0, true);
    });

    test('Event Update Test', () async {
      await matrix.onEvent.close();

      List<EventUpdate> eventUpdateList = await eventUpdateListFuture;

      expect(eventUpdateList.length, 13);

      expect(eventUpdateList[0].eventType, "m.room.member");
      expect(eventUpdateList[0].roomID, "!726s6s6q:example.com");
      expect(eventUpdateList[0].type, "state");

      expect(eventUpdateList[1].eventType, "m.room.canonical_alias");
      expect(eventUpdateList[1].roomID, "!726s6s6q:example.com");
      expect(eventUpdateList[1].type, "state");

      expect(eventUpdateList[2].eventType, "m.room.encryption");
      expect(eventUpdateList[2].roomID, "!726s6s6q:example.com");
      expect(eventUpdateList[2].type, "state");

      expect(eventUpdateList[3].eventType, "m.room.member");
      expect(eventUpdateList[3].roomID, "!726s6s6q:example.com");
      expect(eventUpdateList[3].type, "timeline");

      expect(eventUpdateList[4].eventType, "m.room.message");
      expect(eventUpdateList[4].roomID, "!726s6s6q:example.com");
      expect(eventUpdateList[4].type, "timeline");

      expect(eventUpdateList[5].eventType, "m.typing");
      expect(eventUpdateList[5].roomID, "!726s6s6q:example.com");
      expect(eventUpdateList[5].type, "ephemeral");

      expect(eventUpdateList[6].eventType, "m.receipt");
      expect(eventUpdateList[6].roomID, "!726s6s6q:example.com");
      expect(eventUpdateList[6].type, "ephemeral");

      expect(eventUpdateList[7].eventType, "m.receipt");
      expect(eventUpdateList[7].roomID, "!726s6s6q:example.com");
      expect(eventUpdateList[7].type, "account_data");

      expect(eventUpdateList[8].eventType, "m.tag");
      expect(eventUpdateList[8].roomID, "!726s6s6q:example.com");
      expect(eventUpdateList[8].type, "account_data");

      expect(eventUpdateList[9].eventType, "org.example.custom.room.config");
      expect(eventUpdateList[9].roomID, "!726s6s6q:example.com");
      expect(eventUpdateList[9].type, "account_data");

      expect(eventUpdateList[10].eventType, "m.room.name");
      expect(eventUpdateList[10].roomID, "!696r7674:example.com");
      expect(eventUpdateList[10].type, "invite_state");

      expect(eventUpdateList[11].eventType, "m.room.member");
      expect(eventUpdateList[11].roomID, "!696r7674:example.com");
      expect(eventUpdateList[11].type, "invite_state");
    });

    test('User Update Test', () async {
      await matrix.onUserEvent.close();

      List<UserUpdate> eventUpdateList = await userUpdateListFuture;

      expect(eventUpdateList.length, 5);

      expect(eventUpdateList[0].eventType, "m.presence");
      expect(eventUpdateList[0].type, "presence");

      expect(eventUpdateList[1].eventType, "m.push_rules");
      expect(eventUpdateList[1].type, "account_data");

      expect(eventUpdateList[2].eventType, "org.example.custom.config");
      expect(eventUpdateList[2].type, "account_data");
    });

    test('Login', () async {
      matrix = Client("testclient", debug: true);
      matrix.httpClient = FakeMatrixApi();

      roomUpdateListFuture = matrix.onRoomUpdate.stream.toList();
      eventUpdateListFuture = matrix.onEvent.stream.toList();
      userUpdateListFuture = matrix.onUserEvent.stream.toList();
      final bool checkResp =
          await matrix.checkServer("https://fakeServer.notExisting");

      final bool loginResp = await matrix.login("test", "1234");

      expect(checkResp, true);
      expect(loginResp, true);
    });

    test('createRoom', () async {
      final OpenIdCredentials openId = await matrix.requestOpenIdCredentials();
      expect(openId.accessToken, "SomeT0kenHere");
      expect(openId.tokenType, "Bearer");
      expect(openId.matrixServerName, "example.com");
      expect(openId.expiresIn, 3600);
    });

    test('createRoom', () async {
      final List<User> users = [
        User("@alice:fakeServer.notExisting"),
        User("@bob:fakeServer.notExisting")
      ];
      final String newID = await matrix.createRoom(invite: users);
      expect(newID, "!1234:fakeServer.notExisting");
    });

    test('setAvatar', () async {
      final MatrixFile testFile =
          MatrixFile(bytes: [], path: "fake/path/file.jpeg");
      await matrix.setAvatar(testFile);
    });

    test('setPushers', () async {
      await matrix.setPushers("abcdefg", "http", "com.famedly.famedlysdk",
          "famedlySDK", "GitLabCi", "en", "https://examplepushserver.com",
          format: "event_id_only");
    });

    test('joinRoomById', () async {
      final String roomID = "1234";
      final Map<String, dynamic> resp = await matrix.joinRoomById(roomID);
      expect(resp["room_id"], roomID);
    });

    test('get archive', () async {
      List<Room> archive = await matrix.archive;

      await Future.delayed(Duration(milliseconds: 50));
      expect(archive.length, 2);
      expect(archive[0].id, "!5345234234:example.com");
      expect(archive[0].membership, Membership.leave);
      expect(archive[0].name, "The room name");
      expect(archive[0].lastMessage, "This is an example text message");
      expect(archive[0].roomAccountData.length, 1);
      expect(archive[1].id, "!5345234235:example.com");
      expect(archive[1].membership, Membership.leave);
      expect(archive[1].name, "The room name 2");
    });

    test('getProfileFromUserId', () async {
      final Profile profile =
          await matrix.getProfileFromUserId("@getme:example.com");
      expect(profile.avatarUrl.mxc, "mxc://test");
      expect(profile.displayname, "You got me");
      expect(profile.content["avatar_url"], profile.avatarUrl.mxc);
      expect(profile.content["displayname"], profile.displayname);
    });

    test('Logout when token is unknown', () async {
      Future<LoginState> loginStateFuture =
          matrix.onLoginStateChanged.stream.first;

      try {
        await matrix.jsonRequest(
            type: HTTPType.DELETE, action: "/unknown/token");
      } on MatrixException catch (exception) {
        expect(exception.error, MatrixError.M_UNKNOWN_TOKEN);
      }

      LoginState state = await loginStateFuture;
      expect(state, LoginState.loggedOut);
      expect(matrix.isLogged(), false);
    });
  });
}
