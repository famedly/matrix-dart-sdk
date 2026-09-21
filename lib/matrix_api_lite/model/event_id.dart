// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

part of 'matrix_id.dart';

/// A case-sensitive Matrix event ID (`$localpart:server_name` or `$opaque_id`).
///
/// Supports historical format with server name and modern room v3+ hash format.
/// Invalid input throws [FormatException].
/// See https://spec.matrix.org/v1.19/appendices/#event-ids.
final class EventId(super.value) extends MatrixId {
  this {
    validateEventId(value);
  }

  /// Parses a complete event ID, throwing [FormatException] if invalid.
  new parse(String value) : this(value);

  /// Builds an event ID from its localpart/opaque ID (without `$`) and optional server name.
  new fromParts(String localpart, [String? serverName])
    : this(
        serverName != null
            ? joinIdentifierParts(r'$', localpart, serverName)
            : (localpart.contains(':')
                  ? throw FormatException(
                      'Event ID localpart must not contain :',
                      localpart,
                    )
                  : r'$' + localpart),
      );

  /// Returns null for invalid input instead of throwing [FormatException].
  static EventId? tryParse(String value) {
    try {
      return EventId(value);
    } on FormatException {
      return null;
    }
  }
}
