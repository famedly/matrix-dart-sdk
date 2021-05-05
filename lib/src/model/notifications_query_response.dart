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

class NotificationsQueryResponse {
  String nextToken;
  List<Notification> notifications;

  NotificationsQueryResponse.fromJson(Map<String, dynamic> json)
      : nextToken = json['next_token'],
        notifications = (json['notifications'] as List)
            .map((v) => Notification.fromJson(v))
            .toList();

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (nextToken != null) {
      data['next_token'] = nextToken;
    }
    data['notifications'] = notifications.map((v) => v.toJson()).toList();
    return data;
  }
}

class Notification {
  List<String> actions;
  String profileTag;
  bool read;
  String roomId;
  int ts;
  MatrixEvent event;

  Notification.fromJson(Map<String, dynamic> json) {
    actions = json['actions'].cast<String>();
    profileTag = json['profile_tag'];
    read = json['read'];
    roomId = json['room_id'];
    ts = json['ts'];
    event = MatrixEvent.fromJson(json['event']);
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['actions'] = actions;
    if (profileTag != null) {
      data['profile_tag'] = profileTag;
    }
    data['read'] = read;
    data['room_id'] = roomId;
    data['ts'] = ts;
    data['event'] = event.toJson();
    return data;
  }
}
