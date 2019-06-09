import 'package:famedlysdk/src/Client.dart';
import 'package:famedlysdk/src/utils/MxContent.dart';
import 'package:famedlysdk/src/Room.dart';

class User {
  final String status;
  final String mxid;
  final String displayName;
  final MxContent avatar_url;
  final String directChatRoomId;
  final Room room;

  const User(
    this.mxid, {
    this.status,
    this.displayName,
    this.avatar_url,
    this.directChatRoomId,
    this.room,
  });

  String calcDisplayname() => displayName.isEmpty
      ? mxid.replaceFirst("@", "").split(":")[0]
      : displayName;

  static User fromJson(Map<String, dynamic> json) {
    return User(json['matrix_id'],
        displayName: json['displayname'],
        avatar_url: MxContent(json['avatar_url']),
        status: "",
        directChatRoomId: "");
  }
}
