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

import 'stripped_state_event.dart';

class MatrixEvent extends StrippedStateEvent {
  String eventId;
  String roomId;
  DateTime originServerTs;
  Map<String, dynamic> unsigned;
  Map<String, dynamic> prevContent;
  String redacts;

  MatrixEvent();

  MatrixEvent.fromJson(Map<String, dynamic> json) {
    final strippedStateEvent = StrippedStateEvent.fromJson(json);
    content = strippedStateEvent.content;
    type = strippedStateEvent.type;
    senderId = strippedStateEvent.senderId;
    stateKey = strippedStateEvent.stateKey;
    eventId = json['event_id'];
    roomId = json['room_id'];
    originServerTs =
        DateTime.fromMillisecondsSinceEpoch(json['origin_server_ts']);
    unsigned = json['unsigned'] != null
        ? Map<String, dynamic>.from(json['unsigned'])
        : null;
    prevContent = json['prev_content'] != null
        ? Map<String, dynamic>.from(json['prev_content'])
        : null;
    redacts = json['redacts'];
  }

  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson();
    data['event_id'] = eventId;
    data['origin_server_ts'] = originServerTs.millisecondsSinceEpoch;
    if (unsigned != null) {
      data['unsigned'] = unsigned;
    }
    if (prevContent != null) {
      data['prev_content'] = prevContent;
    }
    if (roomId != null) {
      data['room_id'] = roomId;
    }
    if (data['state_key'] == null) {
      data.remove('state_key');
    }
    if (redacts != null) {
      data['redacts'] = redacts;
    }
    return data;
  }
}
