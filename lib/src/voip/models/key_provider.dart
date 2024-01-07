import 'package:matrix/matrix.dart';

enum E2EEKeyMode {
  kNone,
  kSharedKey,
  kPerParticipant,
}

abstract class EncryptionKeyProvider {
  Future<void> onSetEncryptionKey(
      Participant participant, String key, int index);
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
  // Get the participant info from todevice message params
  final List<EncryptionKeyEntry> keys;
  final String callId;
  final Participant participant;
  EncryptionKeysEventContent(this.keys, this.callId, this.participant);

  factory EncryptionKeysEventContent.fromJson(Map<String, dynamic> json) =>
      EncryptionKeysEventContent(
        (json['keys'] as List<dynamic>)
            .map((e) => EncryptionKeyEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        json['call_id'] as String,
        Participant.fromJson(json['participant'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'keys': keys.map((e) => e.toJson()).toList(),
        'call_id': callId,
        'participant': participant.toJson(),
      };
}
