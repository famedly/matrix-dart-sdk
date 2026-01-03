/// MSC4075: MatrixRTC Notification Event (https://github.com/matrix-org/matrix-spec-proposals/pull/4075)
library;

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

class RtcNotificationContent {
  static const String eventType = 'org.matrix.msc4075.rtc.notification';

  /// The default lifetime for notifications in milliseconds (30 seconds)
  static const int defaultLifetimeMs = 30000;

  /// The maximum recommended lifetime in milliseconds (2 minutes)
  static const int maxLifetimeMs = 120000;

  /// Max deviation between sender_ts and origin_server_ts before fallback (20s)
  static const int maxTimestampDeviationMs = 20000;

  /// The local timestamp observed by the sender device
  final int senderTs;

  /// The relative time to sender_ts for which the notification is active
  final int lifetime;

  /// The type of notification (ring or notification)
  final RtcNotificationType notificationType;

  /// User IDs to mention (from m.mentions.user_ids)
  final List<String>? mentionUserIds;

  /// Whether to mention the entire room (from m.mentions.room)
  final bool mentionRoom;

  /// Event ID of the related member event (from m.relates_to.event_id)
  final String? memberEventId;

  const RtcNotificationContent({
    required this.senderTs,
    required this.notificationType,
    this.lifetime = defaultLifetimeMs,
    this.mentionUserIds,
    this.mentionRoom = false,
    this.memberEventId,
  });

  factory RtcNotificationContent.create({
    required RtcNotificationType type,
    List<String>? userIds,
    bool mentionRoom = false,
    String? memberEventId,
    int lifetime = defaultLifetimeMs,
  }) {
    return RtcNotificationContent(
      senderTs: DateTime.now().millisecondsSinceEpoch,
      notificationType: type,
      lifetime: lifetime,
      mentionUserIds: userIds,
      mentionRoom: mentionRoom,
      memberEventId: memberEventId,
    );
  }

  factory RtcNotificationContent.fromJson(Map<String, Object?> json) {
    final notificationType =
        RtcNotificationType.fromValue(json['notification_type'] as String?);
    if (notificationType == null) {
      throw ArgumentError(
        'Invalid or missing notification_type: ${json['notification_type']}',
      );
    }

    final mentions = json['m.mentions'] as Map<String, Object?>?;
    final relatesTo = json['m.relates_to'] as Map<String, Object?>?;

    return RtcNotificationContent(
      senderTs: json['sender_ts'] as int,
      lifetime: json['lifetime'] as int? ?? defaultLifetimeMs,
      notificationType: notificationType,
      mentionUserIds: (mentions?['user_ids'] as List?)?.cast<String>(),
      mentionRoom: mentions?['room'] as bool? ?? false,
      memberEventId: relatesTo?['event_id'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    final hasMentions =
        mentionRoom || (mentionUserIds != null && mentionUserIds!.isNotEmpty);

    return {
      'sender_ts': senderTs,
      'lifetime': lifetime,
      'notification_type': notificationType.value,
      if (hasMentions)
        'm.mentions': {
          if (mentionRoom) 'room': true,
          if (mentionUserIds != null && mentionUserIds!.isNotEmpty)
            'user_ids': mentionUserIds,
        },
      if (memberEventId != null)
        'm.relates_to': {
          'rel_type': 'm.reference',
          'event_id': memberEventId,
        },
    };
  }

  /// Returns true if the given user ID is mentioned
  bool mentionsUser(String userId) {
    if (mentionRoom) return true;
    return mentionUserIds?.contains(userId) ?? false;
  }

  /// Returns the capped lifetime, ensuring it doesn't exceed [maxLifetimeMs]
  int get cappedLifetime => lifetime.clamp(0, maxLifetimeMs);

  /// Returns the effective timestamp, falling back to origin_server_ts if needed
  int getEffectiveTimestamp(int originServerTs) {
    if ((senderTs - originServerTs).abs() > maxTimestampDeviationMs) {
      return originServerTs;
    }
    return senderTs;
  }

  /// Checks if this notification has expired
  bool isExpired(int originServerTs) {
    final expiryTs = getEffectiveTimestamp(originServerTs) + cappedLifetime;
    return DateTime.now().millisecondsSinceEpoch > expiryTs;
  }
}
