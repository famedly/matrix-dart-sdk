import 'package:matrix_api_lite/src/utils/logs.dart';

import '../basic_event.dart';
import '../../utils/try_get_map_extension.dart';

extension RoomEncryptedContentBasicEventExtension on BasicEvent {
  RoomEncryptedContent get parsedRoomEncryptedContent =>
      RoomEncryptedContent.fromJson(content);
}

class RoomEncryptedContent {
  String algorithm;
  String senderKey;
  String deviceId;
  String sessionId;
  String ciphertextMegolm;
  Map<String, CiphertextInfo> ciphertextOlm;

  RoomEncryptedContent.fromJson(Map<String, dynamic> json)
      : algorithm = json.tryGet<String>('algorithm', ''),
        senderKey = json.tryGet<String>('sender_key', ''),
        deviceId = json.tryGet<String>('device_id'),
        sessionId = json.tryGet<String>('session_id'),
        ciphertextMegolm = json['ciphertext'] is String
            ? json.tryGet<String>('ciphertext')
            : null,
        ciphertextOlm = json['ciphertext'] is Map<String, dynamic>
            ? json
                .tryGet<Map<String, dynamic>>('ciphertext')
                ?.map((k, v) => MapEntry(k, CiphertextInfo.fromJson(v)))
            : null;

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
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
      data['ciphertext'] = ciphertextOlm.map((k, v) => MapEntry(k, v.toJson()));
      if (ciphertextMegolm != null) {
        Logs().wtf(
            'ciphertextOlm and ciphertextMegolm are both set, which should never happen!');
      }
    }
    return data;
  }
}

class CiphertextInfo {
  String body;
  int type;

  CiphertextInfo.fromJson(Map<String, dynamic> json)
      : body = json.tryGet<String>('body'),
        type = json.tryGet<int>('type');

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (body != null) {
      data['body'] = body;
    }
    if (type != null) {
      data['type'] = type;
    }
    return data;
  }
}
