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

import 'package:test/test.dart';

import 'package:matrix/src/models/power_levels.dart';

void main() {
  group('PowerLevel', () {
    group('Factory Constructor', () {
      test('creates UserPowerLevel for levels < 50', () {
        expect(PowerLevel(0), isA<UserPowerLevel>());
        expect(PowerLevel(1), isA<UserPowerLevel>());
        expect(PowerLevel(49), isA<UserPowerLevel>());
        expect(PowerLevel(-1), isA<UserPowerLevel>());
      });

      test('creates ModeratorPowerLevel for levels >= 50 and < 100', () {
        expect(PowerLevel(50), isA<ModeratorPowerLevel>());
        expect(PowerLevel(51), isA<ModeratorPowerLevel>());
        expect(PowerLevel(99), isA<ModeratorPowerLevel>());
      });

      test('creates AdminPowerLevel for levels >= 100 and < owner', () {
        expect(PowerLevel(100), isA<AdminPowerLevel>());
        expect(PowerLevel(101), isA<AdminPowerLevel>());
        expect(PowerLevel(1000), isA<AdminPowerLevel>());
        expect(PowerLevel(9007199254740990), isA<AdminPowerLevel>());
      });

      test('creates OwnerPowerLevel for owner level', () {
        expect(PowerLevel(9007199254740991), isA<OwnerPowerLevel>());
      });
    });

    group('UserPowerLevel', () {
      test('has default level 0', () {
        final level = UserPowerLevel();
        expect(level.level, equals(0));
      });

      test('can set custom level', () {
        final level = UserPowerLevel(level: 10);
        expect(level.level, equals(10));
      });

      test('toString returns correct format', () {
        expect(UserPowerLevel().toString(), equals('UserPowerLevel(0)'));
        expect(
          UserPowerLevel(level: 10).toString(),
          equals('UserPowerLevel(10)'),
        );
      });
    });

    group('ModeratorPowerLevel', () {
      test('has default level 50', () {
        final level = ModeratorPowerLevel();
        expect(level.level, equals(50));
      });

      test('can set custom level', () {
        final level = ModeratorPowerLevel(level: 75);
        expect(level.level, equals(75));
      });

      test('toString returns correct format', () {
        expect(
          ModeratorPowerLevel().toString(),
          equals('ModeratorPowerLevel(50)'),
        );
        expect(
          ModeratorPowerLevel(level: 75).toString(),
          equals('ModeratorPowerLevel(75)'),
        );
      });
    });

    group('AdminPowerLevel', () {
      test('has default level 100', () {
        final level = AdminPowerLevel();
        expect(level.level, equals(100));
      });

      test('can set custom level', () {
        final level = AdminPowerLevel(level: 150);
        expect(level.level, equals(150));
      });

      test('toString returns correct format', () {
        expect(AdminPowerLevel().toString(), equals('AdminPowerLevel(100)'));
        expect(
          AdminPowerLevel(level: 150).toString(),
          equals('AdminPowerLevel(150)'),
        );
      });
    });

    group('OwnerPowerLevel', () {
      test('has default level 9007199254740991', () {
        final level = OwnerPowerLevel();
        expect(level.level, equals(9007199254740991));
      });

      test('can set custom level', () {
        final level = OwnerPowerLevel(level: 9007199254740990);
        expect(level.level, equals(9007199254740990));
      });

      test('toString returns correct format', () {
        expect(
          OwnerPowerLevel().toString(),
          equals('OwnerPowerLevel(9007199254740991)'),
        );
      });
    });

    group('Equality', () {
      test('two PowerLevels with same value are equal', () {
        final level1 = PowerLevel(0);
        final level2 = PowerLevel(0);
        expect(level1, equals(level2));
      });

      test('two PowerLevels with different values are not equal', () {
        final level1 = PowerLevel(0);
        final level2 = PowerLevel(50);
        expect(level1, isNot(equals(level2)));
      });
    });
  });
}
