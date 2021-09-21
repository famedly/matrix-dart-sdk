// @dart=2.9
/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020, 2021 Famedly GmbH
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
import 'package:matrix/matrix.dart';

import 'package:test/test.dart';
import 'package:olm/olm.dart' as olm;
import 'package:matrix/encryption/utils/json_signature_check_extension.dart';

import '../fake_client.dart';
import '../fake_matrix_api.dart';

void main() {
  group('Olm Manager', () {
    Logs().level = Level.error;
    var olmEnabled = true;

    Client client;

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

    test('signatures', () async {
      if (!olmEnabled) return;
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
      if (!olmEnabled) return;
      FakeMatrixApi.calledEndpoints.clear();
      final res =
          await client.encryption.olmManager.uploadKeys(uploadDeviceKeys: true);
      expect(res, true);
      var sent = json.decode(
          FakeMatrixApi.calledEndpoints['/client/r0/keys/upload'].first);
      expect(sent['device_keys'] != null, true);
      expect(sent['one_time_keys'] != null, true);
      expect(sent['one_time_keys'].keys.length, 66);
      expect(sent['fallback_keys'] != null, true);
      expect(sent['fallback_keys'].keys.length, 1);
      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption.olmManager.uploadKeys();
      sent = json.decode(
          FakeMatrixApi.calledEndpoints['/client/r0/keys/upload'].first);
      expect(sent['device_keys'] != null, false);
      expect(sent['fallback_keys'].keys.length, 1);
      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption.olmManager
          .uploadKeys(oldKeyCount: 20, unusedFallbackKey: true);
      sent = json.decode(
          FakeMatrixApi.calledEndpoints['/client/r0/keys/upload'].first);
      expect(sent['one_time_keys'].keys.length, 46);
      expect(sent['fallback_keys'].keys.length, 0);
    });

    test('handleDeviceOneTimeKeysCount', () async {
      if (!olmEnabled) return;
      FakeMatrixApi.calledEndpoints.clear();
      client.encryption.olmManager
          .handleDeviceOneTimeKeysCount({'signed_curve25519': 20}, null);
      await Future.delayed(Duration(milliseconds: 50));
      expect(
          FakeMatrixApi.calledEndpoints.containsKey('/client/r0/keys/upload'),
          true);

      FakeMatrixApi.calledEndpoints.clear();
      client.encryption.olmManager
          .handleDeviceOneTimeKeysCount({'signed_curve25519': 70}, null);
      await Future.delayed(Duration(milliseconds: 50));
      expect(
          FakeMatrixApi.calledEndpoints.containsKey('/client/r0/keys/upload'),
          false);

      FakeMatrixApi.calledEndpoints.clear();
      client.encryption.olmManager.handleDeviceOneTimeKeysCount(null, []);
      await Future.delayed(Duration(milliseconds: 50));
      expect(
          FakeMatrixApi.calledEndpoints.containsKey('/client/r0/keys/upload'),
          true);

      // this will upload keys because we assume the key count is 0, if the server doesn't send one
      FakeMatrixApi.calledEndpoints.clear();
      client.encryption.olmManager
          .handleDeviceOneTimeKeysCount(null, ['signed_curve25519']);
      await Future.delayed(Duration(milliseconds: 50));
      expect(
          FakeMatrixApi.calledEndpoints.containsKey('/client/r0/keys/upload'),
          true);
    });

    test('restoreOlmSession', () async {
      if (!olmEnabled) return;
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
      if (!olmEnabled) return;
      // start an olm session.....with ourself!
      client.encryption.olmManager.olmSessions.clear();
      await client.encryption.olmManager.startOutgoingOlmSessions(
          [client.userDeviceKeys[client.userID].deviceKeys[client.deviceID]]);
      expect(
          client.encryption.olmManager.olmSessions
              .containsKey(client.identityKey),
          true);
    });

    test('replay to_device events', () async {
      if (!olmEnabled) return;
      final userId = '@alice:example.com';
      final deviceId = 'JLAFKJWSCS';
      final senderKey = 'L+4+JCl8MD63dgo8z5Ta+9QAHXiANyOVSfgbHA5d3H8';
      FakeMatrixApi.calledEndpoints.clear();
      await client.database.setLastSentMessageUserDeviceKey(
          json.encode({
            'type': 'm.foxies',
            'content': {
              'floof': 'foxhole',
            },
          }),
          client.id,
          userId,
          deviceId);
      var event = ToDeviceEvent(
        sender: userId,
        type: 'm.dummy',
        content: {},
        encryptedContent: {
          'sender_key': senderKey,
        },
      );
      await client.encryption.olmManager.handleToDeviceEvent(event);
      expect(
          FakeMatrixApi.calledEndpoints.keys.any(
              (k) => k.startsWith('/client/r0/sendToDevice/m.room.encrypted')),
          true);

      // fail scenarios

      // not encrypted
      FakeMatrixApi.calledEndpoints.clear();
      await client.database.setLastSentMessageUserDeviceKey(
          json.encode({
            'type': 'm.foxies',
            'content': {
              'floof': 'foxhole',
            },
          }),
          client.id,
          userId,
          deviceId);
      event = ToDeviceEvent(
        sender: userId,
        type: 'm.dummy',
        content: {},
        encryptedContent: null,
      );
      await client.encryption.olmManager.handleToDeviceEvent(event);
      expect(
          FakeMatrixApi.calledEndpoints.keys.any(
              (k) => k.startsWith('/client/r0/sendToDevice/m.room.encrypted')),
          false);

      // device not found
      FakeMatrixApi.calledEndpoints.clear();
      await client.database.setLastSentMessageUserDeviceKey(
          json.encode({
            'type': 'm.foxies',
            'content': {
              'floof': 'foxhole',
            },
          }),
          client.id,
          userId,
          deviceId);
      event = ToDeviceEvent(
        sender: userId,
        type: 'm.dummy',
        content: {},
        encryptedContent: {
          'sender_key': 'invalid',
        },
      );
      await client.encryption.olmManager.handleToDeviceEvent(event);
      expect(
          FakeMatrixApi.calledEndpoints.keys.any(
              (k) => k.startsWith('/client/r0/sendToDevice/m.room.encrypted')),
          false);

      // don't replay if the last event is m.dummy itself
      FakeMatrixApi.calledEndpoints.clear();
      await client.database.setLastSentMessageUserDeviceKey(
          json.encode({
            'type': 'm.dummy',
            'content': {},
          }),
          client.id,
          userId,
          deviceId);
      event = ToDeviceEvent(
        sender: userId,
        type: 'm.dummy',
        content: {},
        encryptedContent: {
          'sender_key': senderKey,
        },
      );
      await client.encryption.olmManager.handleToDeviceEvent(event);
      expect(
          FakeMatrixApi.calledEndpoints.keys.any(
              (k) => k.startsWith('/client/r0/sendToDevice/m.room.encrypted')),
          false);
    });

    test('dispose client', () async {
      if (!olmEnabled) return;
      await client.dispose(closeDatabase: true);
    });
  });
}
