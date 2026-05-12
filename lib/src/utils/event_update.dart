// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

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

@Deprecated('Use `Event` class directly instead.')
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
