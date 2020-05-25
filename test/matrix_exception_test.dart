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
import 'package:famedlysdk/famedlysdk.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';

void main() {
  /// All Tests related to device keys
  group('Matrix Exception', () {
    test('Matrix Exception', () async {
      final matrixException = MatrixException(
        Response(
          '{"flows":[{"stages":["example.type.foo"]}],"params":{"example.type.baz":{"example_key":"foobar"}},"session":"xxxxxxyz","completed":["example.type.foo"]}',
          401,
        ),
      );
      expect(matrixException.errcode, 'M_FORBIDDEN');
      final flows = matrixException.authenticationFlows;
      expect(flows.length, 1);
      expect(flows.first.stages.length, 1);
      expect(flows.first.stages.first, 'example.type.foo');
      expect(
        matrixException.authenticationParams['example.type.baz'],
        {'example_key': 'foobar'},
      );
      expect(matrixException.completedAuthenticationFlows.length, 1);
      expect(matrixException.completedAuthenticationFlows.first,
          'example.type.foo');
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
          401,
        ),
      );
      expect(matrixException.error, MatrixError.M_UNKNOWN);
    });
  });
}
