/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020, 2021 Famedly GmbH
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

import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:matrix/encryption/utils/pickle_key.dart';
import 'package:matrix/encryption/utils/stored_inbound_group_session.dart';
import 'package:matrix/matrix.dart';

class SessionKey {
  /// The raw json content of the key
  Map<String, dynamic> content = <String, dynamic>{};

  /// Map of stringified-index to event id, so that we can detect replay attacks
  Map<String, String> indexes;

  /// Map of userId to map of deviceId to index, that we know that device receivied, e.g. sending it ourself.
  /// Used for automatically answering key requests
  Map<String, Map<String, int>> allowedAtIndex;

  /// Underlying olm [InboundGroupSession] object
  vod.InboundGroupSession? inboundGroupSession;

  /// Key for libolm pickle / unpickle
  final String key;

  /// Forwarding keychain
  List<String> get forwardingCurve25519KeyChain =>
      (content['forwarding_curve25519_key_chain'] != null
          ? List<String>.from(content['forwarding_curve25519_key_chain'])
          : null) ??
      <String>[];

  /// Claimed keys of the original sender
  late Map<String, String> senderClaimedKeys;

  /// Sender curve25519 key
  String senderKey;

  /// Is this session valid?
  bool get isValid => inboundGroupSession != null;

  /// roomId for this session
  String roomId;

  /// Id of this session
  String sessionId;

  SessionKey({
    required this.content,
    required this.inboundGroupSession,
    required this.key,
    Map<String, String>? indexes,
    Map<String, Map<String, int>>? allowedAtIndex,
    required this.roomId,
    required this.sessionId,
    required this.senderKey,
    required this.senderClaimedKeys,
  })  : indexes = indexes ?? <String, String>{},
        allowedAtIndex = allowedAtIndex ?? <String, Map<String, int>>{};

  SessionKey.fromDb(StoredInboundGroupSession dbEntry, this.key)
      : content = Event.getMapFromPayload(dbEntry.content),
        indexes = Event.getMapFromPayload(dbEntry.indexes)
            .catchMap((k, v) => MapEntry<String, String>(k, v)),
        allowedAtIndex = Event.getMapFromPayload(dbEntry.allowedAtIndex)
            .catchMap((k, v) => MapEntry(k, Map<String, int>.from(v))),
        roomId = dbEntry.roomId,
        sessionId = dbEntry.sessionId,
        senderKey = dbEntry.senderKey {
    final parsedSenderClaimedKeys =
        Event.getMapFromPayload(dbEntry.senderClaimedKeys)
            .catchMap((k, v) => MapEntry<String, String>(k, v));
    // we need to try...catch as the map used to be <String, int> and that will throw an error.
    senderClaimedKeys = (parsedSenderClaimedKeys.isNotEmpty)
        ? parsedSenderClaimedKeys
        : (content
                .tryGetMap<String, dynamic>('sender_claimed_keys')
                ?.catchMap((k, v) => MapEntry<String, String>(k, v)) ??
            (content['sender_claimed_ed25519_key'] is String
                ? <String, String>{
                    'ed25519': content['sender_claimed_ed25519_key'],
                  }
                : <String, String>{}));

    try {
      inboundGroupSession = vod.InboundGroupSession.fromPickleEncrypted(
        pickle: dbEntry.pickle,
        pickleKey: key.toPickleKey(),
      );
    } catch (e, s) {
      try {
        inboundGroupSession = vod.InboundGroupSession.fromOlmPickleEncrypted(
          pickle: dbEntry.pickle,
          pickleKey: utf8.encode(key),
        );
      } catch (_) {
        Logs().e('[LibOlm] Unable to unpickle inboundGroupSession', e, s);
        rethrow;
      }
    }
  }
}
