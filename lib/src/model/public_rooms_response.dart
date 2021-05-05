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

class PublicRoomsResponse {
  List<PublicRoom> chunk;
  String nextBatch;
  String prevBatch;
  int totalRoomCountEstimate;

  PublicRoomsResponse.fromJson(Map<String, dynamic> json) {
    chunk = (json['chunk'] as List).map((v) => PublicRoom.fromJson(v)).toList();
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
