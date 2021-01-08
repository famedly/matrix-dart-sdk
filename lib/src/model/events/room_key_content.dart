import '../basic_event.dart';
import '../../utils/try_get_map_extension.dart';

extension RoomKeyContentBasicEventExtension on BasicEvent {
  RoomKeyContent get parsedRoomKeyContent => RoomKeyContent.fromJson(content);
}

class RoomKeyContent {
  String algorithm;
  String roomId;
  String sessionId;
  String sessionKey;

  RoomKeyContent.fromJson(Map<String, dynamic> json)
      : algorithm = json.tryGet<String>('algorithm', ''),
        roomId = json.tryGet<String>('room_id', ''),
        sessionId = json.tryGet<String>('session_id', ''),
        sessionKey = json.tryGet<String>('session_key', '');

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['algorithm'] = algorithm;
    data['room_id'] = roomId;
    data['session_id'] = sessionId;
    data['session_key'] = sessionKey;
    return data;
  }
}
