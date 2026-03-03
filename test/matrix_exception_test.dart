/*
 *   Famedly Matrix SDK
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

import 'package:http/http.dart';
import 'package:test/test.dart';

import 'package:matrix/matrix.dart';

void main() {
  /// All Tests related to device keys
  group('Matrix Exception', () {
    Logs().level = Level.error;
    test('Matrix Exception', () async {
      final matrixException = MatrixException(
        Response(
          '{"flows":[{"stages":["example.type.foo"]}],"params":{"example.type.baz":{"example_key":"foobar"}},"session":"xxxxxxyz","completed":["example.type.foo"]}',
          401,
        ),
      );
      expect(matrixException.errcode, 'M_FORBIDDEN');
      final flows = matrixException.authenticationFlows;
      expect(flows?.length, 1);
      expect(flows?.first.stages.length, 1);
      expect(flows?.first.stages.first, 'example.type.foo');
      expect(
        matrixException.authenticationParams?['example.type.baz'],
        {'example_key': 'foobar'},
      );
      expect(matrixException.completedAuthenticationFlows.length, 1);
      expect(
        matrixException.completedAuthenticationFlows.first,
        'example.type.foo',
      );
      expect(matrixException.session, 'xxxxxxyz');
    });
    test('Unknown Exception', () async {
      final matrixException = MatrixException(
        Response(
          '{"errcode":"M_HAHA","error":"HAHA","retry_after_ms":500}',
          401,
        ),
      );
      expect(matrixException.error, MatrixError.M_UNKNOWN);
      expect(matrixException.retryAfterMs, 500);
    });
    test('Missing Exception', () async {
      final matrixException = MatrixException(
        Response(
          '{"error":"HAHA"}',
          420,
        ),
      );
      expect(matrixException.error, MatrixError.M_UNKNOWN);
    });
  });
}
