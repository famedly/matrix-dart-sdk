/* MIT License
* 
* Copyright (C) 2022 Famedly GmbH
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

import 'package:matrix/matrix_api_lite/model/stripped_state_event.dart';

class ChildrenState extends StrippedStateEvent {
  DateTime originServerTs;

  ChildrenState({
    required super.type,
    required super.content,
    required super.senderId,
    required String super.stateKey,
    required this.originServerTs,
  });

  ChildrenState.fromJson(super.json)
      : originServerTs = DateTime.fromMillisecondsSinceEpoch(
          json['origin_server_ts'] as int,
        ),
        super.fromJson();

  @override
  Map<String, Object?> toJson() {
    final data = super.toJson();
    data['origin_server_ts'] = originServerTs.millisecondsSinceEpoch;
    return data;
  }
}
