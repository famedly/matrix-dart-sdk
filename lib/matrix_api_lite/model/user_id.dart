// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../utils/identifier_validation.dart';
import '../utils/logs.dart';

/// A Matrix user ID (`@localpart:server_name`).
extension type const UserId(String value) {
  /// Creates a [UserId] from a raw string, logging a warning if malformed.
  factory UserId.fromString(String value) {
    if (!isValidUserId(value)) {
      Logs().w('Malformed Matrix User ID: "$value"');
    }
    return UserId(value);
  }

  factory UserId.fromParts(String localpart, String serverName) =>
      UserId.fromString('@$localpart:$serverName');

  static UserId? tryParse(String? value) {
    if (value == null || !isValidUserId(value)) return null;
    return UserId(value);
  }

  bool get isValid => isValidUserId(value);

  String get sigil => '@';

  /// Localpart without leading sigil or server name.
  String get localpart {
    if (value.isEmpty) return '';
    final start = value.startsWith('@') ? 1 : 0;
    final colonIndex = value.indexOf(':', start);
    return colonIndex == -1
        ? value.substring(start)
        : value.substring(start, colonIndex);
  }

  String get serverName {
    final colonIndex = value.indexOf(':');
    return colonIndex == -1 ? '' : value.substring(colonIndex + 1);
  }

  String? get domain => serverName.isEmpty ? null : serverName;

  bool get hasDomain => serverName.isNotEmpty;

  String toJson() => value;
}
