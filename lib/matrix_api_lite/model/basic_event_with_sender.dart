// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite/model/basic_event.dart';

class BasicEventWithSender extends BasicEvent {
  String senderId;

  BasicEventWithSender({
    required super.type,
    required super.content,
    required this.senderId,
  });

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
