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
import 'package:olm/olm.dart' as olm;

import './fake_client.dart';
import './fake_matrix_api.dart';

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

      final key = DeviceKeys.fromJson(rawJson, null);
      await key.setVerified(false, false);
      await key.setBlocked(true);
      expect(json.encode(key.toJson()), json.encode(rawJson));
      expect(key.directVerified, false);
      expect(key.blocked, true);

      rawJson = <String, dynamic>{
        'user_id': '@test:fakeServer.notExisting',
        'usage': ['master'],
        'keys': {
          'ed25519:82mAXjsmbTbrE6zyShpR869jnrANO75H8nYY0nDLoJ8':
              '82mAXjsmbTbrE6zyShpR869jnrANO75H8nYY0nDLoJ8',
        },
        'signatures': {},
      };
      final crossKey = CrossSigningKey.fromJson(rawJson, null);
      expect(json.encode(crossKey.toJson()), json.encode(rawJson));
      expect(crossKey.usage.first, 'master');
    });

    var olmEnabled = true;
    try {
      olm.init();
      olm.Account();
    } catch (_) {
      olmEnabled = false;
      print('[LibOlm] Failed to load LibOlm: ' + _.toString());
    }
    print('[LibOlm] Enabled: $olmEnabled');

    if (!olmEnabled) return;

    Client client;

    test('setupClient', () async {
      client = await getClient();
    });

    test('set blocked / verified', () async {
      final key =
          client.userDeviceKeys[client.userID].deviceKeys['OTHERDEVICE'];
      final masterKey = client.userDeviceKeys[client.userID].masterKey;
      masterKey.setDirectVerified(true);
      // we need to populate the ssss cache to be able to test signing easily
      final handle = client.encryption.ssss.open();
      handle.unlock(recoveryKey: SSSS_KEY);
      await handle.maybeCacheAll();

      expect(key.verified, true);
      await key.setBlocked(true);
      expect(key.verified, false);
      await key.setBlocked(false);
      expect(key.directVerified, false);
      expect(key.verified, true); // still verified via cross-sgining

      expect(masterKey.verified, true);
      await masterKey.setBlocked(true);
      expect(masterKey.verified, false);
      await masterKey.setBlocked(false);
      expect(masterKey.verified, true);

      FakeMatrixApi.calledEndpoints.clear();
      await key.setVerified(true);
      await Future.delayed(Duration(milliseconds: 10));
      expect(
          FakeMatrixApi.calledEndpoints.keys
              .any((k) => k == '/client/r0/keys/signatures/upload'),
          true);
      expect(key.directVerified, true);

      FakeMatrixApi.calledEndpoints.clear();
      await key.setVerified(false);
      await Future.delayed(Duration(milliseconds: 10));
      expect(
          FakeMatrixApi.calledEndpoints.keys
              .any((k) => k == '/client/r0/keys/signatures/upload'),
          false);
      expect(key.directVerified, false);
    });

    test('verification based on signatures', () async {
      final user = client.userDeviceKeys[client.userID];
      user.masterKey.setDirectVerified(true);
      expect(user.deviceKeys['GHTYAJCE'].crossVerified, true);
      expect(user.deviceKeys['GHTYAJCE'].signed, true);
      expect(user.getKey('GHTYAJCE').crossVerified, true);
      expect(user.deviceKeys['OTHERDEVICE'].crossVerified, true);
      expect(user.selfSigningKey.crossVerified, true);
      expect(
          user
              .getKey('F9ypFzgbISXCzxQhhSnXMkc1vq12Luna3Nw5rqViOJY')
              .crossVerified,
          true);
      expect(user.userSigningKey.crossVerified, true);
      expect(user.verified, UserVerifiedStatus.verified);
      user.masterKey.setDirectVerified(false);
      expect(user.deviceKeys['GHTYAJCE'].crossVerified, false);
      expect(user.deviceKeys['OTHERDEVICE'].crossVerified, false);
      expect(user.verified, UserVerifiedStatus.unknown);
      user.masterKey.setDirectVerified(true);
      user.deviceKeys['GHTYAJCE'].signatures.clear();
      expect(user.deviceKeys['GHTYAJCE'].verified,
          true); // it's our own device, should be direct verified
      expect(
          user.deviceKeys['GHTYAJCE'].signed, false); // not verified for others
      user.deviceKeys['OTHERDEVICE'].signatures.clear();
      expect(user.verified, UserVerifiedStatus.unknownDevice);
    });

    test('start verification', () async {
      var req = client
          .userDeviceKeys['@alice:example.com'].deviceKeys['JLAFKJWSCS']
          .startVerification();
      expect(req != null, true);
      expect(req.room != null, false);

      req =
          await client.userDeviceKeys['@alice:example.com'].startVerification();
      expect(req != null, true);
      expect(req.room != null, true);
    });

    test('dispose client', () async {
      await client.dispose(closeDatabase: true);
    });
  });
}
