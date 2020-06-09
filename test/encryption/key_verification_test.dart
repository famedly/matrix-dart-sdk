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
import 'package:famedlysdk/encryption.dart';
import 'package:test/test.dart';
import 'package:olm/olm.dart' as olm;

import '../fake_client.dart';

void main() {
  /// All Tests related to the ChatTime
  group('Key Verification', () {
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
    Room room;
    var updateCounter = 0;
    KeyVerification keyVerification;

    test('setupClient', () async {
      client = await getClient();
      room = Room(id: '!localpart:server.abc', client: client);
      keyVerification = KeyVerification(
        encryption: client.encryption,
        room: room,
        userId: '@alice:example.com',
        deviceId: 'ABCD',
        onUpdate: () => updateCounter++,
      );
    });

    test('acceptSas', () async {
      await keyVerification.acceptSas();
    });
    test('acceptVerification', () async {
      await keyVerification.acceptVerification();
    });
    test('cancel', () async {
      await keyVerification.cancel('m.cancelcode');
      expect(keyVerification.canceled, true);
      expect(keyVerification.canceledCode, 'm.cancelcode');
      expect(keyVerification.canceledReason, null);
    });
    test('handlePayload', () async {
      await keyVerification.handlePayload('m.key.verification.request', {
        'from_device': 'AliceDevice2',
        'methods': ['m.sas.v1'],
        'timestamp': 1559598944869,
        'transaction_id': 'S0meUniqueAndOpaqueString'
      });
      await keyVerification.handlePayload('m.key.verification.start', {
        'from_device': 'BobDevice1',
        'method': 'm.sas.v1',
        'transaction_id': 'S0meUniqueAndOpaqueString'
      });
      await keyVerification.handlePayload('m.key.verification.cancel', {
        'code': 'm.user',
        'reason': 'User rejected the key verification request',
        'transaction_id': 'S0meUniqueAndOpaqueString'
      });
    });
    test('rejectSas', () async {
      await keyVerification.rejectSas();
    });
    test('rejectVerification', () async {
      await keyVerification.rejectVerification();
    });
    test('start', () async {
      await keyVerification.start();
    });
    test('verifyActivity', () async {
      final verified = await keyVerification.verifyActivity();
      expect(verified, true);
      keyVerification?.dispose();
    });

    test('dispose client', () async {
      await client.dispose(closeDatabase: true);
    });
  });
}
