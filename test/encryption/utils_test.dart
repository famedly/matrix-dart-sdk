/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2022 Famedly GmbH
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

import 'dart:convert';

import 'package:matrix/encryption/utils/base64_unpadded.dart';
import 'package:test/test.dart';

void main() {
  group('Utils', () {
    const base64input = 'foobar';
    final utf8codec = Utf8Codec();
    test('base64 padded', () {
      final paddedBase64 = base64.encode(base64input.codeUnits);

      final decodedPadded =
          utf8codec.decode(base64decodeUnpadded(paddedBase64));
      expect(decodedPadded, base64input, reason: 'Padded base64 decode');
    });

    test('base64 unpadded', () {
      const unpaddedBase64 = 'Zm9vYmFy';
      final decodedUnpadded =
          utf8codec.decode(base64decodeUnpadded(unpaddedBase64));
      expect(decodedUnpadded, base64input, reason: 'Unpadded base64 decode');
    });
  });
}
