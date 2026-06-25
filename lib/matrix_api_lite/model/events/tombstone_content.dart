// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite/model/basic_event.dart';
import 'package:matrix/matrix_api_lite/utils/try_get_map_extension.dart';

extension TombstoneContentBasicEventExtension on BasicEvent {
  TombstoneContent get parsedTombstoneContent =>
      TombstoneContent.fromJson(content);
}

class TombstoneContent {
  String body;
  String replacementRoom;

  TombstoneContent.fromJson(Map<String, Object?> json)
    : body = json.tryGet('body', TryGet.required) ?? '',
      replacementRoom = json.tryGet('replacement_room', TryGet.required) ?? '';

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    data['body'] = body;
    data['replacement_room'] = replacementRoom;
    return data;
  }
}
