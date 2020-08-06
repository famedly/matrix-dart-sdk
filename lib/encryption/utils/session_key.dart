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

import 'package:famedlysdk/src/utils/logs.dart';
import 'package:olm/olm.dart' as olm;
import 'package:famedlysdk/famedlysdk.dart';

import '../../src/database/database.dart' show DbInboundGroupSession;

class SessionKey {
  Map<String, dynamic> content;
  Map<String, int> indexes;
  olm.InboundGroupSession inboundGroupSession;
  final String key;
  List<dynamic> get forwardingCurve25519KeyChain =>
      content['forwarding_curve25519_key_chain'] ?? [];
  String get senderClaimedEd25519Key =>
      content['sender_claimed_ed25519_key'] ?? '';
  String get senderKey => content['sender_key'] ?? '';
  bool get isValid => inboundGroupSession != null;

  SessionKey({this.content, this.inboundGroupSession, this.key, this.indexes});

  SessionKey.fromDb(DbInboundGroupSession dbEntry, String key) : key = key {
    final parsedContent = Event.getMapFromPayload(dbEntry.content);
    final parsedIndexes = Event.getMapFromPayload(dbEntry.indexes);
    content =
        parsedContent != null ? Map<String, dynamic>.from(parsedContent) : null;
    indexes = parsedIndexes != null
        ? Map<String, int>.from(parsedIndexes)
        : <String, int>{};
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
