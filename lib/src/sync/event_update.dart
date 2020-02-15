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

import '../../famedlysdk.dart';

/// Represents a new event (e.g. a message in a room) or an update for an
/// already known event.
class EventUpdate {
  /// Usually 'timeline', 'state' or whatever.
  final String type;

  /// Most events belong to a room. If not, this equals to eventType.
  final String roomID;

  /// See (Matrix Room Events)[https://matrix.org/docs/spec/client_server/r0.4.0.html#room-events]
  /// and (Matrix Events)[https://matrix.org/docs/spec/client_server/r0.4.0.html#id89] for more
  /// informations.
  final String eventType;

  // The json payload of the content of this event.
  final Map<String, dynamic> content;

  EventUpdate({this.eventType, this.roomID, this.type, this.content});

  EventUpdate decrypt(Room room) {
    if (eventType != "m.room.encrypted") {
      return this;
    }
    try {
      Event decrpytedEvent =
          room.decryptGroupMessage(Event.fromJson(content, room));
      return EventUpdate(
        eventType: eventType,
        roomID: roomID,
        type: type,
        content: decrpytedEvent.toJson(),
      );
    } catch (e) {
      print("[LibOlm] Could not decrypt megolm event: " + e.toString());
      return this;
    }
  }
}
