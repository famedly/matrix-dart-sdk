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

import 'package:test/test.dart';
import 'package:famedlysdk/src/utils/ChatTime.dart';

void main() {
  /// All Tests related to the ChatTime
  group("ChatTime", () {
    test("Comparing", () async {
      final int originServerTs = DateTime.now().millisecondsSinceEpoch -
          (ChatTime.minutesBetweenEnvironments - 1) * 1000 * 60;
      final int oldOriginServerTs = DateTime.now().millisecondsSinceEpoch -
          (ChatTime.minutesBetweenEnvironments + 1) * 1000 * 60;

      final ChatTime chatTime = ChatTime(originServerTs);
      final ChatTime oldChatTime = ChatTime(oldOriginServerTs);
      final ChatTime nowTime = ChatTime.now();

      expect(chatTime.toTimeStamp(), originServerTs);
      expect(nowTime.toTimeStamp() > chatTime.toTimeStamp(), true);
      expect(nowTime.sameEnvironment(chatTime), true);
      expect(nowTime.sameEnvironment(oldChatTime), false);

      expect(chatTime > oldChatTime, true);
      expect(chatTime < oldChatTime, false);
      expect(chatTime >= oldChatTime, true);
      expect(chatTime <= oldChatTime, false);
      expect(chatTime == chatTime, true);
      expect(chatTime == oldChatTime, false);
    });

    test("Formatting", () async {
      final int timestamp = DateTime.now().millisecondsSinceEpoch;
      final ChatTime chatTime = ChatTime(timestamp);
      //expect(chatTime.toTimeString(),"05:36"); // This depends on the time and your timezone ;)
      expect(chatTime.toTimeString(), chatTime.toEventTimeString());

      final ChatTime oldChatTime = ChatTime(156014498475);
      expect(oldChatTime.toString(), "11.12.1974");
    });
  });
}
