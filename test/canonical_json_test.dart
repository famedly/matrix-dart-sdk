// SPDX-FileCopyrightText: 2019, 2020 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:canonical_json/canonical_json.dart';
import 'package:matrix/matrix.dart';
import 'package:test/test.dart';

void main() {
  /// All Tests related to the ChatTime
  group('Canonical Json', () {
    Logs().level = Level.error;
    final textMap = <String, Map<String, dynamic>>{
      '{}': {},
      '{"one":1,"two":"Two"}': {'one': 1, 'two': 'Two'},
      '{"a":"1","b":"2"}': {'b': '2', 'a': '1'},
      '{"auth":{"mxid":"@john.doe:example.com","profile":{"display_name":"John Doe","three_pids":[{"address":"john.doe@example.org","medium":"email"},{"address":"123456789","medium":"msisdn"}]},"success":true}}':
          {
        'auth': {
          'success': true,
          'mxid': '@john.doe:example.com',
          'profile': {
            'display_name': 'John Doe',
            'three_pids': [
              {'medium': 'email', 'address': 'john.doe@example.org'},
              {'medium': 'msisdn', 'address': '123456789'},
            ],
          },
        },
      },
      '{"a":null}': {'a': null},
    };
    for (final entry in textMap.entries) {
      test(entry.key, () async {
        expect(
          entry.key,
          String.fromCharCodes(canonicalJson.encode(entry.value)),
        );
      });
    }
  });
}
