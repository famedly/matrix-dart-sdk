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

import 'package:matrix/matrix_api_lite.dart';

void main() {
  group('Try-get-map-extension', () {
    test('it should work', () {
      final data = <String, dynamic>{
        'str': 'foxies',
        'int': 42,
        'list': [2, 3, 4],
        'map': <String, dynamic>{
          'beep': 'boop',
        },
      };
      expect(data.tryGet<String>('str'), 'foxies');
      expect(data.tryGet<int>('str'), null);
      expect(data.tryGet<int>('int'), 42);
      expect(data.tryGet<List>('list'), [2, 3, 4]);
      expect(data.tryGet<Map<String, dynamic>>('map')?.tryGet<String>('beep'),
          'boop');
      expect(data.tryGet<Map<String, dynamic>>('map')?.tryGet<String>('meep'),
          null);
      expect(data.tryGet<Map<String, dynamic>>('pam')?.tryGet<String>('beep'),
          null);
    });
  });
}
