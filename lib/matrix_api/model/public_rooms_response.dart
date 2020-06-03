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

class PublicRoomsResponse {
  List<PublicRoom> chunk;
  String nextBatch;
  String prevBatch;
  int totalRoomCountEstimate;

  PublicRoomsResponse.fromJson(Map<String, dynamic> json) {
    chunk = <PublicRoom>[];
    json['chunk'].forEach((v) {
      chunk.add(PublicRoom.fromJson(v));
    });
    nextBatch = json['next_batch'];
    prevBatch = json['prev_batch'];
    totalRoomCountEstimate = json['total_room_count_estimate'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['chunk'] = chunk.map((v) => v.toJson()).toList();
    if (nextBatch != null) {
      data['next_batch'] = nextBatch;
    }
    if (prevBatch != null) {
      data['prev_batch'] = prevBatch;
    }
    if (totalRoomCountEstimate != null) {
      data['total_room_count_estimate'] = totalRoomCountEstimate;
    }
    return data;
  }
}

class PublicRoom {
  List<String> aliases;
  String avatarUrl;
  bool guestCanJoin;
  String name;
  int numJoinedMembers;
  String roomId;
  String topic;
  bool worldReadable;
  String canonicalAlias;

  PublicRoom.fromJson(Map<String, dynamic> json) {
    aliases = json['aliases']?.cast<String>();
    avatarUrl = json['avatar_url'];
    guestCanJoin = json['guest_can_join'];
    canonicalAlias = json['canonical_alias'];
    name = json['name'];
    numJoinedMembers = json['num_joined_members'];
    roomId = json['room_id'];
    topic = json['topic'];
    worldReadable = json['world_readable'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (aliases != null) {
      data['aliases'] = aliases;
    }
    if (canonicalAlias != null) {
      data['canonical_alias'] = canonicalAlias;
    }
    if (avatarUrl != null) {
      data['avatar_url'] = avatarUrl;
    }
    data['guest_can_join'] = guestCanJoin;
    if (name != null) {
      data['name'] = name;
    }
    data['num_joined_members'] = numJoinedMembers;
    data['room_id'] = roomId;
    if (topic != null) {
      data['topic'] = topic;
    }
    data['world_readable'] = worldReadable;
    return data;
  }
}
