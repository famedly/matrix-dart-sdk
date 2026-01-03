/// MSC4075: MatrixRTC Notification Event (https://github.com/matrix-org/matrix-spec-proposals/pull/4075)
library;

import 'package:matrix/matrix.dart';

export 'models/rtc_notification_content.dart';

extension RtcNotificationEventExtension on Event {
  bool get isRtcNotificationEvent => type == RtcNotificationContent.eventType;

  RtcNotificationContent? tryParseRtcNotificationContent() {
    if (!isRtcNotificationEvent) return null;
    try {
      return RtcNotificationContent.fromJson(content);
    } catch (_) {
      return null;
    }
  }

  bool get isRtcNotificationExpired {
    final notification = tryParseRtcNotificationContent();
    if (notification == null) return true;
    return notification.isExpired(originServerTs.millisecondsSinceEpoch);
  }

  /// Validates that this RTC notification event should cause the client to
  /// notify the user according to MSC4075 rules.
  ///
  /// Returns true if:
  /// - The event is a valid RTC notification and is not expired
  /// - The current user is mentioned in m.mentions
  /// - (For ring) The device is not already ringing for this call
  bool shouldNotifyUser({
    required String currentUserId,
    bool isAlreadyRinging = false,
  }) {
    final notification = tryParseRtcNotificationContent();
    if (notification == null) return false;

    if (!notification.mentionsUser(currentUserId)) return false;
    if (notification.isExpired(originServerTs.millisecondsSinceEpoch)) {
      return false;
    }
    if (notification.notificationType == RtcNotificationType.ring &&
        isAlreadyRinging) {
      return false;
    }

    return true;
  }
}
