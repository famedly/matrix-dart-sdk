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
        'verified': false,
        'blocked': true,
      };
      var rawListJson = <String, dynamic>{
        'user_id': '@alice:example.com',
        'outdated': true,
        'device_keys': {'JLAFKJWSCS': rawJson},
      };

      var userDeviceKeys = <String, DeviceKeysList>{
        '@alice:example.com': DeviceKeysList.fromJson(rawListJson, null),
      };
      var userDeviceKeyRaw = <String, dynamic>{
        '@alice:example.com': rawListJson,
      };

      final key = DeviceKeys.fromJson(rawJson, null);
      rawJson.remove('verified');
      rawJson.remove('blocked');
      expect(json.encode(key.toJson()), json.encode(rawJson));
      expect(key.verified, false);
      expect(key.blocked, true);
      expect(json.encode(DeviceKeysList.fromJson(rawListJson, null).toJson()),
          json.encode(rawListJson));

      var mapFromRaw = <String, DeviceKeysList>{};
      for (final rawListEntry in userDeviceKeyRaw.entries) {
        mapFromRaw[rawListEntry.key] =
            DeviceKeysList.fromJson(rawListEntry.value, null);
      }
      expect(mapFromRaw.toString(), userDeviceKeys.toString());
    });
  });
}
