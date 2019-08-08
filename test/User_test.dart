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

import 'package:famedlysdk/src/State.dart';
import 'package:famedlysdk/src/User.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// All Tests related to the Event
  group("User", () {
    test("Create from json", () async {
      final String id = "@alice:server.abc";
      final Membership membership = Membership.join;
      final String displayName = "Alice";
      final String avatarUrl = "";
      final int powerLevel = 50;

      final Map<String, dynamic> jsonObj = {
        "matrix_id": id,
        "displayname": displayName,
        "avatar_url": avatarUrl,
        "membership": membership.toString().split('.').last,
        "power_level": powerLevel,
      };

      User user = State.fromJson(jsonObj, null).asUser;

      expect(user.id, id);
      expect(user.membership, membership);
      expect(user.displayName, displayName);
      expect(user.avatarUrl.mxc, avatarUrl);
      expect(user.calcDisplayname(), displayName);
    });

    test("calcDisplayname", () async {
      final User user1 = User(senderId: "@alice:example.com");
      final User user2 = User(senderId: "@alice:example.com");
      final User user3 = User(senderId: "@alice:example.com");
      expect(user1.calcDisplayname(), "alice");
      expect(user2.calcDisplayname(), "SuperAlice");
      expect(user3.calcDisplayname(), "alice");
    });
  });
}
