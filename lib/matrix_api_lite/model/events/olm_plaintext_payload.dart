/* MIT License
* 
* Copyright (C) 2019, 2020, 2021 Famedly GmbH
* 
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
* 
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
* 
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

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
