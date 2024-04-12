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

import 'package:matrix/matrix_api_lite.dart';

class PresenceContent {
  PresenceType presence;
  int? lastActiveAgo;
  String? statusMsg;
  bool? currentlyActive;

  PresenceContent.fromJson(Map<String, Object?> json)
      : presence = PresenceType.values.firstWhere(
            (p) => p.toString().split('.').last == json['presence'],
            orElse: () => PresenceType.offline),
        lastActiveAgo = json.tryGet<int>('last_active_ago'),
        statusMsg = json.tryGet<String>('status_msg'),
        currentlyActive = json.tryGet<bool>('currently_active');

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    data['presence'] = presence.toString().split('.').last;
    if (lastActiveAgo != null) {
      data['last_active_ago'] = lastActiveAgo;
    }
    if (statusMsg != null) {
      data['status_msg'] = statusMsg;
    }
    if (currentlyActive != null) {
      data['currently_active'] = currentlyActive;
    }
    return data;
  }
}
