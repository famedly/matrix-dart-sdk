// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../utils/identifier_validation.dart';
import '../utils/logs.dart';

/// A Matrix event ID (`$opaque_id` or historical `$localpart:server_name`).
extension type const EventId(String value) {
  /// Creates an [EventId] from a raw string, logging a warning if malformed.
  factory EventId.fromString(String value) {
    if (!isValidEventId(value)) {
      Logs().w('Malformed Matrix Event ID: "$value"');
    }
    return EventId(value);
  }

  factory EventId.fromParts(String localpart, [String? serverName]) {
    final str = serverName == null
        ? '\$$localpart'
        : '\$$localpart:$serverName';
    return EventId.fromString(str);
  }

  static EventId? tryParse(String? value) {
    if (value == null || !isValidEventId(value)) return null;
    return EventId(value);
  }

  bool get isValid => isValidEventId(value);

  String get sigil => r'$';

  /// Localpart without leading sigil or server name.
  String get localpart {
    if (value.isEmpty) return '';
    final start = value.startsWith(r'$') ? 1 : 0;
    final colonIndex = value.indexOf(':', start);
    return colonIndex == -1
        ? value.substring(start)
        : value.substring(start, colonIndex);
  }

  /// Server name, or `null` for modern room v3+ event IDs.
  String? get serverName {
    final colonIndex = value.indexOf(':');
    return colonIndex == -1 ? null : value.substring(colonIndex + 1);
  }

  String? get domain => serverName;

  bool get hasDomain => serverName != null;

  String toJson() => value;
}
