import '../basic_event.dart';
import '../../utils/try_get_map_extension.dart';

extension RoomEncryptionContentBasicEventExtension on BasicEvent {
  RoomEncryptionContent get parsedRoomEncryptionContent =>
      RoomEncryptionContent.fromJson(content);
}

class RoomEncryptionContent {
  String algorithm;
  int rotationPeriodMs;
  int rotationPeriodMsgs;

  RoomEncryptionContent.fromJson(Map<String, dynamic> json)
      : algorithm = json.tryGet<String>('algorithm', ''),
        rotationPeriodMs = json.tryGet<int>('rotation_period_ms'),
        rotationPeriodMsgs = json.tryGet<int>('rotation_period_msgs');

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['algorithm'] = algorithm;
    if (rotationPeriodMs != null) {
      data['rotation_period_ms'] = rotationPeriodMs;
    }
    if (rotationPeriodMsgs != null) {
      data['rotation_period_msgs'] = rotationPeriodMsgs;
    }
    return data;
  }
}
