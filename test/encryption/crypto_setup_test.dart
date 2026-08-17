// SPDX-FileCopyrightText: 2019-Present, 2020 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:matrix/encryption/ssss.dart';
import 'package:matrix/encryption/utils/bootstrap.dart';
import 'package:matrix/encryption/utils/crypto_setup_extension.dart';
import 'package:matrix/matrix.dart';
import 'package:test/test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import '../fake_client.dart';

void main() {
  group('Bootstrap', tags: 'olm', () {
    Logs().level = Level.error;

    setUpAll(() async {
      await vod.init(wasmPath: './pkg/', libraryPath: './rust/target/debug/');
    });

    test('getCryptoIdentityState', () async {
      final client = await getClient();
      final state = await client.getCryptoIdentityState();
      expect(state.initialized, true);
      expect(state.connected, false);
    });

    test('initCryptoIdentity & restoreCryptoIdentity', () async {
      final client = await getClient();
      var state = await client.getCryptoIdentityState();
      expect(state.initialized, true);
      expect(state.connected, false);

      final recoveryKey = await client.initCryptoIdentity();
      expect(recoveryKey.length, 59);
      expect(recoveryKey.substring(0, 2), 'Es');

      state = await client.getCryptoIdentityState();
      expect(state.initialized, true);
      expect(state.connected, true);

      await client.encryption!.ssss.clearCache();

      state = await client.getCryptoIdentityState();
      expect(state.initialized, true);
      expect(state.connected, false);

      await client.restoreCryptoIdentity(recoveryKey);

      state = await client.getCryptoIdentityState();
      expect(state.initialized, true);
      expect(state.connected, true);
    });

    test('initCryptoIdentity with passphrase', () async {
      final client = await getClient();
      const passphrase = 'mySecretPassphrase42%';
      final recoveryKey = await client.initCryptoIdentity(
        passphrase: passphrase,
      );
      expect(recoveryKey.length, 59);
      expect(recoveryKey.substring(0, 2), 'Es');

      await client.encryption!.ssss.clearCache();

      var state = await client.getCryptoIdentityState();
      expect(state.initialized, true);
      expect(state.connected, false);

      await client.restoreCryptoIdentity(recoveryKey, selfSign: false);

      state = await client.getCryptoIdentityState();
      expect(state.initialized, true);
      expect(state.connected, true);

      await client.encryption!.ssss.clearCache();

      state = await client.getCryptoIdentityState();
      expect(state.initialized, true);
      expect(state.connected, false);

      await client.restoreCryptoIdentity(passphrase, selfSign: false);

      state = await client.getCryptoIdentityState();
      expect(state.initialized, true);
      expect(state.connected, true);
    }, timeout: Timeout(Duration(minutes: 2)));

    test(
      'initCryptoIdentity reuses existing SSSS to heal',
      () async {
        final client = await getClient();
        final recoveryKey = await client.initCryptoIdentity();
        final defaultKeyId = client.encryption!.ssss.defaultKeyId;
        final masterPub =
            client.userDeviceKeys[client.userID]!.masterKey!.ed25519Key;

        Future<String> healInPlace() async {
          final ssss = client.encryption!.ssss;
          return client.initCryptoIdentity(
            reuseExistingStorageRecoveryKeyOrPassphrase: recoveryKey,
            wipeSecureStorage: false,
            wipeKeyBackup: false,
            wipeCrossSigning: false,
            setupMasterKey: !ssss.isSecret(EventTypes.CrossSigningMasterKey),
            setupSelfSigningKey: !ssss.isSecret(
              EventTypes.CrossSigningSelfSigning,
            ),
            setupUserSigningKey: !ssss.isSecret(
              EventTypes.CrossSigningUserSigning,
            ),
            setupOnlineKeyBackup: !ssss.isSecret(EventTypes.MegolmBackup),
          );
        }

        // Already initialized — non-destructive; keep key id and master.
        final reusedKey = await healInPlace();
        expect(reusedKey, recoveryKey);
        var state = await client.getCryptoIdentityState();
        expect(state.initialized, true);
        expect(state.connected, true);
        expect(client.encryption!.ssss.defaultKeyId, defaultKeyId);
        expect(
          client.userDeviceKeys[client.userID]!.masterKey!.ed25519Key,
          masterPub,
        );

        // Preserve master: only self/user signing secrets missing.
        for (final type in [
          EventTypes.CrossSigningSelfSigning,
          EventTypes.CrossSigningUserSigning,
        ]) {
          await client.setAccountData(client.userID!, type, {});
        }
        state = await client.getCryptoIdentityState();
        expect(state.keyBackupEnabled, true);
        expect(state.crossSigningEnabled, false);
        expect(state.initialized, false);

        expect(await healInPlace(), recoveryKey);

        state = await client.getCryptoIdentityState();
        expect(state.initialized, true);
        expect(state.connected, true);
        expect(client.encryption!.ssss.defaultKeyId, defaultKeyId);
        expect(
          client.userDeviceKeys[client.userID]!.masterKey!.ed25519Key,
          masterPub,
        );

        await client.encryption!.ssss.clearCache();
        var open = client.encryption!.ssss.open();
        await open.unlock(keyOrPassphrase: recoveryKey);
        expect(open.isUnlocked, true);

        // Missing all cross-signing secrets (keep key backup so SSSS is usable).
        for (final type in [
          EventTypes.CrossSigningMasterKey,
          EventTypes.CrossSigningSelfSigning,
          EventTypes.CrossSigningUserSigning,
        ]) {
          await client.setAccountData(client.userID!, type, {});
        }
        state = await client.getCryptoIdentityState();
        expect(state.keyBackupEnabled, true);
        expect(state.crossSigningEnabled, false);
        expect(state.initialized, false);

        expect(await healInPlace(), recoveryKey);

        state = await client.getCryptoIdentityState();
        expect(state.initialized, true);
        expect(state.connected, true);
        expect(client.encryption!.ssss.defaultKeyId, defaultKeyId);

        await client.encryption!.ssss.clearCache();
        open = client.encryption!.ssss.open();
        await open.unlock(keyOrPassphrase: recoveryKey);
        expect(open.isUnlocked, true);

        // Missing key backup (keep cross-signing so SSSS is usable).
        await client.setAccountData(
          client.userID!,
          EventTypes.MegolmBackup,
          {},
        );
        state = await client.getCryptoIdentityState();
        expect(state.keyBackupEnabled, false);
        expect(state.crossSigningEnabled, true);
        expect(state.initialized, false);

        expect(await healInPlace(), recoveryKey);

        state = await client.getCryptoIdentityState();
        expect(state.initialized, true);
        expect(state.connected, true);
        expect(client.encryption!.ssss.defaultKeyId, defaultKeyId);

        await client.encryption!.ssss.clearCache();
        open = client.encryption!.ssss.open();
        await open.unlock(keyOrPassphrase: recoveryKey);
        expect(open.isUnlocked, true);

        // Only valid SSSS key, no encrypted secrets.
        for (final type in [
          EventTypes.CrossSigningMasterKey,
          EventTypes.CrossSigningSelfSigning,
          EventTypes.CrossSigningUserSigning,
          EventTypes.MegolmBackup,
        ]) {
          await client.setAccountData(client.userID!, type, {});
        }
        state = await client.getCryptoIdentityState();
        expect(state.initialized, false);

        expect(await healInPlace(), recoveryKey);

        state = await client.getCryptoIdentityState();
        expect(state.initialized, true);
        expect(state.connected, true);
        expect(client.encryption!.ssss.defaultKeyId, defaultKeyId);

        await client.encryption!.ssss.clearCache();
        open = client.encryption!.ssss.open();
        await open.unlock(keyOrPassphrase: recoveryKey);
        expect(open.isUnlocked, true);

        // No usable secret storage key — fall back to destructive init.
        for (final type in [
          EventTypes.CrossSigningMasterKey,
          EventTypes.CrossSigningSelfSigning,
          EventTypes.CrossSigningUserSigning,
          EventTypes.MegolmBackup,
        ]) {
          await client.setAccountData(client.userID!, type, {});
        }
        await client.setAccountData(
          client.userID!,
          EventTypes.SecretStorageDefaultKey,
          {},
        );
        state = await client.getCryptoIdentityState();
        expect(state.initialized, false);

        expect(healInPlace, throwsA(isA<BootstrapBadStateException>()));
      },
      timeout: Timeout(Duration(minutes: 2)),
    );

    test(
      'initCryptoIdentity selfSign controls device signing',
      () async {
        final client = await getClient();
        final userId = client.userID!;
        final deviceId = client.deviceID!;

        bool uploadContainsDevice(List<dynamic> uploads) {
          for (final upload in uploads) {
            final body = jsonDecode(upload as String) as Map;
            final userKeys = body[userId] as Map?;
            if (userKeys?.containsKey(deviceId) ?? false) {
              return true;
            }
          }
          return false;
        }

        FakeMatrixApi.calledEndpoints.clear();
        await client.initCryptoIdentity(selfSign: false);
        final noSelfSignUploads =
            FakeMatrixApi
                .calledEndpoints['/client/v3/keys/signatures/upload'] ??
            [];
        expect(uploadContainsDevice(noSelfSignUploads), false);

        FakeMatrixApi.calledEndpoints.clear();
        final recoveryKey = await client.initCryptoIdentity(selfSign: true);
        final selfSignUploads =
            FakeMatrixApi
                .calledEndpoints['/client/v3/keys/signatures/upload'] ??
            [];
        expect(uploadContainsDevice(selfSignUploads), true);
        expect(recoveryKey.length, 59);
      },
      timeout: Timeout(Duration(minutes: 2)),
    );

    test('Add a second recovery key', () async {
      final client = await getClient();
      await client.encryption!.ssss.clearCache();
      var state = await client.getCryptoIdentityState();
      expect(state.initialized, true);
      expect(state.connected, false);

      final recoveryKey1 = await client.initCryptoIdentity();
      state = await client.getCryptoIdentityState();
      expect(state.initialized, true);
      expect(state.connected, true);

      // Add a secondary recovery key
      final openSsss2 = await client.encryption!.ssss.createKey(null, 'second');
      final recoveryKey2 = openSsss2.recoveryKey!;
      for (final type in cacheTypes) {
        final secret = await client.encryption!.ssss.getCached(type);
        await openSsss2.store(type, secret!, add: true);
      }

      await client.encryption!.ssss.clearCache();

      await client.restoreCryptoIdentity(recoveryKey1, selfSign: false);

      state = await client.getCryptoIdentityState();
      expect(state.initialized, true);
      expect(state.connected, true);

      await client.encryption!.ssss.clearCache();

      final defaultKeyId = client.encryption!.ssss.defaultKeyId!;

      await client.restoreCryptoIdentity(
        recoveryKey2,
        keyIdentifier: openSsss2.keyId,
        selfSign: false,
      );

      state = await client.getCryptoIdentityState();
      expect(state.initialized, true);
      expect(state.connected, true);
      expect(client.encryption!.ssss.defaultKeyId, defaultKeyId);
    }, timeout: Timeout(Duration(minutes: 2)));

    test('clearCryptoIdentity reports greenfield identity state', () async {
      final client = await getClient();
      addTearDown(() async {
        await client.dispose(closeDatabase: true);
      });
      await client.clearCryptoIdentity();
      final state = await client.getCryptoIdentityState();
      expect(state.initialized, false);
      expect(state.connected, false);
      expect(state.keyBackupEnabled, false);
      expect(state.crossSigningEnabled, false);
    });

    test(
      'initCryptoIdentity can create a new key after clear',
      () async {
        final client = await getClient();
        addTearDown(() async {
          await client.dispose(closeDatabase: true);
        });
        await client.clearCryptoIdentity();
        final recoveryKey = await client.initCryptoIdentity();
        expect(recoveryKey.substring(0, 2), 'Es');
        final state = await client.getCryptoIdentityState();
        expect(state.initialized, true);
        expect(state.connected, true);
        expect(client.encryption!.ssss.defaultKeyId, isNotNull);
      },
      timeout: Timeout(Duration(minutes: 2)),
    );
  });
}
