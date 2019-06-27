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
import 'package:famedlysdk/src/Event.dart';

void main() {
  /// All Tests related to the Event
  group("Event", () {
    test("Create from json", () async {
      final int timestamp = DateTime.now().millisecondsSinceEpoch;
      final String id = "!4fsdfjisjf:server.abc";
      final String senderID = "@alice:server.abc";
      final String senderDisplayname = "Alice";
      final String empty = "";
      final String membership = "join";
      final String type = "m.room.message";
      final String msgtype = "m.text";
      final String body = "Hello World";
      final String formatted_body = "<b>Hello</b> World";

      final String contentJson =
          '{"msgtype":"$msgtype","body":"$body","formatted_body":"$formatted_body"}';

      Map<String, dynamic> json = {
        "event_id": id,
        "matrix_id": senderID,
        "displayname": senderDisplayname,
        "avatar_url": empty,
        "membership": membership,
        "origin_server_ts": timestamp,
        "state_key": empty,
        "type": type,
        "content_json": contentJson,
      };

      Event event = Event.fromJson(json, null);

      expect(event.id, id);
      expect(event.sender.id, senderID);
      expect(event.sender.displayName, senderDisplayname);
      expect(event.sender.avatarUrl.mxc, empty);
      expect(event.sender.membership, membership);
      expect(event.status, 2);
      expect(event.text, body);
      expect(event.formattedText, formatted_body);
      expect(event.getBody(), body);
      expect(event.type, EventTypes.Text);
    });
  });
}
