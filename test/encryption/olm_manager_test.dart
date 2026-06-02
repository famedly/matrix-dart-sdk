// SPDX-FileCopyrightText: 2019-Present, 2020, 2021 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:matrix/encryption/utils/json_signature_check_extension.dart';
import 'package:matrix/matrix.dart';
import 'package:test/test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import '../fake_client.dart';

void main() {
  group('Olm Manager', tags: 'olm', () {
    Logs().level = Level.error;

    late Client client;

    setUpAll(() async {
      await vod.init(
        wasmPath: './pkg/',
        libraryPath: './rust/target/debug/',
      );

      client = await getClient();
    });

    test('signatures', () async {
      final payload = <String, dynamic>{
        'fox': 'floof',
      };
      final signedPayload = client.encryption!.olmManager.signJson(payload);
      expect(
        signedPayload.checkJsonSignature(
          client.fingerprintKey,
          client.userID!,
          client.deviceID!,
        ),
        true,
      );
    });

    test('uploadKeys', () async {
      FakeMatrixApi.calledEndpoints.clear();
      final res = await client.encryption!.olmManager
          .uploadKeys(uploadDeviceKeys: true);
      expect(res, true);
      var sent = json.decode(
        FakeMatrixApi.calledEndpoints['/client/v3/keys/upload']!.first,
      );
      expect(sent['device_keys'] != null, true);
      expect(sent['one_time_keys'] != null, true);
      expect(sent['one_time_keys'].keys.length, 33);
      expect(sent['fallback_keys'] != null, true);
      expect(sent['fallback_keys'].keys.length, 1);
      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption!.olmManager.uploadKeys();
      sent = json.decode(
        FakeMatrixApi.calledEndpoints['/client/v3/keys/upload']!.first,
      );
      expect(sent['device_keys'] != null, false);
      expect(sent['fallback_keys'].keys.length, 1);
      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption!.olmManager
          .uploadKeys(oldKeyCount: 20, unusedFallbackKey: true);
      sent = json.decode(
        FakeMatrixApi.calledEndpoints['/client/v3/keys/upload']!.first,
      );
      expect(sent['one_time_keys'].keys.length, 13);
      expect(sent['fallback_keys'].keys.length, 0);
    });

    test('handleDeviceOneTimeKeysCount', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption!.olmManager
          .handleDeviceOneTimeKeysCount({'signed_curve25519': 20}, null);
      await FakeMatrixApi.firstWhereValue('/client/v3/keys/upload');
      expect(
        FakeMatrixApi.calledEndpoints.containsKey('/client/v3/keys/upload'),
        true,
      );

      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption!.olmManager
          .handleDeviceOneTimeKeysCount({'signed_curve25519': 70}, null);
      await FakeMatrixApi.firstWhereValue('/client/v3/keys/upload')
          .timeout(Duration(milliseconds: 50), onTimeout: () => '');
      expect(
        FakeMatrixApi.calledEndpoints.containsKey('/client/v3/keys/upload'),
        false,
      );

      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption!.olmManager
          .handleDeviceOneTimeKeysCount(null, []);
      await FakeMatrixApi.firstWhereValue('/client/v3/keys/upload');
      expect(
        FakeMatrixApi.calledEndpoints.containsKey('/client/v3/keys/upload'),
        true,
      );

      // this will upload keys because we assume the key count is 0, if the server doesn't send one
      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption!.olmManager
          .handleDeviceOneTimeKeysCount(null, ['signed_curve25519']);
      await FakeMatrixApi.firstWhereValue('/client/v3/keys/upload');
      expect(
        FakeMatrixApi.calledEndpoints.containsKey('/client/v3/keys/upload'),
        true,
      );
    });

    test('restoreOlmSession', () async {
      client.encryption!.olmManager.olmSessions.clear();
      await client.encryption!.olmManager
          .restoreOlmSession(client.userID!, client.identityKey);
      expect(client.encryption!.olmManager.olmSessions.length, 1);

      client.encryption!.olmManager.olmSessions.clear();
      await client.encryption!.olmManager
          .restoreOlmSession(client.userID!, 'invalid');
      expect(client.encryption!.olmManager.olmSessions.length, 0);

      client.encryption!.olmManager.olmSessions.clear();
      await client.encryption!.olmManager
          .restoreOlmSession('invalid', client.identityKey);
      expect(client.encryption!.olmManager.olmSessions.length, 0);
    });

    test('startOutgoingOlmSessions', () async {
      // start an olm session.....with ourself!
      client.encryption!.olmManager.olmSessions.clear();
      await client.encryption!.olmManager.startOutgoingOlmSessions([
        client.userDeviceKeys[client.userID!]!.deviceKeys[client.deviceID]!,
      ]);
      expect(
        client.encryption!.olmManager.olmSessions
            .containsKey(client.identityKey),
        true,
      );
    });

    test('replay to_device events', () async {
      const userId = '@alice:example.com';
      const deviceId = 'JLAFKJWSCS';
      const senderKey = 'L+4+JCl8MD63dgo8z5Ta+9QAHXiANyOVSfgbHA5d3H8';
      FakeMatrixApi.calledEndpoints.clear();
      await client.database.setLastSentMessageUserDeviceKey(
        json.encode({
          'type': 'm.foxies',
          'content': {
            'floof': 'foxhole',
          },
        }),
        userId,
        deviceId,
      );
      var event = ToDeviceEvent(
        sender: userId,
        type: 'm.dummy',
        content: {},
        encryptedContent: {
          'sender_key': senderKey,
        },
      );
      await client.encryption!.olmManager.handleToDeviceEvent(event);
      expect(
        FakeMatrixApi.calledEndpoints.keys.any(
          (k) => k.startsWith('/client/v3/sendToDevice/m.room.encrypted'),
        ),
        true,
      );

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
        userId,
        deviceId,
      );
      event = ToDeviceEvent(
        sender: userId,
        type: 'm.dummy',
        content: {},
        encryptedContent: null,
      );
      await client.encryption!.olmManager.handleToDeviceEvent(event);
      expect(
        FakeMatrixApi.calledEndpoints.keys.any(
          (k) => k.startsWith('/client/v3/sendToDevice/m.room.encrypted'),
        ),
        false,
      );

      // device not found
      FakeMatrixApi.calledEndpoints.clear();
      await client.database.setLastSentMessageUserDeviceKey(
        json.encode({
          'type': 'm.foxies',
          'content': {
            'floof': 'foxhole',
          },
        }),
        userId,
        deviceId,
      );
      event = ToDeviceEvent(
        sender: userId,
        type: 'm.dummy',
        content: {},
        encryptedContent: {
          'sender_key': 'invalid',
        },
      );
      await client.encryption!.olmManager.handleToDeviceEvent(event);
      expect(
        FakeMatrixApi.calledEndpoints.keys.any(
          (k) => k.startsWith('/client/v3/sendToDevice/m.room.encrypted'),
        ),
        false,
      );

      // don't replay if the last event is m.dummy itself
      FakeMatrixApi.calledEndpoints.clear();
      await client.database.setLastSentMessageUserDeviceKey(
        json.encode({
          'type': 'm.dummy',
          'content': {},
        }),
        userId,
        deviceId,
      );
      event = ToDeviceEvent(
        sender: userId,
        type: 'm.dummy',
        content: {},
        encryptedContent: {
          'sender_key': senderKey,
        },
      );
      await client.encryption!.olmManager.handleToDeviceEvent(event);
      expect(
        FakeMatrixApi.calledEndpoints.keys.any(
          (k) => k.startsWith('/client/v3/sendToDevice/m.room.encrypted'),
        ),
        false,
      );
    });

    test('dispose client', () async {
      await client.dispose(closeDatabase: true);
    });
  });
}
