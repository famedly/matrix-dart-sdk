// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../../utils/try_get_map_extension.dart';
import '../basic_event.dart';

extension RoomKeyContentBasicEventExtension on BasicEvent {
  RoomKeyContent get parsedRoomKeyContent => RoomKeyContent.fromJson(content);
}

class RoomKeyContent {
  String algorithm;
  String roomId;
  String sessionId;
  String sessionKey;

  RoomKeyContent({
    required this.algorithm,
    required this.roomId,
    required this.sessionId,
    required this.sessionKey,
  });

  RoomKeyContent.fromJson(Map<String, Object?> json)
    : algorithm = json.tryGet('algorithm', TryGet.required) ?? '',
      roomId = json.tryGet('room_id', TryGet.required) ?? '',
      sessionId = json.tryGet('session_id', TryGet.required) ?? '',
      sessionKey = json.tryGet('session_key', TryGet.required) ?? '';

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    data['algorithm'] = algorithm;
    data['room_id'] = roomId;
    data['session_id'] = sessionId;
    data['session_key'] = sessionKey;
    return data;
  }
}
