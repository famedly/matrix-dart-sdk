// SPDX-FileCopyrightText: 2026 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:matrix/matrix.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  group('MatrixSdkDatabase secure storage', () {
    late Map<String, String> secureStore;
    late MatrixSdkDatabase database;
    const name = 'secure_storage_test';

    setUp(() async {
      secureStore = {};
      database = await MatrixSdkDatabase.init(
        name,
        database: await databaseFactoryFfi.openDatabase(
          ':memory:',
          options: OpenDatabaseOptions(singleInstance: false),
        ),
        sqfliteFactory: databaseFactoryFfi,
        secureStorage: (
          read: (key) async => secureStore[key],
          write: (key, value) async => secureStore[key] = value,
          delete: (key) async => secureStore.remove(key),
        ),
      );
    });

    test('storeClient and updateClientKeys write to secure storage', () async {
      await database.storeClient(
        homeserverUrl: 'https://example.org',
        token: 'token',
        refreshToken: 'refresh',
        userId: '@alice:example.org',
        deviceId: 'DEVICE',
        olmAccount: 'olm1',
      );
      final stored =
          jsonDecode(secureStore['client_data_$name']!) as Map<String, Object?>;
      expect(stored['token'], 'token');
      expect(stored['refresh_token'], 'refresh');
      expect(stored['olm_account'], 'olm1');
      expect(stored.containsKey('token_expires_at'), isFalse);

      await database.updateClientKeys('olm2');
      final updated =
          jsonDecode(secureStore['client_data_$name']!) as Map<String, Object?>;
      expect(updated['olm_account'], 'olm2');
      expect(updated['token'], 'token');

      final client = await database.getClient(name);
      expect(client?['olm_account'], 'olm2');
      expect(client?['user_id'], '@alice:example.org');
      expect(client?['device_id'], 'DEVICE');
    });

    test('getClient prefers secure storage values', () async {
      await database.storeClient(
        homeserverUrl: 'https://example.org',
        token: 'token',
        userId: '@alice:example.org',
      );
      secureStore['client_data_$name'] = jsonEncode({'token': 'secure'});
      final client = await database.getClient(name);
      expect(client?['token'], 'secure');
      expect(client?['homeserver_url'], 'https://example.org');
    });

    test('SSSS cache is stored in secure storage', () async {
      const type = EventTypes.MegolmBackup;
      await database.storeSSSSCache(type, 'keyId', 'ciphertext', 'content');
      expect(secureStore['ssss_cache_${name}_$type'], isNotNull);

      final cache = await database.getSSSSCache(type);
      expect(cache?.content, 'content');

      await database.clearSSSSCache();
      expect(secureStore, isEmpty);
      expect(await database.getSSSSCache(type), isNull);
    });

    test('clear wipes secure storage', () async {
      await database.storeClient(
        homeserverUrl: 'https://example.org',
        token: 'token',
        userId: '@alice:example.org',
      );
      await database.storeSSSSCache(
        EventTypes.CrossSigningSelfSigning,
        'keyId',
        'ciphertext',
        'content',
      );
      await database.clear();
      expect(secureStore, isEmpty);
      expect(await database.getClient(name), isNull);
    });
  });
}
