// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'basic_event.dart';
import 'matrix_id.dart';

class BasicEventWithSender extends BasicEvent {
  String senderId;

  /// The validated sender as a [UserId], or null if malformed.
  UserId? get senderUserId => UserId.tryParse(senderId);

  set senderUserId(UserId user) {
    senderId = user.value;
  }

  BasicEventWithSender({
    required super.type,
    required super.content,
    required this.senderId,
  });

  BasicEventWithSender.typed({
    required super.type,
    required super.content,
    required UserId senderUserId,
  }) : senderId = senderUserId.value;

  BasicEventWithSender.fromJson(super.json)
    : senderId = json['sender'] as String,
      super.fromJson();

  @override
  Map<String, Object?> toJson() {
    final data = super.toJson();
    data['sender'] = senderId;
    return data;
  }
}
