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

import 'package:test/test.dart';
import 'package:matrix/src/utils/enum_helper.dart';

enum Animals { fox, bunny, raccoon, ringTailedLemur }

void main() {
  group('EnumHelper', () {
    test('fromString', () {
      expect(EnumHelper(Animals.values).fromString('fox'), Animals.fox);
      expect(EnumHelper(Animals.values).fromString('bunny'), Animals.bunny);
      expect(EnumHelper(Animals.values).fromString('raccoon'), Animals.raccoon);
      expect(EnumHelper(Animals.values).fromString('ringTailedLemur'),
          Animals.ringTailedLemur);
      expect(EnumHelper(Animals.values).fromString('ring_tailed_lemur'),
          Animals.ringTailedLemur);
      expect(EnumHelper(Animals.values).fromString('invalid'), null);
    });
    test('valToString', () {
      expect(EnumHelper.valToString(Animals.fox), 'fox');
      expect(EnumHelper.valToString(Animals.bunny), 'bunny');
      expect(EnumHelper.valToString(Animals.raccoon), 'raccoon');
      expect(
          EnumHelper.valToString(Animals.ringTailedLemur), 'ring_tailed_lemur');
    });
  });
}
