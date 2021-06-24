// @dart=2.9
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

import '../../utils/try_get_map_extension.dart';

class OlmPlaintextPayload {
  String type;
  Map<String, dynamic> content;
  String sender;
  String recipient;
  Map<String, String> recipientKeys;
  Map<String, String> keys;

  OlmPlaintextPayload({
    this.type,
    this.content,
    this.sender,
    this.recipient,
    this.recipientKeys,
    this.keys,
  }) : super();

  factory OlmPlaintextPayload.fromJson(Map<String, dynamic> json) =>
      OlmPlaintextPayload(
        sender: json.tryGet<String>('sender'),
        type: json.tryGet<String>('type'),
        content: json.tryGetMap<String, dynamic>('content'),
        recipient: json.tryGet<String>('recipient'),
        recipientKeys: json.tryGetMap<String, String>('recipient_keys'),
        keys: json.tryGetMap<String, String>('keys'),
      );

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (type != null) data['type'] = type;
    if (sender != null) data['sender'] = sender;
    if (content != null) data['content'] = content;
    if (recipient != null) data['recipient'] = recipient;
    if (recipientKeys != null) data['recipient_keys'] = recipientKeys;
    if (keys != null) data['keys'] = keys;
    return data;
  }
}
