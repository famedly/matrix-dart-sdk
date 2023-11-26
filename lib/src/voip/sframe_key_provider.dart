abstract class EncryptionKeyProvider {
  Future<void> onSetEncryptionKey(String participant, String key, int index);
}

class EncryptionKeyEntry {
  final int index;
  final String key;
  EncryptionKeyEntry(this.index, this.key);

  factory EncryptionKeyEntry.fromJson(Map<String, dynamic> json) =>
      EncryptionKeyEntry(
        json['index'] as int,
        json['key'] as String,
      );

  Map<String, dynamic> toJson() => {
        'index': index,
        'key': key,
      };
}

class EncryptionKeysEventContent {
  final List<EncryptionKeyEntry> keys;
  final String deviceId;
  final String callId;
  EncryptionKeysEventContent(this.keys, this.deviceId, this.callId);

  factory EncryptionKeysEventContent.fromJson(Map<String, dynamic> json) =>
      EncryptionKeysEventContent(
        (json['keys'] as List<dynamic>)
            .map((e) => EncryptionKeyEntry.fromJson(e as Map<String, dynamic>))
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
