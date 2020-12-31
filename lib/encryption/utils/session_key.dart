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

import 'package:olm/olm.dart' as olm;

import '../../famedlysdk.dart';
import '../../src/database/database.dart' show DbInboundGroupSession;

class SessionKey {
  /// The raw json content of the key
  Map<String, dynamic> content;

  /// Map of stringified-index to event id, so that we can detect replay attacks
  Map<String, String> indexes;

  /// Map of userId to map of deviceId to index, that we know that device receivied, e.g. sending it ourself.
  /// Used for automatically answering key requests
  Map<String, Map<String, int>> allowedAtIndex;

  /// Underlying olm [InboundGroupSession] object
  olm.InboundGroupSession inboundGroupSession;

  /// Key for libolm pickle / unpickle
  final String key;

  /// Forwarding keychain
  List<String> get forwardingCurve25519KeyChain =>
      (content['forwarding_curve25519_key_chain'] != null
          ? List<String>.from(content['forwarding_curve25519_key_chain'])
          : null) ??
      <String>[];

  /// Claimed keys of the original sender
  Map<String, String> senderClaimedKeys;

  /// Sender curve25519 key
  String senderKey;

  /// Is this session valid?
  bool get isValid => inboundGroupSession != null;

  /// roomId for this session
  String roomId;

  /// Id of this session
  String sessionId;

  SessionKey(
      {this.content,
      this.inboundGroupSession,
      this.key,
      this.indexes,
      this.allowedAtIndex,
      this.roomId,
      this.sessionId,
      String senderKey,
      Map<String, String> senderClaimedKeys}) {
    _setSenderKey(senderKey);
    _setSenderClaimedKeys(senderClaimedKeys);
    indexes ??= <String, String>{};
    allowedAtIndex ??= <String, Map<String, int>>{};
  }

  SessionKey.fromDb(DbInboundGroupSession dbEntry, String key) : key = key {
    final parsedContent = Event.getMapFromPayload(dbEntry.content);
    final parsedIndexes = Event.getMapFromPayload(dbEntry.indexes);
    final parsedAllowedAtIndex =
        Event.getMapFromPayload(dbEntry.allowedAtIndex);
    final parsedSenderClaimedKeys =
        Event.getMapFromPayload(dbEntry.senderClaimedKeys);
    content = parsedContent;
    // we need to try...catch as the map used to be <String, int> and that will throw an error.
    try {
      indexes = parsedIndexes != null
          ? Map<String, String>.from(parsedIndexes)
          : <String, String>{};
    } catch (e) {
      indexes = <String, String>{};
    }
    try {
      allowedAtIndex = parsedAllowedAtIndex != null
          ? Map<String, Map<String, int>>.from(parsedAllowedAtIndex
              .map((k, v) => MapEntry(k, Map<String, int>.from(v))))
          : <String, Map<String, int>>{};
    } catch (e) {
      allowedAtIndex = <String, Map<String, int>>{};
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
      Logs().e('[LibOlm] Unable to unpickle inboundGroupSession', e, s);
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

  void dispose() {
    inboundGroupSession?.free();
    inboundGroupSession = null;
  }
}
