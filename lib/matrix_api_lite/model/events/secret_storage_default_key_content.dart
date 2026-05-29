// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite/model/basic_event.dart';
import 'package:matrix/matrix_api_lite/utils/try_get_map_extension.dart';

extension SecretStorageDefaultKeyContentBasicEventExtension on BasicEvent {
  SecretStorageDefaultKeyContent get parsedSecretStorageDefaultKeyContent =>
      SecretStorageDefaultKeyContent.fromJson(content);
}

class SecretStorageDefaultKeyContent {
  //TODO: Required by spec, we should require it here and make sure to catch it everywhere
  String? key;

  SecretStorageDefaultKeyContent({required this.key});

  SecretStorageDefaultKeyContent.fromJson(Map<String, Object?> json)
      : key = json.tryGet('key', TryGet.required);

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    if (key != null) data['key'] = key;
    return data;
  }
}
