import '../../utils/try_get_map_extension.dart';

class OlmPlaintextPayload {
  String type;
  Map<String, dynamic> content;
  String sender;
  String recipient;
  Map<String, String> recipientKeys;
  Map<String, String> keys;

  OlmPlaintextPayload({
    this.type,
    this.content,
    this.sender,
    this.recipient,
    this.recipientKeys,
    this.keys,
  }) : super();

  factory OlmPlaintextPayload.fromJson(Map<String, dynamic> json) =>
      OlmPlaintextPayload(
        sender: json.tryGet<String>('sender'),
        type: json.tryGet<String>('type'),
        content: json.tryGetMap<String, dynamic>('content'),
        recipient: json.tryGet<String>('recipient'),
        recipientKeys: json.tryGetMap<String, String>('recipient_keys'),
        keys: json.tryGetMap<String, String>('keys'),
      );

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (type != null) data['type'] = type;
    if (sender != null) data['sender'] = sender;
    if (content != null) data['content'] = content;
    if (recipient != null) data['recipient'] = recipient;
    if (recipientKeys != null) data['recipient_keys'] = recipientKeys;
    if (keys != null) data['keys'] = keys;
    return data;
  }
}
