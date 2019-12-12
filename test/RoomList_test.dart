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
import 'package:famedlysdk/src/RoomList.dart';
import 'package:famedlysdk/src/User.dart';
import 'package:famedlysdk/src/sync/EventUpdate.dart';
import 'package:famedlysdk/src/sync/RoomUpdate.dart';
import 'package:famedlysdk/src/utils/ChatTime.dart';
import 'package:test/test.dart';

void main() {
  /// All Tests related to the MxContent
  group("RoomList", () {
    final roomID = "!1:example.com";

    test("Create and insert one room", () async {
      final Client client = Client("testclient");
      client.homeserver = "https://testserver.abc";
      client.prevBatch = "1234";

      int updateCount = 0;
      List<int> insertList = [];
      List<int> removeList = [];

      RoomList roomList = RoomList(
          client: client,
          rooms: [],
          onUpdate: () {
            updateCount++;
          },
          onInsert: (int insertID) {
            insertList.add(insertID);
          },
          onRemove: (int removeID) {
            insertList.add(removeID);
          });

      expect(roomList.eventSub != null, true);
      expect(roomList.roomSub != null, true);

      client.connection.onRoomUpdate.add(RoomUpdate(
        id: roomID,
        membership: Membership.join,
        notification_count: 2,
        highlight_count: 1,
        limitedTimeline: false,
        prev_batch: "1234",
      ));

      await new Future.delayed(new Duration(milliseconds: 50));

      expect(updateCount, 1);
      expect(insertList, [0]);
      expect(removeList, []);

      expect(roomList.rooms.length, 1);
      expect(roomList.rooms[0].id, roomID);
      expect(roomList.rooms[0].membership, Membership.join);
      expect(roomList.rooms[0].notificationCount, 2);
      expect(roomList.rooms[0].highlightCount, 1);
      expect(roomList.rooms[0].prev_batch, "1234");
      expect(roomList.rooms[0].timeCreated, ChatTime.now());
    });

    test("Restort", () async {
      final Client client = Client("testclient");
      client.homeserver = "https://testserver.abc";
      client.prevBatch = "1234";

      int updateCount = 0;
      List<int> insertList = [];
      List<int> removeList = [];

      RoomList roomList = RoomList(
          client: client,
          rooms: [],
          onUpdate: () {
            updateCount++;
          },
          onInsert: (int insertID) {
            insertList.add(insertID);
          },
          onRemove: (int removeID) {
            insertList.add(removeID);
          });

      client.connection.onRoomUpdate.add(RoomUpdate(
        id: "1",
        membership: Membership.join,
        notification_count: 2,
        highlight_count: 1,
        limitedTimeline: false,
        prev_batch: "1234",
      ));
      client.connection.onRoomUpdate.add(RoomUpdate(
        id: "2",
        membership: Membership.join,
        notification_count: 2,
        highlight_count: 1,
        limitedTimeline: false,
        prev_batch: "1234",
      ));
      client.connection.onRoomUpdate.add(RoomUpdate(
          id: "1",
          membership: Membership.join,
          notification_count: 2,
          highlight_count: 1,
          limitedTimeline: false,
          prev_batch: "12345",
          summary: RoomSummary(
              mHeroes: ["@alice:example.com"],
              mJoinedMemberCount: 1,
              mInvitedMemberCount: 1)));

      await new Future.delayed(new Duration(milliseconds: 50));

      expect(roomList.eventSub != null, true);
      expect(roomList.roomSub != null, true);
      expect(roomList.rooms[0].id, "1");
      expect(roomList.rooms[1].id, "2");
      expect(roomList.rooms[0].prev_batch, "12345");
      expect(roomList.rooms[0].displayname, "alice");
      expect(roomList.rooms[0].mJoinedMemberCount, 1);
      expect(roomList.rooms[0].mInvitedMemberCount, 1);

      ChatTime now = ChatTime.now();

      int roomUpdates = 0;

      roomList.rooms[0].onUpdate = () {
        roomUpdates++;
      };
      roomList.rooms[1].onUpdate = () {
        roomUpdates++;
      };

      client.connection.onEvent.add(EventUpdate(
          type: "timeline",
          roomID: "1",
          eventType: "m.room.message",
          content: {
            "type": "m.room.message",
            "content": {"msgtype": "m.text", "body": "Testcase"},
            "sender": "@alice:example.com",
            "room_id": "1",
            "status": 2,
            "event_id": "1",
            "origin_server_ts": now.toTimeStamp() - 1000
          }));

      client.connection.onEvent.add(EventUpdate(
          type: "timeline",
          roomID: "2",
          eventType: "m.room.message",
          content: {
            "type": "m.room.message",
            "content": {"msgtype": "m.text", "body": "Testcase 2"},
            "sender": "@alice:example.com",
            "room_id": "1",
            "status": 2,
            "event_id": "2",
            "origin_server_ts": now.toTimeStamp()
          }));

      await new Future.delayed(new Duration(milliseconds: 50));

      expect(updateCount, 5);
      expect(roomUpdates, 2);
      expect(insertList, [0, 1]);
      expect(removeList, []);

      expect(roomList.rooms.length, 2);
      expect(
          roomList.rooms[0].timeCreated > roomList.rooms[1].timeCreated, true);
      expect(roomList.rooms[0].id, "2");
      expect(roomList.rooms[1].id, "1");
      expect(roomList.rooms[0].lastMessage, "Testcase 2");
      expect(roomList.rooms[0].timeCreated, now);

      client.connection.onEvent.add(EventUpdate(
          type: "timeline",
          roomID: "1",
          eventType: "m.room.redaction",
          content: {
            "content": {"reason": "Spamming"},
            "event_id": "143273582443PhrSn:example.org",
            "origin_server_ts": 1432735824653,
            "redacts": "1",
            "room_id": "1",
            "sender": "@example:example.org",
            "type": "m.room.redaction",
            "unsigned": {"age": 1234}
          }));

      await new Future.delayed(new Duration(milliseconds: 50));

      expect(updateCount, 6);
      expect(insertList, [0, 1]);
      expect(removeList, []);
      expect(roomList.rooms.length, 2);
      expect(roomList.rooms[1].getState("m.room.message").eventId, "1");
      expect(roomList.rooms[1].getState("m.room.message").redacted, true);
    });

    test("onlyLeft", () async {
      final Client client = Client("testclient");
      client.homeserver = "https://testserver.abc";
      client.prevBatch = "1234";

      int updateCount = 0;
      List<int> insertList = [];
      List<int> removeList = [];

      RoomList roomList = RoomList(
          client: client,
          onlyLeft: true,
          rooms: [],
          onUpdate: () {
            updateCount++;
          },
          onInsert: (int insertID) {
            insertList.add(insertID);
          },
          onRemove: (int removeID) {
            insertList.add(removeID);
          });

      client.connection.onRoomUpdate.add(RoomUpdate(
        id: "1",
        membership: Membership.join,
        notification_count: 2,
        highlight_count: 1,
        limitedTimeline: false,
        prev_batch: "1234",
      ));
      client.connection.onRoomUpdate.add(RoomUpdate(
        id: "2",
        membership: Membership.leave,
        notification_count: 2,
        highlight_count: 1,
        limitedTimeline: false,
        prev_batch: "1234",
      ));

      await new Future.delayed(new Duration(milliseconds: 50));

      expect(roomList.eventSub != null, true);
      expect(roomList.roomSub != null, true);
      expect(roomList.rooms[0].id, "2");
      expect(updateCount, 2);
      expect(insertList, [0]);
      expect(removeList, []);
    });
  });
}
