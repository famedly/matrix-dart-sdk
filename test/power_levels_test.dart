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
  group('PowerLevels', () {
    group('isUser', () {
      test('returns true for levels < 50', () {
        expect(PowerLevels.isUser(0), isTrue);
        expect(PowerLevels.isUser(1), isTrue);
        expect(PowerLevels.isUser(49), isTrue);
      });

      test('returns true for negative levels', () {
        expect(PowerLevels.isUser(-1), isTrue);
        expect(PowerLevels.isUser(-100), isTrue);
      });

      test('returns false for levels >= 50', () {
        expect(PowerLevels.isUser(50), isFalse);
        expect(PowerLevels.isUser(51), isFalse);
        expect(PowerLevels.isUser(100), isFalse);
        expect(PowerLevels.isUser(9007199254740991), isFalse);
      });
    });

    group('isModerator', () {
      test('returns true for levels >= 50 and < 100', () {
        expect(PowerLevels.isModerator(50), isTrue);
        expect(PowerLevels.isModerator(51), isTrue);
        expect(PowerLevels.isModerator(99), isTrue);
      });

      test('returns false for levels < 50', () {
        expect(PowerLevels.isModerator(0), isFalse);
        expect(PowerLevels.isModerator(49), isFalse);
      });

      test('returns false for levels >= 100', () {
        expect(PowerLevels.isModerator(100), isFalse);
        expect(PowerLevels.isModerator(101), isFalse);
        expect(PowerLevels.isModerator(9007199254740991), isFalse);
      });
    });

    group('isAdmin', () {
      test('returns true for levels >= 100 and < owner', () {
        expect(PowerLevels.isAdmin(100), isTrue);
        expect(PowerLevels.isAdmin(101), isTrue);
        expect(PowerLevels.isAdmin(1000), isTrue);
        expect(PowerLevels.isAdmin(9007199254740990), isTrue);
      });

      test('returns false for levels < 100', () {
        expect(PowerLevels.isAdmin(0), isFalse);
        expect(PowerLevels.isAdmin(50), isFalse);
        expect(PowerLevels.isAdmin(99), isFalse);
      });

      test('returns false for owner level', () {
        expect(PowerLevels.isAdmin(PowerLevels.owner), isFalse);
      });
    });

    group('isOwner', () {
      test('returns true only for owner level', () {
        expect(PowerLevels.isOwner(PowerLevels.owner), isTrue);
        expect(PowerLevels.isOwner(9007199254740991), isTrue);
      });

      test('returns false for all other levels', () {
        expect(PowerLevels.isOwner(0), isFalse);
        expect(PowerLevels.isOwner(50), isFalse);
        expect(PowerLevels.isOwner(100), isFalse);
        expect(PowerLevels.isOwner(9007199254740990), isFalse);
        expect(PowerLevels.isOwner(-1), isFalse);
      });
    });

    test('Power levels are mutually exclusive', () {
      // A level should only match one category
      for (final level in [0, 49, 50, 99, 100, 999, 9007199254740990]) {
        final categoriesCounted = [
          PowerLevels.isUser(level),
          PowerLevels.isModerator(level),
          PowerLevels.isAdmin(level),
          PowerLevels.isOwner(level),
        ].where((e) => e).length;

        expect(
          categoriesCounted,
          equals(1),
          reason:
              'Level $level should belong to exactly one category, but matches $categoriesCounted',
        );
      }
    });
  });
}
