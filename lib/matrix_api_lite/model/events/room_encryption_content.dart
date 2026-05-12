// SPDX-FileCopyrightText: 2019-2021 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite/model/basic_event.dart';
import 'package:matrix/matrix_api_lite/utils/try_get_map_extension.dart';

extension RoomEncryptionContentBasicEventExtension on BasicEvent {
  RoomEncryptionContent get parsedRoomEncryptionContent =>
      RoomEncryptionContent.fromJson(content);
}

class RoomEncryptionContent {
  String algorithm;
  int? rotationPeriodMs;
  int? rotationPeriodMsgs;

  RoomEncryptionContent.fromJson(Map<String, Object?> json)
      : algorithm = json.tryGet('algorithm', TryGet.required) ?? '',
        rotationPeriodMs = json.tryGet('rotation_period_ms'),
        rotationPeriodMsgs = json.tryGet('rotation_period_msgs');

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    data['algorithm'] = algorithm;
    if (rotationPeriodMs != null) {
      data['rotation_period_ms'] = rotationPeriodMs;
    }
    if (rotationPeriodMsgs != null) {
      data['rotation_period_msgs'] = rotationPeriodMsgs;
    }
    return data;
  }
}
