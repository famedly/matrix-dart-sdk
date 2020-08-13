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

import '../../src/database/database.dart' show DbOutboundGroupSession;
import '../../src/utils/logs.dart';

class OutboundGroupSession {
  List<String> devices;
  DateTime creationTime;
  olm.OutboundGroupSession outboundGroupSession;
  int sentMessages;
  bool get isValid => outboundGroupSession != null;
  final String key;

  OutboundGroupSession(
      {this.devices,
      this.creationTime,
      this.outboundGroupSession,
      this.sentMessages,
      this.key});

  OutboundGroupSession.fromDb(DbOutboundGroupSession dbEntry, String key)
      : key = key {
    outboundGroupSession = olm.OutboundGroupSession();
    try {
      outboundGroupSession.unpickle(key, dbEntry.pickle);
      devices = List<String>.from(json.decode(dbEntry.deviceIds));
      creationTime = dbEntry.creationTime;
      sentMessages = dbEntry.sentMessages;
    } catch (e, s) {
      dispose();
      Logs.error(
          '[LibOlm] Unable to unpickle outboundGroupSession: ' + e.toString(),
          s);
    }
  }

  void dispose() {
    outboundGroupSession?.free();
    outboundGroupSession = null;
  }
}
