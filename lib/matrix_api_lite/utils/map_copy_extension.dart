// SPDX-FileCopyrightText: 2019-2021 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

extension MapCopyExtension on Map<String, Object?> {
  dynamic _copyValue(dynamic value) {
    if (value is Map<String, Object?>) {
      return value.copy();
    }
    if (value is List) {
      return value.map(_copyValue).toList();
    }
    return value;
  }

  /// Deep-copies a given json map
  Map<String, Object?> copy() {
    final copy = Map<String, Object?>.from(this);
    for (final entry in copy.entries) {
      copy[entry.key] = _copyValue(entry.value);
    }
    return copy;
  }
}
