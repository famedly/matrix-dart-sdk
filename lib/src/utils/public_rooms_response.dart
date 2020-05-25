import '../client.dart';

class PublicRoomsResponse {
  List<PublicRoomEntry> publicRooms;
  final String nextBatch;
  final String prevBatch;
  final int totalRoomCountEstimate;
  Client client;

  PublicRoomsResponse.fromJson(Map<String, dynamic> json, Client client)
      : nextBatch = json['next_batch'],
        prevBatch = json['prev_batch'],
        client = client,
        totalRoomCountEstimate = json['total_room_count_estimate'] {
    if (json['chunk'] != null) {
      publicRooms = <PublicRoomEntry>[];
      json['chunk'].forEach((v) {
        publicRooms.add(PublicRoomEntry.fromJson(v, client));
      });
    }
  }
}

class PublicRoomEntry {
  final List<String> aliases;
  final String avatarUrl;
  final bool guestCanJoin;
  final String name;
  final int numJoinedMembers;
  final String roomId;
  final String topic;
  final bool worldReadable;
  Client client;

  Future<void> join() => client.joinRoomById(roomId);

  PublicRoomEntry.fromJson(Map<String, dynamic> json, Client client)
      : aliases =
            json.containsKey('aliases') ? json['aliases'].cast<String>() : [],
        avatarUrl = json['avatar_url'],
        guestCanJoin = json['guest_can_join'],
        name = json['name'],
        numJoinedMembers = json['num_joined_members'],
        roomId = json['room_id'],
        topic = json['topic'],
        worldReadable = json['world_readable'],
        client = client;
}
