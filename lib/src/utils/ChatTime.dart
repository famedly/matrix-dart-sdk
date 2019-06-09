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

import 'package:intl/intl.dart';

class ChatTime {
  DateTime dateTime = DateTime.now();

  ChatTime(num ts) {
    if (ts != null)
    dateTime = DateTime.fromMicrosecondsSinceEpoch(ts * 1000);
  }

  ChatTime.now() {
    dateTime = DateTime.now();
  }

  String toString() {
    DateTime now = DateTime.now();

    bool sameYear = now.year == dateTime.year;

    bool sameDay =
        sameYear && now.month == dateTime.month && now.day == dateTime.day;

    bool sameWeek = sameYear && !sameDay && now.millisecondsSinceEpoch - dateTime.millisecondsSinceEpoch < 1000*60*60*24*7;

    if (sameDay) {
      return toTimeString();
    } else if (sameWeek) {
      switch (dateTime.weekday) { // TODO: Needs localization
        case 1:
          return "Montag";
        case 2:
          return "Dienstag";
        case 3:
          return "Mittwoch";
        case 4:
          return "Donnerstag";
        case 5:
          return "Freitag";
        case 6:
          return "Samstag";
        case 7:
          return "Sonntag";
      }
    } else if (sameYear) {
      return DateFormat('dd.MM').format(dateTime);
    } else {
      return DateFormat('dd.MM.yyyy').format(dateTime);
    }
  }

  num toTimeStamp() {
    return dateTime.microsecondsSinceEpoch;
  }

  bool sameEnvironment(ChatTime prevTime) {
    return toTimeStamp() - prevTime.toTimeStamp() < 1000*60*5;
  }

  String toTimeString() {
    return DateFormat('HH:mm').format(dateTime);
  }

  String toEventTimeString() {
    DateTime now = DateTime.now();

    bool sameYear = now.year == dateTime.year;

    bool sameDay =
        sameYear && now.month == dateTime.month && now.day == dateTime.day;

    if (sameDay) return toTimeString();
    return "${toString()}, ${DateFormat('HH:mm').format(dateTime)}";
  }
}
