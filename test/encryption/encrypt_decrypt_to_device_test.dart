// SPDX-FileCopyrightText: 2019-Present, 2020 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:test/test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:matrix/matrix.dart';
import '../fake_client.dart';
import '../fake_database.dart';

void main() async {
  final database = await getDatabase();

  group('Encrypt/Decrypt to-device messages', tags: 'olm', () {
    Logs().level = Level.error;

    late Client client;
    final otherClient = Client(
      'othertestclient',
      httpClient: FakeMatrixApi(),
      database: database,
    );
    late DeviceKeys device;
    late Map<String, dynamic> payload;

    setUpAll(() async {
      await vod.init(
        wasmPath: './pkg/',
        libraryPath: './rust/target/debug/',
      );

      client = await getClient();
    });

    test('setupClient', () async {
      client = await getClient();
      await client.abortSync();
      await otherClient.checkHomeserver(
        Uri.parse('https://fakeserver.notexisting'),
        checkWellKnown: false,
      );
      await otherClient.init(
        newToken: 'abc',
        newUserID: '@othertest:fakeServer.notExisting',
        newHomeserver: otherClient.homeserver,
        newDeviceName: 'Text Matrix Client',
        newDeviceID: 'FOXDEVICE',
      );
      await otherClient.abortSync();

      await Future.delayed(Duration(milliseconds: 10));
      device = DeviceKeys.fromJson(
        {
          'user_id': client.userID,
          'device_id': client.deviceID,
          'algorithms': [
            AlgorithmTypes.olmV1Curve25519AesSha2,
            AlgorithmTypes.megolmV1AesSha2,
          ],
          'keys': {
            'curve25519:${client.deviceID}': client.identityKey,
            'ed25519:${client.deviceID}': client.fingerprintKey,
          },
        },
        client,
      );
    });

    test('encryptToDeviceMessage', () async {
      payload = await otherClient.encryption!
          .encryptToDeviceMessage([device], 'm.to_device', {'hello': 'foxies'});
    });

    test('decryptToDeviceEvent', () async {
      final encryptedEvent = ToDeviceEvent(
        sender: '@othertest:fakeServer.notExisting',
        type: EventTypes.Encrypted,
        content: payload[client.userID][client.deviceID],
      );
      final decryptedEvent =
          await client.encryption!.decryptToDeviceEvent(encryptedEvent);
      expect(decryptedEvent.type, 'm.to_device');
      expect(decryptedEvent.content['hello'], 'foxies');
    });

    test('decryptToDeviceEvent nocache', () async {
      client.encryption!.olmManager.olmSessions.clear();
      payload = await otherClient.encryption!.encryptToDeviceMessage(
        [device],
        'm.to_device',
        {'hello': 'superfoxies'},
      );
      final encryptedEvent = ToDeviceEvent(
        sender: '@othertest:fakeServer.notExisting',
        type: EventTypes.Encrypted,
        content: payload[client.userID][client.deviceID],
      );
      final decryptedEvent =
          await client.encryption!.decryptToDeviceEvent(encryptedEvent);
      expect(decryptedEvent.type, 'm.to_device');
      expect(decryptedEvent.content['hello'], 'superfoxies');
    });

    test('dispose client', () async {
      await client.dispose(closeDatabase: true);
      await otherClient.dispose(closeDatabase: true);
    });
  });
}
