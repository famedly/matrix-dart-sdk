// SPDX-FileCopyrightText: 2019, 2020 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:http/http.dart';
import 'package:matrix/matrix.dart';
import 'package:test/test.dart';

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
      expect(matrixException.authenticationParams?['example.type.baz'], {
        'example_key': 'foobar',
      });
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
        Response('{"error":"HAHA"}', 420),
      );
      expect(matrixException.error, MatrixError.M_UNKNOWN);
    });
  });
}
