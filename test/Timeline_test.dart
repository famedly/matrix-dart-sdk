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

import 'package:flutter_test/flutter_test.dart';
import 'package:famedlysdk/src/Client.dart';
import 'package:famedlysdk/src/Room.dart';
import 'package:famedlysdk/src/Timeline.dart';
import 'package:famedlysdk/src/sync/EventUpdate.dart';
import 'package:famedlysdk/src/utils/ChatTime.dart';

void main() {
  /// All Tests related to the MxContent
  group("Timeline", () {
    final String roomID = "!1234:example.com";
    final testTimeStamp = ChatTime.now().toTimeStamp();
    int updateCount = 0;
    List<int> insertList = [];

    test("Create", () async {
      Client client = Client("testclient");
      client.homeserver = "https://testserver.abc";

      Room room = Room(id: roomID, client: client);
      Timeline timeline = Timeline(
          room: room,
          events: [],
          onUpdate: () {
            updateCount++;
          },
          onInsert: (int insertID) {
            insertList.add(insertID);
          });

      client.connection.onEvent.add(EventUpdate(
          type: "timeline",
          roomID: roomID,
          eventType: "m.room.message",
          content: {
            "type": "m.room.message",
            "content": {"msgtype": "m.text", "body": "Testcase"},
            "sender": "@alice:example.com",
            "status": 2,
            "id": "1",
            "origin_server_ts": testTimeStamp
          }));

      expect(timeline.sub != null, true);

      await new Future.delayed(new Duration(milliseconds: 50));

      expect(updateCount, 1);
      expect(insertList, [0]);
      expect(timeline.events.length, 1);
      expect(timeline.events[0].id, "1");
      expect(timeline.events[0].sender.id, "@alice:example.com");
      expect(timeline.events[0].time.toTimeStamp(), testTimeStamp);
      expect(timeline.events[0].environment, "m.room.message");
      expect(timeline.events[0].getBody(), "Testcase");
    });
  });
}
