// SPDX-FileCopyrightText: 2019-2021 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite/utils/map_copy_extension.dart';

class BasicEvent {
  String type;
  Map<String, Object?> content;

  BasicEvent({
    required this.type,
    required this.content,
  });

  BasicEvent.fromJson(Map<String, Object?> json)
      : type = json['type'] as String,
        content = (json['content'] as Map<String, Object?>).copy();

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    data['type'] = type;
    data['content'] = content;
    return data;
  }
}
