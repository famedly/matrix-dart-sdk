// SPDX-FileCopyrightText: 2019-Present, 2020 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:test/test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:matrix/encryption/ssss.dart';
import 'package:matrix/encryption/utils/crypto_setup_extension.dart';
import 'package:matrix/matrix.dart';
import '../fake_client.dart';

void main() {
  group('Bootstrap', tags: 'olm', () {
    Logs().level = Level.error;

    setUpAll(() async {
      await vod.init(
        wasmPath: './pkg/',
        libraryPath: './rust/target/debug/',
      );
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

    test('TOFU', () async {
      final client = await getClient();
      await client.initCryptoIdentity();
      expect(
        client.userDeviceKeys['@othertest:fakeServer.notExisting']!.masterKey!
            .lastSeenPublicKey,
        null,
      );
      expect(
        client.userDeviceKeys['@othertest:fakeServer.notExisting']!.masterKey!
            .tofuVerified,
        true,
      );
    });

    test(
      'initCryptoIdentity with passphrase',
      () async {
        final client = await getClient();
        const passphrase = 'mySecretPassphrase42%';
        final recoveryKey =
            await client.initCryptoIdentity(passphrase: passphrase);
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
      },
      timeout: Timeout(Duration(minutes: 2)),
    );
    test(
      'Add a second recovery key',
      () async {
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
        final openSsss2 =
            await client.encryption!.ssss.createKey(null, 'second');
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

        await client.restoreCryptoIdentity(
          recoveryKey2,
          keyIdentifier: openSsss2.keyId,
          selfSign: false,
        );

        state = await client.getCryptoIdentityState();
        expect(state.initialized, true);
        expect(state.connected, true);
      },
      timeout: Timeout(Duration(minutes: 2)),
    );
  });
}
