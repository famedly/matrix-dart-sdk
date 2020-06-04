/*
 *   Ansible inventory script used at Famedly GmbH for managing many hosts
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

import 'package:famedlysdk/famedlysdk.dart';
import 'package:test/test.dart';
import 'package:olm/olm.dart' as olm;

import '../fake_matrix_api.dart';
import '../fake_database.dart';

void main() {
  // key @test:fakeServer.notExisting
  const pickledOlmAccount =
      'N2v1MkIFGcl0mQpo2OCwSopxPQJ0wnl7oe7PKiT4141AijfdTIhRu+ceXzXKy3Kr00nLqXtRv7kid6hU4a+V0rfJWLL0Y51+3Rp/ORDVnQy+SSeo6Fn4FHcXrxifJEJ0djla5u98fBcJ8BSkhIDmtXRPi5/oJAvpiYn+8zMjFHobOeZUAxYR0VfQ9JzSYBsSovoQ7uFkNks1M4EDUvHtu/BjDjz0C3ioDgrrFdoSrn+GSeF5FGKsNu8OLkQ9Lq5+BrUutK5QSJI19uoZj2sj/OixvIpnun8XxYpXo7cfh9MEtKI8ob7lLM2OpZ8BogU70ORgkwthsPSOtxQGPhx8+y5Sg7B6KGlU';

  const otherPickledOlmAccount = 'VWhVApbkcilKAEGppsPDf9nNVjaK8/IxT3asSR0sYg0S5KgbfE8vXEPwoiKBX2cEvwX3OessOBOkk+ZE7TTbjlrh/KEd31p8Wo+47qj0AP+Ky+pabnhi+/rTBvZy+gfzTqUfCxZrkzfXI9Op4JnP6gYmy7dVX2lMYIIs9WCO1jcmIXiXum5jnfXu1WLfc7PZtO2hH+k9CDKosOFaXRBmsu8k/BGXPSoWqUpvu6WpEG9t5STk4FeAzA';

  group('Encrypt/Decrypt to-device messages', () {
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

    var client = Client('testclient', debug: true, httpClient: FakeMatrixApi());
    var otherClient = Client('othertestclient', debug: true, httpClient: FakeMatrixApi());
    final roomId = '!726s6s6q:example.com';
    DeviceKeys device;
    Map<String, dynamic> payload;

    test('setupClient', () async {
      client.database = getDatabase();
      otherClient.database = client.database;
      await client.checkServer('https://fakeServer.notExisting');
      await otherClient.checkServer('https://fakeServer.notExisting');
      final resp = await client.api.login(
        type: 'm.login.password',
        user: 'test',
        password: '1234',
        initialDeviceDisplayName: 'Fluffy Matrix Client',
      );
      client.connect(
        newToken: resp.accessToken,
        newUserID: resp.userId,
        newHomeserver: client.api.homeserver,
        newDeviceName: 'Text Matrix Client',
        newDeviceID: resp.deviceId,
        newOlmAccount: pickledOlmAccount,
      );
      otherClient.connect(
        newToken: 'abc',
        newUserID: '@othertest:fakeServer.notExisting',
        newHomeserver: otherClient.api.homeserver,
        newDeviceName: 'Text Matrix Client',
        newDeviceID: 'FOXDEVICE',
        newOlmAccount: otherPickledOlmAccount,
      );

      await Future.delayed(Duration(milliseconds: 50));
      device = DeviceKeys(
        userId: resp.userId,
        deviceId: resp.deviceId,
        algorithms: ['m.olm.v1.curve25519-aes-sha2', 'm.megolm.v1.aes-sha2'],
        keys: {
          'curve25519:${resp.deviceId}': client.identityKey,
          'ed25519:${resp.deviceId}': client.fingerprintKey,
        },
        verified: true,
        blocked: false,
      );
    });

    test('encryptToDeviceMessage', () async {
      payload = await otherClient.encryption.encryptToDeviceMessage([device], 'm.to_device', {'hello': 'foxies'});
    });

    test('encryptToDeviceMessagePayload', () async {
      // just a hard test if nothing errors
      await otherClient.encryption.encryptToDeviceMessagePayload(device, 'm.to_device', {'hello': 'foxies'});
    });

    test('decryptToDeviceEvent', () async {
      final encryptedEvent = ToDeviceEvent(
        sender: '@othertest:fakeServer.notExisting',
        type: EventTypes.Encrypted,
        content: payload[client.userID][client.deviceID],
      );
      final decryptedEvent = await client.encryption.decryptToDeviceEvent(encryptedEvent);
      expect(decryptedEvent.type, 'm.to_device');
      expect(decryptedEvent.content['hello'], 'foxies');
    });

    test('decryptToDeviceEvent nocache', () async {
      client.encryption.olmManager.olmSessions.clear();
      payload = await otherClient.encryption.encryptToDeviceMessage([device], 'm.to_device', {'hello': 'superfoxies'});
      final encryptedEvent = ToDeviceEvent(
        sender: '@othertest:fakeServer.notExisting',
        type: EventTypes.Encrypted,
        content: payload[client.userID][client.deviceID],
      );
      final decryptedEvent = await client.encryption.decryptToDeviceEvent(encryptedEvent);
      expect(decryptedEvent.type, 'm.to_device');
      expect(decryptedEvent.content['hello'], 'superfoxies');
    });
  });
}
