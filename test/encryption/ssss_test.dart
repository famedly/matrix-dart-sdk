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

import 'dart:typed_data';
import 'dart:convert';

import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/matrix_api.dart';
import 'package:famedlysdk/encryption.dart';
import 'package:test/test.dart';
import 'package:encrypt/encrypt.dart';
import 'package:olm/olm.dart' as olm;

import '../fake_client.dart';
import '../fake_matrix_api.dart';

void main() {
  group('SSSS', () {
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

    Client client;

    test('setupClient', () async {
      client = await getClient();
    });

    test('basic things', () async {
      expect(client.encryption.ssss.defaultKeyId,
          '0FajDWYaM6wQ4O60OZnLvwZfsBNu4Bu3');
    });

    test('encrypt / decrypt', () {
      final key = Uint8List.fromList(SecureRandom(32).bytes);

      final enc = SSSS.encryptAes('secret foxies', key, 'name');
      final dec = SSSS.decryptAes(enc, key, 'name');
      expect(dec, 'secret foxies');
    });

    test('store', () async {
      final handle = client.encryption.ssss.open();
      var failed = false;
      try {
        handle.unlock(passphrase: 'invalid');
      } catch (_) {
        failed = true;
      }
      expect(failed, true);
      expect(handle.isUnlocked, false);
      failed = false;
      try {
        handle.unlock(recoveryKey: 'invalid');
      } catch (_) {
        failed = true;
      }
      expect(failed, true);
      expect(handle.isUnlocked, false);
      handle.unlock(passphrase: SSSS_PASSPHRASE);
      handle.unlock(recoveryKey: SSSS_KEY);
      expect(handle.isUnlocked, true);
      FakeMatrixApi.calledEndpoints.clear();
      await handle.store('best animal', 'foxies');
      // alright, since we don't properly sync we will manually have to update
      // account_data for this test
      final content = FakeMatrixApi
          .calledEndpoints[
              '/client/r0/user/%40test%3AfakeServer.notExisting/account_data/best+animal']
          .first;
      client.accountData['best animal'] = BasicEvent.fromJson({
        'type': 'best animal',
        'content': json.decode(content),
      });
      expect(await handle.getStored('best animal'), 'foxies');
    });

    test('cache', () async {
      final handle =
          client.encryption.ssss.open('m.cross_signing.self_signing');
      handle.unlock(recoveryKey: SSSS_KEY);
      expect(
          (await client.encryption.ssss
                  .getCached('m.cross_signing.self_signing')) !=
              null,
          false);
      expect(
          (await client.encryption.ssss
                  .getCached('m.cross_signing.user_signing')) !=
              null,
          false);
      await handle.getStored('m.cross_signing.self_signing');
      expect(
          (await client.encryption.ssss
                  .getCached('m.cross_signing.self_signing')) !=
              null,
          true);
      await handle.maybeCacheAll();
      expect(
          (await client.encryption.ssss
                  .getCached('m.cross_signing.user_signing')) !=
              null,
          true);
      expect(
          (await client.encryption.ssss.getCached('m.megolm_backup.v1')) !=
              null,
          true);
    });

    test('make share requests', () async {
      final key =
          client.userDeviceKeys[client.userID].deviceKeys['OTHERDEVICE'];
      key.setDirectVerified(true);
      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption.ssss.request('some.type', [key]);
      expect(
          FakeMatrixApi.calledEndpoints.keys.any(
              (k) => k.startsWith('/client/r0/sendToDevice/m.room.encrypted')),
          true);
    });

    test('answer to share requests', () async {
      var event = ToDeviceEvent(
        sender: client.userID,
        type: 'm.secret.request',
        content: {
          'action': 'request',
          'requesting_device_id': 'OTHERDEVICE',
          'name': 'm.cross_signing.self_signing',
          'request_id': '1',
        },
      );
      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption.ssss.handleToDeviceEvent(event);
      expect(
          FakeMatrixApi.calledEndpoints.keys.any(
              (k) => k.startsWith('/client/r0/sendToDevice/m.room.encrypted')),
          true);

      // now test some fail scenarios

      // not by us
      event = ToDeviceEvent(
        sender: '@someotheruser:example.org',
        type: 'm.secret.request',
        content: {
          'action': 'request',
          'requesting_device_id': 'OTHERDEVICE',
          'name': 'm.cross_signing.self_signing',
          'request_id': '1',
        },
      );
      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption.ssss.handleToDeviceEvent(event);
      expect(
          FakeMatrixApi.calledEndpoints.keys.any(
              (k) => k.startsWith('/client/r0/sendToDevice/m.room.encrypted')),
          false);

      // secret not cached
      event = ToDeviceEvent(
        sender: client.userID,
        type: 'm.secret.request',
        content: {
          'action': 'request',
          'requesting_device_id': 'OTHERDEVICE',
          'name': 'm.unknown.secret',
          'request_id': '1',
        },
      );
      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption.ssss.handleToDeviceEvent(event);
      expect(
          FakeMatrixApi.calledEndpoints.keys.any(
              (k) => k.startsWith('/client/r0/sendToDevice/m.room.encrypted')),
          false);

      // is a cancelation
      event = ToDeviceEvent(
        sender: client.userID,
        type: 'm.secret.request',
        content: {
          'action': 'request_cancellation',
          'requesting_device_id': 'OTHERDEVICE',
          'name': 'm.cross_signing.self_signing',
          'request_id': '1',
        },
      );
      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption.ssss.handleToDeviceEvent(event);
      expect(
          FakeMatrixApi.calledEndpoints.keys.any(
              (k) => k.startsWith('/client/r0/sendToDevice/m.room.encrypted')),
          false);

      // device not verified
      final key =
          client.userDeviceKeys[client.userID].deviceKeys['OTHERDEVICE'];
      key.setDirectVerified(false);
      event = ToDeviceEvent(
        sender: client.userID,
        type: 'm.secret.request',
        content: {
          'action': 'request',
          'requesting_device_id': 'OTHERDEVICE',
          'name': 'm.cross_signing.self_signing',
          'request_id': '1',
        },
      );
      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption.ssss.handleToDeviceEvent(event);
      expect(
          FakeMatrixApi.calledEndpoints.keys.any(
              (k) => k.startsWith('/client/r0/sendToDevice/m.room.encrypted')),
          false);
      key.setDirectVerified(true);
    });

    test('receive share requests', () async {
      final key =
          client.userDeviceKeys[client.userID].deviceKeys['OTHERDEVICE'];
      key.setDirectVerified(true);
      final handle =
          client.encryption.ssss.open('m.cross_signing.self_signing');
      handle.unlock(recoveryKey: SSSS_KEY);

      await client.database.clearSSSSCache(client.id);
      client.encryption.ssss.pendingShareRequests.clear();
      await client.encryption.ssss.request('best animal', [key]);
      var event = ToDeviceEvent(
        sender: client.userID,
        type: 'm.secret.send',
        content: {
          'request_id': client.encryption.ssss.pendingShareRequests.keys.first,
          'secret': 'foxies!',
        },
        encryptedContent: {
          'sender_key': key.curve25519Key,
        },
      );
      await client.encryption.ssss.handleToDeviceEvent(event);
      expect(await client.encryption.ssss.getCached('best animal'), 'foxies!');

      // test the different validators
      for (final type in [
        'm.cross_signing.self_signing',
        'm.cross_signing.user_signing',
        'm.megolm_backup.v1'
      ]) {
        final secret = await handle.getStored(type);
        await client.database.clearSSSSCache(client.id);
        client.encryption.ssss.pendingShareRequests.clear();
        await client.encryption.ssss.request(type, [key]);
        event = ToDeviceEvent(
          sender: client.userID,
          type: 'm.secret.send',
          content: {
            'request_id':
                client.encryption.ssss.pendingShareRequests.keys.first,
            'secret': secret,
          },
          encryptedContent: {
            'sender_key': key.curve25519Key,
          },
        );
        await client.encryption.ssss.handleToDeviceEvent(event);
        expect(await client.encryption.ssss.getCached(type), secret);
      }

      // test different fail scenarios

      // not encrypted
      await client.database.clearSSSSCache(client.id);
      client.encryption.ssss.pendingShareRequests.clear();
      await client.encryption.ssss.request('best animal', [key]);
      event = ToDeviceEvent(
        sender: client.userID,
        type: 'm.secret.send',
        content: {
          'request_id': client.encryption.ssss.pendingShareRequests.keys.first,
          'secret': 'foxies!',
        },
      );
      await client.encryption.ssss.handleToDeviceEvent(event);
      expect(await client.encryption.ssss.getCached('best animal'), null);

      // unknown request id
      await client.database.clearSSSSCache(client.id);
      client.encryption.ssss.pendingShareRequests.clear();
      await client.encryption.ssss.request('best animal', [key]);
      event = ToDeviceEvent(
        sender: client.userID,
        type: 'm.secret.send',
        content: {
          'request_id': 'invalid',
          'secret': 'foxies!',
        },
        encryptedContent: {
          'sender_key': key.curve25519Key,
        },
      );
      await client.encryption.ssss.handleToDeviceEvent(event);
      expect(await client.encryption.ssss.getCached('best animal'), null);

      // not from a device we sent the request to
      await client.database.clearSSSSCache(client.id);
      client.encryption.ssss.pendingShareRequests.clear();
      await client.encryption.ssss.request('best animal', [key]);
      event = ToDeviceEvent(
        sender: client.userID,
        type: 'm.secret.send',
        content: {
          'request_id': client.encryption.ssss.pendingShareRequests.keys.first,
          'secret': 'foxies!',
        },
        encryptedContent: {
          'sender_key': 'invalid',
        },
      );
      await client.encryption.ssss.handleToDeviceEvent(event);
      expect(await client.encryption.ssss.getCached('best animal'), null);

      // secret not a string
      await client.database.clearSSSSCache(client.id);
      client.encryption.ssss.pendingShareRequests.clear();
      await client.encryption.ssss.request('best animal', [key]);
      event = ToDeviceEvent(
        sender: client.userID,
        type: 'm.secret.send',
        content: {
          'request_id': client.encryption.ssss.pendingShareRequests.keys.first,
          'secret': 42,
        },
        encryptedContent: {
          'sender_key': key.curve25519Key,
        },
      );
      await client.encryption.ssss.handleToDeviceEvent(event);
      expect(await client.encryption.ssss.getCached('best animal'), null);

      // validator doesn't check out
      await client.database.clearSSSSCache(client.id);
      client.encryption.ssss.pendingShareRequests.clear();
      await client.encryption.ssss.request('m.megolm_backup.v1', [key]);
      event = ToDeviceEvent(
        sender: client.userID,
        type: 'm.secret.send',
        content: {
          'request_id': client.encryption.ssss.pendingShareRequests.keys.first,
          'secret': 'foxies!',
        },
        encryptedContent: {
          'sender_key': key.curve25519Key,
        },
      );
      await client.encryption.ssss.handleToDeviceEvent(event);
      expect(
          await client.encryption.ssss.getCached('m.megolm_backup.v1'), null);
    });

    test('request all', () async {
      final key =
          client.userDeviceKeys[client.userID].deviceKeys['OTHERDEVICE'];
      key.setDirectVerified(true);
      await client.database.clearSSSSCache(client.id);
      client.encryption.ssss.pendingShareRequests.clear();
      await client.encryption.ssss.maybeRequestAll([key]);
      expect(client.encryption.ssss.pendingShareRequests.length, 3);
    });

    test('dispose client', () async {
      await client.dispose(closeDatabase: true);
    });
  });
}
