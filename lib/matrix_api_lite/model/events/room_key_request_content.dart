// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite/model/basic_event.dart';
import 'package:matrix/matrix_api_lite/utils/try_get_map_extension.dart';

extension RoomKeyRequestContentBasicEventExtension on BasicEvent {
  RoomKeyRequestContent get parsedRoomKeyRequestContent =>
      RoomKeyRequestContent.fromJson(content);
}

class RoomKeyRequestContent {
  RequestedKeyInfo? body;
  String action;
  String requestingDeviceId;
  String requestId;

  RoomKeyRequestContent.fromJson(Map<String, Object?> json)
      : body = ((Map<String, Object?>? x) => x != null
            ? RequestedKeyInfo.fromJson(x)
            : null)(json.tryGet('body')),
        action = json.tryGet('action', TryGet.required) ?? '',
        requestingDeviceId =
            json.tryGet('requesting_device_id', TryGet.required) ?? '',
        requestId = json.tryGet('request_id', TryGet.required) ?? '';

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    if (body != null) data['body'] = body!.toJson();
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

  RequestedKeyInfo({
    required this.algorithm,
    required this.roomId,
    required this.sessionId,
    required this.senderKey,
  });

  RequestedKeyInfo.fromJson(Map<String, Object?> json)
      : algorithm = json.tryGet('algorithm', TryGet.required) ?? '',
        roomId = json.tryGet('room_id', TryGet.required) ?? '',
        sessionId = json.tryGet('session_id', TryGet.required) ?? '',
        senderKey = json.tryGet('sender_key', TryGet.required) ?? '';

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    data['algorithm'] = algorithm;
    data['room_id'] = roomId;
    data['session_id'] = sessionId;
    data['sender_key'] = senderKey;
    return data;
  }
}
