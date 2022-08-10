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

import 'dart:async';
import 'dart:convert';

import 'package:olm/olm.dart' as olm;
import 'package:test/test.dart';

import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import '../fake_client.dart';

void main() {
  group('Bootstrap', () {
    Logs().level = Level.error;
    var olmEnabled = true;

    late Client client;
    late Map<String, dynamic> oldSecret;
    late String origKeyId;

    test('setupClient', () async {
      client = await getClient();
      await client.abortSync();
    });

    test('setup', () async {
      try {
        await olm.init();
        olm.get_library_version();
      } catch (e) {
        olmEnabled = false;
        Logs().w('[LibOlm] Failed to load LibOlm', e);
      }
      Logs().i('[LibOlm] Enabled: $olmEnabled');
      if (!olmEnabled) return;

      Bootstrap? bootstrap;
      bootstrap = client.encryption!.bootstrap(
        onUpdate: () async {
          while (bootstrap == null) {
            await Future.delayed(Duration(milliseconds: 5));
          }
          if (bootstrap.state == BootstrapState.askWipeSsss) {
            bootstrap.wipeSsss(true);
          } else if (bootstrap.state == BootstrapState.askNewSsss) {
            await bootstrap.newSsss('foxies');
          } else if (bootstrap.state == BootstrapState.askWipeCrossSigning) {
            bootstrap.wipeCrossSigning(true);
          } else if (bootstrap.state == BootstrapState.askSetupCrossSigning) {
            await bootstrap.askSetupCrossSigning(
              setupMasterKey: true,
              setupSelfSigningKey: true,
              setupUserSigningKey: true,
            );
          } else if (bootstrap.state == BootstrapState.askWipeOnlineKeyBackup) {
            bootstrap.wipeOnlineKeyBackup(true);
          } else if (bootstrap.state ==
              BootstrapState.askSetupOnlineKeyBackup) {
            await bootstrap.askSetupOnlineKeyBackup(true);
          }
        },
      );
      while (bootstrap.state != BootstrapState.done) {
        await Future.delayed(Duration(milliseconds: 50));
      }
      final defaultKey = client.encryption!.ssss.open();
      await defaultKey.unlock(passphrase: 'foxies');

      // test all the x-signing keys match up
      for (final keyType in {'master', 'user_signing', 'self_signing'}) {
        final privateKey = base64
            .decode(await defaultKey.getStored('m.cross_signing.$keyType'));
        final keyObj = olm.PkSigning();
        try {
          final pubKey = keyObj.init_with_seed(privateKey);
          expect(
              pubKey,
              client.userDeviceKeys[client.userID]
                  ?.getCrossSigningKey(keyType)
                  ?.publicKey);
        } finally {
          keyObj.free();
        }
      }

      await defaultKey.store('foxes', 'floof');
      await Future.delayed(Duration(milliseconds: 50));
      oldSecret =
          json.decode(json.encode(client.accountData['foxes']!.content));
      origKeyId = defaultKey.keyId;
    }, timeout: Timeout(Duration(minutes: 2)));

    test('change recovery passphrase', () async {
      if (!olmEnabled) return;
      Bootstrap? bootstrap;
      bootstrap = client.encryption!.bootstrap(
        onUpdate: () async {
          while (bootstrap == null) {
            await Future.delayed(Duration(milliseconds: 5));
          }
          if (bootstrap.state == BootstrapState.askWipeSsss) {
            bootstrap.wipeSsss(false);
          } else if (bootstrap.state == BootstrapState.askUseExistingSsss) {
            bootstrap.useExistingSsss(false);
          } else if (bootstrap.state == BootstrapState.askUnlockSsss) {
            await bootstrap.oldSsssKeys![client.encryption!.ssss.defaultKeyId]!
                .unlock(passphrase: 'foxies');
            bootstrap.unlockedSsss();
          } else if (bootstrap.state == BootstrapState.askNewSsss) {
            await bootstrap.newSsss('newfoxies');
          } else if (bootstrap.state == BootstrapState.askWipeCrossSigning) {
            bootstrap.wipeCrossSigning(false);
          } else if (bootstrap.state == BootstrapState.askWipeOnlineKeyBackup) {
            bootstrap.wipeOnlineKeyBackup(false);
          }
        },
      );
      while (bootstrap.state != BootstrapState.done) {
        await Future.delayed(Duration(milliseconds: 50));
      }
      final defaultKey = client.encryption!.ssss.open();
      await defaultKey.unlock(passphrase: 'newfoxies');

      // test all the x-signing keys match up
      for (final keyType in {'master', 'user_signing', 'self_signing'}) {
        final privateKey = base64
            .decode(await defaultKey.getStored('m.cross_signing.$keyType'));
        final keyObj = olm.PkSigning();
        try {
          final pubKey = keyObj.init_with_seed(privateKey);
          expect(
              pubKey,
              client.userDeviceKeys[client.userID]
                  ?.getCrossSigningKey(keyType)
                  ?.publicKey);
        } finally {
          keyObj.free();
        }
      }

      expect(await defaultKey.getStored('foxes'), 'floof');
    }, timeout: Timeout(Duration(minutes: 2)));

    test('change passphrase with multiple keys', () async {
      if (!olmEnabled) return;
      await client.setAccountData(client.userID!, 'foxes', oldSecret);
      await Future.delayed(Duration(milliseconds: 50));

      Bootstrap? bootstrap;
      bootstrap = client.encryption!.bootstrap(
        onUpdate: () async {
          while (bootstrap == null) {
            await Future.delayed(Duration(milliseconds: 5));
          }
          if (bootstrap.state == BootstrapState.askWipeSsss) {
            bootstrap.wipeSsss(false);
          } else if (bootstrap.state == BootstrapState.askUseExistingSsss) {
            bootstrap.useExistingSsss(false);
          } else if (bootstrap.state == BootstrapState.askUnlockSsss) {
            await bootstrap.oldSsssKeys![client.encryption!.ssss.defaultKeyId]!
                .unlock(passphrase: 'newfoxies');
            await bootstrap.oldSsssKeys![origKeyId]!
                .unlock(passphrase: 'foxies');
            bootstrap.unlockedSsss();
          } else if (bootstrap.state == BootstrapState.askNewSsss) {
            await bootstrap.newSsss('supernewfoxies');
          } else if (bootstrap.state == BootstrapState.askWipeCrossSigning) {
            bootstrap.wipeCrossSigning(false);
          } else if (bootstrap.state == BootstrapState.askWipeOnlineKeyBackup) {
            bootstrap.wipeOnlineKeyBackup(false);
          }
        },
      );
      while (bootstrap.state != BootstrapState.done) {
        await Future.delayed(Duration(milliseconds: 50));
      }
      final defaultKey = client.encryption!.ssss.open();
      await defaultKey.unlock(passphrase: 'supernewfoxies');

      // test all the x-signing keys match up
      for (final keyType in {'master', 'user_signing', 'self_signing'}) {
        final privateKey = base64
            .decode(await defaultKey.getStored('m.cross_signing.$keyType'));
        final keyObj = olm.PkSigning();
        try {
          final pubKey = keyObj.init_with_seed(privateKey);
          expect(
              pubKey,
              client.userDeviceKeys[client.userID]
                  ?.getCrossSigningKey(keyType)
                  ?.publicKey);
        } finally {
          keyObj.free();
        }
      }

      expect(await defaultKey.getStored('foxes'), 'floof');
    }, timeout: Timeout(Duration(minutes: 2)));

    test('setup new ssss', () async {
      if (!olmEnabled) return;
      client.accountData.clear();
      Bootstrap? bootstrap;
      bootstrap = client.encryption!.bootstrap(
        onUpdate: () async {
          while (bootstrap == null) {
            await Future.delayed(Duration(milliseconds: 5));
          }
          if (bootstrap.state == BootstrapState.askNewSsss) {
            await bootstrap.newSsss('thenewestfoxies');
          } else if (bootstrap.state == BootstrapState.askSetupCrossSigning) {
            await bootstrap.askSetupCrossSigning();
          } else if (bootstrap.state ==
              BootstrapState.askSetupOnlineKeyBackup) {
            await bootstrap.askSetupOnlineKeyBackup(false);
          }
        },
      );
      while (bootstrap.state != BootstrapState.done) {
        await Future.delayed(Duration(milliseconds: 50));
      }
      final defaultKey = client.encryption!.ssss.open();
      await defaultKey.unlock(passphrase: 'thenewestfoxies');
    }, timeout: Timeout(Duration(minutes: 2)));

    test('bad ssss', () async {
      if (!olmEnabled) return;
      client.accountData.clear();
      await client.setAccountData(client.userID!, 'foxes', oldSecret);
      await Future.delayed(Duration(milliseconds: 50));
      var askedBadSsss = false;
      Bootstrap? bootstrap;
      bootstrap = client.encryption!.bootstrap(
        onUpdate: () async {
          while (bootstrap == null) {
            await Future.delayed(Duration(milliseconds: 5));
          }
          if (bootstrap.state == BootstrapState.askWipeSsss) {
            bootstrap.wipeSsss(false);
          } else if (bootstrap.state == BootstrapState.askBadSsss) {
            askedBadSsss = true;
            bootstrap.ignoreBadSecrets(false);
          }
        },
      );
      while (bootstrap.state != BootstrapState.error) {
        await Future.delayed(Duration(milliseconds: 50));
      }
      expect(askedBadSsss, true);
    });

    test('dispose client', () async {
      if (!olmEnabled) return;
      await client.dispose(closeDatabase: true);
    });

    // see https://github.com/dart-lang/test/issues/1698
    test('KeyVerification dummy test', () async {
      await Future.delayed(Duration(seconds: 1));
    });
  });
}
