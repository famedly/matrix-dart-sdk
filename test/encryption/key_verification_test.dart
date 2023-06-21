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
import 'dart:typed_data';

import 'package:olm/olm.dart' as olm;
import 'package:test/test.dart';

import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import '../fake_client.dart';
import '../fake_database.dart';
import '../fake_matrix_api.dart';

EventUpdate getLastSentEvent(KeyVerification req) {
  final entry = FakeMatrixApi.calledEndpoints.entries
      .firstWhere((p) => p.key.contains('/send/'));
  final type = entry.key.split('/')[6];
  final content = json.decode(entry.value.first);
  return EventUpdate(
    content: {
      'event_id': req.transactionId,
      'type': type,
      'content': content,
      'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
      'sender': req.client.userID,
    },
    type: EventUpdateType.timeline,
    roomID: req.room!.id,
  );
}

void main() async {
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

    // key @othertest:fakeServer.notExisting
    const otherPickledOlmAccount =
        'VWhVApbkcilKAEGppsPDf9nNVjaK8/IxT3asSR0sYg0S5KgbfE8vXEPwoiKBX2cEvwX3OessOBOkk+ZE7TTbjlrh/KEd31p8Wo+47qj0AP+Ky+pabnhi+/rTBvZy+gfzTqUfCxZrkzfXI9Op4JnP6gYmy7dVX2lMYIIs9WCO1jcmIXiXum5jnfXu1WLfc7PZtO2hH+k9CDKosOFaXRBmsu8k/BGXPSoWqUpvu6WpEG9t5STk4FeAzA';

    late Client client1;
    late Client client2;
    setUp(() async {
      client1 = await getClient();
      client2 = Client(
        'othertestclient',
        httpClient: FakeMatrixApi.currentApi!,
        databaseBuilder: getDatabase,
      );
      await client2.checkHomeserver(Uri.parse('https://fakeserver.notexisting'),
          checkWellKnown: false);
      await client2.init(
        newToken: 'abc',
        newUserID: '@othertest:fakeServer.notExisting',
        newHomeserver: client2.homeserver,
        newDeviceName: 'Text Matrix Client',
        newDeviceID: 'FOXDEVICE',
        newOlmAccount: otherPickledOlmAccount,
      );
      await Future.delayed(Duration(milliseconds: 10));
      client1.verificationMethods = {
        KeyVerificationMethod.emoji,
        KeyVerificationMethod.numbers,
        KeyVerificationMethod.qrScan,
        KeyVerificationMethod.qrShow,
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

    test('Run emoji / number verification', () async {
      // for a full run we test in-room verification in a cleartext room
      // because then we can easily intercept the payloads and inject in the other client
      FakeMatrixApi.calledEndpoints.clear();
      // make sure our master key is *not* verified to not triger SSSS for now
      client1.userDeviceKeys[client1.userID]!.masterKey!
          .setDirectVerified(false);
      final req1 =
          await client1.userDeviceKeys[client2.userID]!.startVerification(
        newDirectChatEnableEncryption: false,
      );
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.room.message'));
      var evt = getLastSentEvent(req1);
      expect(req1.state, KeyVerificationState.waitingAccept);

      final comp = Completer<KeyVerification>();
      final sub = client2.onKeyVerificationRequest.stream.listen((req) {
        comp.complete(req);
      });
      await client2.encryption!.keyVerificationManager.handleEventUpdate(evt);
      final req2 = await comp.future;
      await sub.cancel();

      expect(
          client2.encryption!.keyVerificationManager
              .getRequest(req2.transactionId!),
          req2);
      // send ready
      FakeMatrixApi.calledEndpoints.clear();
      await req2.acceptVerification();
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.ready'));

      evt = getLastSentEvent(req2);
      expect(req2.state, KeyVerificationState.askChoice);

      FakeMatrixApi.calledEndpoints.clear();

      await client1.encryption!.keyVerificationManager.handleEventUpdate(evt);

      expect(req1.possibleMethods, [EventTypes.Sas]);
      expect(req2.possibleMethods, [EventTypes.Sas]);
      expect(req1.state, KeyVerificationState.waitingAccept);

      // no need for start (continueVerification) because sas only mode override already sent it after ready
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.start'));
      evt = getLastSentEvent(req1);

      // send accept
      FakeMatrixApi.calledEndpoints.clear();
      await client2.encryption!.keyVerificationManager.handleEventUpdate(evt);
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.accept'));
      evt = getLastSentEvent(req2);

      // send key
      FakeMatrixApi.calledEndpoints.clear();
      await client1.encryption!.keyVerificationManager.handleEventUpdate(evt);
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.key'));
      evt = getLastSentEvent(req1);

      // send key
      FakeMatrixApi.calledEndpoints.clear();
      await client2.encryption!.keyVerificationManager.handleEventUpdate(evt);
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.key'));
      evt = getLastSentEvent(req2);

      // receive last key
      FakeMatrixApi.calledEndpoints.clear();
      await client1.encryption!.keyVerificationManager.handleEventUpdate(evt);

      // compare emoji
      expect(req1.state, KeyVerificationState.askSas);
      expect(req2.state, KeyVerificationState.askSas);
      expect(req1.sasTypes[0], 'emoji');
      expect(req1.sasTypes[1], 'decimal');
      expect(req2.sasTypes[0], 'emoji');
      expect(req2.sasTypes[1], 'decimal');
      // compare emoji
      final emoji1 = req1.sasEmojis;
      final emoji2 = req2.sasEmojis;
      for (var i = 0; i < 7; i++) {
        expect(emoji1[i].emoji, emoji2[i].emoji);
        expect(emoji1[i].name, emoji2[i].name);
      }
      // compare numbers
      final numbers1 = req1.sasNumbers;
      final numbers2 = req2.sasNumbers;
      for (var i = 0; i < 3; i++) {
        expect(numbers1[i], numbers2[i]);
      }

      // alright, they match

      // send mac
      FakeMatrixApi.calledEndpoints.clear();
      await req1.acceptSas();
      evt = getLastSentEvent(req1);
      await client2.encryption!.keyVerificationManager.handleEventUpdate(evt);
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.mac'));
      expect(req1.state, KeyVerificationState.waitingSas);

      // send mac
      FakeMatrixApi.calledEndpoints.clear();
      await req2.acceptSas();
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.mac'));
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.done'));
      evt = getLastSentEvent(req2);
      FakeMatrixApi.calledEndpoints.clear();
      await client1.encryption!.keyVerificationManager.handleEventUpdate(evt);
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.done'));

      expect(req1.state, KeyVerificationState.done);
      expect(req2.state, KeyVerificationState.done);
      expect(
          client1.userDeviceKeys[client2.userID]?.deviceKeys[client2.deviceID]
              ?.directVerified,
          true);
      expect(
          client2.userDeviceKeys[client1.userID]?.deviceKeys[client1.deviceID]
              ?.directVerified,
          true);
      await client1.encryption!.keyVerificationManager.cleanup();
      await client2.encryption!.keyVerificationManager.cleanup();
    });

    test('ask SSSS start', () async {
      client1.userDeviceKeys[client1.userID]!.masterKey!
          .setDirectVerified(true);
      await client1.encryption!.ssss.clearCache();
      final req1 = await client1.userDeviceKeys[client2.userID]!
          .startVerification(newDirectChatEnableEncryption: false);
      expect(req1.state, KeyVerificationState.askSSSS);
      await req1.openSSSS(recoveryKey: ssssKey);
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.room.message'));
      expect(req1.state, KeyVerificationState.waitingAccept);

      await req1.cancel();
      await client1.encryption!.keyVerificationManager.cleanup();
    });

    test('ask SSSS end', () async {
      FakeMatrixApi.calledEndpoints.clear();
      // make sure our master key is *not* verified to not triger SSSS for now
      client1.userDeviceKeys[client1.userID]!.masterKey!
          .setDirectVerified(false);
      // the other one has to have their master key verified to trigger asking for ssss
      client2.userDeviceKeys[client2.userID]!.masterKey!
          .setDirectVerified(true);
      final req1 = await client1.userDeviceKeys[client2.userID]!
          .startVerification(newDirectChatEnableEncryption: false);
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.room.message'));
      var evt = getLastSentEvent(req1);
      expect(req1.state, KeyVerificationState.waitingAccept);

      final comp = Completer<KeyVerification>();
      final sub = client2.onKeyVerificationRequest.stream.listen((req) {
        comp.complete(req);
      });
      await client2.encryption!.keyVerificationManager.handleEventUpdate(evt);
      final req2 = await comp.future;
      await sub.cancel();

      // send ready
      FakeMatrixApi.calledEndpoints.clear();
      await req2.acceptVerification();
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.ready'));
      evt = getLastSentEvent(req2);
      expect(req2.state, KeyVerificationState.askChoice);
      FakeMatrixApi.calledEndpoints.clear();

      await client1.encryption!.keyVerificationManager.handleEventUpdate(evt);

      expect(req1.possibleMethods, [EventTypes.Sas]);
      expect(req2.possibleMethods, [EventTypes.Sas]);
      expect(req1.state, KeyVerificationState.waitingAccept);

      // no need for start (continueVerification) because sas only mode override already sent it after ready
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.start'));
      evt = getLastSentEvent(req1);

      // send accept
      FakeMatrixApi.calledEndpoints.clear();
      await client2.encryption!.keyVerificationManager.handleEventUpdate(evt);
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.accept'));
      evt = getLastSentEvent(req2);

      // send key
      FakeMatrixApi.calledEndpoints.clear();
      await client1.encryption!.keyVerificationManager.handleEventUpdate(evt);
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.key'));
      evt = getLastSentEvent(req1);

      // send key
      FakeMatrixApi.calledEndpoints.clear();
      await client2.encryption!.keyVerificationManager.handleEventUpdate(evt);
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.key'));
      evt = getLastSentEvent(req2);

      // receive last key
      FakeMatrixApi.calledEndpoints.clear();
      await client1.encryption!.keyVerificationManager.handleEventUpdate(evt);

      // compare emoji
      expect(req1.state, KeyVerificationState.askSas);
      expect(req2.state, KeyVerificationState.askSas);
      // compare emoji
      final emoji1 = req1.sasEmojis;
      final emoji2 = req2.sasEmojis;
      for (var i = 0; i < 7; i++) {
        expect(emoji1[i].emoji, emoji2[i].emoji);
        expect(emoji1[i].name, emoji2[i].name);
      }
      // compare numbers
      final numbers1 = req1.sasNumbers;
      final numbers2 = req2.sasNumbers;
      for (var i = 0; i < 3; i++) {
        expect(numbers1[i], numbers2[i]);
      }

      // alright, they match
      client1.userDeviceKeys[client1.userID]!.masterKey!
          .setDirectVerified(true);
      await client1.encryption!.ssss.clearCache();

      // send mac
      FakeMatrixApi.calledEndpoints.clear();
      await req1.acceptSas();
      evt = getLastSentEvent(req1);
      await client2.encryption!.keyVerificationManager.handleEventUpdate(evt);
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.mac'));
      expect(req1.state, KeyVerificationState.waitingSas);

      // send mac
      FakeMatrixApi.calledEndpoints.clear();
      await req2.acceptSas();
      evt = getLastSentEvent(req2);
      await client1.encryption!.keyVerificationManager.handleEventUpdate(evt);
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.mac'));
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.done'));
      FakeMatrixApi.calledEndpoints.clear();

      expect(req1.state, KeyVerificationState.askSSSS);
      expect(req2.state, KeyVerificationState.done);

      await req1.openSSSS(recoveryKey: ssssKey);
      expect(req1.state, KeyVerificationState.done);

      // let any background box usage from ssss signing finish
      await Future.delayed(Duration(seconds: 1));
      await client1.encryption!.keyVerificationManager.cleanup();
      await client2.encryption!.keyVerificationManager.cleanup();
    });

    test('reject verification', () async {
      FakeMatrixApi.calledEndpoints.clear();
      // make sure our master key is *not* verified to not triger SSSS for now
      client1.userDeviceKeys[client1.userID]!.masterKey!
          .setDirectVerified(false);
      final req1 = await client1.userDeviceKeys[client2.userID]!
          .startVerification(newDirectChatEnableEncryption: false);
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.room.message'));
      var evt = getLastSentEvent(req1);
      expect(req1.state, KeyVerificationState.waitingAccept);

      final comp = Completer<KeyVerification>();
      final sub = client2.onKeyVerificationRequest.stream.listen((req) {
        comp.complete(req);
      });
      await client2.encryption!.keyVerificationManager.handleEventUpdate(evt);
      final req2 = await comp.future;
      await sub.cancel();

      FakeMatrixApi.calledEndpoints.clear();
      await req2.rejectVerification();
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.cancel'));
      evt = getLastSentEvent(req2);
      await client1.encryption!.keyVerificationManager.handleEventUpdate(evt);
      expect(req1.state, KeyVerificationState.error);
      expect(req2.state, KeyVerificationState.error);

      await client1.encryption!.keyVerificationManager.cleanup();
      await client2.encryption!.keyVerificationManager.cleanup();
    });

    test('reject sas', () async {
      FakeMatrixApi.calledEndpoints.clear();
      // make sure our master key is *not* verified to not triger SSSS for now
      client1.userDeviceKeys[client1.userID]!.masterKey!
          .setDirectVerified(false);
      final req1 = await client1.userDeviceKeys[client2.userID]!
          .startVerification(newDirectChatEnableEncryption: false);
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.room.message'));
      var evt = getLastSentEvent(req1);
      expect(req1.state, KeyVerificationState.waitingAccept);

      final comp = Completer<KeyVerification>();
      final sub = client2.onKeyVerificationRequest.stream.listen((req) {
        comp.complete(req);
      });
      await client2.encryption!.keyVerificationManager.handleEventUpdate(evt);
      final req2 = await comp.future;
      await sub.cancel();

      // send ready
      FakeMatrixApi.calledEndpoints.clear();
      await req2.acceptVerification();
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.ready'));
      evt = getLastSentEvent(req2);
      expect(req2.state, KeyVerificationState.askChoice);
      FakeMatrixApi.calledEndpoints.clear();

      await client1.encryption!.keyVerificationManager.handleEventUpdate(evt);

      expect(req1.possibleMethods, [EventTypes.Sas]);
      expect(req2.possibleMethods, [EventTypes.Sas]);

      expect(req1.state, KeyVerificationState.waitingAccept);

      // no need for start (continueVerification) because sas only mode override already sent it after ready
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.start'));
      evt = getLastSentEvent(req1);

      // send accept
      FakeMatrixApi.calledEndpoints.clear();
      await client2.encryption!.keyVerificationManager.handleEventUpdate(evt);
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.accept'));
      evt = getLastSentEvent(req2);

      // send key
      FakeMatrixApi.calledEndpoints.clear();
      await client1.encryption!.keyVerificationManager.handleEventUpdate(evt);
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.key'));
      evt = getLastSentEvent(req1);

      // send key
      FakeMatrixApi.calledEndpoints.clear();
      await client2.encryption!.keyVerificationManager.handleEventUpdate(evt);
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.key'));
      evt = getLastSentEvent(req2);

      // receive last key
      FakeMatrixApi.calledEndpoints.clear();
      await client1.encryption!.keyVerificationManager.handleEventUpdate(evt);

      await req1.acceptSas();
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.mac'));
      FakeMatrixApi.calledEndpoints.clear();
      await req2.rejectSas();
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.cancel'));
      evt = getLastSentEvent(req2);
      await client1.encryption!.keyVerificationManager.handleEventUpdate(evt);
      expect(req1.state, KeyVerificationState.error);
      expect(req2.state, KeyVerificationState.error);

      await client1.encryption!.keyVerificationManager.cleanup();
      await client2.encryption!.keyVerificationManager.cleanup();
    });

    test('other device accepted', () async {
      FakeMatrixApi.calledEndpoints.clear();
      // make sure our master key is *not* verified to not triger SSSS for now
      client1.userDeviceKeys[client1.userID]!.masterKey!
          .setDirectVerified(false);
      final req1 = await client1.userDeviceKeys[client2.userID]!
          .startVerification(newDirectChatEnableEncryption: false);
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.room.message'));
      final evt = getLastSentEvent(req1);
      expect(req1.state, KeyVerificationState.waitingAccept);

      final comp = Completer<KeyVerification>();
      final sub = client2.onKeyVerificationRequest.stream.listen((req) {
        comp.complete(req);
      });
      await client2.encryption!.keyVerificationManager.handleEventUpdate(evt);
      final req2 = await comp.future;
      await sub.cancel();

      await client2.encryption!.keyVerificationManager
          .handleEventUpdate(EventUpdate(
        content: {
          'event_id': req2.transactionId,
          'type': 'm.key.verification.ready',
          'content': {
            'methods': [EventTypes.Sas],
            'from_device': 'SOMEOTHERDEVICE',
            'm.relates_to': {
              'rel_type': 'm.reference',
              'event_id': req2.transactionId,
            },
          },
          'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
          'sender': client2.userID,
        },
        type: EventUpdateType.timeline,
        roomID: req2.room!.id,
      ));
      expect(req2.state, KeyVerificationState.error);

      await req2.cancel();
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.cancel'));
      await client1.encryption!.keyVerificationManager.cleanup();
      await client2.encryption!.keyVerificationManager.cleanup();
    });

    test('Run qr verification mode 0, ssss start', () async {
      expect(client1.userDeviceKeys[client2.userID]?.masterKey!.directVerified,
          false);
      expect(client2.userDeviceKeys[client1.userID]?.masterKey!.directVerified,
          false);
      // for a full run we test in-room verification in a cleartext room
      // because then we can easily intercept the payloads and inject in the other client
      FakeMatrixApi.calledEndpoints.clear();
      // make sure our master key is *not* verified to not triger SSSS for now
      client1.userDeviceKeys[client1.userID]!.masterKey!
          .setDirectVerified(true);
      client2.userDeviceKeys[client2.userID]!.masterKey!
          .setDirectVerified(true);
      await client1.encryption!.ssss.clearCache();

      final req1 =
          await client1.userDeviceKeys[client2.userID]!.startVerification(
        newDirectChatEnableEncryption: false,
      );

      expect(req1.state, KeyVerificationState.askSSSS);
      await req1.openSSSS(recoveryKey: ssssKey);

      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.room.message'));

      var evt = getLastSentEvent(req1);
      expect(req1.state, KeyVerificationState.waitingAccept);

      final comp = Completer<KeyVerification>();
      final sub = client2.onKeyVerificationRequest.stream.listen((req) {
        comp.complete(req);
      });
      await client2.encryption!.keyVerificationManager.handleEventUpdate(evt);
      final req2 = await comp.future;
      await sub.cancel();

      expect(
          client2.encryption!.keyVerificationManager
              .getRequest(req2.transactionId!),
          req2);

      // send ready
      FakeMatrixApi.calledEndpoints.clear();
      await req2.acceptVerification();
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.ready'));
      evt = getLastSentEvent(req2);
      expect(req2.state, KeyVerificationState.askChoice);
      await client1.encryption!.keyVerificationManager.handleEventUpdate(evt);
      expect(req1.state, KeyVerificationState.askChoice);
      expect(req1.possibleMethods,
          [EventTypes.Sas, EventTypes.Reciprocate, EventTypes.QRScan]);
      expect(req2.possibleMethods,
          [EventTypes.Sas, EventTypes.Reciprocate, EventTypes.QRShow]);

      // send start
      FakeMatrixApi.calledEndpoints.clear();
      await req1.continueVerification(EventTypes.Reciprocate,
          qrDataRawBytes:
              Uint8List.fromList(req2.qrCode?.qrDataRawBytes ?? []));
      expect(req2.qrCode!.randomSharedSecret, req1.randomSharedSecretForQRCode);
      expect(req1.state, KeyVerificationState.showQRSuccess);
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.start'));
      evt = getLastSentEvent(req1);

      // send done
      FakeMatrixApi.calledEndpoints.clear();
      await client2.encryption!.keyVerificationManager.handleEventUpdate(evt);
      expect(req2.state, KeyVerificationState.confirmQRScan);
      await req2.acceptQRScanConfirmation();
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.done'));
      evt = getLastSentEvent(req2);

      FakeMatrixApi.calledEndpoints.clear();
      await client1.encryption!.keyVerificationManager.handleEventUpdate(evt);

      expect(req1.state, KeyVerificationState.done);
      expect(req2.state, KeyVerificationState.done);

      expect(client1.userDeviceKeys[client2.userID]?.masterKey!.directVerified,
          true);
      expect(client2.userDeviceKeys[client1.userID]?.masterKey!.directVerified,
          true);

      await client1.encryption!.keyVerificationManager.cleanup();
      await client2.encryption!.keyVerificationManager.cleanup();
    });

    test('Run qr verification mode 0, but fail on masterKey unverified client1',
        () async {
      // for a full run we test in-room verification in a cleartext room
      // because then we can easily intercept the payloads and inject in the other client
      FakeMatrixApi.calledEndpoints.clear();
      // make sure our master key is *not* verified to not triger SSSS for now
      client1.userDeviceKeys[client1.userID]!.masterKey!
          .setDirectVerified(false);

      final req1 =
          await client1.userDeviceKeys[client2.userID]!.startVerification(
        newDirectChatEnableEncryption: false,
      );
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.room.message'));

      var evt = getLastSentEvent(req1);
      expect(req1.state, KeyVerificationState.waitingAccept);

      final comp = Completer<KeyVerification>();
      final sub = client2.onKeyVerificationRequest.stream.listen((req) {
        comp.complete(req);
      });
      await client2.encryption!.keyVerificationManager.handleEventUpdate(evt);
      final req2 = await comp.future;
      await sub.cancel();

      expect(
          client2.encryption!.keyVerificationManager
              .getRequest(req2.transactionId!),
          req2);
      // send ready
      FakeMatrixApi.calledEndpoints.clear();
      await req2.acceptVerification();
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.ready'));
      evt = getLastSentEvent(req2);
      expect(req2.state, KeyVerificationState.askChoice);
      await client1.encryption!.keyVerificationManager.handleEventUpdate(evt);

      expect(req1.possibleMethods, [EventTypes.Sas]);
      expect(req2.possibleMethods, [EventTypes.Sas]);

      expect(req1.state, KeyVerificationState.waitingAccept);

      // send start
      FakeMatrixApi.calledEndpoints.clear();
      // qrCode will be null here anyway because masterKey not signed
      await req1.continueVerification(EventTypes.Reciprocate,
          qrDataRawBytes:
              Uint8List.fromList(req2.qrCode?.qrDataRawBytes ?? []));
      expect(req1.state, KeyVerificationState.error);

      await client1.encryption!.keyVerificationManager.cleanup();
      await client2.encryption!.keyVerificationManager.cleanup();
    });

    test('Run qr verification mode 0, but fail on masterKey unverified client2',
        () async {
      // for a full run we test in-room verification in a cleartext room
      // because then we can easily intercept the payloads and inject in the other client
      FakeMatrixApi.calledEndpoints.clear();
      // make sure our master key is *not* verified to not triger SSSS for now
      client1.userDeviceKeys[client1.userID]!.masterKey!
          .setDirectVerified(false);

      final req1 =
          await client1.userDeviceKeys[client2.userID]!.startVerification(
        newDirectChatEnableEncryption: false,
      );
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.room.message'));

      var evt = getLastSentEvent(req1);
      expect(req1.state, KeyVerificationState.waitingAccept);

      final comp = Completer<KeyVerification>();
      final sub = client2.onKeyVerificationRequest.stream.listen((req) {
        comp.complete(req);
      });
      await client2.encryption!.keyVerificationManager.handleEventUpdate(evt);
      final req2 = await comp.future;
      await sub.cancel();

      expect(
          client2.encryption!.keyVerificationManager
              .getRequest(req2.transactionId!),
          req2);
      // send ready
      FakeMatrixApi.calledEndpoints.clear();
      await req2.acceptVerification();
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.ready'));
      evt = getLastSentEvent(req2);
      expect(req2.state, KeyVerificationState.askChoice);
      await client1.encryption!.keyVerificationManager.handleEventUpdate(evt);

      expect(req1.possibleMethods, [EventTypes.Sas]);
      expect(req2.possibleMethods, [EventTypes.Sas]);

      expect(req1.state, KeyVerificationState.waitingAccept);
      FakeMatrixApi.calledEndpoints.clear();
      // qrCode will be null here anyway because masterKey not signed
      await req2.continueVerification(EventTypes.Reciprocate,
          qrDataRawBytes:
              Uint8List.fromList(req2.qrCode?.qrDataRawBytes ?? []));
      expect(req2.state, KeyVerificationState.error);

      await client1.encryption!.keyVerificationManager.cleanup();
      await client2.encryption!.keyVerificationManager.cleanup();
    });

    test(
        'Run qr verification mode, but fail because no knownVerificationMethod',
        () async {
      client1.verificationMethods = {
        KeyVerificationMethod.emoji,
        KeyVerificationMethod.numbers
      };
      client2.verificationMethods = {
        KeyVerificationMethod.emoji,
        KeyVerificationMethod.numbers
      };

      // for a full run we test in-room verification in a cleartext room
      // because then we can easily intercept the payloads and inject in the other client
      FakeMatrixApi.calledEndpoints.clear();
      // make sure our master key is *not* verified to not triger SSSS for now
      client1.userDeviceKeys[client1.userID]!.masterKey!
          .setDirectVerified(false);

      final req1 =
          await client1.userDeviceKeys[client2.userID]!.startVerification(
        newDirectChatEnableEncryption: false,
      );
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.room.message'));

      var evt = getLastSentEvent(req1);
      expect(req1.state, KeyVerificationState.waitingAccept);

      final comp = Completer<KeyVerification>();
      final sub = client2.onKeyVerificationRequest.stream.listen((req) {
        comp.complete(req);
      });
      await client2.encryption!.keyVerificationManager.handleEventUpdate(evt);
      final req2 = await comp.future;
      await sub.cancel();

      expect(
          client2.encryption!.keyVerificationManager
              .getRequest(req2.transactionId!),
          req2);
      // send ready
      FakeMatrixApi.calledEndpoints.clear();
      await req2.acceptVerification();
      await FakeMatrixApi.firstWhere((e) => e.startsWith(
          '/client/v3/rooms/!1234%3AfakeServer.notExisting/send/m.key.verification.ready'));
      evt = getLastSentEvent(req2);
      expect(req2.state, KeyVerificationState.askChoice);
      await client1.encryption!.keyVerificationManager.handleEventUpdate(evt);

      expect(req1.possibleMethods, [EventTypes.Sas]);
      expect(req2.possibleMethods, [EventTypes.Sas]);

      expect(req1.state, KeyVerificationState.waitingAccept);
      FakeMatrixApi.calledEndpoints.clear();

      // qrCode will be null here anyway because qr isn't supported
      await req1.continueVerification(EventTypes.Reciprocate,
          qrDataRawBytes:
              Uint8List.fromList(req2.qrCode?.qrDataRawBytes ?? []));
      expect(req1.state, KeyVerificationState.error);

      await client1.encryption!.keyVerificationManager.cleanup();
      await client2.encryption!.keyVerificationManager.cleanup();
    });
  }, skip: skip);
}
