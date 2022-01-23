import 'package:matrix/src/room.dart';

class MatrixWidget {
  final Room room;
  final String creatorUserId;
  final Map<String, dynamic> data;
  final String id;
  final String name;
  final String type;
  final String url;
  final bool waitForIframeLoad;

  MatrixWidget({
    required this.room,
    required this.creatorUserId,
    required this.data,
    required this.id,
    required this.name,
    required this.type,

    /// use [buildWidgetUrl] instead
    required this.url,
    required this.waitForIframeLoad,
  });

  factory MatrixWidget.fromJson(Map<String, dynamic> json, Room room) =>
      MatrixWidget(
        room: room,
        creatorUserId: json['creatorUserId'],
        data: json['data'],
        id: json['id'],
        name: json['name'],
        type: json['type'],
        url: json['url'],
        waitForIframeLoad: json['waitForIframeLoad'],
      );

  Future<Uri> buildWidgetUrl() async {
    // See https://github.com/matrix-org/matrix-doc/issues/1236 for a
    // description, specifically the section
    // `What does the other stuff in content mean?`
    final userProfile = await room.client.ownProfile;
    var parsedUri = url;

    // a key-value map with the strings to be replaced
    final replaceMap = {
      r'$matrix_user_id': userProfile.userId,
      r'$matrix_room_id': room.id,
      r'$matrix_display_name': userProfile.displayName ?? '',
      r'$matrix_avatar_url': userProfile.avatarUrl?.toString() ?? '',
      // removing potentially dangerous keys containing anything but
      // `[a-zA-Z0-9_-]` as well as non string values
      ...Map.from(data)
        ..removeWhere((key, value) =>
            !RegExp(r'^[\w-]+$').hasMatch(key) || !value is String)
        ..map((key, value) => MapEntry('\$key', value)),
    };

    replaceMap.forEach((key, value) {
      parsedUri = parsedUri.replaceAll(key, Uri.encodeComponent(value));
    });

    return Uri.parse(parsedUri);
  }
}
