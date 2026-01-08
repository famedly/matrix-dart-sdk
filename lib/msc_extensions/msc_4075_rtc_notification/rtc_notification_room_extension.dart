/// MSC4075: MatrixRTC Notification Event (https://github.com/matrix-org/matrix-spec-proposals/pull/4075)
library;

import 'package:matrix/matrix.dart';

extension RtcNotificationRoomExtension on Room {
  /// Sends an RTC notification event to this room.
  ///
  /// This notifies room members about an active MatrixRTC session
  /// (e.g., to make their devices ring for an incoming call).
  ///
  /// [type] - Whether this is a 'ring' or 'notification' event.
  /// [userIds] - Optional list of user IDs to mention for targeted notifications.
  /// [mentionRoom] - If true, mentions the entire room (@room).
  /// [memberEventId] - Optional event ID of the related member state event.
  /// [lifetime] - How long the notification is active. Defaults to 30s.
  Future<String?> sendRtcNotification({
    required RtcNotificationType type,
    List<String>? userIds,
    bool mentionRoom = false,
    String? memberEventId,
    Duration lifetime = RtcNotificationContent.defaultLifetime,
  }) {
    final notification = RtcNotificationContent.create(
      type: type,
      lifetime: lifetime,
    );

    final content = <String, Object?>{
      ...notification.toJson(),
      if (mentionRoom || (userIds != null && userIds.isNotEmpty))
        'm.mentions': {
          if (mentionRoom) 'room': true,
          if (userIds != null && userIds.isNotEmpty) 'user_ids': userIds,
        },
      if (memberEventId != null)
        'm.relates_to': {
          'rel_type': 'm.reference',
          'event_id': memberEventId,
        },
    };

    return sendEvent(
      content,
      type: RtcNotificationContent.eventType,
    );
  }
}
