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

import 'matrix_event.dart';

class EventsSyncUpdate {
  String start;
  String end;
  List<MatrixEvent> chunk;

  EventsSyncUpdate.fromJson(Map<String, dynamic> json)
      : start = json['start'],
        end = json['end'],
        chunk = json['chunk'] != null
            ? (json['chunk'] as List)
                .map((i) => MatrixEvent.fromJson(i))
                .toList()
            : null;

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (start != null) {
      data['start'] = start;
    }
    if (end != null) {
      data['end'] = end;
    }
    if (chunk != null) {
      data['chunk'] = chunk.map((i) => i.toJson()).toList();
    }
    return data;
  }
}
