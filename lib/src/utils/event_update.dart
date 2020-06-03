/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import '../../famedlysdk.dart';
import '../../matrix_api.dart';

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

  // the order where to stort this event
  final double sortOrder;

  EventUpdate(
      {this.eventType, this.roomID, this.type, this.content, this.sortOrder});

  EventUpdate decrypt(Room room) {
    if (eventType != EventTypes.Encrypted) {
      return this;
    }
    try {
      var decrpytedEvent =
          room.decryptGroupMessage(Event.fromJson(content, room, sortOrder));
      return EventUpdate(
        eventType: decrpytedEvent.type,
        roomID: roomID,
        type: type,
        content: decrpytedEvent.toJson(),
        sortOrder: sortOrder,
      );
    } catch (e) {
      print('[LibOlm] Could not decrypt megolm event: ' + e.toString());
      return this;
    }
  }
}
