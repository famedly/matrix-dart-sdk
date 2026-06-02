// SPDX-FileCopyrightText: 2019-Present, 2020 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/src/utils/copy_map.dart';
import 'package:test/test.dart';

void main() {
  group('Map-copy-extension', () {
    test('it should work', () {
      final original = <String, dynamic>{
        'attr': 'fox',
        'child': <String, dynamic>{
          'attr': 'bunny',
          'list': [1, 2],
        },
      };
      final copy = copyMap(original);
      original['child']['attr'] = 'raccoon';
      expect((copy['child'] as Map)['attr'], 'bunny');
      original['child']['list'].add(3);
      expect((copy['child'] as Map)['list'], [1, 2]);
    });
  });
}
