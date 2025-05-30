/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020, 2021 Famedly GmbH
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

  OlmSession.fromJson(Map<String, dynamic> dbEntry, this.key)
      : identityKey = dbEntry['identity_key'] ?? '' {
    try {
      try {
        session = vod.Session.fromPickleEncrypted(
          pickleKey: key.toPickleKey(),
          pickle: dbEntry['pickle'],
        );
      } catch (_) {
        Logs().d('Unable to unpickle Olm session. Try LibOlm format.');
        session = vod.Session.fromOlmPickleEncrypted(
          pickleKey: utf8.encode(key),
          pickle: dbEntry['pickle'],
        );
      }
      sessionId = dbEntry['session_id'];
      lastReceived =
          DateTime.fromMillisecondsSinceEpoch(dbEntry['last_received'] ?? 0);
      assert(sessionId == session!.sessionId);
    } catch (e, s) {
      Logs().e('[Vodozemac] Could not unpickle olm session', e, s);
    }
  }
}
