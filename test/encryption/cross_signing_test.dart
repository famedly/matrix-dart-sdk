/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020 Famedly GmbH
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
import '../fake_client.dart';

void main() {
  group('Cross Signing', tags: 'olm', () {
    Logs().level = Level.error;

    late Client client;

    setUpAll(() async {
      await olm.init();
      olm.get_library_version();
      client = await getClient();
      await client.abortSync();
    });

    test('basic things', () async {
      expect(client.encryption?.crossSigning.enabled, true);
    });

    test('selfSign', () async {
      final key = client.userDeviceKeys[client.userID]!.masterKey!;
      key.setDirectVerified(false);
      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption!.crossSigning.selfSign(recoveryKey: ssssKey);
      expect(key.directVerified, true);
      expect(
          FakeMatrixApi.calledEndpoints
              .containsKey('/client/v3/keys/signatures/upload'),
          true);
      expect(await client.encryption!.crossSigning.isCached(), true);
    });

    test('signable', () async {
      expect(
          client.encryption!.crossSigning
              .signable([client.userDeviceKeys[client.userID!]!.masterKey!]),
          true);
      expect(
          client.encryption!.crossSigning.signable([
            client.userDeviceKeys[client.userID!]!.deviceKeys[client.deviceID!]!
          ]),
          false);
      expect(
          client.encryption!.crossSigning.signable([
            client.userDeviceKeys[client.userID!]!.deviceKeys['OTHERDEVICE']!
          ]),
          true);
      expect(
          client.encryption!.crossSigning.signable([
            client
                .userDeviceKeys['@alice:example.com']!.deviceKeys['JLAFKJWSCS']!
          ]),
          false);
    });

    test('sign', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption!.crossSigning.sign([
        client.userDeviceKeys[client.userID!]!.masterKey!,
        client.userDeviceKeys[client.userID!]!.deviceKeys['OTHERDEVICE']!,
        client.userDeviceKeys['@othertest:fakeServer.notExisting']!.masterKey!
      ]);
      final body = json.decode(FakeMatrixApi
          .calledEndpoints['/client/v3/keys/signatures/upload']!.first);
      expect(body['@test:fakeServer.notExisting']?.containsKey('OTHERDEVICE'),
          true);
      expect(
          body['@test:fakeServer.notExisting'].containsKey(
              client.userDeviceKeys[client.userID]!.masterKey!.publicKey),
          true);
      expect(
          body['@othertest:fakeServer.notExisting'].containsKey(client
              .userDeviceKeys['@othertest:fakeServer.notExisting']
              ?.masterKey
              ?.publicKey),
          true);
    });

    test('dispose client', () async {
      await client.dispose(closeDatabase: true);
    });
  });
}
