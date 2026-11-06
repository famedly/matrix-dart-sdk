// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../utils/identifier_validation.dart';
import '../utils/logs.dart';

/// A Matrix device ID.
extension type const DeviceId(String value) {
  /// Creates a [DeviceId] from a raw string, logging a warning if malformed.
  factory DeviceId.fromString(String value) {
    if (!isValidDeviceId(value)) {
      Logs().w('Malformed Matrix Device ID: "$value"');
    }
    return DeviceId(value);
  }

  static DeviceId? tryParse(String? value) {
    if (value == null || !isValidDeviceId(value)) return null;
    return DeviceId(value);
  }

  bool get isValid => isValidDeviceId(value);

  String toJson() => value;
}
