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

import 'package:famedlysdk/src/Event.dart';
import 'package:famedlysdk/src/User.dart';
import 'package:test/test.dart';

void main() {
  /// All Tests related to the Event
  group("User", () {
    test("Create from json", () async {
      final String id = "@alice:server.abc";
      final Membership membership = Membership.join;
      final String displayName = "Alice";
      final String avatarUrl = "";

      final Map<String, dynamic> jsonObj = {
        "content": {
          "membership": "join",
          "avatar_url": avatarUrl,
          "displayname": displayName
        },
        "type": "m.room.member",
        "event_id": "143273582443PhrSn:example.org",
        "room_id": "!636q39766251:example.com",
        "sender": id,
        "origin_server_ts": 1432735824653,
        "unsigned": {"age": 1234},
        "state_key": id
      };

      User user = Event.fromJson(jsonObj, null).asUser;

      expect(user.id, id);
      expect(user.membership, membership);
      expect(user.displayName, displayName);
      expect(user.avatarUrl.mxc, avatarUrl);
      expect(user.calcDisplayname(), displayName);
    });

    test("calcDisplayname", () async {
      final User user1 = User("@alice:example.com");
      final User user2 = User("@SuperAlice:example.com");
      final User user3 = User("@alice:example.com");
      expect(user1.calcDisplayname(), "alice");
      expect(user2.calcDisplayname(), "SuperAlice");
      expect(user3.calcDisplayname(), "alice");
    });
  });
}
