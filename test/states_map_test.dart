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
import 'package:famedlysdk/src/utils/states_map.dart';

void main() {
  /// All Tests related to the ChatTime
  group("StateKeys", () {
    test("Operator overload", () async {
      StatesMap states = StatesMap();
      states["m.room.name"] = Event(
          eventId: "1",
          content: {"name": "test"},
          typeKey: "m.room.name",
          stateKey: "",
          roomId: "!test:test.test",
          senderId: "@alice:test.test");

      states["@alice:test.test"] = Event(
          eventId: "2",
          content: {"membership": "join"},
          typeKey: "m.room.name",
          stateKey: "@alice:test.test",
          roomId: "!test:test.test",
          senderId: "@alice:test.test");

      states["m.room.member"]["@bob:test.test"] = Event(
          eventId: "3",
          content: {"membership": "join"},
          typeKey: "m.room.name",
          stateKey: "@bob:test.test",
          roomId: "!test:test.test",
          senderId: "@bob:test.test");

      states["com.test.custom"] = Event(
          eventId: "4",
          content: {"custom": "stuff"},
          typeKey: "com.test.custom",
          stateKey: "customStateKey",
          roomId: "!test:test.test",
          senderId: "@bob:test.test");

      expect(states["m.room.name"].eventId, "1");
      expect(states["@alice:test.test"].eventId, "2");
      expect(states["m.room.member"]["@alice:test.test"].eventId, "2");
      expect(states["@bob:test.test"].eventId, "3");
      expect(states["m.room.member"]["@bob:test.test"].eventId, "3");
      expect(states["m.room.member"].length, 2);
      expect(states["com.test.custom"]["customStateKey"].eventId, "4");
    });
  });
}
