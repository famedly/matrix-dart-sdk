/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020 Famedly GmbH
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

class RoomKeysSingleKey {
  int firstMessageIndex;
  int forwardedCount;
  bool isVerified;
  Map<String, dynamic> sessionData;

  RoomKeysSingleKey(
      {this.firstMessageIndex,
      this.forwardedCount,
      this.isVerified,
      this.sessionData});

  RoomKeysSingleKey.fromJson(Map<String, dynamic> json) {
    firstMessageIndex = json['first_message_index'];
    forwardedCount = json['forwarded_count'];
    isVerified = json['is_verified'];
    sessionData = json['session_data'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['first_message_index'] = firstMessageIndex;
    data['forwarded_count'] = forwardedCount;
    data['is_verified'] = isVerified;
    data['session_data'] = sessionData;
    return data;
  }
}

class RoomKeysRoom {
  Map<String, RoomKeysSingleKey> sessions;

  RoomKeysRoom({this.sessions}) {
    sessions ??= <String, RoomKeysSingleKey>{};
  }

  RoomKeysRoom.fromJson(Map<String, dynamic> json) {
    sessions = (json['sessions'] as Map)
        .map((k, v) => MapEntry(k, RoomKeysSingleKey.fromJson(v)));
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['sessions'] = sessions.map((k, v) => MapEntry(k, v.toJson()));
    return data;
  }
}

class RoomKeys {
  Map<String, RoomKeysRoom> rooms;

  RoomKeys({this.rooms}) {
    rooms ??= <String, RoomKeysRoom>{};
  }

  RoomKeys.fromJson(Map<String, dynamic> json) {
    rooms = (json['rooms'] as Map)
        .map((k, v) => MapEntry(k, RoomKeysRoom.fromJson(v)));
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['rooms'] = rooms.map((k, v) => MapEntry(k, v.toJson()));
    return data;
  }
}

class RoomKeysUpdateResponse {
  String etag;
  int count;

  RoomKeysUpdateResponse.fromJson(Map<String, dynamic> json) {
    etag = json['etag']; // synapse replies an int but docs say string?
    count = json['count'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['etag'] = etag;
    data['count'] = count;
    return data;
  }
}
