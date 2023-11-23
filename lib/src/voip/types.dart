import 'package:matrix/matrix.dart';

extension VoipEventTypes on EventTypes {
  static const String sFrameKeysPrefix = 'com.famedly.sframe.keys';
}

class SframeKeyEntry {
  final int index;
  final String key;
  SframeKeyEntry(this.index, this.key);

  factory SframeKeyEntry.fromJson(Map<String, dynamic> json) => SframeKeyEntry(
        json['index'] as int,
        json['key'] as String,
      );

  Map<String, dynamic> toJson() => {
        'index': index,
        'key': key,
      };
}

class SframeKeysEventContent {
  final List<SframeKeyEntry> keys;
  final String deviceId;
  final String callId;
  SframeKeysEventContent(this.keys, this.deviceId, this.callId);

  factory SframeKeysEventContent.fromJson(Map<String, dynamic> json) =>
      SframeKeysEventContent(
        (json['keys'] as List<dynamic>)
            .map((e) => SframeKeyEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        json['device_id'] as String,
        json['call_id'] as String,
      );

  Map<String, dynamic> toJson() => {
        'keys': keys.map((e) => e.toJson()).toList(),
        'device_id': deviceId,
        'call_id': callId,
      };
}
