// SPDX-FileCopyrightText: 2019-Present, 2020 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:typed_data';

import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:test/test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import '../fake_client.dart';

void main() async {
  // need to mock to pass correct data to handleToDeviceEvent
  Future<void> ingestCorrectReadyEvent(
    KeyVerification req1,
    KeyVerification req2,
  ) async {
    final copyKnownVerificationMethods = List<String>.from(
      await req2.knownVerificationMethods,
    );

    // this is the same logic from `acceptVerification()` just couldn't find a
    // easy to to mock it
    // qr code only works when atleast one side has verified master key
    if (req2.userId == req2.client.userID) {
      final ownKeys = await req2.client.fetchUserDeviceKeysLists({
        req2.client.userID!,
      });
      if (!(await ownKeys[req2.client.userID]?.deviceKeys[req2.deviceId]
                  ?.hasValidSignatureChain(verifiedByTheirMasterKey: true) ??
              false) &&
          !(await ownKeys[req2.client.userID]?.masterKey?.verified ?? false)) {
        copyKnownVerificationMethods.removeWhere(
          (element) => element.startsWith('m.qr_code'),
        );
        copyKnownVerificationMethods.remove(EventTypes.Reciprocate);
      }
    }
    await req1.client.encryption!.keyVerificationManager.handleToDeviceEvent(
      ToDeviceEvent(
        type: EventTypes.KeyVerificationReady,
        sender: req2.client.userID!,
        content: {
          'from_device': req2.client.deviceID,
          'methods': copyKnownVerificationMethods,
          'transaction_id': req2.transactionId,
        },
      ),
    );
  }

  /// All Tests related to the ChatTime
  group('Key Verification', tags: 'olm', () {
    Logs().level = Level.error;

    late Client client1;
    late Client client2;
    Future? vodInit;

    setUp(() async {
      vodInit ??= vod.init(
        wasmPath: './pkg/',
        libraryPath: './rust/target/debug/',
      );
      await vodInit;
      client1 = await getClient();
      client2 = await getOtherClient();

      await Future.delayed(Duration(milliseconds: 10));
      client1.verificationMethods = {
        KeyVerificationMethod.emoji,
        KeyVerificationMethod.numbers,
        KeyVerificationMethod.qrScan,
        KeyVerificationMethod.reciprocate,
      };
      client2.verificationMethods = {
        KeyVerificationMethod.emoji,
        KeyVerificationMethod.numbers,
        KeyVerificationMethod.qrShow,
        KeyVerificationMethod.reciprocate,
      };
    });
    tearDown(() async {
      await client1.dispose(closeDatabase: true);
      await client2.dispose(closeDatabase: true);
    });

    test('Run qr verification mode 1', () async {
      expect(
        await (await client1.fetchUserDeviceKeysLists({
          client2.userID!,
        }))[client2.userID!]?.masterKey!.verified,
        false,
      );
      expect(
        await (await client2.fetchUserDeviceKeysLists({
          client1.userID!,
        }))[client1.userID!]?.masterKey!.verified,
        false,
      );
      expect(
        await (await client1.fetchUserDeviceKeysLists({
          client2.userID!,
        }))[client2.userID!]?.deviceKeys[client2.deviceID]?.verified,
        false,
      );
      expect(
        await (await client2.fetchUserDeviceKeysLists({
          client1.userID!,
        }))[client1.userID!]?.deviceKeys[client1.deviceID]?.verified,
        false,
      );
      // make sure our master key is *not* verified to not triger SSSS for now
      await (await client1.fetchUserDeviceKeysLists({
        client1.userID!,
      }))[client1.userID!]!.masterKey!.setVerified(true, false);
      await (await client2.fetchUserDeviceKeysLists({
        client2.userID!,
      }))[client2.userID!]!.masterKey!.setVerified(false, false);
      await client1.encryption!.ssss.clearCache();
      final req1 =
          await (await client1.fetchUserDeviceKeysLists({
            client2.userID!,
          }))[client2.userID!]!.startVerification(
            newDirectChatEnableEncryption: false,
          );

      expect(req1.state, KeyVerificationState.askSSSS);
      await req1.openSSSS(recoveryKey: ssssKey);

      expect(req1.state, KeyVerificationState.waitingAccept);

      final comp = Completer<KeyVerification>();
      final sub = client2.onKeyVerificationRequest.stream.listen(comp.complete);
      await client2.encryption!.keyVerificationManager.handleToDeviceEvent(
        ToDeviceEvent(
          type: EventTypes.KeyVerificationRequest,
          sender: req1.client.userID!,
          content: {
            'from_device': req1.client.deviceID,
            'methods': await req1.knownVerificationMethods,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'transaction_id': req1.transactionId,
          },
        ),
      );

      final req2 = await comp.future;
      await sub.cancel();

      expect(
        client2.encryption!.keyVerificationManager.getRequest(
          req2.transactionId!,
        ),
        req2,
      );

      expect(req1.possibleMethods, []);
      await req2.acceptVerification();

      expect(req2.state, KeyVerificationState.askChoice);
      await ingestCorrectReadyEvent(req1, req2);
      expect(req1.possibleMethods, [
        EventTypes.Sas,
        EventTypes.Reciprocate,
        EventTypes.QRScan,
      ]);
      expect(req2.possibleMethods, [
        EventTypes.Sas,
        EventTypes.Reciprocate,
        EventTypes.QRShow,
      ]);

      expect(req1.state, KeyVerificationState.askChoice);

      expect(await req1.getOurQRMode(), QRMode.verifySelfTrusted);
      expect(await req2.getOurQRMode(), QRMode.verifySelfUntrusted);

      // send start
      await req1.continueVerification(
        EventTypes.Reciprocate,
        qrDataRawBytes: Uint8List.fromList(req2.qrCode?.qrDataRawBytes ?? []),
      );

      expect(req2.qrCode!.randomSharedSecret, req1.randomSharedSecretForQRCode);
      expect(req1.state, KeyVerificationState.showQRSuccess);

      await client2.encryption!.keyVerificationManager.handleToDeviceEvent(
        ToDeviceEvent(
          type: 'm.key.verification.start',
          sender: req1.client.userID!,
          content: {
            'from_device': req1.client.deviceID,
            'm.relates_to': {
              'event_id': req1.transactionId,
              'rel_type': 'm.reference',
            },
            'method': EventTypes.Reciprocate,
            'secret': req1.randomSharedSecretForQRCode,
            'transaction_id': req1.transactionId,
          },
        ),
      );

      expect(req2.state, KeyVerificationState.confirmQRScan);

      await req2.acceptQRScanConfirmation();

      await client1.encryption!.keyVerificationManager.handleToDeviceEvent(
        ToDeviceEvent(
          type: 'm.key.verification.done',
          sender: req2.client.userID!,
          content: {'transaction_id': req2.transactionId},
        ),
      );

      expect(req1.state, KeyVerificationState.done);
      expect(req2.state, KeyVerificationState.done);

      expect(
        await (await client1.fetchUserDeviceKeysLists({
          client2.userID!,
        }))[client2.userID!]?.masterKey!.verified,
        true,
      );
      expect(
        await (await client2.fetchUserDeviceKeysLists({
          client1.userID!,
        }))[client1.userID!]?.masterKey!.verified,
        true,
      );

      expect(
        await (await client1.fetchUserDeviceKeysLists({
          client2.userID!,
        }))[client2.userID!]?.deviceKeys[client2.deviceID]?.verified,
        true,
      );
      expect(
        await (await client2.fetchUserDeviceKeysLists({
          client1.userID!,
        }))[client1.userID!]?.deviceKeys[client1.deviceID]?.verified,
        true,
      );

      // let any background box usage from ssss signing finish
      await Future.delayed(Duration(seconds: 1));
      await client1.encryption!.keyVerificationManager.cleanup();
      await client2.encryption!.keyVerificationManager.cleanup();
    });

    test('Run qr verification mode 2', () async {
      expect(
        await (await client1.fetchUserDeviceKeysLists({
          client2.userID!,
        }))[client2.userID!]?.masterKey!.verified,
        false,
      );
      expect(
        await (await client2.fetchUserDeviceKeysLists({
          client1.userID!,
        }))[client1.userID!]?.masterKey!.verified,
        false,
      );
      expect(
        await (await client1.fetchUserDeviceKeysLists({
          client2.userID!,
        }))[client2.userID!]?.deviceKeys[client2.deviceID]?.verified,
        false,
      );
      expect(
        await (await client2.fetchUserDeviceKeysLists({
          client1.userID!,
        }))[client1.userID!]?.deviceKeys[client1.deviceID]?.verified,
        false,
      );
      // make sure our master key is *not* verified to not triger SSSS for now
      await (await client1.fetchUserDeviceKeysLists({
        client1.userID!,
      }))[client1.userID!]!.masterKey!.setVerified(false, false);
      await (await client2.fetchUserDeviceKeysLists({
        client2.userID!,
      }))[client2.userID!]!.masterKey!.setVerified(true, false);
      // await client1.encryption!.ssss.clearCache();
      final req1 =
          await (await client1.fetchUserDeviceKeysLists({
            client2.userID!,
          }))[client2.userID!]!.startVerification(
            newDirectChatEnableEncryption: false,
          );

      expect(req1.state, KeyVerificationState.waitingAccept);

      final comp = Completer<KeyVerification>();
      final sub = client2.onKeyVerificationRequest.stream.listen(comp.complete);
      await client2.encryption!.keyVerificationManager.handleToDeviceEvent(
        ToDeviceEvent(
          type: EventTypes.KeyVerificationRequest,
          sender: req1.client.userID!,
          content: {
            'from_device': req1.client.deviceID,
            'methods': await req1.knownVerificationMethods,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'transaction_id': req1.transactionId,
          },
        ),
      );

      final req2 = await comp.future;
      await sub.cancel();

      expect(
        client2.encryption!.keyVerificationManager.getRequest(
          req2.transactionId!,
        ),
        req2,
      );

      expect(req1.possibleMethods, []);
      await req2.acceptVerification();

      expect(req2.state, KeyVerificationState.askChoice);
      await ingestCorrectReadyEvent(req1, req2);

      expect(req1.possibleMethods, [
        EventTypes.Sas,
        EventTypes.Reciprocate,
        EventTypes.QRScan,
      ]);
      expect(req2.possibleMethods, [
        EventTypes.Sas,
        EventTypes.Reciprocate,
        EventTypes.QRShow,
      ]);

      expect(req1.state, KeyVerificationState.askChoice);

      expect(await req1.getOurQRMode(), QRMode.verifySelfUntrusted);
      expect(await req2.getOurQRMode(), QRMode.verifySelfTrusted);

      // send start
      await req1.continueVerification(
        EventTypes.Reciprocate,
        qrDataRawBytes: Uint8List.fromList(req2.qrCode?.qrDataRawBytes ?? []),
      );

      expect(req2.qrCode!.randomSharedSecret, req1.randomSharedSecretForQRCode);
      expect(req1.state, KeyVerificationState.showQRSuccess);

      await client2.encryption!.keyVerificationManager.handleToDeviceEvent(
        ToDeviceEvent(
          type: 'm.key.verification.start',
          sender: req1.client.userID!,
          content: {
            'from_device': req1.client.deviceID,
            'm.relates_to': {
              'event_id': req1.transactionId,
              'rel_type': 'm.reference',
            },
            'method': EventTypes.Reciprocate,
            'secret': req1.randomSharedSecretForQRCode,
            'transaction_id': req1.transactionId,
          },
        ),
      );

      expect(req2.state, KeyVerificationState.confirmQRScan);

      await req2.acceptQRScanConfirmation();

      await client1.encryption!.keyVerificationManager.handleToDeviceEvent(
        ToDeviceEvent(
          type: 'm.key.verification.done',
          sender: req2.client.userID!,
          content: {'transaction_id': req2.transactionId},
        ),
      );

      expect(req1.state, KeyVerificationState.done);
      expect(req2.state, KeyVerificationState.askSSSS);
      await req2.openSSSS(recoveryKey: ssssKey);
      expect(req2.state, KeyVerificationState.done);

      expect(
        await (await client1.fetchUserDeviceKeysLists({
          client2.userID!,
        }))[client2.userID!]?.masterKey!.verified,
        true,
      );
      expect(
        await (await client2.fetchUserDeviceKeysLists({
          client1.userID!,
        }))[client1.userID!]?.masterKey!.verified,
        true,
      );

      expect(
        await (await client1.fetchUserDeviceKeysLists({
          client2.userID!,
        }))[client2.userID!]?.deviceKeys[client2.deviceID]?.verified,
        true,
      );
      expect(
        await (await client2.fetchUserDeviceKeysLists({
          client1.userID!,
        }))[client1.userID!]?.deviceKeys[client1.deviceID]?.verified,
        true,
      );

      await client1.encryption!.keyVerificationManager.cleanup();
      await client2.encryption!.keyVerificationManager.cleanup();
    });

    test(
      'Run qr verification mode 1, but fail because incorrect secret',
      () async {
        // make sure our master key is *not* verified to not triger SSSS for now
        await (await client1.fetchUserDeviceKeysLists({
          client1.userID!,
        }))[client1.userID!]!.masterKey!.setVerified(true, false);
        await (await client2.fetchUserDeviceKeysLists({
          client2.userID!,
        }))[client2.userID!]!.masterKey!.setVerified(false, false);
        await client1.encryption!.ssss.clearCache();
        final req1 =
            await (await client1.fetchUserDeviceKeysLists({
              client2.userID!,
            }))[client2.userID!]!.startVerification(
              newDirectChatEnableEncryption: false,
            );

        expect(req1.state, KeyVerificationState.askSSSS);
        await req1.openSSSS(recoveryKey: ssssKey);

        expect(req1.state, KeyVerificationState.waitingAccept);

        final comp = Completer<KeyVerification>();
        final sub = client2.onKeyVerificationRequest.stream.listen(
          comp.complete,
        );
        await client2.encryption!.keyVerificationManager.handleToDeviceEvent(
          ToDeviceEvent(
            type: EventTypes.KeyVerificationRequest,
            sender: req1.client.userID!,
            content: {
              'from_device': req1.client.deviceID,
              'methods': await req1.knownVerificationMethods,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'transaction_id': req1.transactionId,
            },
          ),
        );

        final req2 = await comp.future;
        await sub.cancel();

        expect(
          client2.encryption!.keyVerificationManager.getRequest(
            req2.transactionId!,
          ),
          req2,
        );

        expect(req1.possibleMethods, []);
        await req2.acceptVerification();

        expect(req2.possibleMethods, [
          EventTypes.Sas,
          EventTypes.Reciprocate,
          EventTypes.QRShow,
        ]);

        expect(req2.state, KeyVerificationState.askChoice);
        await ingestCorrectReadyEvent(req1, req2);

        expect(req1.possibleMethods, [
          EventTypes.Sas,
          EventTypes.Reciprocate,
          EventTypes.QRScan,
        ]);

        expect(req1.state, KeyVerificationState.askChoice);

        expect(await req1.getOurQRMode(), QRMode.verifySelfTrusted);
        expect(await req2.getOurQRMode(), QRMode.verifySelfUntrusted);

        // send start
        await req1.continueVerification(
          EventTypes.Reciprocate,
          qrDataRawBytes: Uint8List.fromList(req2.qrCode?.qrDataRawBytes ?? []),
        );

        expect(
          req2.qrCode!.randomSharedSecret,
          req1.randomSharedSecretForQRCode,
        );
        expect(req1.state, KeyVerificationState.showQRSuccess);

        await client2.encryption!.keyVerificationManager.handleToDeviceEvent(
          ToDeviceEvent(
            type: 'm.key.verification.start',
            sender: req1.client.userID!,
            content: {
              'from_device': req1.client.deviceID,
              'm.relates_to': {
                'event_id': req1.transactionId,
                'rel_type': 'm.reference',
              },
              'method': EventTypes.Reciprocate,
              'secret': 'fake_secret',
              'transaction_id': req1.transactionId,
            },
          ),
        );

        expect(req1.state, KeyVerificationState.showQRSuccess);
        expect(req2.state, KeyVerificationState.error);

        await client1.encryption!.keyVerificationManager.cleanup();
        await client2.encryption!.keyVerificationManager.cleanup();
      },
    );

    test(
      'Run qr verification mode 2, but both unverified master key',
      () async {
        // make sure our master key is *not* verified to not triger SSSS for now
        await (await client1.fetchUserDeviceKeysLists({
          client1.userID!,
        }))[client1.userID!]!.masterKey!.setBlocked(true);
        await (await client2.fetchUserDeviceKeysLists({
          client2.userID!,
        }))[client2.userID!]!.masterKey!.setBlocked(true);
        // await client1.encryption!.ssss.clearCache();
        final req1 =
            await (await client1.fetchUserDeviceKeysLists({
              client2.userID!,
            }))[client2.userID!]!.startVerification(
              newDirectChatEnableEncryption: false,
            );

        expect(req1.state, KeyVerificationState.waitingAccept);

        final comp = Completer<KeyVerification>();
        final sub = client2.onKeyVerificationRequest.stream.listen(
          comp.complete,
        );
        await client2.encryption!.keyVerificationManager.handleToDeviceEvent(
          ToDeviceEvent(
            type: EventTypes.KeyVerificationRequest,
            sender: req1.client.userID!,
            content: {
              'from_device': req1.client.deviceID,
              'methods': await req1.knownVerificationMethods,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'transaction_id': req1.transactionId,
            },
          ),
        );

        final req2 = await comp.future;
        await sub.cancel();

        expect(
          client2.encryption!.keyVerificationManager.getRequest(
            req2.transactionId!,
          ),
          req2,
        );

        await req2.acceptVerification();
        expect(req2.possibleMethods, [EventTypes.Sas]);
        expect(req2.state, KeyVerificationState.askChoice);

        await ingestCorrectReadyEvent(req1, req2);

        expect(req1.possibleMethods, [EventTypes.Sas]);

        expect(req1.state, KeyVerificationState.waitingAccept);

        expect(await req1.getOurQRMode(), QRMode.verifySelfUntrusted);
        expect(await req2.getOurQRMode(), QRMode.verifySelfUntrusted);

        // send start
        await req1.continueVerification(
          EventTypes.Reciprocate,
          qrDataRawBytes: Uint8List.fromList(req2.qrCode?.qrDataRawBytes ?? []),
        );

        expect(req1.state, KeyVerificationState.error);

        await client2.encryption!.keyVerificationManager.handleToDeviceEvent(
          ToDeviceEvent(
            type: 'm.key.verification.start',
            sender: req1.client.userID!,
            content: {
              'from_device': req1.client.deviceID,
              'm.relates_to': {
                'event_id': req1.transactionId,
                'rel_type': 'm.reference',
              },
              'method': EventTypes.Reciprocate,
              'secret': 'stub_incorrect_secret_here',
              'transaction_id': req1.transactionId,
            },
          ),
        );

        expect(req1.state, KeyVerificationState.error);
        expect(req2.state, KeyVerificationState.error);

        await client1.encryption!.keyVerificationManager.cleanup();
        await client2.encryption!.keyVerificationManager.cleanup();
      },
    );
  });
}
