import 'package:matrix/matrix.dart';

class SyncRequestBody {
  /// An optional string to identify this connection to the server. Only one sliding sync connection is allowed per given conn_id (empty or not).
  final String? connId;

  /// Omitted if this is the first request of a connection (initial sync). Otherwise, the pos token from the previous call to /sync
  final String? pos;

  /// How long to wait for new events in milliseconds. If omitted the response is always returned immediately, even if there are no changes. Ignored when no pos is set.
  final Duration? timeout;

  /// Same as in /v3/sync, controls whether the client is automatically marked as online by polling this API.
  ///
  /// If this parameter is omitted then the client is automatically marked as online when it uses this API. Otherwise if the parameter is set to “offline” then the client is not marked as being online when it uses this API. When set to “unavailable”, the client is marked as being idle.
  ///
  /// An unknown value will result in a 400 error response with code M_INVALID_PARAM.
  // TODO: migrate to enum
  final String? setPresence;

  /// Sliding window API. A map of list key to list information (SyncListConfig). The list keys should be arbitrary strings which the client is using to refer to the list.
  ///
  /// Max lists: 100.
  /// Max list name length: 64 bytes.
  final Map<String, SyncListConfig>? lists;

  /// A map of room ID to room subscription information. Used to subscribe to a specific room. Sometimes clients know exactly which room they want to get information about e.g by following a permalink or by refreshing a webapp currently viewing a specific room. The sliding window API alone is insufficient for this use case because there's no way to say "please track this room explicitly".
  final Map<String, RoomSubscription>? roomSubscriptions;

  /// A map of extension key to extension config. Different extensions have different configuration formats.
  final Map<String, ExtensionConfig>? extensions;

  const SyncRequestBody({
    required this.connId,
    required this.pos,
    required this.timeout,
    required this.setPresence,
    required this.lists,
    required this.roomSubscriptions,
    required this.extensions,
  });

  Map<String, Object?> toJson() => {
        if (connId != null) 'conn_id': connId,
        if (pos != null) 'pos': pos,
        if (timeout != null) 'timeout': timeout!.inMilliseconds,
        if (setPresence != null) 'set_presence': setPresence,
        if (lists != null)
          'lists': lists!.map((k, v) => MapEntry(k, v.toJson())),
        if (roomSubscriptions != null)
          'room_subscriptions':
              roomSubscriptions!.map((k, v) => MapEntry(k, v.toJson())),
        if (extensions != null)
          'extensions': extensions!.map((k, v) => MapEntry(k, v.toJson())),
      };
}
