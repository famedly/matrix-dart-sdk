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

import 'package:famedlysdk/src/Client.dart';
import 'package:famedlysdk/src/Connection.dart';
import 'package:famedlysdk/src/User.dart';
import 'package:famedlysdk/src/requests/SetPushersRequest.dart';
import 'package:famedlysdk/src/responses/ErrorResponse.dart';
import 'package:famedlysdk/src/responses/PushrulesResponse.dart';
import 'package:famedlysdk/src/sync/EventUpdate.dart';
import 'package:famedlysdk/src/sync/RoomUpdate.dart';
import 'package:famedlysdk/src/sync/UserUpdate.dart';
import 'package:flutter_test/flutter_test.dart';

import 'FakeMatrixApi.dart';

void main() {
  Client matrix;

  Future<List<RoomUpdate>> roomUpdateListFuture;
  Future<List<EventUpdate>> eventUpdateListFuture;
  Future<List<UserUpdate>> userUpdateListFuture;

  /// All Tests related to the Login
  group("FluffyMatrix", () {
    /// Check if all Elements get created

    final create = (WidgetTester tester) {
      matrix = Client("testclient", debug: true);
      matrix.connection.httpClient = FakeMatrixApi();

      roomUpdateListFuture = matrix.connection.onRoomUpdate.stream.toList();
      eventUpdateListFuture = matrix.connection.onEvent.stream.toList();
      userUpdateListFuture = matrix.connection.onUserEvent.stream.toList();
    };
    testWidgets('should get created', create);

    test('Login', () async {
      Future<ErrorResponse> errorFuture =
          matrix.connection.onError.stream.first;

      final bool checkResp1 =
          await matrix.checkServer("https://fakeserver.wrongaddress");
      final bool checkResp2 =
          await matrix.checkServer("https://fakeserver.notexisting");

      ErrorResponse checkError = await errorFuture;

      expect(checkResp1, false);
      expect(checkResp2, true);
      expect(checkError.errcode, "NO_RESPONSE");

      final resp = await matrix.connection
          .jsonRequest(type: HTTPType.POST, action: "/client/r0/login", data: {
        "type": "m.login.password",
        "user": "test",
        "password": "1234",
        "initial_device_display_name": "Fluffy Matrix Client"
      });
      expect(resp is ErrorResponse, false);

      Future<LoginState> loginStateFuture =
          matrix.connection.onLoginStateChanged.stream.first;
      Future<bool> firstSyncFuture = matrix.connection.onFirstSync.stream.first;
      Future<dynamic> syncFuture = matrix.connection.onSync.stream.first;

      matrix.connection.connect(
          newToken: resp["access_token"],
          newUserID: resp["user_id"],
          newHomeserver: matrix.homeserver,
          newDeviceName: "Text Matrix Client",
          newDeviceID: resp["device_id"],
          newMatrixVersions: matrix.matrixVersions,
          newLazyLoadMembers: matrix.lazyLoadMembers);

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

      expect(matrix.accountData.length, 2);
      expect(matrix.getDirectChatFromUserId("@bob:example.com"),
          "!abcdefgh:example.com");
      expect(matrix.directChats, matrix.accountData["m.direct"].content);
      expect(matrix.presences.length, 1);
      expect(matrix.roomList.rooms.length, 2);
      expect(matrix.roomList.rooms[1].canonicalAlias,
          "#famedlyContactDiscovery:${matrix.userID.split(":")[1]}");
      final List<User> contacts = await matrix.loadFamedlyContacts();
      expect(contacts.length, 1);
      expect(contacts[0].senderId, "@alice:example.com");
    });

    test('Try to get ErrorResponse', () async {
      final resp = await matrix.connection
          .jsonRequest(type: HTTPType.PUT, action: "/non/existing/path");
      expect(resp is ErrorResponse, true);
    });

    test('Logout', () async {
      final dynamic resp = await matrix.connection
          .jsonRequest(type: HTTPType.POST, action: "/client/r0/logout");
      expect(resp is ErrorResponse, false);

      Future<LoginState> loginStateFuture =
          matrix.connection.onLoginStateChanged.stream.first;

      matrix.connection.clear();

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
      matrix.connection.onRoomUpdate.close();

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

      expect(roomUpdateList[2].id == "!5345234234:example.com", true);
      expect(roomUpdateList[2].membership == Membership.leave, true);
      expect(roomUpdateList[2].prev_batch == "", true);
      expect(roomUpdateList[2].limitedTimeline == false, true);
      expect(roomUpdateList[2].notification_count == 0, true);
      expect(roomUpdateList[2].highlight_count == 0, true);
    });

    test('Event Update Test', () async {
      matrix.connection.onEvent.close();

      List<EventUpdate> eventUpdateList = await eventUpdateListFuture;

      expect(eventUpdateList.length, 7);

      expect(eventUpdateList[0].eventType == "m.room.member", true);
      expect(eventUpdateList[0].roomID == "!726s6s6q:example.com", true);
      expect(eventUpdateList[0].type == "state", true);

      expect(eventUpdateList[1].eventType == "m.room.member", true);
      expect(eventUpdateList[1].roomID == "!726s6s6q:example.com", true);
      expect(eventUpdateList[1].type == "timeline", true);

      expect(eventUpdateList[2].eventType == "m.room.message", true);
      expect(eventUpdateList[2].roomID == "!726s6s6q:example.com", true);
      expect(eventUpdateList[2].type == "timeline", true);

      expect(eventUpdateList[3].eventType == "m.tag", true);
      expect(eventUpdateList[3].roomID == "!726s6s6q:example.com", true);
      expect(eventUpdateList[3].type == "account_data", true);

      expect(eventUpdateList[4].eventType == "org.example.custom.room.config",
          true);
      expect(eventUpdateList[4].roomID == "!726s6s6q:example.com", true);
      expect(eventUpdateList[4].type == "account_data", true);

      expect(eventUpdateList[5].eventType == "m.room.name", true);
      expect(eventUpdateList[5].roomID == "!696r7674:example.com", true);
      expect(eventUpdateList[5].type == "invite_state", true);

      expect(eventUpdateList[6].eventType == "m.room.member", true);
      expect(eventUpdateList[6].roomID == "!696r7674:example.com", true);
      expect(eventUpdateList[6].type == "invite_state", true);
    });

    test('User Update Test', () async {
      matrix.connection.onUserEvent.close();

      List<UserUpdate> eventUpdateList = await userUpdateListFuture;

      expect(eventUpdateList.length, 4);

      expect(eventUpdateList[0].eventType == "m.presence", true);
      expect(eventUpdateList[0].type == "presence", true);

      expect(eventUpdateList[1].eventType == "org.example.custom.config", true);
      expect(eventUpdateList[1].type == "account_data", true);
    });

    testWidgets('should get created', create);

    test('Login', () async {
      final bool checkResp =
          await matrix.checkServer("https://fakeServer.notExisting");

      final bool loginResp = await matrix.login("test", "1234");

      expect(checkResp, true);
      expect(loginResp, true);
    });

    test('createGroup', () async {
      final List<User> users = [
        User("@alice:fakeServer.notExisting"),
        User("@bob:fakeServer.notExisting")
      ];
      final String newID = await matrix.createGroup(users);
      expect(newID, "!1234:fakeServer.notExisting");
    });

    test('getPushrules', () async {
      final PushrulesResponse pushrules = await matrix.getPushrules();
      final PushrulesResponse awaited_resp = PushrulesResponse.fromJson(
          FakeMatrixApi.api["GET"]["/client/r0/pushrules/"](""));
      expect(pushrules.toJson(), awaited_resp.toJson());
    });

    test('setPushers', () async {
      final SetPushersRequest data = SetPushersRequest(
          app_id: "com.famedly.famedlysdk",
          device_display_name: "GitLabCi",
          app_display_name: "famedlySDK",
          pushkey: "abcdefg",
          kind: "http",
          lang: "en",
          data: PusherData(
              format: "event_id_only", url: "https://examplepushserver.com"));
      final dynamic resp = await matrix.setPushers(data);
      expect(resp is ErrorResponse, false);
    });

    test('joinRoomById', () async {
      final String roomID = "1234";
      final Map<String, dynamic> resp = await matrix.joinRoomById(roomID);
      expect(resp["room_id"], roomID);
    });

    test('Logout when token is unknown', () async {
      Future<LoginState> loginStateFuture =
          matrix.connection.onLoginStateChanged.stream.first;
      await matrix.connection
          .jsonRequest(type: HTTPType.DELETE, action: "/unknown/token");

      LoginState state = await loginStateFuture;
      expect(state, LoginState.loggedOut);
      expect(matrix.isLogged(), false);
    });
  });
}
