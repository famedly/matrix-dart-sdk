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

import 'dart:convert';

import 'package:olm/olm.dart' as olm;
import 'package:test/test.dart';

import 'package:matrix/matrix.dart';
import './fake_client.dart';
import './fake_matrix_api.dart';

void main() {
  /// All Tests related to device keys
  group('Device keys', () {
    Logs().level = Level.error;

    var olmEnabled = true;

    late Client client;

    test('setupClient', () async {
      try {
        await olm.init();
        olm.get_library_version();
      } catch (e) {
        olmEnabled = false;
        Logs().w('[LibOlm] Failed to load LibOlm', e);
      }
      Logs().i('[LibOlm] Enabled: $olmEnabled');
      if (!olmEnabled) return;

      client = await getClient();
    });

    test('fromJson', () async {
      if (!olmEnabled) return;
      var rawJson = <String, dynamic>{
        'user_id': '@alice:example.com',
        'device_id': 'JLAFKJWSCS',
        'algorithms': [
          AlgorithmTypes.olmV1Curve25519AesSha2,
          AlgorithmTypes.megolmV1AesSha2
        ],
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

      final key = DeviceKeys.fromJson(rawJson, client);
      // NOTE(Nico): this actually doesn't do anything, because the device signature is invalid...
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
      final crossKey = CrossSigningKey.fromJson(rawJson, client);
      expect(json.encode(crossKey.toJson()), json.encode(rawJson));
      expect(crossKey.usage.first, 'master');
    });

    test('reject devices without self-signature', () async {
      if (!olmEnabled) return;
      var key = DeviceKeys.fromJson({
        'user_id': '@test:fakeServer.notExisting',
        'device_id': 'BADDEVICE',
        'algorithms': [
          AlgorithmTypes.olmV1Curve25519AesSha2,
          AlgorithmTypes.megolmV1AesSha2
        ],
        'keys': {
          'curve25519:BADDEVICE': 'ds6+bItpDiWyRaT/b0ofoz1R+GCy7YTbORLJI4dmYho',
          'ed25519:BADDEVICE': 'CdDKVf44LO2QlfWopP6VWmqedSrRaf9rhHKvdVyH38w'
        },
      }, client);
      expect(key.isValid, false);
      expect(key.selfSigned, false);
      key = DeviceKeys.fromJson({
        'user_id': '@test:fakeServer.notExisting',
        'device_id': 'BADDEVICE',
        'algorithms': [
          AlgorithmTypes.olmV1Curve25519AesSha2,
          AlgorithmTypes.megolmV1AesSha2
        ],
        'keys': {
          'curve25519:BADDEVICE': 'ds6+bItpDiWyRaT/b0ofoz1R+GCy7YTbORLJI4dmYho',
          'ed25519:BADDEVICE': 'CdDKVf44LO2QlfWopP6VWmqedSrRaf9rhHKvdVyH38w'
        },
        'signatures': {
          '@test:fakeServer.notExisting': {
            'ed25519:BADDEVICE': 'invalid',
          },
        },
      }, client);
      expect(key.isValid, false);
      expect(key.selfSigned, false);
    });

    test('set blocked / verified', () async {
      if (!olmEnabled) return;
      final key =
          client.userDeviceKeys[client.userID]!.deviceKeys['OTHERDEVICE']!;
      client.userDeviceKeys[client.userID]?.deviceKeys['UNSIGNEDDEVICE'] =
          DeviceKeys.fromJson({
        'user_id': '@test:fakeServer.notExisting',
        'device_id': 'UNSIGNEDDEVICE',
        'algorithms': [
          AlgorithmTypes.olmV1Curve25519AesSha2,
          AlgorithmTypes.megolmV1AesSha2
        ],
        'keys': {
          'curve25519:UNSIGNEDDEVICE':
              'ds6+bItpDiWyRaT/b0ofoz1R+GCy7YTbORLJI4dmYho',
          'ed25519:UNSIGNEDDEVICE':
              'CdDKVf44LO2QlfWopP6VWmqedSrRaf9rhHKvdVyH38w'
        },
        'signatures': {
          '@test:fakeServer.notExisting': {
            'ed25519:UNSIGNEDDEVICE':
                'f2p1kv6PIz+hnoFYnHEurhUKIyRsdxwR2RTKT1EnQ3aF2zlZOjmnndOCtIT24Q8vs2PovRw+/jkHKj4ge2yDDw',
          },
        },
      }, client);
      expect(client.shareKeysWithUnverifiedDevices, true);
      expect(key.encryptToDevice, true);
      client.shareKeysWithUnverifiedDevices = false;
      expect(key.encryptToDevice, false);
      client.shareKeysWithUnverifiedDevices = true;
      final masterKey = client.userDeviceKeys[client.userID]!.masterKey!;
      masterKey.setDirectVerified(true);
      // we need to populate the ssss cache to be able to test signing easily
      final handle = client.encryption!.ssss.open();
      await handle.unlock(recoveryKey: ssssKey);
      await handle.maybeCacheAll();

      expect(key.verified, true);
      expect(key.encryptToDevice, true);
      await key.setBlocked(true);
      expect(key.verified, false);
      expect(key.encryptToDevice, false);
      await key.setBlocked(false);
      expect(key.directVerified, false);
      expect(key.verified, true); // still verified via cross-sgining
      expect(key.encryptToDevice, true);
      expect(
          client.userDeviceKeys[client.userID]?.deviceKeys['UNSIGNEDDEVICE']
              ?.encryptToDevice,
          true);

      expect(masterKey.verified, true);
      await masterKey.setBlocked(true);
      expect(masterKey.verified, false);
      expect(
          client.userDeviceKeys[client.userID]?.deviceKeys['UNSIGNEDDEVICE']
              ?.encryptToDevice,
          true);
      await masterKey.setBlocked(false);
      expect(masterKey.verified, true);

      FakeMatrixApi.calledEndpoints.clear();
      await key.setVerified(true);
      await Future.delayed(Duration(milliseconds: 10));
      expect(
          FakeMatrixApi.calledEndpoints.keys
              .any((k) => k == '/client/v3/keys/signatures/upload'),
          true);
      expect(key.directVerified, true);

      FakeMatrixApi.calledEndpoints.clear();
      await key.setVerified(false);
      await Future.delayed(Duration(milliseconds: 10));
      expect(
          FakeMatrixApi.calledEndpoints.keys
              .any((k) => k == '/client/v3/keys/signatures/upload'),
          false);
      expect(key.directVerified, false);
      client.userDeviceKeys[client.userID]?.deviceKeys.remove('UNSIGNEDDEVICE');
    });

    test('verification based on signatures', () async {
      if (!olmEnabled) return;
      final user = client.userDeviceKeys[client.userID]!;
      user.masterKey?.setDirectVerified(true);
      expect(user.deviceKeys['GHTYAJCE']?.crossVerified, true);
      expect(user.deviceKeys['GHTYAJCE']?.signed, true);
      expect(user.getKey('GHTYAJCE')?.crossVerified, true);
      expect(user.deviceKeys['OTHERDEVICE']?.crossVerified, true);
      expect(user.selfSigningKey?.crossVerified, true);
      expect(
          user
              .getKey('F9ypFzgbISXCzxQhhSnXMkc1vq12Luna3Nw5rqViOJY')
              ?.crossVerified,
          true);
      expect(user.userSigningKey?.crossVerified, true);
      expect(user.verified, UserVerifiedStatus.verified);
      user.masterKey?.setDirectVerified(false);
      expect(user.deviceKeys['GHTYAJCE']?.crossVerified, false);
      expect(user.deviceKeys['OTHERDEVICE']?.crossVerified, false);
      expect(user.verified, UserVerifiedStatus.unknown);

      user.deviceKeys['OTHERDEVICE']?.setDirectVerified(true);
      expect(user.verified, UserVerifiedStatus.verified);
      user.deviceKeys['OTHERDEVICE']?.setDirectVerified(false);

      user.masterKey?.setDirectVerified(true);
      user.deviceKeys['GHTYAJCE']?.signatures?[client.userID]
          ?.removeWhere((k, v) => k != 'ed25519:GHTYAJCE');
      expect(user.deviceKeys['GHTYAJCE']?.verified,
          true); // it's our own device, should be direct verified
      expect(user.deviceKeys['GHTYAJCE']?.signed,
          false); // not verified for others
      user.deviceKeys['OTHERDEVICE']?.signatures?.clear();
      expect(user.verified, UserVerifiedStatus.unknownDevice);
    });

    test('start verification', () async {
      if (!olmEnabled) return;
      var req = await client
          .userDeviceKeys['@alice:example.com']?.deviceKeys['JLAFKJWSCS']
          ?.startVerification();
      expect(req != null, true);
      expect(req?.room != null, false);

      req = await client.userDeviceKeys['@alice:example.com']
          ?.startVerification(newDirectChatEnableEncryption: false);
      expect(req != null, true);
      expect(req?.room != null, true);
    });

    test('dispose client', () async {
      if (!olmEnabled) return;
      await client.dispose(closeDatabase: true);
    });
  });
}
