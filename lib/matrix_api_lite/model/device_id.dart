// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../utils/identifier_validation.dart';

/// A validated Matrix device ID.
///
/// Device IDs are opaque client-assigned or server-generated strings identifying
/// a specific user device or session.
/// Invalid input throws [FormatException].
///
/// See https://spec.matrix.org/latest/client-server-api/#device-management.
final class DeviceId(final String value) {
  this {
    validateDeviceId(value);
  }

  /// Parses a complete device ID, throwing [FormatException] if invalid.
  new parse(String value) : this(value);

  /// Returns null for invalid input instead of throwing [FormatException].
  static DeviceId? tryParse(String value) {
    try {
      return DeviceId(value);
    } on FormatException {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is DeviceId && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;

  String toJson() => value;
}
