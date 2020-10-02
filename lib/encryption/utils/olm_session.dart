/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020 Famedly GmbH
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

import '../../src/database/database.dart' show DbOlmSessions;
import '../../src/utils/logs.dart';

class OlmSession {
  String identityKey;
  String sessionId;
  olm.Session session;
  DateTime lastReceived;
  final String key;
  String get pickledSession => session.pickle(key);

  bool get isValid => session != null;

  OlmSession({
    this.key,
    this.identityKey,
    this.sessionId,
    this.session,
    this.lastReceived,
  });

  OlmSession.fromDb(DbOlmSessions dbEntry, String key) : key = key {
    session = olm.Session();
    try {
      session.unpickle(key, dbEntry.pickle);
      identityKey = dbEntry.identityKey;
      sessionId = dbEntry.sessionId;
      lastReceived =
          DateTime.fromMillisecondsSinceEpoch(dbEntry.lastReceived ?? 0);
      assert(sessionId == session.session_id());
    } catch (e, s) {
      Logs.error('[LibOlm] Could not unpickle olm session: ' + e.toString(), s);
      dispose();
    }
  }

  void dispose() {
    session?.free();
    session = null;
  }
}
