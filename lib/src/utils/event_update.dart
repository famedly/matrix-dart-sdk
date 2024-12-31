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

enum EventUpdateType {
  /// Newly received events from /sync
  timeline,

  /// A state update not visible in the timeline currently
  state,

  /// Messages that have been fetched when requesting past history
  history,

  /// The state of an invite
  inviteState,

  /// Events that came down timeline, but we only received the keys for it later so we send a second update for them in the decrypted state
  decryptedTimelineQueue,
}

/// Represents a new event (e.g. a message in a room) or an update for an
/// already known event.
class EventUpdate {
  /// Usually 'timeline', 'state' or whatever.
  final EventUpdateType type;

  /// Most events belong to a room. If not, this equals to eventType.
  final String roomID;

  // The json payload of the content of this event.
  final Map<String, dynamic> content;

  EventUpdate({
    required this.roomID,
    required this.type,
    required this.content,
  });
}
