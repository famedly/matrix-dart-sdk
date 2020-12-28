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

import 'basic_event.dart';

class BasicRoomEvent extends BasicEvent {
  String roomId;

  BasicRoomEvent({
    this.roomId,
    Map<String, dynamic> content,
    String type,
  }) : super(
          content: content,
          type: type,
        );

  BasicRoomEvent.fromJson(Map<String, dynamic> json) {
    final basicEvent = BasicEvent.fromJson(json);
    content = basicEvent.content;
    type = basicEvent.type;
    roomId = json['room_id'];
  }

  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson();
    if (roomId != null) data['room_id'] = roomId;
    return data;
  }
}
