// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite.dart';

extension RoomEncryptedContentBasicEventExtension on BasicEvent {
  RoomEncryptedContent get parsedRoomEncryptedContent =>
      RoomEncryptedContent.fromJson(content);
}

class RoomEncryptedContent {
  String algorithm;
  String senderKey;
  String? deviceId;
  String? sessionId;
  String? ciphertextMegolm;
  Map<String, CiphertextInfo>? ciphertextOlm;

  RoomEncryptedContent.fromJson(Map<String, Object?> json)
    : algorithm = json.tryGet('algorithm', TryGet.required) ?? '',
      senderKey = json.tryGet('sender_key', TryGet.required) ?? '',
      deviceId = json.tryGet('device_id'),
      sessionId = json.tryGet('session_id'),
      ciphertextMegolm = json.tryGet('ciphertext', TryGet.silent),
      // filter out invalid/incomplete CiphertextInfos
      ciphertextOlm = json
          .tryGet<Map<String, Object?>>('ciphertext', TryGet.silent)
          ?.catchMap(
            (k, v) =>
                MapEntry(k, CiphertextInfo.fromJson(v as Map<String, Object?>)),
          );

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    data['algorithm'] = algorithm;
    data['sender_key'] = senderKey;
    if (deviceId != null) {
      data['device_id'] = deviceId;
    }
    if (sessionId != null) {
      data['session_id'] = sessionId;
    }
    if (ciphertextMegolm != null) {
      data['ciphertext'] = ciphertextMegolm;
    }
    if (ciphertextOlm != null) {
      data['ciphertext'] = ciphertextOlm!.map(
        (k, v) => MapEntry(k, v.toJson()),
      );
      if (ciphertextMegolm != null) {
        Logs().wtf(
          'ciphertextOlm and ciphertextMegolm are both set, which should never happen!',
        );
      }
    }
    return data;
  }
}

class CiphertextInfo {
  String body;
  int type;

  CiphertextInfo.fromJson(Map<String, Object?> json)
    : body = json['body'] as String,
      type = json['type'] as int;

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    data['body'] = body;
    data['type'] = type;
    return data;
  }
}
