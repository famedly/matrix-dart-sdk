// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../utils/identifier_validation.dart';
import '../utils/logs.dart';

/// A Matrix room ID (`!localpart:server_name` or domainless `!opaque_id`).
extension type const RoomId(String value) {
  /// Creates a [RoomId] from a raw string, logging a warning if malformed.
  factory RoomId.fromString(String value) {
    if (!isValidRoomId(value)) {
      Logs().w('Malformed Matrix Room ID: "$value"');
    }
    return RoomId(value);
  }

  factory RoomId.fromParts(String localpart, [String? serverName]) {
    final str = serverName == null ? '!$localpart' : '!$localpart:$serverName';
    return RoomId.fromString(str);
  }

  static RoomId? tryParse(String? value) {
    if (value == null || !isValidRoomId(value)) return null;
    return RoomId(value);
  }

  bool get isValid => isValidRoomId(value);

  String get sigil => '!';

  /// Localpart without leading sigil or server name.
  String get localpart {
    if (value.isEmpty) return '';
    final start = value.startsWith('!') ? 1 : 0;
    final colonIndex = value.indexOf(':', start);
    return colonIndex == -1
        ? value.substring(start)
        : value.substring(start, colonIndex);
  }

  /// Server name, or `null` for domainless room IDs (room v12).
  String? get serverName {
    final colonIndex = value.indexOf(':');
    return colonIndex == -1 ? null : value.substring(colonIndex + 1);
  }

  String? get domain => serverName;

  bool get hasDomain => serverName != null;

  String toJson() => value;
}
