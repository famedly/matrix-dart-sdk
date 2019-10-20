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
import 'package:famedlysdk/src/AccountData.dart';
import 'package:famedlysdk/src/RoomState.dart';

/// Stripped down events for account data and ephemrals of a room.
class RoomAccountData extends AccountData {
  /// The user who has sent this event if it is not a global account data event.
  final String roomId;

  final Room room;

  RoomAccountData(
      {this.roomId, this.room, Map<String, dynamic> content, String typeKey})
      : super(content: content, typeKey: typeKey);

  /// Get a State event from a table row or from the event stream.
  factory RoomAccountData.fromJson(
      Map<String, dynamic> jsonPayload, Room room) {
    final Map<String, dynamic> content =
        RoomState.getMapFromPayload(jsonPayload['content']);
    return RoomAccountData(
        content: content,
        typeKey: jsonPayload['type'],
        roomId: jsonPayload['room_id'],
        room: room);
  }
}
