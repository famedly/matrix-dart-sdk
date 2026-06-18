import 'package:matrix/matrix_api_lite/model/matrix_event.dart';

abstract class MSC4354ExtensionKeys {
  /// The unstable prefix to use for the sticky events that get returned
  /// in the /sync response inside rooms -> join -> room_id -> JoinedRoomUpdate.
  static const syncJoinedRoomSticky = 'msc4354_sticky';

  /// The unstable prefix to use for the sticky event duration in milliseconds
  /// inside the sticky object of a sticky event.
  static const stickyDurationMs = 'org.matrix.msc4354.sticky_duration_ms';

  /// The unstable prefix to use for the sticky object inside a sticky event.
  static const sticky = 'msc4354_sticky';
}

abstract class MSC4354StickyEventContent {
  static const stickyKey = 'msc4354_sticky_key';

  static const unsignedDurationTtlMs = 'msc4354_sticky_duration_ttl_ms';
}

class StickyEventsUpdate {
  final List<StickyEvent> events;

  StickyEventsUpdate({
    required this.events,
  });

  /// Creates a [StickyEventsUpdate] from JSON.
  StickyEventsUpdate.fromJson(Map<String, Object?> json)
      : events = (json['events'] as List?)
                ?.map((v) => StickyEvent.fromJson(v as Map<String, Object?>))
                .toList() ??
            [];

  /// Serializes this [StickyEventsUpdate] to JSON.
  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    data['events'] = events.map((i) => i.toJson()).toList();
    return data;
  }
}

class StickyEvent extends MatrixEvent {
  final StickyEventDuration sticky;

  StickyEvent({
    required this.sticky,
    required super.type,
    required super.content,
    required super.senderId,
    super.stateKey,
    required super.eventId,
    super.roomId,
    required super.originServerTs,
    super.unsigned,
    super.prevContent,
    super.redacts,
  });

  StickyEvent.fromJson(super.json)
      : sticky = StickyEventDuration.fromJson(
          json[MSC4354ExtensionKeys.sticky] as Map<String, Object?>? ?? {},
        ),
        super.fromJson();

  @override
  Map<String, Object?> toJson() {
    final data = super.toJson();
    data[MSC4354ExtensionKeys.sticky] = sticky.toJson();
    return data;
  }

  String? get stickyKey {
    return content[MSC4354StickyEventContent.stickyKey] as String?;
  }

  Duration? get unsignedDurationTtlMs {
    final durationMs =
        unsigned?[MSC4354StickyEventContent.unsignedDurationTtlMs] as int?;

    if (durationMs == null) return null;

    return Duration(milliseconds: durationMs);
  }
}

class StickyEventDuration {
  final int durationMs;

  StickyEventDuration({
    required this.durationMs,
  });

  /// Creates a [StickyEventDuration] from JSON.
  StickyEventDuration.fromJson(Map<String, Object?> json)
      : durationMs = json[MSC4354ExtensionKeys.stickyDurationMs] as int? ?? 0;

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    data[MSC4354ExtensionKeys.stickyDurationMs] = durationMs;
    return data;
  }
}
