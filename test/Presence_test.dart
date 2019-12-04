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

import 'package:famedlysdk/famedlysdk.dart';
import 'package:test/test.dart';

void main() {
  /// All Tests related to the ChatTime
  group("Presence", () {
    test("fromJson", () async {
      Map<String, dynamic> rawPresence = {
        "content": {
          "avatar_url": "mxc://localhost:wefuiwegh8742w",
          "currently_active": false,
          "last_active_ago": 2478593,
          "presence": "online",
          "status_msg": "Making cupcakes"
        },
        "sender": "@example:localhost",
        "type": "m.presence"
      };
      Presence presence = Presence.fromJson(rawPresence);
      expect(presence.sender, "@example:localhost");
      expect(presence.avatarUrl.mxc, "mxc://localhost:wefuiwegh8742w");
      expect(presence.currentlyActive, false);
      expect(presence.lastActiveAgo, 2478593);
      expect(presence.presence, PresenceType.online);
      expect(presence.statusMsg, "Making cupcakes");
    });
  });
}
