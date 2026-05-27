// SPDX-FileCopyrightText: 2019-Present, 2020 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

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
  group(
    'SSSS',
    tags: 'olm',
    () {
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

        await handle.ssss
            .store('best animal', 'foxies', handle.keyId, handle.privateKey!);

        expect(
          FakeMatrixApi.calledEndpoints[
              '/client/v3/user/%40test%3AfakeServer.notExisting/account_data/best%20animal'],
          isNotNull,
        );
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

      test('looksLikeRecoveryKey', () {
        expect(SSSS.looksLikeRecoveryKey(ssssKey), isTrue);
        expect(SSSS.looksLikeRecoveryKey('my-passphrase'), isFalse);
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
            'request_id':
                client.encryption!.ssss.pendingShareRequests.keys.first,
            'secret': 'foxies!',
          },
          encryptedContent: {
            'sender_key': key.curve25519Key,
          },
        );
        await client.encryption!.ssss.handleToDeviceEvent(event);
        expect(
          await client.encryption!.ssss.getCached('best animal'),
          'foxies!',
        );

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
            'request_id':
                client.encryption!.ssss.pendingShareRequests.keys.first,
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
            'request_id':
                client.encryption!.ssss.pendingShareRequests.keys.first,
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
            'request_id':
                client.encryption!.ssss.pendingShareRequests.keys.first,
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
            'request_id':
                client.encryption!.ssss.pendingShareRequests.keys.first,
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
        client.userDeviceKeys[client.userID!]!.masterKey!
            .setDirectVerified(true);
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
        var newKey =
            await client.encryption!.ssss.createKey('test', 'key_name');
        expect(client.encryption!.ssss.isKeyValid(newKey.keyId), true);
        var testKey = client.encryption!.ssss.open(newKey.keyId);
        await testKey.unlock(passphrase: 'test');
        await testKey.setPrivateKey(newKey.privateKey!);
        expect(testKey.keyData.name, 'key_name');

        // without passphrase
        newKey = await client.encryption!.ssss.createKey();
        expect(client.encryption!.ssss.isKeyValid(newKey.keyId), true);
        testKey = client.encryption!.ssss.open(newKey.keyId);
        await testKey.setPrivateKey(newKey.privateKey!);
      });

      test('migrateSecretsToKey strips non-allowed keys when requested',
          () async {
        final ssss = client.encryption!.ssss;
        final defaultKeyId = ssss.defaultKeyId!;
        final defaultKey = ssss.open(defaultKeyId);
        await defaultKey.unlock(recoveryKey: ssssKey);

        final passphraseKey = await ssss.createKey(
          'test-passphrase',
          'passphrase',
        );
        final migratedSecretTypes = await ssss.migrateSecretsToKey(
          primaryUnlockedKey: defaultKey,
          destinationKey: passphraseKey,
          stripKeys: true,
          stripAsDefaultKey: false,
        );
        expect(migratedSecretTypes, isNotEmpty);

        final migratedType = migratedSecretTypes.first;
        final encrypted = client.accountData[migratedType]!.content
            .tryGetMap<String, Object?>('encrypted')!;
        expect(encrypted.containsKey(defaultKeyId), true);
        expect(encrypted.containsKey(passphraseKey.keyId), true);

        final allowed = {defaultKeyId, passphraseKey.keyId};
        final analyzed = ssss.analyzeEncryptedSecrets()[migratedType];
        expect(analyzed, isNotNull);
        expect(analyzed!.difference(allowed), isEmpty);
      });

      test('migrateSecretsToKey without migrated types does not strip',
          () async {
        final ssss = client.encryption!.ssss;
        final defaultKeyId = ssss.defaultKeyId!;
        final defaultKey = ssss.open(defaultKeyId);
        await defaultKey.unlock(recoveryKey: ssssKey);

        final passphraseKey = await ssss.createKey(
          'test-passphrase-new',
          'passphrase-new',
        );
        final staleKey =
            await ssss.createKey('test-passphrase-old', 'passphrase-old');

        const secretType = EventTypes.CrossSigningSelfSigning;
        final secret = await defaultKey.getStored(secretType);
        await passphraseKey.store(secretType, secret, add: true);
        await staleKey.store(secretType, secret, add: true);
        await ssss.migrateSecretsToKey(
          primaryUnlockedKey: defaultKey,
          destinationKey: passphraseKey,
          stripKeys: true,
          stripAsDefaultKey: false,
        );

        final encrypted = client.accountData[secretType]!.content
            .tryGetMap<String, Object?>('encrypted')!;
        final encryptedKeys = encrypted.keys.toSet();
        expect(
          encryptedKeys.containsAll({
            defaultKeyId,
            passphraseKey.keyId,
            staleKey.keyId,
          }),
          true,
        );
        final analyzed = ssss.analyzeEncryptedSecrets()[secretType];
        expect(analyzed, isNotNull);
        expect(
          analyzed!.contains(passphraseKey.keyId),
          true,
        );
        expect(
          analyzed.contains(staleKey.keyId),
          true,
        );
      });

      test(
        'migrateSecretsToKey retries same secret type with fallback key',
        () async {
          final ssss = client.encryption!.ssss;
          final defaultKeyId = ssss.defaultKeyId!;
          final defaultKey = ssss.open(defaultKeyId);
          await defaultKey.unlock(recoveryKey: ssssKey);

          const secretType = EventTypes.CrossSigningSelfSigning;
          final originalSecret = await defaultKey.getStored(secretType);

          final fallbackKey = await ssss.createKey(
            'fallback-passphrase',
            'fallback-key',
          );
          await fallbackKey.store(secretType, originalSecret, add: true);

          final encrypted = Map<String, Object?>.from(
            client.accountData[secretType]!.content
                .tryGetMap<String, Object?>('encrypted')!,
          );
          encrypted[defaultKeyId] = {
            'iv': 'invalid-but-structured-iv',
            'ciphertext': 'invalid-ciphertext',
            'mac': 'invalid-mac',
          };
          await client.setAccountData(client.userID!, secretType, {
            'encrypted': encrypted,
          });

          final destination = await ssss.createKey(
            'destination-passphrase',
            'destination-key',
          );

          final migratedSecretTypes = await ssss.migrateSecretsToKey(
            primaryUnlockedKey: defaultKey,
            destinationKey: destination,
            candidateOldKeys: {fallbackKey.keyId: fallbackKey},
          );
          expect(migratedSecretTypes.contains(secretType), true);

          final migratedSecret = await destination.getStored(secretType);
          expect(migratedSecret, originalSecret);
        },
      );

      test(
        'keyIdForNamedSecretStorageKey prefers key used in encrypted secrets '
        'when names collide',
        () async {
          final ssss = client.encryption!.ssss;
          final defaultKeyId = ssss.defaultKeyId!;
          final defaultKey = ssss.open(defaultKeyId);
          await defaultKey.unlock(recoveryKey: ssssKey);

          const dupName = 'duplicate-name-ssss-test';
          final orphan = await ssss.createKey('orphan-pass', dupName);
          final used = await ssss.createKey('used-pass', dupName);
          await ssss.migrateSecretsToKey(
            primaryUnlockedKey: defaultKey,
            destinationKey: used,
          );

          expect(
            ssss.keyIdForNamedSecretStorageKey(dupName),
            used.keyId,
            reason: 'Orphan key shares name but is not referenced by secrets',
          );
          expect(orphan.keyId, isNot(used.keyId));
        },
      );

      test(
        'keyIdForNamedSecretStorageKey returns only matching key when name is unused',
        () async {
          final ssss = client.encryption!.ssss;
          const unusedName = 'unused-passphrase-name-test';
          final key = await ssss.createKey('orphan-only-pass', unusedName);
          expect(ssss.keyIdForNamedSecretStorageKey(unusedName), key.keyId);
        },
      );

      test(
        'keyIdForNamedSecretStorageKey returns key id for single orphan key',
        () async {
          final ssss = client.encryption!.ssss;
          const orphanName = 'single-orphan-passphrase-test';
          final key = await ssss.createKey('only-definition', orphanName);
          expect(ssss.keyIdForNamedSecretStorageKey(orphanName), key.keyId);
        },
      );

      test(
        'keyIdForNamedSecretStorageKey returns null for multiple unused matching keys',
        () async {
          final ssss = client.encryption!.ssss;
          const dupUnusedName = 'duplicate-unused-passphrase-name-test';
          await ssss.createKey('unused-1', dupUnusedName);
          await ssss.createKey('unused-2', dupUnusedName);

          expect(ssss.keyIdForNamedSecretStorageKey(dupUnusedName), isNull);
        },
      );

      test(
        'hasInvalidEncryptedEntries detects malformed entries and invalid key ids',
        () async {
          final ssss = client.encryption!.ssss;
          final defaultKeyId = ssss.defaultKeyId!;
          final encrypted = client
              .accountData[EventTypes.CrossSigningSelfSigning]!.content
              .tryGetMap<String, Object?>('encrypted')!;
          final validPayload = Map<String, Object?>.from(
            encrypted[defaultKeyId] as Map,
          );

          await client.setAccountData(client.userID!, 'm.test.valid.secret', {
            'encrypted': {defaultKeyId: validPayload},
          });
          expect(ssss.hasInvalidEncryptedEntries('m.test.valid.secret'), false);

          await client.setAccountData(client.userID!, 'm.test.invalid.secret', {
            'encrypted': {
              'missing-fields': {'iv': 'a'},
              'invalid-key-id': validPayload,
            },
          });
          expect(
            ssss.hasInvalidEncryptedEntries('m.test.invalid.secret'),
            true,
          );

          await client.setAccountData(client.userID!, 'm.test.nonmap.secret', {
            'encrypted': {
              defaultKeyId: 'not-a-map',
            },
          });
          expect(ssss.hasInvalidEncryptedEntries('m.test.nonmap.secret'), true);
        },
      );

      test('dispose client', () async {
        await client.dispose(closeDatabase: true);
      });
    },
    timeout: Timeout(const Duration(minutes: 2)),
  );
}
