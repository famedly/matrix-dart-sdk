/*
 * Copyright (c) 2019 Zender & Kurtz GbR.
 *
 * Authors:
 *   Christian Pauly <krille@famedly.com>
 *   Marcel Radzio <mtrnord@famedly.com>
 *
 * This file is part of famedlysdk.
 *
 * famedlysdk is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * famedlysdk is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with famedlysdk.  If not, see <http://www.gnu.org/licenses/>.
 */

import 'dart:typed_data';

import 'package:famedlysdk/famedlysdk.dart';
import 'package:test/test.dart';
import 'package:olm/olm.dart' as olm;

void main() {
  /// All Tests related to device keys
  group('Matrix File', () {
    test('Decrypt', () async {
      final text = 'hello world';
      final file = MatrixFile(
        path: '/path/to/file.txt',
        bytes: Uint8List.fromList(text.codeUnits),
      );
      var olmEnabled = true;
      try {
        await olm.init();
        olm.Account();
      } catch (_) {
        olmEnabled = false;
      }
      if (olmEnabled) {
        final encryptedFile = await file.encrypt();
        expect(encryptedFile != null, true);
      }
    });
  });
}
