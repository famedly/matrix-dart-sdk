// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite/utils/try_get_map_extension.dart';

class OlmPlaintextPayload {
  String? type;
  Map<String, Object?>? content;
  String? sender;
  String? recipient;
  Map<String, String>? recipientKeys;
  Map<String, String>? keys;

  OlmPlaintextPayload({
    this.type,
    this.content,
    this.sender,
    this.recipient,
    this.recipientKeys,
    this.keys,
  }) : super();

  factory OlmPlaintextPayload.fromJson(Map<String, Object?> json) =>
      OlmPlaintextPayload(
        sender: json.tryGet('sender', TryGet.required),
        type: json.tryGet('type', TryGet.required),
        content: json.tryGetMap('content', TryGet.required),
        recipient: json.tryGet('recipient', TryGet.required),
        recipientKeys: json.tryGetMap('recipient_keys', TryGet.required),
        keys: json.tryGetMap('keys', TryGet.required),
      );

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    if (type != null) data['type'] = type;
    if (sender != null) data['sender'] = sender;
    if (content != null) data['content'] = content;
    if (recipient != null) data['recipient'] = recipient;
    if (recipientKeys != null) data['recipient_keys'] = recipientKeys;
    if (keys != null) data['keys'] = keys;
    return data;
  }
}
