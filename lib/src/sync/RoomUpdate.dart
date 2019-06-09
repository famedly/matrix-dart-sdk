/// Represents a new room or an update for an
/// already known room.
class RoomUpdate {

  /// All rooms have an idea in the format: !uniqueid:server.abc
  final String id;

  /// The current membership state of the user in this room.
  final String membership;

  /// Represents the number of unead notifications. This probably doesn't fit the number
  /// of unread messages.
  final num notification_count;

  // The number of unread highlighted notifications.
  final num highlight_count;

  /// If there are too much new messages, the [homeserver] will only send the
  /// last X (default is 10) messages and set the [limitedTimelinbe] flag to true.
  final bool limitedTimeline;

  /// Represents the current position of the client in the room history.
  final String prev_batch;

  RoomUpdate({
    this.id,
    this.membership,
    this.notification_count,
    this.highlight_count,
    this.limitedTimeline,
    this.prev_batch,
  });
}
