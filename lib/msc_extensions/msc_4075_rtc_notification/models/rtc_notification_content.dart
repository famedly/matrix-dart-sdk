/// MSC4075: MatrixRTC Notification Event (https://github.com/matrix-org/matrix-spec-proposals/pull/4075)
library;

import 'package:matrix/matrix.dart';

enum RtcNotificationType {
  ring('ring'),
  notification('notification');

  const RtcNotificationType(this.value);
  final String value;

  static RtcNotificationType? fromValue(String? value) {
    if (value == null) return null;
    return RtcNotificationType.values.cast<RtcNotificationType?>().firstWhere(
          (t) => t!.value == value,
          orElse: () => null,
        );
  }
}

/// The content of an MSC4075 RTC notification event.
///
/// This is a data class representing the RTC-specific fields of the event.
/// For mentions use [Event.mentions] and related member event use id use
/// [Event.relationshipEventId] of the respective event.
class RtcNotificationContent {
  static const String eventType = 'org.matrix.msc4075.rtc.notification';

  /// The default lifetime for notifications (30 seconds)
  static const Duration defaultLifetime = Duration(seconds: 30);

  /// The maximum recommended lifetime (2 minutes)
  static const Duration maxLifetime = Duration(minutes: 2);

  /// Max deviation between sender_ts and origin_server_ts before fallback (20s)
  static const Duration maxTimestampDeviation = Duration(seconds: 20);

  /// The local timestamp observed by the sender device
  final DateTime senderTs;

  /// The relative time to sender_ts for which the notification is active
  final Duration lifetime;

  /// The type of notification (ring or notification)
  final RtcNotificationType notificationType;

  const RtcNotificationContent({
    required this.senderTs,
    required this.notificationType,
    this.lifetime = defaultLifetime,
  });

  factory RtcNotificationContent.create({
    required RtcNotificationType type,
    Duration lifetime = defaultLifetime,
  }) {
    return RtcNotificationContent(
      senderTs: DateTime.now(),
      notificationType: type,
      lifetime: lifetime,
    );
  }

  factory RtcNotificationContent.fromEvent(Event event) {
    final content = event.content;
    final notificationType =
        RtcNotificationType.fromValue(content['notification_type'] as String?);
    if (notificationType == null) {
      throw ArgumentError(
        'Invalid or missing notification_type: ${content['notification_type']}',
      );
    }

    return RtcNotificationContent(
      senderTs:
          DateTime.fromMillisecondsSinceEpoch(content['sender_ts'] as int),
      lifetime: Duration(
        milliseconds:
            content['lifetime'] as int? ?? defaultLifetime.inMilliseconds,
      ),
      notificationType: notificationType,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'sender_ts': senderTs.millisecondsSinceEpoch,
      'lifetime': lifetime.inMilliseconds,
      'notification_type': notificationType.value,
    };
  }

  /// Returns the capped lifetime, ensuring it doesn't exceed [maxLifetime]
  Duration get cappedLifetime {
    if (lifetime > maxLifetime) return maxLifetime;
    if (lifetime.isNegative) return Duration.zero;
    return lifetime;
  }

  /// Returns the effective timestamp, falling back to origin_server_ts if needed
  DateTime getEffectiveTimestamp(DateTime originServerTs) {
    if (senderTs.difference(originServerTs).abs() > maxTimestampDeviation) {
      return originServerTs;
    }
    return senderTs;
  }

  /// Checks if this notification has expired
  bool isExpired(DateTime originServerTs) {
    final expiryTime =
        getEffectiveTimestamp(originServerTs).add(cappedLifetime);
    return DateTime.now().isAfter(expiryTime);
  }

  /// Validates that this RTC notification event should cause the client to
  /// notify the user according to MSC4075 rules.
  ///
  /// Returns true if:
  /// - The current user is mentioned in m.mentions
  /// - The notification is not expired
  /// - (For ring) The device is not already ringing for this call
  bool shouldNotifyUser({
    required Event event,
    required String currentUserId,
    bool isAlreadyRinging = false,
  }) {
    final mentions = event.mentions;
    if (!mentions.room && !mentions.userIds.contains(currentUserId)) {
      return false;
    }
    if (isExpired(event.originServerTs)) {
      return false;
    }
    if (notificationType == RtcNotificationType.ring && isAlreadyRinging) {
      return false;
    }

    return true;
  }
}
