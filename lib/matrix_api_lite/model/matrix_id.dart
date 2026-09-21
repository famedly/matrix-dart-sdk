// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

library;

import '../utils/identifier_validation.dart';

part 'event_id.dart';
part 'room_alias.dart';
part 'room_id.dart';
part 'user_id.dart';

/// Sealed base class for all sigil-based Matrix identifiers.
///
/// Direct subtypes:
/// - [UserId] (`@localpart:server_name`)
/// - [RoomId] (`!localpart:server_name` or `!opaque_id`)
/// - [RoomAlias] (`#localpart:server_name`)
/// - [EventId] (`$localpart:server_name` or `$opaque_id`)
///
/// See https://spec.matrix.org/v1.19/appendices/#identifier-grammar.
sealed class MatrixId(final String value) {
  this {
    validateCommonIdentifier(value);
  }

  /// Parses an arbitrary Matrix identifier string by inspecting its leading sigil.
  ///
  /// Throws [FormatException] if the string is empty, has an unknown sigil,
  /// or fails validation for the specific identifier type.
  static MatrixId parse(String value) {
    if (value.isEmpty) {
      throw const FormatException('Cannot parse empty identifier');
    }
    return switch (value[0]) {
      '@' => UserId(value),
      '!' => RoomId(value),
      '#' => RoomAlias(value),
      r'$' => EventId(value),
      final sigil => throw FormatException(
        'Unknown Matrix identifier sigil: "$sigil"',
        value,
      ),
    };
  }

  /// Tries to parse an arbitrary Matrix identifier string, returning `null` on error.
  static MatrixId? tryParse(String value) {
    try {
      return MatrixId.parse(value);
    } on FormatException {
      return null;
    }
  }

  /// The leading sigil character (`@`, `!`, `#`, or `$`).
  String get sigil => value[0];

  /// The localpart portion of the identifier without the sigil.
  String get localpart {
    final colonIndex = value.indexOf(':');
    return colonIndex == -1
        ? value.substring(1)
        : value.substring(1, colonIndex);
  }

  /// The server name portion of the identifier, or `null` if the identifier
  /// has no domain (e.g. modern room v3+ event IDs).
  String? get serverName {
    final colonIndex = value.indexOf(':');
    return colonIndex == -1 ? null : value.substring(colonIndex + 1);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other.runtimeType == runtimeType &&
          other is MatrixId &&
          other.value == value);

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => value;

  /// Serializes the identifier to its wire string representation.
  String toJson() => value;
}
