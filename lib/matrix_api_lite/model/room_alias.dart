// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

part of 'matrix_id.dart';

/// A validated, case-sensitive Matrix room alias (`#localpart:server_name`).
///
/// Invalid input throws [FormatException].
/// See https://spec.matrix.org/v1.19/appendices/#room-aliases.
final class RoomAlias(super.value) extends MatrixId {
  this {
    validateIdentifier(value, sigil: '#');
  }

  /// Parses a complete room alias, throwing [FormatException] if invalid.
  new parse(String value) : this(value);

  /// Builds a room alias from its localpart (without `#`) and server name.
  new fromParts(String localpart, String serverName)
    : this(joinIdentifierParts('#', localpart, serverName));

  /// Returns null for invalid input instead of throwing [FormatException].
  static RoomAlias? tryParse(String value) {
    try {
      return RoomAlias(value);
    } on FormatException {
      return null;
    }
  }

  @override
  String get serverName => super.serverName!;
}
