import '../basic_event.dart';
import '../../utils/try_get_map_extension.dart';

extension RoomKeyRequestContentBasicEventExtension on BasicEvent {
  RoomKeyRequestContent get parsedRoomKeyRequestContent =>
      RoomKeyRequestContent.fromJson(content);
}

class RoomKeyRequestContent {
  RequestedKeyInfo body;
  String action;
  String requestingDeviceId;
  String requestId;

  RoomKeyRequestContent.fromJson(Map<String, dynamic> json)
      : body = RequestedKeyInfo.fromJson(
            json.tryGet<Map<String, dynamic>>('body')),
        action = json.tryGet<String>('action', ''),
        requestingDeviceId = json.tryGet<String>('requesting_device_id', ''),
        requestId = json.tryGet<String>('request_id', '');

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (body != null) data['body'] = body.toJson();
    data['action'] = action;
    data['requesting_device_id'] = requestingDeviceId;
    data['request_id'] = requestId;
    return data;
  }
}

class RequestedKeyInfo {
  String algorithm;
  String roomId;
  String sessionId;
  String senderKey;

  RequestedKeyInfo();

  factory RequestedKeyInfo.fromJson(Map<String, dynamic> json) {
    if (json == null) return null;
    final requestKeyInfo = RequestedKeyInfo();
    requestKeyInfo.algorithm = json.tryGet<String>('algorithm', '');
    requestKeyInfo.roomId = json.tryGet<String>('room_id', '');
    requestKeyInfo.sessionId = json.tryGet<String>('session_id', '');
    requestKeyInfo.senderKey = json.tryGet<String>('sender_key', '');
    return requestKeyInfo;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['algorithm'] = algorithm;
    data['room_id'] = roomId;
    data['session_id'] = sessionId;
    data['sender_key'] = senderKey;
    return data;
  }
}
