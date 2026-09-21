// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

part of 'matrix_id.dart';

/// A case-sensitive Matrix user ID (`@localpart:server_name`).
///
/// Accepts historical user IDs, including empty and Unicode localparts.
/// Invalid input throws [FormatException].
/// See https://spec.matrix.org/v1.19/appendices/#historical-user-ids.
final class UserId(super.value) extends MatrixId {
  this {
    validateIdentifier(value, sigil: '@');
  }

  /// Parses a complete user ID, throwing [FormatException] if invalid.
  new parse(String value) : this(value);

  /// Builds a user ID from its localpart (without `@`) and server name.
  new fromParts(String localpart, String serverName)
    : this(joinIdentifierParts('@', localpart, serverName));

  /// Returns null for invalid input instead of throwing [FormatException].
  static UserId? tryParse(String value) {
    try {
      return UserId(value);
    } on FormatException {
      return null;
    }
  }

  @override
  String get serverName => super.serverName!;
}
