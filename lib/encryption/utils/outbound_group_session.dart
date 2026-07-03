// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:matrix/encryption/utils/pickle_key.dart';
import 'package:matrix/matrix.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

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

    creationTime = DateTime.fromMillisecondsSinceEpoch(
      dbEntry['creation_time'],
    );

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
        Logs().e('[Vodozemac] Unable to unpickle outboundGroupSession', e, s);
      }
    }
  }
}
