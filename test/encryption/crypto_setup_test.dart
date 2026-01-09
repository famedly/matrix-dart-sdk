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

import 'package:test/test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:matrix/encryption/utils/crypto_setup_extension.dart';
import 'package:matrix/matrix.dart';
import '../fake_client.dart';

void main() {
  group('Bootstrap', tags: 'olm', () {
    Logs().level = Level.error;

    late Client client;

    setUpAll(() async {
      await vod.init(
        wasmPath: './pkg/',
        libraryPath: './rust/target/debug/',
      );

      client = await getClient();
    });

    test('getCryptoIdentityState', () async {
      final state = await client.getCryptoIdentityState();
      expect(state.initialized, true);
      expect(state.connected, false);
    });

    test('initCryptoIdentity & restoreCryptoIdentity', () async {
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
      const passphrase = 'mySecretPassphrase42%';
      final recoveryKey =
          await client.initCryptoIdentity(passphrase: passphrase);
      expect(recoveryKey.length, 59);
      expect(recoveryKey.substring(0, 2), 'Es');

      await client.encryption!.ssss.clearCache();

      var state = await client.getCryptoIdentityState();
      expect(state.initialized, true);
      expect(state.connected, false);

      await client.restoreCryptoIdentity(recoveryKey);

      state = await client.getCryptoIdentityState();
      expect(state.initialized, true);
      expect(state.connected, true);

      await client.encryption!.ssss.clearCache();

      state = await client.getCryptoIdentityState();
      expect(state.initialized, true);
      expect(state.connected, false);

      await client.restoreCryptoIdentity(passphrase);

      state = await client.getCryptoIdentityState();
      expect(state.initialized, true);
      expect(state.connected, true);
    });
  });
}
