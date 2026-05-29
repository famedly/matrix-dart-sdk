// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite.dart';

class StrippedStateEvent extends BasicEventWithSender {
  String? stateKey;

  StrippedStateEvent({
    required super.type,
    required super.content,
    required super.senderId,
    this.stateKey,
  });

  StrippedStateEvent.fromJson(super.json)
      : stateKey = json.tryGet<String>('state_key'),
        super.fromJson();

  @override
  Map<String, Object?> toJson() {
    final data = super.toJson();
    data['state_key'] = stateKey;
    return data;
  }
}
