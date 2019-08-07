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

import 'dart:convert';

import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/src/RawEvent.dart';
import 'package:flutter_test/flutter_test.dart';

import 'FakeMatrixApi.dart';

void main() {
  /// All Tests related to the Event
  group("Event", () {
    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    final String id = "!4fsdfjisjf:server.abc";
    final String senderID = "@alice:server.abc";
    final String type = "m.room.message";
    final String msgtype = "m.text";
    final String body = "Hello World";
    final String formatted_body = "<b>Hello</b> World";

    final String contentJson =
        '{"msgtype":"$msgtype","body":"$body","formatted_body":"$formatted_body"}';

    Map<String, dynamic> jsonObj = {
      "event_id": id,
      "sender": senderID,
      "origin_server_ts": timestamp,
      "type": type,
      "status": 2,
      "content": contentJson,
    };

    test("Create from json", () async {
      Event event = Event.fromJson(jsonObj, null);

      expect(event.eventId, id);
      expect(event.senderId, senderID);
      expect(event.status, 2);
      expect(event.text, body);
      expect(event.formattedText, formatted_body);
      expect(event.getBody(), body);
      expect(event.type, EventTypes.Text);
    });
    test("Test all EventTypes", () async {
      Event event;

      jsonObj["type"] = "m.room.avatar";
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomAvatar);

      jsonObj["type"] = "m.room.name";
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomName);

      jsonObj["type"] = "m.room.topic";
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomTopic);

      jsonObj["type"] = "m.room.Aliases";
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomAliases);

      jsonObj["type"] = "m.room.canonical_alias";
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomCanonicalAlias);

      jsonObj["type"] = "m.room.create";
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomCreate);

      jsonObj["type"] = "m.room.join_rules";
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomJoinRules);

      jsonObj["type"] = "m.room.member";
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomMember);

      jsonObj["type"] = "m.room.power_levels";
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomPowerLevels);

      jsonObj["type"] = "m.room.guest_access";
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.GuestAccess);

      jsonObj["type"] = "m.room.history_visibility";
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.HistoryVisibility);

      jsonObj["type"] = "m.room.message";
      jsonObj["content"] = json.decode(jsonObj["content"]);

      jsonObj["content"]["msgtype"] = "m.notice";
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.Notice);

      jsonObj["content"]["msgtype"] = "m.emote";
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.Emote);

      jsonObj["content"]["msgtype"] = "m.image";
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.Image);

      jsonObj["content"]["msgtype"] = "m.video";
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.Video);

      jsonObj["content"]["msgtype"] = "m.audio";
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.Audio);

      jsonObj["content"]["msgtype"] = "m.file";
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.File);

      jsonObj["content"]["msgtype"] = "m.location";
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.Location);

      jsonObj["type"] = "m.room.message";
      jsonObj["content"]["msgtype"] = "m.text";
      jsonObj["content"]["m.relates_to"] = {};
      jsonObj["content"]["m.relates_to"]["m.in_reply_to"] = {
        "event_id": "1234",
      };
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.Reply);
    });

    test("remove", () async {
      Event event = Event.fromJson(
          jsonObj, Room(id: "1234", client: Client("testclient", debug: true)));
      final bool removed1 = await event.remove();
      event.status = 0;
      final bool removed2 = await event.remove();
      expect(removed1, false);
      expect(removed2, true);
    });

    test("sendAgain", () async {
      Client matrix = Client("testclient", debug: true);
      matrix.connection.httpClient = FakeMatrixApi();
      await matrix.checkServer("https://fakeServer.notExisting");
      await matrix.login("test", "1234");

      Event event = Event.fromJson(
          jsonObj, Room(id: "!1234:example.com", client: matrix));
      final String resp1 = await event.sendAgain();
      event.status = -1;
      final String resp2 = await event.sendAgain(txid: "1234");
      expect(resp1, null);
      expect(resp2, "42");
    });
  });
}
