/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'matrix_event.dart';

class NotificationsQueryResponse {
  String nextToken;
  List<Notification> notifications;

  NotificationsQueryResponse.fromJson(Map<String, dynamic> json) {
    nextToken = json['next_token'];
    notifications = <Notification>[];
    json['notifications'].forEach((v) {
      notifications.add(Notification.fromJson(v));
    });
  }

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
