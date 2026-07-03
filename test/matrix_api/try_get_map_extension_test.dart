// SPDX-FileCopyrightText: 2019-Present, 2020 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite.dart';
import 'package:test/test.dart';

void main() {
  group('Try-get-map-extension', () {
    test('it should work', () {
      final data = <String, dynamic>{
        'str': 'foxies',
        'int': 42,
        'list': [2, 3, 4],
        'map': <String, dynamic>{'beep': 'boop'},
      };
      expect(data.tryGet<String>('str'), 'foxies');
      expect(data.tryGet<int>('str'), null);
      expect(data.tryGet<int>('int'), 42);
      expect(data.tryGet<List>('list'), [2, 3, 4]);
      expect(
        data.tryGet<Map<String, dynamic>>('map')?.tryGet<String>('beep'),
        'boop',
      );
      expect(
        data.tryGet<Map<String, dynamic>>('map')?.tryGet<String>('meep'),
        null,
      );
      expect(
        data.tryGet<Map<String, dynamic>>('pam')?.tryGet<String>('beep'),
        null,
      );
    });
  });
}
