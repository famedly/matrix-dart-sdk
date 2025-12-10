/// MSC4075: RTC notification events
/// https://github.com/matrix-org/matrix-spec-proposals/blob/toger5/matrixrtc-call-ringing/proposals/4075-rtc-notification-event.md
library;

import 'package:matrix/matrix.dart';
import 'package:matrix/msc_extensions/msc_4075_rtc_notification_events/models.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';

extension RTCNotificationHandler on Client {
  /// Stream for incoming RTC notification events
  static final CachedStreamController<RTCNotificationContent>
      _onRTCNotification = CachedStreamController();

  /// Subscribe to incoming RTC notification events
  Stream<RTCNotificationContent> get onRTCNotification =>
      _onRTCNotification.stream;

  /// Send an RTC notification event
  ///
  /// `roomId` - The room where the call is happening
  /// `callId` - The call ID being notified about
  /// `callType` - The type of call ('voice' or 'video')
  /// `notifyType` - The notification type ('ring' or 'notify'), defaults to 'ring'
  Future<String?> sendRTCNotificationEvent({
    required String roomId,
    required String callId,
    required String callType,
    String notifyType = 'ring',
  }) async {
    final room = getRoomById(roomId);
    if (room == null) {
      throw Exception('Room $roomId not found');
    }

    final content = RTCNotificationContent(
      callId: callId,
      roomId: roomId,
      callType: callType,
      notifyType: notifyType,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    return await room.sendEvent(
      content.toJson(),
      type: RTCNotificationEventTypes.rtcNotification,
    );
  }

  /// Set up a listener for incoming RTC notification events
  ///
  /// This method subscribes to the client's timeline events and processes
  /// RTC notification events, emitting them to the onRTCNotification stream.
  ///
  /// Call this once during client initialization if you want to handle
  /// RTC notifications in your application.
  ///
  /// Example:
  /// ```dart
  /// client.setupRTCNotificationListener();
  /// client.onRTCNotification.listen((notification) {
  ///   print('Incoming call: ${notification.callType} in room ${notification.roomId}');
  /// });
  /// ```
  void setupRTCNotificationListener() {
    onTimelineEvent.stream.listen((Event event) {
      if (event.type == RTCNotificationEventTypes.rtcNotification) {
        try {
          final notification = RTCNotificationContent.fromJson(event.content);
          _onRTCNotification.add(notification);
        } catch (e) {
          Logs().w('Failed to parse RTC notification event: $e');
        }
      }
    });
  }

  /// Enable push notifications for RTC notification events
  ///
  /// Creates or updates a push rule to trigger notifications when RTC
  /// notification events are received. The rule will make the events trigger
  /// notifications with a "ring" sound, similar to m.call.invite events.
  ///
  /// [ruleId] The ID for this push rule (default: '.m.rule.rtc_notification')
  ///
  /// Example:
  /// ```dart
  /// await client.enableRTCNotificationPushRule();
  /// ```
  Future<void> enableRTCNotificationPushRule({
    String ruleId = '.m.rule.rtc_notification',
  }) async {
    await setPushRule(
      PushRuleKind.underride,
      ruleId,
      [
        'notify',
        {'set_tweak': 'sound', 'value': 'ring'},
        {'set_tweak': 'highlight', 'value': false},
      ],
      conditions: [
        PushCondition(
          kind: 'event_match',
          key: 'type',
          pattern: RTCNotificationEventTypes.rtcNotification,
        ),
      ],
    );
    await setPushRuleEnabled(PushRuleKind.underride, ruleId, true);
  }

  /// Disable push notifications for RTC notification events
  ///
  /// Disables the push rule for RTC notification events.
  ///
  /// [ruleId] The ID of the push rule to disable (default: '.m.rule.rtc_notification')
  Future<void> disableRTCNotificationPushRule({
    String ruleId = '.m.rule.rtc_notification',
  }) async {
    await setPushRuleEnabled(PushRuleKind.underride, ruleId, false);
  }
}
