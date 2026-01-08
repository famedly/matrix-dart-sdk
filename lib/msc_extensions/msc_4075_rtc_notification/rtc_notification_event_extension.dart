/// MSC4075: MatrixRTC Notification Event (https://github.com/matrix-org/matrix-spec-proposals/pull/4075)
library;

import 'package:matrix/matrix.dart';

export 'models/rtc_notification_content.dart';

extension RtcNotificationEventExtension on Event {
  bool get isRtcNotificationEvent => type == RtcNotificationContent.eventType;

  RtcNotificationContent? tryParseRtcNotificationContent() {
    if (!isRtcNotificationEvent) return null;
    try {
      return RtcNotificationContent.fromEvent(this);
    } catch (_) {
      return null;
    }
  }
}
