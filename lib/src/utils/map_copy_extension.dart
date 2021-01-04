/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020, 2021 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

extension MapCopyExtension on Map<String, dynamic> {
  /// Deep-copies a given json map
  Map<String, dynamic> copy() {
    final copy = Map<String, dynamic>.from(this);
    for (final entry in copy.entries) {
      if (entry.value is Map<String, dynamic>) {
        copy[entry.key] = (entry.value as Map<String, dynamic>).copy();
      }
      if (entry.value is List) {
        copy[entry.key] = List.from(entry.value);
      }
    }
    return copy;
  }
}
