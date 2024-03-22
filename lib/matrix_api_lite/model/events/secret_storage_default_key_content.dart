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
import '../basic_event.dart';

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
