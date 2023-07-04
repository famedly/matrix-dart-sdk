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
import 'dart:typed_data';

import 'package:olm/olm.dart' as olm;
import 'package:test/test.dart';

import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import '../fake_client.dart';

void main() async {
  // need to mock to pass correct data to handleToDeviceEvent
  Future<void> ingestCorrectReadyEvent(
      KeyVerification req1, KeyVerification req2) async {
    final copyKnownVerificationMethods =
        List.from(req2.knownVerificationMethods);

    // this is the same logic from `acceptVerification()` just couldn't find a
    // easy to to mock it
    // qr code only works when atleast one side has verified master key
    if (req2.userId == req2.client.userID) {
      if (!(req2.client.userDeviceKeys[req2.client.userID]
                  ?.deviceKeys[req2.deviceId]
                  ?.hasValidSignatureChain(verifiedByTheirMasterKey: true) ??
              false) &&
          !(req2.client.userDeviceKeys[req2.client.userID]?.masterKey
                  ?.verified ??
              false)) {
        copyKnownVerificationMethods
            .removeWhere((element) => element.startsWith('m.qr_code'));
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
          'transaction_id': req2.transactionId
        },
      ),
    );
  }

  var olmEnabled = true;
  try {
    await olm.init();
    olm.get_library_version();
  } catch (e) {
    olmEnabled = false;
    Logs().w('[LibOlm] Failed to load LibOlm', e);
  }
  Logs().i('[LibOlm] Enabled: $olmEnabled');

  final dynamic skip = olmEnabled ? false : 'olm library not available';

  /// All Tests related to the ChatTime
  group('Key Verification', () {
    Logs().level = Level.error;

    late Client client1;
    late Client client2;
    setUp(() async {
      client1 = await getClient();
      client2 = await getOtherClient();

      await Future.delayed(Duration(milliseconds: 10));
      client1.verificationMethods = {
        KeyVerificationMethod.emoji,
        KeyVerificationMethod.numbers,
        KeyVerificationMethod.qrScan,
        KeyVerificationMethod.reciprocate
      };
      client2.verificationMethods = {
        KeyVerificationMethod.emoji,
        KeyVerificationMethod.numbers,
        KeyVerificationMethod.qrShow,
        KeyVerificationMethod.reciprocate
      };
    });
    tearDown(() async {
      await client1.dispose(closeDatabase: true);
      await client2.dispose(closeDatabase: true);
    });

    test('Run qr verification mode 1', () async {
      expect(
          client1.userDeviceKeys[client2.userID]?.masterKey!.verified, false);
      expect(
          client2.userDeviceKeys[client1.userID]?.masterKey!.verified, false);
      expect(
          client1.userDeviceKeys[client2.userID]?.deviceKeys[client2.deviceID]
              ?.verified,
          false);
      expect(
          client2.userDeviceKeys[client1.userID]?.deviceKeys[client1.deviceID]
              ?.verified,
          false);
      // make sure our master key is *not* verified to not triger SSSS for now
      client1.userDeviceKeys[client1.userID]!.masterKey!
          .setDirectVerified(true);
      client2.userDeviceKeys[client2.userID]!.masterKey!
          .setDirectVerified(false);

      await client1.encryption!.ssss.clearCache();
      final req1 = await client1.userDeviceKeys[client2.userID]!
          .startVerification(newDirectChatEnableEncryption: false);

      expect(req1.state, KeyVerificationState.askSSSS);
      await req1.openSSSS(recoveryKey: ssssKey);

      expect(req1.state, KeyVerificationState.waitingAccept);

      final comp = Completer<KeyVerification>();
      final sub = client2.onKeyVerificationRequest.stream.listen((req) {
        comp.complete(req);
      });
      await client2.encryption!.keyVerificationManager.handleToDeviceEvent(
        ToDeviceEvent(
          type: EventTypes.KeyVerificationRequest,
          sender: req1.client.userID!,
          content: {
            'from_device': req1.client.deviceID,
            'methods': req1.knownVerificationMethods,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'transaction_id': req1.transactionId
          },
        ),
      );

      final req2 = await comp.future;
      await sub.cancel();

      expect(
          client2.encryption!.keyVerificationManager
              .getRequest(req2.transactionId!),
          req2);

      expect(req1.possibleMethods, []);
      await req2.acceptVerification();

      expect(req2.state, KeyVerificationState.askChoice);
      await ingestCorrectReadyEvent(req1, req2);
      expect(req1.possibleMethods,
          [EventTypes.Sas, EventTypes.Reciprocate, EventTypes.QRScan]);
      expect(req2.possibleMethods,
          [EventTypes.Sas, EventTypes.Reciprocate, EventTypes.QRShow]);

      expect(req1.state, KeyVerificationState.askChoice);

      expect(req1.getOurQRMode(), QRMode.verifySelfTrusted);
      expect(req2.getOurQRMode(), QRMode.verifySelfUntrusted);

      // send start
      await req1.continueVerification(EventTypes.Reciprocate,
          qrDataRawBytes:
              Uint8List.fromList(req2.qrCode?.qrDataRawBytes ?? []));

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
              'rel_type': 'm.reference'
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
          content: {
            'transaction_id': req2.transactionId,
          },
        ),
      );

      expect(req1.state, KeyVerificationState.done);
      expect(req2.state, KeyVerificationState.done);

      expect(client1.userDeviceKeys[client2.userID]?.masterKey!.verified, true);
      expect(client2.userDeviceKeys[client1.userID]?.masterKey!.verified, true);

      expect(
          client1.userDeviceKeys[client2.userID]?.deviceKeys[client2.deviceID]
              ?.verified,
          true);
      expect(
          client2.userDeviceKeys[client1.userID]?.deviceKeys[client1.deviceID]
              ?.verified,
          true);

      // let any background box usage from ssss signing finish
      await Future.delayed(Duration(seconds: 1));
      await client1.encryption!.keyVerificationManager.cleanup();
      await client2.encryption!.keyVerificationManager.cleanup();
    });

    test('Run qr verification mode 2', () async {
      expect(
          client1.userDeviceKeys[client2.userID]?.masterKey!.verified, false);
      expect(
          client2.userDeviceKeys[client1.userID]?.masterKey!.verified, false);
      expect(
          client1.userDeviceKeys[client2.userID]?.deviceKeys[client2.deviceID]
              ?.verified,
          false);
      expect(
          client2.userDeviceKeys[client1.userID]?.deviceKeys[client1.deviceID]
              ?.verified,
          false);
      // make sure our master key is *not* verified to not triger SSSS for now
      client1.userDeviceKeys[client1.userID]!.masterKey!
          .setDirectVerified(false);
      client2.userDeviceKeys[client2.userID]!.masterKey!
          .setDirectVerified(true);
      // await client1.encryption!.ssss.clearCache();
      final req1 =
          await client1.userDeviceKeys[client2.userID]!.startVerification(
        newDirectChatEnableEncryption: false,
      );

      expect(req1.state, KeyVerificationState.waitingAccept);

      final comp = Completer<KeyVerification>();
      final sub = client2.onKeyVerificationRequest.stream.listen((req) {
        comp.complete(req);
      });
      await client2.encryption!.keyVerificationManager.handleToDeviceEvent(
        ToDeviceEvent(
          type: EventTypes.KeyVerificationRequest,
          sender: req1.client.userID!,
          content: {
            'from_device': req1.client.deviceID,
            'methods': req1.knownVerificationMethods,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'transaction_id': req1.transactionId
          },
        ),
      );

      final req2 = await comp.future;
      await sub.cancel();

      expect(
          client2.encryption!.keyVerificationManager
              .getRequest(req2.transactionId!),
          req2);

      expect(req1.possibleMethods, []);
      await req2.acceptVerification();

      expect(req2.state, KeyVerificationState.askChoice);
      await ingestCorrectReadyEvent(req1, req2);

      expect(req1.possibleMethods,
          [EventTypes.Sas, EventTypes.Reciprocate, EventTypes.QRScan]);
      expect(req2.possibleMethods,
          [EventTypes.Sas, EventTypes.Reciprocate, EventTypes.QRShow]);

      expect(req1.state, KeyVerificationState.askChoice);

      expect(req1.getOurQRMode(), QRMode.verifySelfUntrusted);
      expect(req2.getOurQRMode(), QRMode.verifySelfTrusted);

      // send start
      await req1.continueVerification(EventTypes.Reciprocate,
          qrDataRawBytes:
              Uint8List.fromList(req2.qrCode?.qrDataRawBytes ?? []));

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
              'rel_type': 'm.reference'
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
          content: {
            'transaction_id': req2.transactionId,
          },
        ),
      );

      expect(req1.state, KeyVerificationState.done);
      expect(req2.state, KeyVerificationState.askSSSS);
      await req2.openSSSS(recoveryKey: ssssKey);
      expect(req2.state, KeyVerificationState.done);

      expect(client1.userDeviceKeys[client2.userID]?.masterKey!.verified, true);
      expect(client2.userDeviceKeys[client1.userID]?.masterKey!.verified, true);

      expect(
          client1.userDeviceKeys[client2.userID]?.deviceKeys[client2.deviceID]
              ?.verified,
          true);
      expect(
          client2.userDeviceKeys[client1.userID]?.deviceKeys[client1.deviceID]
              ?.verified,
          true);

      await client1.encryption!.keyVerificationManager.cleanup();
      await client2.encryption!.keyVerificationManager.cleanup();
    });

    test('Run qr verification mode 1, but fail because incorrect secret',
        () async {
      // make sure our master key is *not* verified to not triger SSSS for now
      client1.userDeviceKeys[client1.userID]!.masterKey!
          .setDirectVerified(true);
      client2.userDeviceKeys[client2.userID]!.masterKey!
          .setDirectVerified(false);

      await client1.encryption!.ssss.clearCache();
      final req1 =
          await client1.userDeviceKeys[client2.userID]!.startVerification(
        newDirectChatEnableEncryption: false,
      );

      expect(req1.state, KeyVerificationState.askSSSS);
      await req1.openSSSS(recoveryKey: ssssKey);

      expect(req1.state, KeyVerificationState.waitingAccept);

      final comp = Completer<KeyVerification>();
      final sub = client2.onKeyVerificationRequest.stream.listen((req) {
        comp.complete(req);
      });
      await client2.encryption!.keyVerificationManager.handleToDeviceEvent(
        ToDeviceEvent(
          type: EventTypes.KeyVerificationRequest,
          sender: req1.client.userID!,
          content: {
            'from_device': req1.client.deviceID,
            'methods': req1.knownVerificationMethods,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'transaction_id': req1.transactionId
          },
        ),
      );

      final req2 = await comp.future;
      await sub.cancel();

      expect(
          client2.encryption!.keyVerificationManager
              .getRequest(req2.transactionId!),
          req2);

      expect(req1.possibleMethods, []);
      await req2.acceptVerification();

      expect(req2.possibleMethods,
          [EventTypes.Sas, EventTypes.Reciprocate, EventTypes.QRShow]);

      expect(req2.state, KeyVerificationState.askChoice);
      await ingestCorrectReadyEvent(req1, req2);

      expect(req1.possibleMethods,
          [EventTypes.Sas, EventTypes.Reciprocate, EventTypes.QRScan]);

      expect(req1.state, KeyVerificationState.askChoice);

      expect(req1.getOurQRMode(), QRMode.verifySelfTrusted);
      expect(req2.getOurQRMode(), QRMode.verifySelfUntrusted);

      // send start
      await req1.continueVerification(EventTypes.Reciprocate,
          qrDataRawBytes:
              Uint8List.fromList(req2.qrCode?.qrDataRawBytes ?? []));

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
              'rel_type': 'm.reference'
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
    });

    test('Run qr verification mode 2, but both unverified master key',
        () async {
      // make sure our master key is *not* verified to not triger SSSS for now
      await client1.userDeviceKeys[client1.userID]!.masterKey!.setBlocked(true);
      await client2.userDeviceKeys[client2.userID]!.masterKey!.setBlocked(true);
      // await client1.encryption!.ssss.clearCache();
      final req1 =
          await client1.userDeviceKeys[client2.userID]!.startVerification(
        newDirectChatEnableEncryption: false,
      );

      expect(req1.state, KeyVerificationState.waitingAccept);

      final comp = Completer<KeyVerification>();
      final sub = client2.onKeyVerificationRequest.stream.listen((req) {
        comp.complete(req);
      });
      await client2.encryption!.keyVerificationManager.handleToDeviceEvent(
        ToDeviceEvent(
          type: EventTypes.KeyVerificationRequest,
          sender: req1.client.userID!,
          content: {
            'from_device': req1.client.deviceID,
            'methods': req1.knownVerificationMethods,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'transaction_id': req1.transactionId
          },
        ),
      );

      final req2 = await comp.future;
      await sub.cancel();

      expect(
          client2.encryption!.keyVerificationManager
              .getRequest(req2.transactionId!),
          req2);

      await req2.acceptVerification();
      expect(req2.possibleMethods, [EventTypes.Sas]);
      expect(req2.state, KeyVerificationState.askChoice);

      await ingestCorrectReadyEvent(req1, req2);

      expect(req1.possibleMethods, [EventTypes.Sas]);

      expect(req1.state, KeyVerificationState.waitingAccept);

      expect(req1.getOurQRMode(), QRMode.verifySelfUntrusted);
      expect(req2.getOurQRMode(), QRMode.verifySelfUntrusted);

      // send start
      await req1.continueVerification(EventTypes.Reciprocate,
          qrDataRawBytes:
              Uint8List.fromList(req2.qrCode?.qrDataRawBytes ?? []));

      expect(req1.state, KeyVerificationState.error);

      await client2.encryption!.keyVerificationManager.handleToDeviceEvent(
        ToDeviceEvent(
          type: 'm.key.verification.start',
          sender: req1.client.userID!,
          content: {
            'from_device': req1.client.deviceID,
            'm.relates_to': {
              'event_id': req1.transactionId,
              'rel_type': 'm.reference'
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
    });
  }, skip: skip);
}
