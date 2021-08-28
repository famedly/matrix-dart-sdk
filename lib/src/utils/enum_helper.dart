/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2021 Famedly GmbH
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

// EnumHelper takes Enum.values because 1. you can't extend all enums at once and
// 2. there is no generic that you can limit for enum types. See https://stackoverflow.com/a/60459896

/// Helper class around enums. Initialize it with the values of the enum, e.g.
/// EnumHelper(MyEnum.values). Then you can do things like create the enum value
/// from a string, respecting underscore_snake --> camelCase conversion.
/// Casting a value to a string, converting camelCase --> underscore_snake is static
/// as the whole enum is not needed.
class EnumHelper<T> {
  final List<T> values;
  EnumHelper(this.values);

  /// Convert a camelCase string to an underscore_snake string
  static String _camelCaseToUnderscore(String s) => s
      .replaceAllMapped(RegExp(r'(?<=[a-z])[A-Z]'), (m) => ('_' + m.group(0)!))
      .toLowerCase();

  /// Creates an enum value based on a string
  T? fromString(String val) {
    final enumType = T.toString();
    return values.cast<T?>().firstWhere((v) {
      final strippedValue = v.toString().replaceAll('$enumType.', '');
      return strippedValue == val ||
          _camelCaseToUnderscore(strippedValue) == val;
    }, orElse: () => null);
  }

  /// Converts an enum value to a string
  static String valToString<T>(T val) =>
      _camelCaseToUnderscore(val.toString().replaceAll('$T.', ''));
}
