// SPDX-FileCopyrightText: 2019-Present, 2020 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';

import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:test/test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import '../fake_client.dart';

void main() {
  group('Bootstrap', tags: 'olm', () {
    Logs().level = Level.error;

    late Client client;
    late Map<String, dynamic> oldSecret;
    late String origKeyId;

    setUpAll(() async {
      await vod.init(wasmPath: './pkg/', libraryPath: './rust/target/debug/');

      client = await getClient();
    });

    test('setup', () async {
      Bootstrap? bootstrap;
      bootstrap = client.encryption!.bootstrap(
        onUpdate: (bootstrap) async {
          if (bootstrap.state == BootstrapState.askWipeSsss) {
            bootstrap.wipeSsss(true);
          } else if (bootstrap.state == BootstrapState.askNewSsss) {
            await bootstrap.newSsss('foxies');
          } else if (bootstrap.state == BootstrapState.askWipeCrossSigning) {
            await bootstrap.wipeCrossSigning(true);
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
        final privateKey = await defaultKey.getStored(
          'm.cross_signing.$keyType',
        );
        final keyObj = vod.PkSigning.fromSecretKey(privateKey);
        final pubKey = keyObj.publicKey.toBase64();
        expect(
          pubKey,
          client.userDeviceKeys[client.userID]
              ?.getCrossSigningKey(keyType)
              ?.publicKey,
        );
      }

      await defaultKey.store('foxes', 'floof');
      await Future.delayed(Duration(milliseconds: 50));
      oldSecret = json.decode(
        json.encode(client.accountData['foxes']!.content),
      );
      origKeyId = defaultKey.keyId;
    }, timeout: Timeout(Duration(minutes: 2)));

    test('change recovery passphrase', () async {
      Bootstrap? bootstrap;
      bootstrap = client.encryption!.bootstrap(
        onUpdate: (bootstrap) async {
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
            await bootstrap.wipeCrossSigning(false);
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
        final privateKey = await defaultKey.getStored(
          'm.cross_signing.$keyType',
        );
        final keyObj = vod.PkSigning.fromSecretKey(privateKey);
        final pubKey = keyObj.publicKey.toBase64();
        expect(
          pubKey,
          client.userDeviceKeys[client.userID]
              ?.getCrossSigningKey(keyType)
              ?.publicKey,
        );
      }

      expect(await defaultKey.getStored('foxes'), 'floof');
    }, timeout: Timeout(Duration(minutes: 2)));

    test(
      'change passphrase with multiple keys',
      () async {
        await client.setAccountData(client.userID!, 'foxes', oldSecret);
        await Future.delayed(Duration(milliseconds: 50));

        Bootstrap? bootstrap;
        bootstrap = client.encryption!.bootstrap(
          onUpdate: (bootstrap) async {
            if (bootstrap.state == BootstrapState.askWipeSsss) {
              bootstrap.wipeSsss(false);
            } else if (bootstrap.state == BootstrapState.askUseExistingSsss) {
              bootstrap.useExistingSsss(false);
            } else if (bootstrap.state == BootstrapState.askUnlockSsss) {
              await bootstrap
                  .oldSsssKeys![client.encryption!.ssss.defaultKeyId]!
                  .unlock(passphrase: 'newfoxies');
              await bootstrap.oldSsssKeys![origKeyId]!.unlock(
                passphrase: 'foxies',
              );
              bootstrap.unlockedSsss();
            } else if (bootstrap.state == BootstrapState.askNewSsss) {
              await bootstrap.newSsss('supernewfoxies');
            } else if (bootstrap.state == BootstrapState.askWipeCrossSigning) {
              await bootstrap.wipeCrossSigning(false);
            } else if (bootstrap.state ==
                BootstrapState.askWipeOnlineKeyBackup) {
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
          final privateKey = await defaultKey.getStored(
            'm.cross_signing.$keyType',
          );
          final keyObj = vod.PkSigning.fromSecretKey(privateKey);
          final pubKey = keyObj.publicKey.toBase64();
          expect(
            pubKey,
            client.userDeviceKeys[client.userID]
                ?.getCrossSigningKey(keyType)
                ?.publicKey,
          );
        }

        expect(await defaultKey.getStored('foxes'), 'floof');
      },
      timeout: Timeout(Duration(minutes: 2)),
    );

    test('setup new ssss', () async {
      client.accountData.clear();
      Bootstrap? bootstrap;
      bootstrap = client.encryption!.bootstrap(
        onUpdate: (bootstrap) async {
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

    test(
      'newSsss skips migration when old key map is empty',
      () async {
        client.accountData.clear();
        final bootstrap = client.encryption!.bootstrap();

        expect(bootstrap.state, BootstrapState.askNewSsss);
        bootstrap.oldSsssKeys = {};

        await bootstrap.newSsss('empty-old-keys-passphrase');

        expect(bootstrap.state, isNot(BootstrapState.error));
        expect(bootstrap.newSsssKey, isNotNull);
      },
      timeout: Timeout(Duration(minutes: 2)),
    );

    test('bad ssss', () async {
      client.accountData.clear();
      await client.setAccountData(client.userID!, 'foxes', oldSecret);
      await Future.delayed(Duration(milliseconds: 50));
      var askedBadSsss = false;
      Bootstrap? bootstrap;
      bootstrap = client.encryption!.bootstrap(
        onUpdate: (bootstrap) async {
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
      await client.dispose(closeDatabase: true);
    });
  });
}
