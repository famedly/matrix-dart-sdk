/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020, 2021 Famedly GmbH
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

import '../../matrix.dart';

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

  @Deprecated("Use `content['type']` instead.")
  String get eventType => content['type'];

  // The json payload of the content of this event.
  final Map<String, dynamic> content;

  EventUpdate({
    required this.roomID,
    required this.type,
    required this.content,
  });

  Future<EventUpdate> decrypt(Room room, {bool store = false}) async {
    if (content['type'] != EventTypes.Encrypted ||
        !room.client.encryptionEnabled) {
      return this;
    }
    try {
      final decrpytedEvent = await room.client.encryption.decryptRoomEvent(
          room.id, Event.fromJson(content, room),
          store: store, updateType: type);
      return EventUpdate(
        roomID: roomID,
        type: type,
        content: decrpytedEvent.toJson(),
      );
    } catch (e, s) {
      Logs().e('[LibOlm] Could not decrypt megolm event', e, s);
      return this;
    }
  }
}
