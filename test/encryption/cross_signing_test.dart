// SPDX-FileCopyrightText: 2019-Present, 2020 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:test/test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:matrix/matrix.dart';
import '../fake_client.dart';

void main() {
  group('Cross Signing', tags: 'olm', () {
    Logs().level = Level.error;

    late Client client;

    setUpAll(() async {
      await vod.init(
        wasmPath: './pkg/',
        libraryPath: './rust/target/debug/',
      );

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
        true,
      );
      expect(await client.encryption!.crossSigning.isCached(), true);
    });

    test('signable', () async {
      expect(
        client.encryption!.crossSigning
            .signable([client.userDeviceKeys[client.userID!]!.masterKey!]),
        true,
      );
      expect(
        client.encryption!.crossSigning.signable([
          client.userDeviceKeys[client.userID!]!.deviceKeys[client.deviceID!]!,
        ]),
        false,
      );
      expect(
        client.encryption!.crossSigning.signable([
          client.userDeviceKeys[client.userID!]!.deviceKeys['OTHERDEVICE']!,
        ]),
        true,
      );
      expect(
        client.encryption!.crossSigning.signable([
          client
              .userDeviceKeys['@alice:example.com']!.deviceKeys['JLAFKJWSCS']!,
        ]),
        false,
      );
    });

    test('sign', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption!.crossSigning.sign([
        client.userDeviceKeys[client.userID!]!.masterKey!,
        client.userDeviceKeys[client.userID!]!.deviceKeys['OTHERDEVICE']!,
        client.userDeviceKeys['@othertest:fakeServer.notExisting']!.masterKey!,
      ]);
      final body = json.decode(
        FakeMatrixApi
            .calledEndpoints['/client/v3/keys/signatures/upload']!.first,
      );
      expect(
        body['@test:fakeServer.notExisting']?.containsKey('OTHERDEVICE'),
        true,
      );
      expect(
        body['@test:fakeServer.notExisting'].containsKey(
          client.userDeviceKeys[client.userID]!.masterKey!.publicKey,
        ),
        true,
      );
      expect(
        body['@othertest:fakeServer.notExisting'].containsKey(
          client.userDeviceKeys['@othertest:fakeServer.notExisting']?.masterKey
              ?.publicKey,
        ),
        true,
      );
    });

    test('dispose client', () async {
      await client.dispose(closeDatabase: true);
    });
  });
}
