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
import 'logs.dart';

enum EventUpdateType {
  timeline,
  state,
  history,
  accountData,
  ephemeral,
  inviteState
}

/// Represents a new event (e.g. a message in a room) or an update for an
/// already known event.
class EventUpdate {
  /// Usually 'timeline', 'state' or whatever.
  final EventUpdateType type;

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

  Future<EventUpdate> decrypt(Room room, {bool store = false}) async {
    if (eventType != EventTypes.Encrypted || !room.client.encryptionEnabled) {
      return this;
    }
    try {
      var decrpytedEvent = await room.client.encryption.decryptRoomEvent(
          room.id, Event.fromJson(content, room, sortOrder),
          store: store, updateType: type);
      return EventUpdate(
        eventType: decrpytedEvent.type,
        roomID: roomID,
        type: type,
        content: decrpytedEvent.toJson(),
        sortOrder: sortOrder,
      );
    } catch (e, s) {
      Logs.error('[LibOlm] Could not decrypt megolm event: ' + e.toString(), s);
      return this;
    }
  }
}
