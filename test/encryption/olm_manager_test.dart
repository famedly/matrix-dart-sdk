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

import 'dart:convert';
import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/src/utils/logs.dart';
import 'package:test/test.dart';
import 'package:olm/olm.dart' as olm;
import 'package:famedlysdk/encryption/utils/json_signature_check_extension.dart';

import '../fake_client.dart';
import '../fake_matrix_api.dart';

void main() {
  group('Olm Manager', () {
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

    test('setupClient', () async {
      client = await getClient();
    });

    test('signatures', () async {
      final payload = <String, dynamic>{
        'fox': 'floof',
      };
      final signedPayload = client.encryption.olmManager.signJson(payload);
      expect(
          signedPayload.checkJsonSignature(
              client.fingerprintKey, client.userID, client.deviceID),
          true);
    });

    test('uploadKeys', () async {
      FakeMatrixApi.calledEndpoints.clear();
      final res =
          await client.encryption.olmManager.uploadKeys(uploadDeviceKeys: true);
      expect(res, true);
      var sent = json.decode(
          FakeMatrixApi.calledEndpoints['/client/r0/keys/upload'].first);
      expect(sent['device_keys'] != null, true);
      expect(sent['one_time_keys'] != null, true);
      expect(sent['one_time_keys'].keys.length, 66);
      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption.olmManager.uploadKeys();
      sent = json.decode(
          FakeMatrixApi.calledEndpoints['/client/r0/keys/upload'].first);
      expect(sent['device_keys'] != null, false);
      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption.olmManager.uploadKeys(oldKeyCount: 20);
      sent = json.decode(
          FakeMatrixApi.calledEndpoints['/client/r0/keys/upload'].first);
      expect(sent['one_time_keys'].keys.length, 46);
    });

    test('handleDeviceOneTimeKeysCount', () async {
      FakeMatrixApi.calledEndpoints.clear();
      client.encryption.olmManager
          .handleDeviceOneTimeKeysCount({'signed_curve25519': 20});
      await Future.delayed(Duration(milliseconds: 50));
      expect(
          FakeMatrixApi.calledEndpoints.containsKey('/client/r0/keys/upload'),
          true);

      FakeMatrixApi.calledEndpoints.clear();
      client.encryption.olmManager
          .handleDeviceOneTimeKeysCount({'signed_curve25519': 70});
      await Future.delayed(Duration(milliseconds: 50));
      expect(
          FakeMatrixApi.calledEndpoints.containsKey('/client/r0/keys/upload'),
          false);
    });

    test('restoreOlmSession', () async {
      client.encryption.olmManager.olmSessions.clear();
      await client.encryption.olmManager
          .restoreOlmSession(client.userID, client.identityKey);
      expect(client.encryption.olmManager.olmSessions.length, 1);

      client.encryption.olmManager.olmSessions.clear();
      await client.encryption.olmManager
          .restoreOlmSession(client.userID, 'invalid');
      expect(client.encryption.olmManager.olmSessions.length, 0);

      client.encryption.olmManager.olmSessions.clear();
      await client.encryption.olmManager
          .restoreOlmSession('invalid', client.identityKey);
      expect(client.encryption.olmManager.olmSessions.length, 0);
    });

    test('startOutgoingOlmSessions', () async {
      // start an olm session.....with ourself!
      client.encryption.olmManager.olmSessions.clear();
      await client.encryption.olmManager.startOutgoingOlmSessions(
          [client.userDeviceKeys[client.userID].deviceKeys[client.deviceID]]);
      expect(
          client.encryption.olmManager.olmSessions
              .containsKey(client.identityKey),
          true);
    });

    test('dispose client', () async {
      await client.dispose(closeDatabase: true);
    });
  });
}
