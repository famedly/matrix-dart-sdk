/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:convert';

import 'package:olm/olm.dart' as olm;

import '../../famedlysdk.dart';
import '../../src/database/database.dart' show DbInboundGroupSession;
import '../../src/utils/logs.dart';

class SessionKey {
  Map<String, dynamic> content;
  Map<String, String> indexes;
  olm.InboundGroupSession inboundGroupSession;
  final String key;
  List<String> get forwardingCurve25519KeyChain =>
      (content['forwarding_curve25519_key_chain'] != null
          ? List<String>.from(content['forwarding_curve25519_key_chain'])
          : null) ??
      <String>[];
  Map<String, String> senderClaimedKeys;
  String senderKey;
  bool get isValid => inboundGroupSession != null;
  String roomId;
  String sessionId;

  SessionKey(
      {this.content,
      this.inboundGroupSession,
      this.key,
      this.indexes,
      this.roomId,
      this.sessionId,
      String senderKey,
      Map<String, String> senderClaimedKeys}) {
    _setSenderKey(senderKey);
    _setSenderClaimedKeys(senderClaimedKeys);
  }

  SessionKey.fromDb(DbInboundGroupSession dbEntry, String key) : key = key {
    final parsedContent = Event.getMapFromPayload(dbEntry.content);
    final parsedIndexes = Event.getMapFromPayload(dbEntry.indexes);
    final parsedSenderClaimedKeys =
        Event.getMapFromPayload(dbEntry.senderClaimedKeys);
    content =
        parsedContent != null ? Map<String, dynamic>.from(parsedContent) : null;
    // we need to try...catch as the map used to be <String, int> and that will throw an error.
    try {
      indexes = parsedIndexes != null
          ? Map<String, String>.from(parsedIndexes)
          : <String, String>{};
    } catch (e) {
      indexes = <String, String>{};
    }
    roomId = dbEntry.roomId;
    sessionId = dbEntry.sessionId;
    _setSenderKey(dbEntry.senderKey);
    _setSenderClaimedKeys(Map<String, String>.from(parsedSenderClaimedKeys));

    inboundGroupSession = olm.InboundGroupSession();
    try {
      inboundGroupSession.unpickle(key, dbEntry.pickle);
    } catch (e, s) {
      dispose();
      Logs.error(
          '[LibOlm] Unable to unpickle inboundGroupSession: ' + e.toString(),
          s);
    }
  }

  void _setSenderKey(String key) {
    senderKey = key ?? content['sender_key'] ?? '';
  }

  void _setSenderClaimedKeys(Map<String, String> keys) {
    senderClaimedKeys = (keys != null && keys.isNotEmpty)
        ? keys
        : (content['sender_claimed_keys'] is Map
            ? Map<String, String>.from(content['sender_claimed_keys'])
            : (content['sender_claimed_ed25519_key'] is String
                ? <String, String>{
                    'ed25519': content['sender_claimed_ed25519_key']
                  }
                : <String, String>{}));
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

  void dispose() {
    inboundGroupSession?.free();
    inboundGroupSession = null;
  }

  @override
  String toString() => json.encode(toJson());
}
