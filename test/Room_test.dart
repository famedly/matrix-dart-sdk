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
 * along with Foobar.  If not, see <http://www.gnu.org/licenses/>.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:famedlysdk/src/Room.dart';
import 'package:famedlysdk/src/Client.dart';
import 'dart:async';
import 'FakeMatrixApi.dart';

void main() {
  /// All Tests related to the Event
  group("Room", () {
    test("Create from json", () async {
      Client matrix = Client("testclient");
      matrix.connection.httpClient = FakeMatrixApi();
      matrix.homeserver = "https://fakeServer.notExisting";

      final String id = "!jf983jjf:server.abc";
      final String name = "My Room";
      final String topic = "This is my own room";
      final int unread = DateTime.now().millisecondsSinceEpoch;
      final int notificationCount = 2;
      final int highlightCount = 1;
      final String fullyRead = "fjh82jdjifd:server.abc";
      final String notificationSettings = "all";
      final String guestAccess = "forbidden";
      final String historyVisibility = "invite";
      final String joinRules = "invite";

      final Map<String, dynamic> jsonObj = {
        "id": id,
        "topic": name,
        "description": topic,
        "avatar_url": "",
        "notification_count": notificationCount,
        "highlight_count": highlightCount,
        "unread": unread,
        "fully_read": fullyRead,
        "notification_settings": notificationSettings,
        "direct_chat_matrix_id": "",
        "draft": "",
        "prev_batch": "",
        "guest_access": guestAccess,
        "history_visibility": historyVisibility,
        "join_rules": joinRules,
        "power_events_default": 0,
        "power_state_default": 0,
        "power_redact": 0,
        "power_invite": 0,
        "power_ban": 0,
        "power_kick": 0,
        "power_user_default": 0,
        "power_event_avatar": 0,
        "power_event_history_visibility": 0,
        "power_event_canonical_alias": 0,
        "power_event_aliases": 0,
        "power_event_name": 0,
        "power_event_power_levels": 0,
      };

      Room room = await Room.getRoomFromTableRow(jsonObj, matrix);

      expect(room.id,id);
      expect(room.name,name);
      expect(room.topic,topic);
      expect(room.avatar.mxc,"");
      expect(room.notificationCount,notificationCount);
      expect(room.highlightCount,highlightCount);
      expect(room.unread.toTimeStamp(),unread);
      expect(room.fullyRead,fullyRead);
      expect(room.notificationSettings,notificationSettings);
      expect(room.directChatMatrixID,"");
      expect(room.draft,"");
      expect(room.prev_batch,"");
      expect(room.guestAccess,guestAccess);
      expect(room.historyVisibility,historyVisibility);
      expect(room.joinRules,joinRules);
      room.powerLevels.forEach((String key, int value) {
        expect(value, 0);
      });

    });
  });
}
