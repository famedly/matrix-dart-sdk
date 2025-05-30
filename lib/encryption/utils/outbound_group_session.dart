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
import 'package:matrix/matrix.dart';

class OutboundGroupSession {
  /// The devices is a map from user id to device id to if the device is blocked.
  /// This way we can easily know if a new user is added, leaves, a new devices is added, and,
  /// very importantly, if we block a device. These are all important for determining if/when
  /// an outbound session needs to be rotated.
  Map<String, Map<String, bool>> devices = {};
  // Default to a date, that would get this session rotated in any case to make handling easier
  DateTime creationTime = DateTime.fromMillisecondsSinceEpoch(0);
  vod.GroupSession? outboundGroupSession;
  int? get sentMessages => outboundGroupSession?.messageIndex;
  bool get isValid => outboundGroupSession != null;
  final String key;

  OutboundGroupSession({
    required this.devices,
    required this.creationTime,
    required this.outboundGroupSession,
    required this.key,
  });

  OutboundGroupSession.fromJson(Map<String, dynamic> dbEntry, this.key) {
    try {
      for (final entry in json.decode(dbEntry['device_ids']).entries) {
        devices[entry.key] = Map<String, bool>.from(entry.value);
      }
    } catch (e) {
      // devices is bad (old data), so just not use this session
      Logs().i(
        '[OutboundGroupSession] Session in database is old, not using it. $e',
      );
      return;
    }

    creationTime =
        DateTime.fromMillisecondsSinceEpoch(dbEntry['creation_time']);

    try {
      outboundGroupSession = vod.GroupSession.fromPickleEncrypted(
        pickleKey: key.toPickleKey(),
        pickle: dbEntry['pickle'],
      );
    } catch (e, s) {
      try {
        outboundGroupSession = vod.GroupSession.fromOlmPickleEncrypted(
          pickleKey: utf8.encode(key),
          pickle: dbEntry['pickle'],
        );
      } catch (_) {
        Logs().e('[LibOlm] Unable to unpickle outboundGroupSession', e, s);
      }
    }
  }
}
