/// MSC4075: MatrixRTC Notification Event (https://github.com/matrix-org/matrix-spec-proposals/pull/4075)
///
/// Provides support for MatrixRTC notification events which allow clients
/// to make targeted devices ring when an RTC session (like a call) is initiated.
///
/// ## Usage
///
/// To send a ring notification:
/// ```dart
/// await room.sendRtcNotification(
///   type: RtcNotificationType.ring,
///   userIds: ['@alice:example.com'],
///   memberEventId: memberStateEventId,
/// );
/// ```
///
/// To check if an event should trigger a notification:
/// ```dart
/// final notification = event.tryParseRtcNotificationContent();
/// if(notification != null){
///   if (notification.shouldNotifyUser(
///     event: event,
///     currentUserId: client.userID!,
///     isUserInCall: false,
///   )) {
///     // Play ring sound or show notification
///   }
/// }
/// ```
library;

export 'models/rtc_notification_content.dart';
export 'rtc_notification_event_extension.dart';
export 'rtc_notification_room_extension.dart';
