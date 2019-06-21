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
import 'package:famedlysdk/src/User.dart';

void main() {
  /// All Tests related to the Event
  group("User", () {
    test("Create from json", () async {
      final String id = "@alice:server.abc";
      final String membership = "join";
      final String displayName = "Alice";
      final String avatarUrl = "";
      final int powerLevel = 50;

      final Map<String, dynamic> jsonObj = {
        "matrix_id": id,
        "displayname": displayName,
        "avatar_url": avatarUrl,
        "membership": membership,
        "power_level": powerLevel,
      };

      User user = User.fromJson(jsonObj, null);

      expect(user.id, id);
      expect(user.membership, membership);
      expect(user.displayName, displayName);
      expect(user.avatarUrl.mxc, avatarUrl);
      expect(user.powerLevel, powerLevel);
      expect(user.calcDisplayname(), displayName);
    });
  });
}
