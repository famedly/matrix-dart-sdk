import 'dart:convert';

/// Push Notification object from https://spec.matrix.org/v1.2/push-gateway-api/
class PushNotification {
  final Map<String, dynamic>? content;
  final PushNotificationCounts? counts;
  final List<PushNotificationDevice> devices;
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
    required this.devices,
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
  factory PushNotification.fromJson(Map<String, dynamic> json) =>
      PushNotification(
        content: json['content'] is Map
            ? Map<String, dynamic>.from(json['content'])
            : json['content'] is String
                ? jsonDecode(json['content'])
                : null,
        counts: json['counts'] is Map
            ? PushNotificationCounts.fromJson(json['counts'])
            : json['counts'] is String
                ? PushNotificationCounts.fromJson(jsonDecode(json['counts']))
                : null,
        devices: json['devices'] is List
            ? (json['devices'] as List)
                .map((d) => PushNotificationDevice.fromJson(d))
                .toList()
            : (jsonDecode(json['devices']) as List)
                .map((d) => PushNotificationDevice.fromJson(d))
                .toList(),
        eventId: json['event_id'],
        prio: json['prio'],
        roomAlias: json['room_alias'],
        roomId: json['room_id'],
        roomName: json['room_name'],
        sender: json['sender'],
        senderDisplayName: json['sender_display_name'],
        type: json['type'],
      );

  Map<String, dynamic> toJson() => {
        if (content != null) 'content': content,
        if (counts != null) 'counts': counts?.toJson(),
        'devices': devices.map((i) => i.toJson()).toList(),
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

  factory PushNotificationCounts.fromJson(Map<String, dynamic> json) =>
      PushNotificationCounts(
        missedCalls: json['missed_calls'],
        unread: json['unread'],
      );

  Map<String, dynamic> toJson() => {
        if (missedCalls != null) 'missed_calls': missedCalls,
        if (unread != null) 'unread': unread,
      };
}

class PushNotificationDevice {
  final String appId;
  final Map<String, dynamic>? data;
  final String pushkey;
  final int? pushkeyTs;
  final Tweaks? tweaks;

  const PushNotificationDevice({
    required this.appId,
    this.data,
    required this.pushkey,
    this.pushkeyTs,
    this.tweaks,
  });

  factory PushNotificationDevice.fromJson(Map<String, dynamic> json) =>
      PushNotificationDevice(
        appId: json['app_id'],
        data: json['data'] == null
            ? null
            : Map<String, dynamic>.from(json['data']),
        pushkey: json['pushkey'],
        pushkeyTs: json['pushkey_ts'],
        tweaks: json['tweaks'] == null ? null : Tweaks.fromJson(json['tweaks']),
      );

  Map<String, dynamic> toJson() => {
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

  factory Tweaks.fromJson(Map<String, dynamic> json) => Tweaks(
        sound: json['sound'],
      );

  Map<String, dynamic> toJson() => {
        if (sound != null) 'sound': sound,
      };
}
