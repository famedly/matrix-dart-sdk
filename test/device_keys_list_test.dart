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

import 'dart:convert';

import 'package:famedlysdk/famedlysdk.dart';
import 'package:test/test.dart';

void main() {
  /// All Tests related to device keys
  group('Device keys', () {
    test('fromJson', () async {
      var rawJson = <String, dynamic>{
        'user_id': '@alice:example.com',
        'device_id': 'JLAFKJWSCS',
        'algorithms': ['m.olm.v1.curve25519-aes-sha2', 'm.megolm.v1.aes-sha2'],
        'keys': {
          'curve25519:JLAFKJWSCS':
              '3C5BFWi2Y8MaVvjM8M22DBmh24PmgR0nPvJOIArzgyI',
          'ed25519:JLAFKJWSCS': 'lEuiRJBit0IG6nUf5pUzWTUEsRVVe/HJkoKuEww9ULI'
        },
        'signatures': {
          '@alice:example.com': {
            'ed25519:JLAFKJWSCS':
                'dSO80A01XiigH3uBiDVx/EjzaoycHcjq9lfQX0uWsqxl2giMIiSPR8a4d291W1ihKJL/a+myXS367WT6NAIcBA'
          }
        },
        'unsigned': {'device_display_name': "Alice's mobile phone"},
      };
      var rawListJson = <String, dynamic>{
        'user_id': '@alice:example.com',
        'outdated': true,
        'device_keys': {'JLAFKJWSCS': rawJson},
      };

      final key = DeviceKeys.fromJson(rawJson, null);
      key.setVerified(false, false);
      key.setBlocked(true);
      expect(json.encode(key.toJson()), json.encode(rawJson));
      expect(key.directVerified, false);
      expect(key.blocked, true);
    });
  });
}
