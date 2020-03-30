import 'dart:convert';

import 'package:olm/olm.dart';

class SessionKey {
  Map<String, dynamic> content;
  Map<String, int> indexes;
  InboundGroupSession inboundGroupSession;
  final String key;
  List<dynamic> get forwardingCurve25519KeyChain =>
      content['forwarding_curve25519_key_chain'] ?? [];
  String get senderClaimedEd25519Key =>
      content['sender_claimed_ed25519_key'] ?? '';

  SessionKey({this.content, this.inboundGroupSession, this.key, this.indexes});

  SessionKey.fromJson(Map<String, dynamic> json, String key) : key = key {
    content = json['content'] != null
        ? Map<String, dynamic>.from(json['content'])
        : null;
    indexes = json['indexes'] != null
        ? Map<String, int>.from(json['indexes'])
        : <String, int>{};
    var newInboundGroupSession = InboundGroupSession();
    newInboundGroupSession.unpickle(key, json['inboundGroupSession']);
    inboundGroupSession = newInboundGroupSession;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (content != null) {
      data['content'] = content;
    }
    if (indexes != null) {
      data['indexes'] = indexes;
    }
    data['inboundGroupSession'] = inboundGroupSession.pickle(key);
    return data;
  }

  @override
  String toString() => json.encode(toJson());
}
