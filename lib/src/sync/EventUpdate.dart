/// Represents a new event (e.g. a message in a room) or an update for an
/// already known event.
class EventUpdate {

  /// Usually 'timeline', 'state' or whatever.
  final String eventType;

  /// Most events belong to a room. If not, this equals to eventType.
  final String roomID;

  /// See (Matrix Room Events)[https://matrix.org/docs/spec/client_server/r0.4.0.html#room-events]
  /// and (Matrix Events)[https://matrix.org/docs/spec/client_server/r0.4.0.html#id89] for more
  /// informations.
  final String type;

  // The json payload of the content of this event.
  final dynamic content;

  EventUpdate({this.eventType, this.roomID, this.type, this.content});
}
