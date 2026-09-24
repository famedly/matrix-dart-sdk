// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

part of 'matrix_id.dart';

/// A case-sensitive Matrix room ID (`!localpart:server_name` or `!opaque_id`).
///
/// Supports historical format with server name and Room Version 12+ domainless format.
/// Invalid input throws [FormatException].
/// See https://spec.matrix.org/v1.19/appendices/#room-ids.
final class RoomId(super.value) extends MatrixId {
  this {
    validateIdentifier(value, sigil: '!', requireServerName: false);
  }

  /// Parses a complete room ID, throwing [FormatException] if invalid.
  new parse(String value) : this(value);

  /// Builds a room ID from its localpart (without `!`) and optional server name.
  new fromParts(String localpart, [String? serverName])
    : this(
        serverName != null
            ? joinIdentifierParts('!', localpart, serverName)
            : (localpart.contains(':')
                  ? throw FormatException(
                      'Room ID localpart must not contain :',
                      localpart,
                    )
                  : '!$localpart'),
      );

  /// Returns null for invalid input instead of throwing [FormatException].
  static RoomId? tryParse(String value) {
    try {
      return RoomId(value);
    } on FormatException {
      return null;
    }
  }
}
