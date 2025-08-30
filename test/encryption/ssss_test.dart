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
import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import '../fake_client.dart';

Uint8List secureRandomBytes(int len) {
  final rng = Random.secure();
  final list = Uint8List(len);
  list.setAll(0, Iterable.generate(list.length, (i) => rng.nextInt(256)));
  return list;
}

class MockSSSS extends SSSS {
  MockSSSS(super.encryption);

  bool requestedSecrets = false;
  @override
  Future<void> maybeRequestAll([List<DeviceKeys>? devices]) async {
    requestedSecrets = true;
    final handle = open();
    await handle.unlock(recoveryKey: ssssKey);
    await handle.maybeCacheAll();
  }
}

void main() {
  group('SSSS', tags: 'olm', () {
    Logs().level = Level.error;

    late Client client;

    setUpAll(() async {
      await vod.init(
        wasmPath: './pkg/',
        libraryPath: './rust/target/debug/',
      );

      client = await getClient();
    });

    test('basic things', () async {
      expect(
        client.encryption!.ssss.defaultKeyId,
        '0FajDWYaM6wQ4O60OZnLvwZfsBNu4Bu3',
      );
    });

    test('encrypt / decrypt', () async {
      final key = Uint8List.fromList(secureRandomBytes(32));

      final enc = await SSSS.encryptAes('secret foxies', key, 'name');
      final dec = await SSSS.decryptAes(enc, key, 'name');
      expect(dec, 'secret foxies');
    });

    test('store', () async {
      final handle = client.encryption!.ssss.open();
      var failed = false;
      try {
        await handle.unlock(passphrase: 'invalid');
      } catch (_) {
        failed = true;
      }
      expect(failed, true);
      expect(handle.isUnlocked, false);
      failed = false;
      try {
        await handle.unlock(recoveryKey: 'invalid');
      } catch (_) {
        failed = true;
      }
      expect(failed, true);
      expect(handle.isUnlocked, false);
      await handle.unlock(passphrase: ssssPassphrase);
      await handle.unlock(recoveryKey: ssssKey);
      expect(handle.isUnlocked, true);
      FakeMatrixApi.calledEndpoints.clear();

      // OpenSSSS store waits for accountdata to be updated before returning
      // but we can't update that before the below endpoint is not hit.
      await handle.ssss
          .store('best animal', 'foxies', handle.keyId, handle.privateKey!);

      final content = FakeMatrixApi
          .calledEndpoints[
              '/client/v3/user/%40test%3AfakeServer.notExisting/account_data/best%20animal']!
          .first;
      client.accountData['best animal'] = BasicEvent.fromJson({
        'type': 'best animal',
        'content': json.decode(content),
      });
      expect(await handle.getStored('best animal'), 'foxies');
    });

    test('encode / decode recovery key', () async {
      final key = Uint8List.fromList(secureRandomBytes(32));
      final encoded = SSSS.encodeRecoveryKey(key);
      var decoded = SSSS.decodeRecoveryKey(encoded);
      expect(key, decoded);

      decoded = SSSS.decodeRecoveryKey('$encoded \n\t');
      expect(key, decoded);

      final handle = client.encryption!.ssss.open();
      await handle.unlock(recoveryKey: ssssKey);
      expect(handle.recoveryKey, ssssKey);
    });

    test('cache', () async {
      await client.encryption!.ssss.clearCache();
      final handle =
          client.encryption!.ssss.open(EventTypes.CrossSigningSelfSigning);
      await handle.unlock(recoveryKey: ssssKey, postUnlock: false);
      expect(
        (await client.encryption!.ssss
                .getCached(EventTypes.CrossSigningSelfSigning)) !=
            null,
        false,
      );
      expect(
        (await client.encryption!.ssss
                .getCached(EventTypes.CrossSigningUserSigning)) !=
            null,
        false,
      );
      await handle.getStored(EventTypes.CrossSigningSelfSigning);
      expect(
        (await client.encryption!.ssss
                .getCached(EventTypes.CrossSigningSelfSigning)) !=
            null,
        true,
      );
      await handle.maybeCacheAll();
      expect(
        (await client.encryption!.ssss
                .getCached(EventTypes.CrossSigningUserSigning)) !=
            null,
        true,
      );
      expect(
        (await client.encryption!.ssss.getCached(EventTypes.MegolmBackup)) !=
            null,
        true,
      );
    });

    test('postUnlock', () async {
      await client.encryption!.ssss.clearCache();
      client.userDeviceKeys[client.userID!]!.masterKey!
          .setDirectVerified(false);
      final handle =
          client.encryption!.ssss.open(EventTypes.CrossSigningSelfSigning);
      await handle.unlock(recoveryKey: ssssKey);
      expect(
        (await client.encryption!.ssss
                .getCached(EventTypes.CrossSigningSelfSigning)) !=
            null,
        true,
      );
      expect(
        (await client.encryption!.ssss
                .getCached(EventTypes.CrossSigningUserSigning)) !=
            null,
        true,
      );
      expect(
        (await client.encryption!.ssss.getCached(EventTypes.MegolmBackup)) !=
            null,
        true,
      );
      expect(
        client.userDeviceKeys[client.userID!]!.masterKey!.directVerified,
        true,
      );
    });

    test('make share requests', () async {
      final key =
          client.userDeviceKeys[client.userID!]!.deviceKeys['OTHERDEVICE']!;
      key.setDirectVerified(true);
      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption!.ssss.request('some.type', [key]);
      expect(
        FakeMatrixApi.calledEndpoints.keys.any(
          (k) => k.startsWith('/client/v3/sendToDevice/m.room.encrypted'),
        ),
        true,
      );
    });

    test('answer to share requests', () async {
      var event = ToDeviceEvent(
        sender: client.userID!,
        type: 'm.secret.request',
        content: {
          'action': 'request',
          'requesting_device_id': 'OTHERDEVICE',
          'name': EventTypes.CrossSigningSelfSigning,
          'request_id': '1',
        },
      );
      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption!.ssss.handleToDeviceEvent(event);
      expect(
        FakeMatrixApi.calledEndpoints.keys.any(
          (k) => k.startsWith('/client/v3/sendToDevice/m.room.encrypted'),
        ),
        true,
      );

      // now test some fail scenarios

      // not by us
      event = ToDeviceEvent(
        sender: '@someotheruser:example.org',
        type: 'm.secret.request',
        content: {
          'action': 'request',
          'requesting_device_id': 'OTHERDEVICE',
          'name': EventTypes.CrossSigningSelfSigning,
          'request_id': '1',
        },
      );
      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption!.ssss.handleToDeviceEvent(event);
      expect(
        FakeMatrixApi.calledEndpoints.keys.any(
          (k) => k.startsWith('/client/v3/sendToDevice/m.room.encrypted'),
        ),
        false,
      );

      // secret not cached
      event = ToDeviceEvent(
        sender: client.userID!,
        type: 'm.secret.request',
        content: {
          'action': 'request',
          'requesting_device_id': 'OTHERDEVICE',
          'name': 'm.unknown.secret',
          'request_id': '1',
        },
      );
      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption!.ssss.handleToDeviceEvent(event);
      expect(
        FakeMatrixApi.calledEndpoints.keys.any(
          (k) => k.startsWith('/client/v3/sendToDevice/m.room.encrypted'),
        ),
        false,
      );

      // is a cancelation
      event = ToDeviceEvent(
        sender: client.userID!,
        type: 'm.secret.request',
        content: {
          'action': 'request_cancellation',
          'requesting_device_id': 'OTHERDEVICE',
          'name': EventTypes.CrossSigningSelfSigning,
          'request_id': '1',
        },
      );
      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption!.ssss.handleToDeviceEvent(event);
      expect(
        FakeMatrixApi.calledEndpoints.keys.any(
          (k) => k.startsWith('/client/v3/sendToDevice/m.room.encrypted'),
        ),
        false,
      );

      // device not verified
      final key =
          client.userDeviceKeys[client.userID!]!.deviceKeys['OTHERDEVICE']!;
      key.setDirectVerified(false);
      client.userDeviceKeys[client.userID!]!.masterKey!
          .setDirectVerified(false);
      event = ToDeviceEvent(
        sender: client.userID!,
        type: 'm.secret.request',
        content: {
          'action': 'request',
          'requesting_device_id': 'OTHERDEVICE',
          'name': EventTypes.CrossSigningSelfSigning,
          'request_id': '1',
        },
      );
      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption!.ssss.handleToDeviceEvent(event);
      expect(
        FakeMatrixApi.calledEndpoints.keys.any(
          (k) => k.startsWith('/client/v3/sendToDevice/m.room.encrypted'),
        ),
        false,
      );
      key.setDirectVerified(true);
    });

    test('receive share requests', () async {
      final key =
          client.userDeviceKeys[client.userID!]!.deviceKeys['OTHERDEVICE']!;
      key.setDirectVerified(true);
      final handle =
          client.encryption!.ssss.open(EventTypes.CrossSigningSelfSigning);
      await handle.unlock(recoveryKey: ssssKey);

      await client.encryption!.ssss.clearCache();
      client.encryption!.ssss.pendingShareRequests.clear();
      await client.encryption!.ssss.request('best animal', [key]);
      var event = ToDeviceEvent(
        sender: client.userID!,
        type: 'm.secret.send',
        content: {
          'request_id': client.encryption!.ssss.pendingShareRequests.keys.first,
          'secret': 'foxies!',
        },
        encryptedContent: {
          'sender_key': key.curve25519Key,
        },
      );
      await client.encryption!.ssss.handleToDeviceEvent(event);
      expect(await client.encryption!.ssss.getCached('best animal'), 'foxies!');

      // test the different validators
      for (final type in [
        EventTypes.CrossSigningSelfSigning,
        EventTypes.CrossSigningUserSigning,
        EventTypes.MegolmBackup,
      ]) {
        final secret = await handle.getStored(type);
        await client.encryption!.ssss.clearCache();
        client.encryption!.ssss.pendingShareRequests.clear();
        await client.encryption!.ssss.request(type, [key]);
        event = ToDeviceEvent(
          sender: client.userID!,
          type: 'm.secret.send',
          content: {
            'request_id':
                client.encryption!.ssss.pendingShareRequests.keys.first,
            'secret': secret,
          },
          encryptedContent: {
            'sender_key': key.curve25519Key,
          },
        );
        await client.encryption!.ssss.handleToDeviceEvent(event);
        expect(await client.encryption!.ssss.getCached(type), secret);
      }

      // test different fail scenarios

      // not encrypted
      await client.encryption!.ssss.clearCache();
      client.encryption!.ssss.pendingShareRequests.clear();
      await client.encryption!.ssss.request('best animal', [key]);
      event = ToDeviceEvent(
        sender: client.userID!,
        type: 'm.secret.send',
        content: {
          'request_id': client.encryption!.ssss.pendingShareRequests.keys.first,
          'secret': 'foxies!',
        },
      );
      await client.encryption!.ssss.handleToDeviceEvent(event);
      expect(await client.encryption!.ssss.getCached('best animal'), null);

      // unknown request id
      await client.encryption!.ssss.clearCache();
      client.encryption!.ssss.pendingShareRequests.clear();
      await client.encryption!.ssss.request('best animal', [key]);
      event = ToDeviceEvent(
        sender: client.userID!,
        type: 'm.secret.send',
        content: {
          'request_id': 'invalid',
          'secret': 'foxies!',
        },
        encryptedContent: {
          'sender_key': key.curve25519Key,
        },
      );
      await client.encryption!.ssss.handleToDeviceEvent(event);
      expect(await client.encryption!.ssss.getCached('best animal'), null);

      // not from a device we sent the request to
      await client.encryption!.ssss.clearCache();
      client.encryption!.ssss.pendingShareRequests.clear();
      await client.encryption!.ssss.request('best animal', [key]);
      event = ToDeviceEvent(
        sender: client.userID!,
        type: 'm.secret.send',
        content: {
          'request_id': client.encryption!.ssss.pendingShareRequests.keys.first,
          'secret': 'foxies!',
        },
        encryptedContent: {
          'sender_key': 'invalid',
        },
      );
      await client.encryption!.ssss.handleToDeviceEvent(event);
      expect(await client.encryption!.ssss.getCached('best animal'), null);

      // secret not a string
      await client.encryption!.ssss.clearCache();
      client.encryption!.ssss.pendingShareRequests.clear();
      await client.encryption!.ssss.request('best animal', [key]);
      event = ToDeviceEvent(
        sender: client.userID!,
        type: 'm.secret.send',
        content: {
          'request_id': client.encryption!.ssss.pendingShareRequests.keys.first,
          'secret': 42,
        },
        encryptedContent: {
          'sender_key': key.curve25519Key,
        },
      );
      await client.encryption!.ssss.handleToDeviceEvent(event);
      expect(await client.encryption!.ssss.getCached('best animal'), null);

      // validator doesn't check out
      await client.encryption!.ssss.clearCache();
      client.encryption!.ssss.pendingShareRequests.clear();
      await client.encryption!.ssss.request(EventTypes.MegolmBackup, [key]);
      event = ToDeviceEvent(
        sender: client.userID!,
        type: 'm.secret.send',
        content: {
          'request_id': client.encryption!.ssss.pendingShareRequests.keys.first,
          'secret': 'foxies!',
        },
        encryptedContent: {
          'sender_key': key.curve25519Key,
        },
      );
      await client.encryption!.ssss.handleToDeviceEvent(event);
      expect(
        await client.encryption!.ssss.getCached(EventTypes.MegolmBackup),
        null,
      );
    });

    test('request all', () async {
      final key =
          client.userDeviceKeys[client.userID!]!.deviceKeys['OTHERDEVICE']!;
      key.setDirectVerified(true);
      await client.encryption!.ssss.clearCache();
      client.encryption!.ssss.pendingShareRequests.clear();
      await client.encryption!.ssss.maybeRequestAll([key]);
      expect(client.encryption!.ssss.pendingShareRequests.length, 3);
    });

    test('periodicallyRequestMissingCache', () async {
      client.userDeviceKeys[client.userID!]!.masterKey!.setDirectVerified(true);
      client.encryption!.ssss = MockSSSS(client.encryption!);
      (client.encryption!.ssss as MockSSSS).requestedSecrets = false;
      await client.encryption!.ssss.periodicallyRequestMissingCache();
      expect((client.encryption!.ssss as MockSSSS).requestedSecrets, true);
      // it should only retry once every 15 min
      (client.encryption!.ssss as MockSSSS).requestedSecrets = false;
      await client.encryption!.ssss.periodicallyRequestMissingCache();
      expect((client.encryption!.ssss as MockSSSS).requestedSecrets, false);
    });

    test('createKey', () async {
      // with passphrase
      var newKey = await client.encryption!.ssss.createKey('test');
      expect(client.encryption!.ssss.isKeyValid(newKey.keyId), true);
      var testKey = client.encryption!.ssss.open(newKey.keyId);
      await testKey.unlock(passphrase: 'test');
      await testKey.setPrivateKey(newKey.privateKey!);

      // without passphrase
      newKey = await client.encryption!.ssss.createKey();
      expect(client.encryption!.ssss.isKeyValid(newKey.keyId), true);
      testKey = client.encryption!.ssss.open(newKey.keyId);
      await testKey.setPrivateKey(newKey.privateKey!);
    });

    test('dispose client', () async {
      await client.dispose(closeDatabase: true);
    });
  });
}
