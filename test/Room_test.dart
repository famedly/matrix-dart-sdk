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

import 'package:famedlysdk/src/Client.dart';
import 'package:famedlysdk/src/Event.dart';
import 'package:famedlysdk/src/Room.dart';
import 'package:famedlysdk/src/Timeline.dart';
import 'package:famedlysdk/src/User.dart';
import 'package:famedlysdk/src/utils/MatrixFile.dart';
import 'package:test/test.dart';

import 'FakeMatrixApi.dart';

void main() {
  Client matrix;
  Room room;

  /// All Tests related to the Event
  group("Room", () {
    test('Login', () async {
      matrix = Client("testclient", debug: true);
      matrix.httpClient = FakeMatrixApi();

      final bool checkResp =
          await matrix.checkServer("https://fakeServer.notExisting");

      final bool loginResp = await matrix.login("test", "1234");

      expect(checkResp, true);
      expect(loginResp, true);
    });

    test("Create from json", () async {
      final String id = "!localpart:server.abc";
      final Membership membership = Membership.join;
      final int notificationCount = 2;
      final int highlightCount = 1;
      final List<String> heroes = [
        "@alice:matrix.org",
        "@bob:example.com",
        "@charley:example.org"
      ];

      Map<String, dynamic> jsonObj = {
        "room_id": id,
        "membership": membership.toString().split('.').last,
        "avatar_url": "",
        "notification_count": notificationCount,
        "highlight_count": highlightCount,
        "prev_batch": "",
        "joined_member_count": notificationCount,
        "invited_member_count": notificationCount,
        "heroes": heroes.join(","),
      };

      Function states = () async => [
            {
              "content": {"join_rule": "public"},
              "event_id": "143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": id,
              "sender": "@example:example.org",
              "state_key": "",
              "type": "m.room.join_rules",
              "unsigned": {"age": 1234}
            }
          ];

      Function roomAccountData = () async => [
            {
              "content": {"foo": "bar"},
              "room_id": id,
              "type": "com.test.foo"
            }
          ];

      room = await Room.getRoomFromTableRow(
        jsonObj,
        matrix,
        states: states(),
        roomAccountData: roomAccountData(),
      );

      expect(room.id, id);
      expect(room.membership, membership);
      expect(room.notificationCount, notificationCount);
      expect(room.highlightCount, highlightCount);
      expect(room.mJoinedMemberCount, notificationCount);
      expect(room.mInvitedMemberCount, notificationCount);
      expect(room.mHeroes, heroes);
      expect(room.displayname, "alice, bob, charley");
      expect(room.getState("m.room.join_rules").content["join_rule"], "public");
      expect(room.roomAccountData["com.test.foo"].content["foo"], "bar");

      room.states["m.room.canonical_alias"] = Event(
          senderId: "@test:example.com",
          typeKey: "m.room.canonical_alias",
          roomId: room.id,
          room: room,
          eventId: "123",
          content: {"alias": "#testalias:example.com"},
          stateKey: "");
      expect(room.displayname, "testalias");
      expect(room.canonicalAlias, "#testalias:example.com");

      room.states["m.room.name"] = Event(
          senderId: "@test:example.com",
          typeKey: "m.room.name",
          roomId: room.id,
          room: room,
          eventId: "123",
          content: {"name": "testname"},
          stateKey: "");
      expect(room.displayname, "testname");

      expect(room.topic, "");
      room.states["m.room.topic"] = Event(
          senderId: "@test:example.com",
          typeKey: "m.room.topic",
          roomId: room.id,
          room: room,
          eventId: "123",
          content: {"topic": "testtopic"},
          stateKey: "");
      expect(room.topic, "testtopic");

      expect(room.avatar.mxc, "");
      room.states["m.room.avatar"] = Event(
          senderId: "@test:example.com",
          typeKey: "m.room.avatar",
          roomId: room.id,
          room: room,
          eventId: "123",
          content: {"url": "mxc://testurl"},
          stateKey: "");
      expect(room.avatar.mxc, "mxc://testurl");
      room.states["m.room.message"] = Event(
          senderId: "@test:example.com",
          typeKey: "m.room.message",
          roomId: room.id,
          room: room,
          eventId: "12345",
          time: DateTime.now(),
          content: {"msgtype": "m.text", "body": "test"},
          stateKey: "");
      expect(room.lastEvent.eventId, "12345");
      expect(room.lastMessage, "test");
      expect(room.timeCreated, room.lastEvent.time);
    });

    test("sendReadReceipt", () async {
      await room.sendReadReceipt("§1234:fakeServer.notExisting");
    });

    test("requestParticipants", () async {
      final List<User> participants = await room.requestParticipants();
      expect(participants.length, 1);
      User user = participants[0];
      expect(user.id, "@alice:example.org");
      expect(user.displayName, "Alice Margatroid");
      expect(user.membership, Membership.join);
      expect(user.avatarUrl.mxc, "mxc://example.org/SEsfnsuifSDFSSEF");
      expect(user.room.id, "!localpart:server.abc");
    });

    test("getEventByID", () async {
      final Event event = await room.getEventById("1234");
      expect(event.eventId, "143273582443PhrSn:example.org");
    });

    test("setName", () async {
      final String eventId = await room.setName("Testname");
      expect(eventId, "42");
    });

    test("setDescription", () async {
      final String eventId = await room.setDescription("Testname");
      expect(eventId, "42");
    });

    test("kick", () async {
      await room.kick("Testname");
    });

    test("ban", () async {
      await room.ban("Testname");
    });

    test("unban", () async {
      await room.unban("Testname");
    });

    test("PowerLevels", () async {
      room.states["m.room.power_levels"] = Event(
          senderId: "@test:example.com",
          typeKey: "m.room.power_levels",
          roomId: room.id,
          room: room,
          eventId: "123",
          content: {
            "ban": 50,
            "events": {"m.room.name": 100, "m.room.power_levels": 100},
            "events_default": 0,
            "invite": 50,
            "kick": 50,
            "notifications": {"room": 20},
            "redact": 50,
            "state_default": 50,
            "users": {"@test:fakeServer.notExisting": 100},
            "users_default": 10
          },
          stateKey: "");
      expect(room.ownPowerLevel, 100);
      expect(room.getPowerLevelByUserId(matrix.userID), room.ownPowerLevel);
      expect(room.getPowerLevelByUserId("@nouser:example.com"), 10);
      expect(room.ownPowerLevel, 100);
      expect(room.canBan, true);
      expect(room.canInvite, true);
      expect(room.canKick, true);
      expect(room.canRedact, true);
      expect(room.canSendDefaultMessages, true);
      expect(room.canSendDefaultStates, true);
      expect(room.canChangePowerLevel, true);
      expect(room.canSendEvent("m.room.name"), true);
      expect(room.canSendEvent("m.room.power_levels"), true);
      expect(room.canSendEvent("m.room.member"), true);
      expect(room.powerLevels,
          room.states["m.room.power_levels"].content["users"]);

      room.states["m.room.power_levels"] = Event(
          senderId: "@test:example.com",
          typeKey: "m.room.power_levels",
          roomId: room.id,
          room: room,
          eventId: "123abc",
          content: {
            "ban": 50,
            "events": {"m.room.name": 0, "m.room.power_levels": 100},
            "events_default": 0,
            "invite": 50,
            "kick": 50,
            "notifications": {"room": 20},
            "redact": 50,
            "state_default": 50,
            "users": {},
            "users_default": 0
          },
          stateKey: "");
      expect(room.ownPowerLevel, 0);
      expect(room.canBan, false);
      expect(room.canInvite, false);
      expect(room.canKick, false);
      expect(room.canRedact, false);
      expect(room.canSendDefaultMessages, true);
      expect(room.canSendDefaultStates, false);
      expect(room.canChangePowerLevel, false);
      expect(room.canSendEvent("m.room.name"), true);
      expect(room.canSendEvent("m.room.power_levels"), false);
      expect(room.canSendEvent("m.room.member"), false);
      expect(room.canSendEvent("m.room.message"), true);
      final String resp =
          await room.setPower("@test:fakeServer.notExisting", 90);
      expect(resp, "42");
    });

    test("invite", () async {
      await room.invite("Testname");
    });

    test("getParticipants", () async {
      room.setState(Event(
          senderId: "@alice:test.abc",
          typeKey: "m.room.member",
          roomId: room.id,
          room: room,
          eventId: "12345",
          time: DateTime.now(),
          content: {"displayname": "alice"},
          stateKey: "@alice:test.abc"));
      final List<User> userList = room.getParticipants();
      expect(userList.length, 4);
      expect(userList[3].displayName, "alice");
    });

    test("addToDirectChat", () async {
      await room.addToDirectChat("Testname");
    });

    test("getTimeline", () async {
      final Timeline timeline = await room.getTimeline();
      expect(timeline.events, []);
    });

    test("getUserByMXID", () async {
      User user;
      try {
        user = await room.getUserByMXID("@getme:example.com");
      } catch (_) {}
      expect(user.stateKey, "@getme:example.com");
      expect(user.calcDisplayname(), "You got me");
    });

    test('setAvatar', () async {
      final MatrixFile testFile =
          MatrixFile(bytes: [], path: "fake/path/file.jpeg");
      final dynamic resp = await room.setAvatar(testFile);
      expect(resp, "YUwRidLecu:example.com");
    });

    test('sendEvent', () async {
      final dynamic resp = await room.sendEvent(
          {"msgtype": "m.text", "body": "hello world"},
          txid: "testtxid");
      expect(resp, "42");
    });

    test('sendEvent', () async {
      final dynamic resp =
          await room.sendTextEvent("Hello world", txid: "testtxid");
      expect(resp, "42");
    });

    // Not working because there is no real file to test it...
    /*test('sendImageEvent', () async {
      final File testFile = File.fromUri(Uri.parse("fake/path/file.jpeg"));
      final dynamic resp =
          await room.sendImageEvent(testFile, txid: "testtxid");
      expect(resp, "42");
    });*/

    test('sendFileEvent', () async {
      final MatrixFile testFile =
          MatrixFile(bytes: [], path: "fake/path/file.jpeg");
      final dynamic resp = await room.sendFileEvent(testFile,
          msgType: "m.file", txid: "testtxid");
      expect(resp, "42");
    });

    test('pushRuleState', () async {
      expect(room.pushRuleState, PushRuleState.mentions_only);
      matrix.accountData["m.push_rules"].content["global"]["override"]
          .add(matrix.accountData["m.push_rules"].content["global"]["room"][0]);
      expect(room.pushRuleState, PushRuleState.dont_notify);
    });
  });
}
