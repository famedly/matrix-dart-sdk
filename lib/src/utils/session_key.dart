import 'dart:convert';

import 'package:olm/olm.dart';

class SessionKey {
  Map<String, dynamic> content;
  Map<String, int> indexes;
  InboundGroupSession inboundGroupSession;
  final String key;

  SessionKey({this.content, this.inboundGroupSession, this.key, this.indexes});

  SessionKey.fromJson(Map<String, dynamic> json, String key) : this.key = key {
    content = json['content'] != null
        ? Map<String, dynamic>.from(json['content'])
        : null;
    indexes = json['indexes'] != null
        ? Map<String, int>.from(json['indexes'])
        : Map<String, int>();
    InboundGroupSession newInboundGroupSession = InboundGroupSession();
    newInboundGroupSession.unpickle(key, json['inboundGroupSession']);
    inboundGroupSession = newInboundGroupSession;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    if (this.content != null) {
      data['content'] = this.content;
    }
    if (this.indexes != null) {
      data['indexes'] = this.indexes;
    }
    data['inboundGroupSession'] = this.inboundGroupSession.pickle(this.key);
    return data;
  }

  String toString() => json.encode(this.toJson());
}
