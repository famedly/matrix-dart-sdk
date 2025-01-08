import 'dart:convert';

/// Push Notification object from https://spec.matrix.org/v1.2/push-gateway-api/
class PushNotification {
  final Map<String, Object?>? content;
  final PushNotificationCounts? counts;
  final List<PushNotificationDevice>? devices;
  final String? eventId;
  final String? prio;
  final String? roomAlias;
  final String? roomId;
  final String? roomName;
  final String? sender;
  final String? senderDisplayName;
  final String? type;

  const PushNotification({
    this.content,
    this.counts,
    this.devices,
    this.eventId,
    this.prio,
    this.roomAlias,
    this.roomId,
    this.roomName,
    this.sender,
    this.senderDisplayName,
    this.type,
  });

  /// Generate a Push Notification object from JSON. It also supports a
  /// `map<String, String>` which usually comes from Firebase Cloud Messaging.
  factory PushNotification.fromJson(Map<String, Object?> json) =>
      PushNotification(
        content: json['content'] is Map
            ? Map<String, Object?>.from(json['content'] as Map)
            : json['content'] is String
                ? jsonDecode(json['content'] as String)
                : null,
        counts: json['counts'] is Map
            ? PushNotificationCounts.fromJson(
                json['counts'] as Map<String, Object?>,
              )
            : json['counts'] is String
                ? PushNotificationCounts.fromJson(
                    jsonDecode(json['counts'] as String),
                  )
                : null,
        devices: json['devices'] is List
            ? (json['devices'] as List)
                .map((d) => PushNotificationDevice.fromJson(d))
                .toList()
            : (jsonDecode(json['devices'] as String) as List)
                .map((d) => PushNotificationDevice.fromJson(d))
                .toList(),
        eventId: json['event_id'] as String?,
        prio: json['prio'] as String?,
        roomAlias: json['room_alias'] as String?,
        roomId: json['room_id'] as String?,
        roomName: json['room_name'] as String?,
        sender: json['sender'] as String?,
        senderDisplayName: json['sender_display_name'] as String?,
        type: json['type'] as String?,
      );

  Map<String, Object?> toJson() => {
        if (content != null) 'content': content,
        if (counts != null) 'counts': counts?.toJson(),
        if (devices != null)
          'devices': devices?.map((i) => i.toJson()).toList(),
        if (eventId != null) 'event_id': eventId,
        if (prio != null) 'prio': prio,
        if (roomAlias != null) 'room_alias': roomAlias,
        if (roomId != null) 'room_id': roomId,
        if (roomName != null) 'room_name': roomName,
        if (sender != null) 'sender': sender,
        if (senderDisplayName != null) 'sender_display_name': senderDisplayName,
        if (type != null) 'type': type,
      };
}

class PushNotificationCounts {
  final int? missedCalls;
  final int? unread;

  const PushNotificationCounts({
    this.missedCalls,
    this.unread,
  });

  factory PushNotificationCounts.fromJson(Map<String, Object?> json) =>
      PushNotificationCounts(
        missedCalls: json['missed_calls'] as int?,
        unread: json['unread'] as int?,
      );

  Map<String, Object?> toJson() => {
        if (missedCalls != null) 'missed_calls': missedCalls,
        if (unread != null) 'unread': unread,
      };
}

class PushNotificationDevice {
  final String? appId;
  final Map<String, Object?>? data;
  final String? pushkey;
  final int? pushkeyTs;
  final Tweaks? tweaks;

  const PushNotificationDevice({
    this.appId,
    this.data,
    this.pushkey,
    this.pushkeyTs,
    this.tweaks,
  });

  factory PushNotificationDevice.fromJson(Map<String, Object?> json) =>
      PushNotificationDevice(
        appId: json['app_id'] as String?,
        data: json['data'] == null
            ? null
            : Map<String, Object?>.from(json['data'] as Map),
        pushkey: json['pushkey'] as String?,
        pushkeyTs: json['pushkey_ts'] as int?,
        tweaks: json['tweaks'] == null
            ? null
            : Tweaks.fromJson(json['tweaks'] as Map<String, Object?>),
      );

  Map<String, Object?> toJson() => {
        'app_id': appId,
        if (data != null) 'data': data,
        'pushkey': pushkey,
        if (pushkeyTs != null) 'pushkey_ts': pushkeyTs,
        if (tweaks != null) 'tweaks': tweaks?.toJson(),
      };
}

class Tweaks {
  final String? sound;

  const Tweaks({
    this.sound,
  });

  factory Tweaks.fromJson(Map<String, Object?> json) => Tweaks(
        sound: json['sound'] as String?,
      );

  Map<String, Object?> toJson() => {
        if (sound != null) 'sound': sound,
      };
}
