// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../utils/identifier_validation.dart';
import '../utils/logs.dart';

/// A Matrix room alias (`#localpart:server_name`).
extension type const RoomAlias(String value) {
  /// Creates a [RoomAlias] from a raw string, logging a warning if malformed.
  factory RoomAlias.fromString(String value) {
    if (!isValidRoomAlias(value)) {
      Logs().w('Malformed Matrix Room Alias: "$value"');
    }
    return RoomAlias(value);
  }

  factory RoomAlias.fromParts(String localpart, String serverName) =>
      RoomAlias.fromString('#$localpart:$serverName');

  static RoomAlias? tryParse(String? value) {
    if (value == null || !isValidRoomAlias(value)) return null;
    return RoomAlias(value);
  }

  bool get isValid => isValidRoomAlias(value);

  String get sigil => '#';

  /// Localpart without leading sigil or server name.
  String get localpart {
    if (value.isEmpty) return '';
    final start = value.startsWith('#') ? 1 : 0;
    final colonIndex = value.indexOf(':', start);
    return colonIndex == -1
        ? value.substring(start)
        : value.substring(start, colonIndex);
  }

  String get serverName {
    final colonIndex = value.indexOf(':');
    return colonIndex == -1 ? '' : value.substring(colonIndex + 1);
  }

  String get domain => serverName;

  bool get hasDomain => serverName.isNotEmpty;

  String toJson() => value;
}
