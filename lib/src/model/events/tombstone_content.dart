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

extension TombstoneContentBasicEventExtension on BasicEvent {
  TombstoneContent get parsedTombstoneContent =>
      TombstoneContent.fromJson(content);
}

class TombstoneContent {
  String body;
  String replacementRoom;

  TombstoneContent.fromJson(Map<String, Object?> json)
      : body = json.tryGet('body', TryGet.required) ?? '',
        replacementRoom =
            json.tryGet('replacement_room', TryGet.required) ?? '';

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    data['body'] = body;
    data['replacement_room'] = replacementRoom;
    return data;
  }
}
