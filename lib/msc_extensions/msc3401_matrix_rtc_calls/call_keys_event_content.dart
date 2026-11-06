// SPDX-FileCopyrightText: 2026-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import '../../matrix.dart';

class CallKeysEvent extends ToDeviceEvent {
  CallKeysEvent._({
    required super.sender,
    required super.type,
    required super.content,
  });

  factory CallKeysEvent.fromToDeviceEvent(ToDeviceEvent event) =>
      CallKeysEvent._(
        content: event.content,
        sender: event.sender,
        type: event.type,
      );

  CallKeysEventContent get callKeysContent =>
      CallKeysEventContent.fromJson(super.content);

  String get key =>
      String.fromCharCodes(base64Decode(callKeysContent.keys.key));
}

/// To-device event content for encryption key exchange (EncryptionKeysToDeviceEventContent).
class CallKeysEventContent {
  static const String eventType = 'io.element.call.encryption_keys';

  final EncryptionKeyEntry keys;
  final CallKeysMember member;
  final String roomId;
  final CallKeysSession session;
  final int? sentTs;

  const CallKeysEventContent({
    required this.keys,
    required this.member,
    required this.roomId,
    required this.session,
    this.sentTs,
  });

  factory CallKeysEventContent.fromJson(Map<String, Object?> json) =>
      CallKeysEventContent(
        keys: EncryptionKeyEntry.fromJson(
          Map<String, Object?>.from(json['keys'] as Map),
        ),
        member: CallKeysMember.fromJson(
          Map<String, Object?>.from(json['member'] as Map),
        ),
        roomId: json['room_id'] as String,
        session: CallKeysSession.fromJson(
          Map<String, Object?>.from(json['session'] as Map),
        ),
        sentTs: json['sent_ts'] as int?,
      );

  Map<String, Object?> toJson() => {
    'keys': keys.toJson(),
    'member': member.toJson(),
    'room_id': roomId,
    'session': session.toJson(),
    if (sentTs != null) 'sent_ts': sentTs,
  };
}

class CallKeysMember {
  final String id;
  final String claimedDeviceId;

  const CallKeysMember({required this.id, required this.claimedDeviceId});

  factory CallKeysMember.fromJson(Map<String, Object?> json) => CallKeysMember(
    id: json['id'] as String,
    claimedDeviceId: json['claimed_device_id'] as String,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'claimed_device_id': claimedDeviceId,
  };
}

class CallKeysSession {
  final String application;
  final String callId;
  final String scope;

  const CallKeysSession({
    required this.application,
    required this.callId,
    required this.scope,
  });

  factory CallKeysSession.fromJson(Map<String, Object?> json) =>
      CallKeysSession(
        application: json['application'] as String,
        callId: json['call_id'] as String,
        scope: json['scope'] as String,
      );

  Map<String, Object?> toJson() => {
    'application': application,
    'call_id': callId,
    'scope': scope,
  };
}
