/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020 Famedly GmbH
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

import 'package:matrix/src/utils/map_copy_extension.dart';

void main() {
  group('Map-copy-extension', () {
    test('it should work', () {
      final original = <String, Object?>{
        'attr': 'fox',
        'child': <String, Object?>{
          'attr': 'bunny',
          'list': [1, 2],
        },
      };
      final copy = original.copy();
      (original['child'] as Map<String, Object?>)['attr'] = 'raccoon';
      expect((copy['child'] as Map<String, Object?>)['attr'], 'bunny');
      ((original['child'] as Map<String, Object?>)['list'] as List).add(3);
      expect((copy['child'] as Map<String, Object?>)['list'], [1, 2]);
    });
  });
}
