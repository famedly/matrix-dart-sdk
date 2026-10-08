// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:vodozemac/vodozemac.dart' as vod;

import '../../matrix.dart';
import 'pickle_key.dart';
import 'stored_inbound_group_session.dart';

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

  /// Whether the creator of this session agreed that it may be shared with
  /// users invited later (MSC4268). matrix-rust-sdk sends `m.shared_history`
  /// and older versions the unstable key, so we accept all of them.
  bool get sharedHistory =>
      sharedHistoryKeys.any((key) => content[key] == true);

  static const sharedHistoryKeys = [
    'shared_history',
    'm.shared_history',
    'org.matrix.msc3061.shared_history',
  ];

  /// `shared_history` is the spec name. matrix-rust-sdk only reads
  /// `m.shared_history` or the unstable key, so we write the latter as well.
  static Map<String, bool> sharedHistoryContent(bool sharedHistory) => {
    'shared_history': sharedHistory,
    'org.matrix.msc3061.shared_history': sharedHistory,
  };

  /// The user who shared this session with us in a key bundle (MSC4268). We
  /// only have their word that the claimed sender created this session, so
  /// this should be shown to the user.
  String? get sharedBy => content.tryGet<String>(sharedByKey);

  static const sharedByKey = 'com.famedly.msc4268.shared_by';

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
  }) : indexes = indexes ?? <String, String>{},
       allowedAtIndex = allowedAtIndex ?? <String, Map<String, int>>{};

  SessionKey.fromDb(StoredInboundGroupSession dbEntry, this.key)
    : content = Event.getMapFromPayload(dbEntry.content),
      indexes = Event.getMapFromPayload(
        dbEntry.indexes,
      ).catchMap((k, v) => MapEntry<String, String>(k, v)),
      allowedAtIndex = Event.getMapFromPayload(
        dbEntry.allowedAtIndex,
      ).catchMap((k, v) => MapEntry(k, Map<String, int>.from(v))),
      roomId = dbEntry.roomId,
      sessionId = dbEntry.sessionId,
      senderKey = dbEntry.senderKey {
    final parsedSenderClaimedKeys = Event.getMapFromPayload(
      dbEntry.senderClaimedKeys,
    ).catchMap((k, v) => MapEntry<String, String>(k, v));
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
        Logs().d('Unable to unpickle inboundGroupSession. Try LibOlm format.');
        inboundGroupSession = vod.InboundGroupSession.fromOlmPickleEncrypted(
          pickle: dbEntry.pickle,
          pickleKey: utf8.encode(key),
        );
      } catch (_) {
        Logs().e('[Vodozemac] Unable to unpickle inboundGroupSession', e, s);
        rethrow;
      }
    }
  }
}
