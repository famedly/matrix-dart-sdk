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
import 'package:famedlysdk/src/utils/logs.dart';
import 'package:test/test.dart';
import 'package:olm/olm.dart' as olm;

import '../fake_client.dart';
import '../fake_matrix_api.dart';

void main() {
  // key @othertest:fakeServer.notExisting
  const otherPickledOlmAccount =
      'VWhVApbkcilKAEGppsPDf9nNVjaK8/IxT3asSR0sYg0S5KgbfE8vXEPwoiKBX2cEvwX3OessOBOkk+ZE7TTbjlrh/KEd31p8Wo+47qj0AP+Ky+pabnhi+/rTBvZy+gfzTqUfCxZrkzfXI9Op4JnP6gYmy7dVX2lMYIIs9WCO1jcmIXiXum5jnfXu1WLfc7PZtO2hH+k9CDKosOFaXRBmsu8k/BGXPSoWqUpvu6WpEG9t5STk4FeAzA';

  group('Encrypt/Decrypt to-device messages', () {
    var olmEnabled = true;
    try {
      olm.init();
      olm.Account();
    } catch (_) {
      olmEnabled = false;
      Logs.warning('[LibOlm] Failed to load LibOlm: ' + _.toString());
    }
    Logs.success('[LibOlm] Enabled: $olmEnabled');

    if (!olmEnabled) return;

    Client client;
    var otherClient = Client('othertestclient', httpClient: FakeMatrixApi());
    DeviceKeys device;
    Map<String, dynamic> payload;

    test('setupClient', () async {
      client = await getClient();
      otherClient.database = client.database;
      await otherClient.checkHomeserver('https://fakeServer.notExisting');
      otherClient.connect(
        newToken: 'abc',
        newUserID: '@othertest:fakeServer.notExisting',
        newHomeserver: otherClient.homeserver,
        newDeviceName: 'Text Matrix Client',
        newDeviceID: 'FOXDEVICE',
        newOlmAccount: otherPickledOlmAccount,
      );

      await Future.delayed(Duration(milliseconds: 10));
      device = DeviceKeys.fromJson({
        'user_id': client.userID,
        'device_id': client.deviceID,
        'algorithms': ['m.olm.v1.curve25519-aes-sha2', 'm.megolm.v1.aes-sha2'],
        'keys': {
          'curve25519:${client.deviceID}': client.identityKey,
          'ed25519:${client.deviceID}': client.fingerprintKey,
        },
      }, client);
    });

    test('encryptToDeviceMessage', () async {
      payload = await otherClient.encryption
          .encryptToDeviceMessage([device], 'm.to_device', {'hello': 'foxies'});
    });

    test('encryptToDeviceMessagePayload', () async {
      // just a hard test if nothing errors
      await otherClient.encryption.encryptToDeviceMessagePayload(
          device, 'm.to_device', {'hello': 'foxies'});
    });

    test('decryptToDeviceEvent', () async {
      final encryptedEvent = ToDeviceEvent(
        sender: '@othertest:fakeServer.notExisting',
        type: EventTypes.Encrypted,
        content: payload[client.userID][client.deviceID],
      );
      final decryptedEvent =
          await client.encryption.decryptToDeviceEvent(encryptedEvent);
      expect(decryptedEvent.type, 'm.to_device');
      expect(decryptedEvent.content['hello'], 'foxies');
    });

    test('decryptToDeviceEvent nocache', () async {
      client.encryption.olmManager.olmSessions.clear();
      payload = await otherClient.encryption.encryptToDeviceMessage(
          [device], 'm.to_device', {'hello': 'superfoxies'});
      final encryptedEvent = ToDeviceEvent(
        sender: '@othertest:fakeServer.notExisting',
        type: EventTypes.Encrypted,
        content: payload[client.userID][client.deviceID],
      );
      final decryptedEvent =
          await client.encryption.decryptToDeviceEvent(encryptedEvent);
      expect(decryptedEvent.type, 'm.to_device');
      expect(decryptedEvent.content['hello'], 'superfoxies');
    });

    test('dispose client', () async {
      await client.dispose(closeDatabase: true);
      await otherClient.dispose(closeDatabase: true);
    });
  });
}
