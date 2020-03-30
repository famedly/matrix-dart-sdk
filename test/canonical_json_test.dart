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

import 'package:canonical_json/canonical_json.dart';
import 'package:test/test.dart';

void main() {
  /// All Tests related to the ChatTime
  group('Canonical Json', () {
    var textMap = <String, Map<String, dynamic>>{
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
              {'medium': 'msisdn', 'address': '123456789'}
            ]
          }
        }
      },
      '{"a":null}': {'a': null},
    };
    for (final entry in textMap.entries) {
      test(entry.key, () async {
        expect(
            entry.key, String.fromCharCodes(canonicalJson.encode(entry.value)));
      });
    }
  });
}
