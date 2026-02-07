/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019-2026 Famedly GmbH
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
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'package:matrix/matrix.dart';

void main() {
  group('MatrixApi.unexpectedResponse', () {
    Logs().level = Level.error;
    final api = MatrixApi(homeserver: Uri.parse('https://example.com'));

    /// Helper to assert that [api.unexpectedResponse] throws a [MatrixException]
    /// with specific properties, matching the Matrix Spec behavior.
    void expectMatrixException(
      dynamic jsonBody,
      int statusCode, {
      String? errcode,
      String? session,
      bool? softLogout,
    }) {
      final body = Uint8List.fromList(utf8.encode(json.encode(jsonBody)));
      final response = http.Response.bytes(body, statusCode);
      try {
        api.unexpectedResponse(response, body);
      } on MatrixException catch (e) {
        if (errcode != null) expect(e.errcode, errcode);
        if (session != null) expect(e.session, session);
        if (softLogout != null) expect(e.raw['soft_logout'], softLogout);
      } catch (e) {
        fail(
          'Caught wrong exception type: ${e.runtimeType}. Expected MatrixException.',
        );
      }
    }

    /// Helper to assert that [api.unexpectedResponse] falls through to the
    /// super implementation (throwing a generic Exception) for non-Matrix errors.
    void expectGenericException(dynamic content, int statusCode) {
      final bytes = content is String
          ? utf8.encode(content)
          : utf8.encode(json.encode(content));
      final body = Uint8List.fromList(bytes as List<int>);
      final response = http.Response.bytes(body, statusCode);

      expect(
        () => api.unexpectedResponse(response, body),
        throwsA(isNot(isA<MatrixException>())),
        reason:
            'Should not interpret valid JSON as MatrixException if it lacks spec fields',
      );
    }

    test('identifies Standard Matrix Errors (errcode present)', () {
      // Spec: Standard error response
      // https://spec.matrix.org/latest/client-server-api/#api-standards
      expectMatrixException(
        {'errcode': 'M_FORBIDDEN', 'error': 'You do not have permission'},
        403,
        errcode: 'M_FORBIDDEN',
      );
    });

    test('identifies UIA Challenges (flows/session present)', () {
      // Spec: 401 User-Interactive Authentication API
      // https://spec.matrix.org/latest/client-server-api/#user-interactive-authentication-api
      // These often lack 'errcode' but must be caught as MatrixExceptions.
      expectMatrixException(
        {
          'flows': [
            {
              'stages': ['m.login.password'],
            }
          ],
          'session': 'uia_session_id',
        },
        401,
        session: 'uia_session_id',
      );
    });

    test('identifies partial UIA Challenges (session only)', () {
      // Edge case: Session provided, flows might come later or logic simply checks key existence.
      expectMatrixException(
        {'session': 'partial_session'},
        401,
        session: 'partial_session',
      );
    });

    test('identifies partial UIA Challenges (flows only)', () {
      // Edge case: Flows provided without session (stateless stages).
      expectMatrixException({'flows': []}, 401);
    });

    test('identifies Soft Logout', () {
      // Spec: 401 with unknown token and soft_logout: true
      expectMatrixException(
        {'errcode': 'M_UNKNOWN_TOKEN', 'soft_logout': true},
        401,
        errcode: 'M_UNKNOWN_TOKEN',
        softLogout: true,
      );
    });

    test('ignores valid JSON that is not a Map (e.g. List)', () {
      // A JSON list [] is valid JSON but cannot be a MatrixError.
      // Parsers must ensure they don't crash or cast incorrectly.
      expectGenericException([], 500);
    });

    test('ignores JSON Maps missing Matrix error keys', () {
      // Pass-through ensuring unrelated JSON isn't swallowed as a MatrixException.
      expectGenericException({'random_field': 'value'}, 500);
    });

    test('ignores non-JSON content', () {
      // HTML or plain text errors should not trigger JSON parsing logic that throws MatrixException.
      expectGenericException('<html>502 Bad Gateway</html>', 502);
    });
  });
}
