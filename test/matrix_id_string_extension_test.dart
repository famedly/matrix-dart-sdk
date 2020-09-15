/*
 *   Ansible inventory script used at Famedly GmbH for managing many hosts
 *   Copyright (C) 2019, 2020 Famedly GmbH
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
import 'package:famedlysdk/src/utils/matrix_id_string_extension.dart';

void main() {
  /// All Tests related to the ChatTime
  group('Matrix ID String Extension', () {
    test('Matrix ID String Extension', () async {
      final mxId = '@test:example.com';
      expect(mxId.isValidMatrixId, true);
      expect('#test:example.com'.isValidMatrixId, true);
      expect('!test:example.com'.isValidMatrixId, true);
      expect('+test:example.com'.isValidMatrixId, true);
      expect('\$test:example.com'.isValidMatrixId, true);
      expect('\$testevent'.isValidMatrixId, true);
      expect('test:example.com'.isValidMatrixId, false);
      expect('@testexample.com'.isValidMatrixId, false);
      expect('@:example.com'.isValidMatrixId, true);
      expect('@test:'.isValidMatrixId, false);
      expect(mxId.sigil, '@');
      expect('#test:example.com'.sigil, '#');
      expect('!test:example.com'.sigil, '!');
      expect('+test:example.com'.sigil, '+');
      expect('\$test:example.com'.sigil, '\$');
      expect(mxId.localpart, 'test');
      expect(mxId.domain, 'example.com');
      expect(mxId.equals('@Test:example.com'), true);
      expect(mxId.equals('@test:example.org'), false);
      expect('@user:domain:8448'.localpart, 'user');
      expect('@user:domain:8448'.domain, 'domain:8448');
    });
  });
}
