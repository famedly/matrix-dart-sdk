/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2026 Famedly GmbH
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

// 2^53 - 1 from https://spec.matrix.org/v1.15/appendices/#canonical-json
const int _ownerLevel = 9007199254740991;

/// Sealed class representing a power level in Matrix.
/// Can be one of: UserPowerLevel, ModeratorPowerLevel, AdminPowerLevel, or OwnerPowerLevel.
sealed class PowerLevel implements Comparable<PowerLevel> {
  /// The numeric value of this power level.
  final int level;

  PowerLevel._(this.level);

  /// Convenience constants for default power levels.
  static final PowerLevel user = UserPowerLevel();
  static final PowerLevel moderator = ModeratorPowerLevel();
  static final PowerLevel admin = AdminPowerLevel();
  static final PowerLevel owner = OwnerPowerLevel();

  /// Factory constructor that creates the appropriate PowerLevel subclass
  /// based on the numeric level value.
  factory PowerLevel(int level) {
    if (level == _ownerLevel) {
      return OwnerPowerLevel(level: level);
    } else if (level >= 100) {
      return AdminPowerLevel(level: level);
    } else if (level >= 50) {
      return ModeratorPowerLevel(level: level);
    } else {
      return UserPowerLevel(level: level);
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PowerLevel && other.level == level;
  }

  @override
  int get hashCode => level.hashCode;

  bool operator <(PowerLevel other) => level < other.level;
  bool operator <=(PowerLevel other) => level <= other.level;
  bool operator >(PowerLevel other) => level > other.level;
  bool operator >=(PowerLevel other) => level >= other.level;

  @override
  int compareTo(PowerLevel other) => level.compareTo(other.level);

  @override
  String toString() => 'PowerLevel($level)';
}

/// Power level for regular users. Default level: 0.
final class UserPowerLevel extends PowerLevel {
  UserPowerLevel({int level = 0}) : super._(level);

  @override
  String toString() => 'UserPowerLevel($level)';
}

/// Power level for moderators. Default level: 50.
final class ModeratorPowerLevel extends PowerLevel {
  ModeratorPowerLevel({int level = 50}) : super._(level);

  @override
  String toString() => 'ModeratorPowerLevel($level)';
}

/// Power level for admins. Default level: 100.
final class AdminPowerLevel extends PowerLevel {
  AdminPowerLevel({int level = 100}) : super._(level);

  @override
  String toString() => 'AdminPowerLevel($level)';
}

/// Power level for owners. Default level: 9007199254740991 (2^53 - 1).
final class OwnerPowerLevel extends PowerLevel {
  OwnerPowerLevel({int level = _ownerLevel}) : super._(level);

  @override
  String toString() => 'OwnerPowerLevel($level)';
}
