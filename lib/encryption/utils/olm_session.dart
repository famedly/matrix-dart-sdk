// SPDX-FileCopyrightText: 2019-Present, 2020, 2021 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:matrix/encryption/utils/pickle_key.dart';
import 'package:matrix/matrix.dart';

class OlmSession {
  String identityKey;
  String? sessionId;
  vod.Session? session;
  DateTime? lastReceived;
  final String key;
  String? get pickledSession => session?.toPickleEncrypted(key.toPickleKey());

  bool get isValid => session != null;

  OlmSession({
    required this.key,
    required this.identityKey,
    required this.sessionId,
    required this.session,
    required this.lastReceived,
  });

  OlmSession.fromJson(Map<String, Object?> dbEntry, this.key)
      : identityKey = dbEntry.tryGet<String>('identity_key') ?? '' {
    try {
      try {
        session = vod.Session.fromPickleEncrypted(
          pickleKey: key.toPickleKey(),
          pickle: dbEntry['pickle'] as String,
        );
      } catch (_) {
        Logs().d('Unable to unpickle Olm session. Try LibOlm format.');
        session = vod.Session.fromOlmPickleEncrypted(
          pickleKey: utf8.encode(key),
          pickle: dbEntry['pickle'] as String,
        );
      }
      sessionId = dbEntry['session_id'] as String;
      lastReceived = DateTime.fromMillisecondsSinceEpoch(
        dbEntry.tryGet<int>('last_received') ?? 0,
      );
      assert(sessionId == session!.sessionId);
    } catch (e, s) {
      Logs().e('[Vodozemac] Could not unpickle olm session', e, s);
    }
  }
}
