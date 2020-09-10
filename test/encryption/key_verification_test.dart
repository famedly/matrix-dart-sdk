/*
 *   Ansible inventory script used at Famedly GmbH for managing many hosts
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

import 'dart:convert';

import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/encryption.dart';
import 'package:famedlysdk/src/utils/logs.dart';
import 'package:test/test.dart';
import 'package:olm/olm.dart' as olm;

import '../fake_client.dart';
import '../fake_matrix_api.dart';

class MockSSSS extends SSSS {
  MockSSSS(Encryption encryption) : super(encryption);

  bool requestedSecrets = false;
  @override
  Future<void> maybeRequestAll([List<DeviceKeys> devices]) async {
    requestedSecrets = true;
    final handle = open();
    handle.unlock(recoveryKey: SSSS_KEY);
    await handle.maybeCacheAll();
  }
}

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
    eventType: type,
    type: 'timeline',
    roomID: req.room.id,
  );
}

void main() {
  /// All Tests related to the ChatTime
  group('Key Verification', () {
    var olmEnabled = true;
    try {
      olm.init();
      olm.Account();
    } catch (_) {
      olmEnabled = false;
      Logs.warning('[LibOlm] Failed to load LibOlm: ' + _.toString());
    }
    Logs.success('[LibOlm] Enabled: $olmEnabled');

    if (!olmEnabled) return;

    // key @othertest:fakeServer.notExisting
    const otherPickledOlmAccount =
        'VWhVApbkcilKAEGppsPDf9nNVjaK8/IxT3asSR0sYg0S5KgbfE8vXEPwoiKBX2cEvwX3OessOBOkk+ZE7TTbjlrh/KEd31p8Wo+47qj0AP+Ky+pabnhi+/rTBvZy+gfzTqUfCxZrkzfXI9Op4JnP6gYmy7dVX2lMYIIs9WCO1jcmIXiXum5jnfXu1WLfc7PZtO2hH+k9CDKosOFaXRBmsu8k/BGXPSoWqUpvu6WpEG9t5STk4FeAzA';

    Client client1;
    Client client2;

    test('setupClient', () async {
      client1 = await getClient();
      client2 = Client('othertestclient', httpClient: FakeMatrixApi());
      client2.database = client1.database;
      await client2.checkServer('https://fakeServer.notExisting');
      client2.connect(
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
        KeyVerificationMethod.numbers
      };
      client2.verificationMethods = {
        KeyVerificationMethod.emoji,
        KeyVerificationMethod.numbers
      };
    });

    test('Run emoji / number verification', () async {
      // for a full run we test in-room verification in a cleartext room
      // because then we can easily intercept the payloads and inject in the other client
      FakeMatrixApi.calledEndpoints.clear();
      // make sure our master key is *not* verified to not triger SSSS for now
      client1.userDeviceKeys[client1.userID].masterKey.setDirectVerified(false);
      final req1 =
          await client1.userDeviceKeys[client2.userID].startVerification();
      var evt = getLastSentEvent(req1);
      expect(req1.state, KeyVerificationState.waitingAccept);

      KeyVerification req2;
      final sub = client2.onKeyVerificationRequest.stream.listen((req) {
        req2 = req;
      });
      await client2.encryption.keyVerificationManager.handleEventUpdate(evt);
      await Future.delayed(Duration(milliseconds: 10));
      await sub.cancel();
      expect(req2 != null, true);

      // send ready
      FakeMatrixApi.calledEndpoints.clear();
      await req2.acceptVerification();
      evt = getLastSentEvent(req2);
      expect(req2.state, KeyVerificationState.waitingAccept);

      // send start
      FakeMatrixApi.calledEndpoints.clear();
      await client1.encryption.keyVerificationManager.handleEventUpdate(evt);
      evt = getLastSentEvent(req1);

      // send accept
      FakeMatrixApi.calledEndpoints.clear();
      await client2.encryption.keyVerificationManager.handleEventUpdate(evt);
      evt = getLastSentEvent(req2);

      // send key
      FakeMatrixApi.calledEndpoints.clear();
      await client1.encryption.keyVerificationManager.handleEventUpdate(evt);
      evt = getLastSentEvent(req1);

      // send key
      FakeMatrixApi.calledEndpoints.clear();
      await client2.encryption.keyVerificationManager.handleEventUpdate(evt);
      evt = getLastSentEvent(req2);

      // receive last key
      FakeMatrixApi.calledEndpoints.clear();
      await client1.encryption.keyVerificationManager.handleEventUpdate(evt);

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
      await client2.encryption.keyVerificationManager.handleEventUpdate(evt);
      expect(req1.state, KeyVerificationState.waitingSas);

      // send mac
      FakeMatrixApi.calledEndpoints.clear();
      await req2.acceptSas();
      evt = getLastSentEvent(req2);
      await client1.encryption.keyVerificationManager.handleEventUpdate(evt);

      expect(req1.state, KeyVerificationState.done);
      expect(req2.state, KeyVerificationState.done);
      expect(
          client1.userDeviceKeys[client2.userID].deviceKeys[client2.deviceID]
              .directVerified,
          true);
      expect(
          client2.userDeviceKeys[client1.userID].deviceKeys[client1.deviceID]
              .directVerified,
          true);
      await client1.encryption.keyVerificationManager.cleanup();
      await client2.encryption.keyVerificationManager.cleanup();
    });

    test('ask SSSS start', () async {
      client1.userDeviceKeys[client1.userID].masterKey.setDirectVerified(true);
      await client1.encryption.ssss.clearCache();
      final req1 =
          await client1.userDeviceKeys[client2.userID].startVerification();
      expect(req1.state, KeyVerificationState.askSSSS);
      await req1.openSSSS(recoveryKey: SSSS_KEY);
      await Future.delayed(Duration(milliseconds: 10));
      expect(req1.state, KeyVerificationState.waitingAccept);

      await req1.cancel();
      await client1.encryption.keyVerificationManager.cleanup();
    });

    test('ask SSSS end', () async {
      FakeMatrixApi.calledEndpoints.clear();
      // make sure our master key is *not* verified to not triger SSSS for now
      client1.userDeviceKeys[client1.userID].masterKey.setDirectVerified(false);
      // the other one has to have their master key verified to trigger asking for ssss
      client2.userDeviceKeys[client2.userID].masterKey.setDirectVerified(true);
      final req1 =
          await client1.userDeviceKeys[client2.userID].startVerification();
      var evt = getLastSentEvent(req1);
      expect(req1.state, KeyVerificationState.waitingAccept);

      KeyVerification req2;
      final sub = client2.onKeyVerificationRequest.stream.listen((req) {
        req2 = req;
      });
      await client2.encryption.keyVerificationManager.handleEventUpdate(evt);
      await Future.delayed(Duration(milliseconds: 10));
      await sub.cancel();
      expect(req2 != null, true);

      // send ready
      FakeMatrixApi.calledEndpoints.clear();
      await req2.acceptVerification();
      evt = getLastSentEvent(req2);
      expect(req2.state, KeyVerificationState.waitingAccept);

      // send start
      FakeMatrixApi.calledEndpoints.clear();
      await client1.encryption.keyVerificationManager.handleEventUpdate(evt);
      evt = getLastSentEvent(req1);

      // send accept
      FakeMatrixApi.calledEndpoints.clear();
      await client2.encryption.keyVerificationManager.handleEventUpdate(evt);
      evt = getLastSentEvent(req2);

      // send key
      FakeMatrixApi.calledEndpoints.clear();
      await client1.encryption.keyVerificationManager.handleEventUpdate(evt);
      evt = getLastSentEvent(req1);

      // send key
      FakeMatrixApi.calledEndpoints.clear();
      await client2.encryption.keyVerificationManager.handleEventUpdate(evt);
      evt = getLastSentEvent(req2);

      // receive last key
      FakeMatrixApi.calledEndpoints.clear();
      await client1.encryption.keyVerificationManager.handleEventUpdate(evt);

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
      client1.userDeviceKeys[client1.userID].masterKey.setDirectVerified(true);
      await client1.encryption.ssss.clearCache();

      // send mac
      FakeMatrixApi.calledEndpoints.clear();
      await req1.acceptSas();
      evt = getLastSentEvent(req1);
      await client2.encryption.keyVerificationManager.handleEventUpdate(evt);
      expect(req1.state, KeyVerificationState.waitingSas);

      // send mac
      FakeMatrixApi.calledEndpoints.clear();
      await req2.acceptSas();
      evt = getLastSentEvent(req2);
      await client1.encryption.keyVerificationManager.handleEventUpdate(evt);

      expect(req1.state, KeyVerificationState.askSSSS);
      expect(req2.state, KeyVerificationState.done);

      await req1.openSSSS(recoveryKey: SSSS_KEY);
      await Future.delayed(Duration(milliseconds: 10));
      expect(req1.state, KeyVerificationState.done);

      client1.encryption.ssss = MockSSSS(client1.encryption);
      (client1.encryption.ssss as MockSSSS).requestedSecrets = false;
      await client1.encryption.ssss.clearCache();
      await req1.maybeRequestSSSSSecrets();
      await Future.delayed(Duration(milliseconds: 10));
      expect((client1.encryption.ssss as MockSSSS).requestedSecrets, true);
      // delay for 12 seconds to be sure no other tests clear the ssss cache
      await Future.delayed(Duration(seconds: 12));

      await client1.encryption.keyVerificationManager.cleanup();
      await client2.encryption.keyVerificationManager.cleanup();
    });

    test('reject verification', () async {
      FakeMatrixApi.calledEndpoints.clear();
      // make sure our master key is *not* verified to not triger SSSS for now
      client1.userDeviceKeys[client1.userID].masterKey.setDirectVerified(false);
      final req1 =
          await client1.userDeviceKeys[client2.userID].startVerification();
      var evt = getLastSentEvent(req1);
      expect(req1.state, KeyVerificationState.waitingAccept);

      KeyVerification req2;
      final sub = client2.onKeyVerificationRequest.stream.listen((req) {
        req2 = req;
      });
      await client2.encryption.keyVerificationManager.handleEventUpdate(evt);
      await Future.delayed(Duration(milliseconds: 10));
      await sub.cancel();

      FakeMatrixApi.calledEndpoints.clear();
      await req2.rejectVerification();
      evt = getLastSentEvent(req2);
      await client1.encryption.keyVerificationManager.handleEventUpdate(evt);
      expect(req1.state, KeyVerificationState.error);
      expect(req2.state, KeyVerificationState.error);

      await client1.encryption.keyVerificationManager.cleanup();
      await client2.encryption.keyVerificationManager.cleanup();
    });

    test('reject sas', () async {
      FakeMatrixApi.calledEndpoints.clear();
      // make sure our master key is *not* verified to not triger SSSS for now
      client1.userDeviceKeys[client1.userID].masterKey.setDirectVerified(false);
      final req1 =
          await client1.userDeviceKeys[client2.userID].startVerification();
      var evt = getLastSentEvent(req1);
      expect(req1.state, KeyVerificationState.waitingAccept);

      KeyVerification req2;
      final sub = client2.onKeyVerificationRequest.stream.listen((req) {
        req2 = req;
      });
      await client2.encryption.keyVerificationManager.handleEventUpdate(evt);
      await Future.delayed(Duration(milliseconds: 10));
      await sub.cancel();
      expect(req2 != null, true);

      // send ready
      FakeMatrixApi.calledEndpoints.clear();
      await req2.acceptVerification();
      evt = getLastSentEvent(req2);
      expect(req2.state, KeyVerificationState.waitingAccept);

      // send start
      FakeMatrixApi.calledEndpoints.clear();
      await client1.encryption.keyVerificationManager.handleEventUpdate(evt);
      evt = getLastSentEvent(req1);

      // send accept
      FakeMatrixApi.calledEndpoints.clear();
      await client2.encryption.keyVerificationManager.handleEventUpdate(evt);
      evt = getLastSentEvent(req2);

      // send key
      FakeMatrixApi.calledEndpoints.clear();
      await client1.encryption.keyVerificationManager.handleEventUpdate(evt);
      evt = getLastSentEvent(req1);

      // send key
      FakeMatrixApi.calledEndpoints.clear();
      await client2.encryption.keyVerificationManager.handleEventUpdate(evt);
      evt = getLastSentEvent(req2);

      // receive last key
      FakeMatrixApi.calledEndpoints.clear();
      await client1.encryption.keyVerificationManager.handleEventUpdate(evt);

      await req1.acceptSas();
      FakeMatrixApi.calledEndpoints.clear();
      await req2.rejectSas();
      evt = getLastSentEvent(req2);
      await client1.encryption.keyVerificationManager.handleEventUpdate(evt);
      expect(req1.state, KeyVerificationState.error);
      expect(req2.state, KeyVerificationState.error);

      await client1.encryption.keyVerificationManager.cleanup();
      await client2.encryption.keyVerificationManager.cleanup();
    });

    test('other device accepted', () async {
      FakeMatrixApi.calledEndpoints.clear();
      // make sure our master key is *not* verified to not triger SSSS for now
      client1.userDeviceKeys[client1.userID].masterKey.setDirectVerified(false);
      final req1 =
          await client1.userDeviceKeys[client2.userID].startVerification();
      var evt = getLastSentEvent(req1);
      expect(req1.state, KeyVerificationState.waitingAccept);

      KeyVerification req2;
      final sub = client2.onKeyVerificationRequest.stream.listen((req) {
        req2 = req;
      });
      await client2.encryption.keyVerificationManager.handleEventUpdate(evt);
      await Future.delayed(Duration(milliseconds: 10));
      await sub.cancel();
      expect(req2 != null, true);

      await client2.encryption.keyVerificationManager
          .handleEventUpdate(EventUpdate(
        content: {
          'event_id': req2.transactionId,
          'type': 'm.key.verification.ready',
          'content': {
            'methods': ['m.sas.v1'],
            'from_device': 'SOMEOTHERDEVICE',
            'm.relates_to': {
              'rel_type': 'm.reference',
              'event_id': req2.transactionId,
            },
          },
          'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
          'sender': client2.userID,
        },
        eventType: 'm.key.verification.ready',
        type: 'timeline',
        roomID: req2.room.id,
      ));
      expect(req2.state, KeyVerificationState.error);

      await req2.cancel();
      await client1.encryption.keyVerificationManager.cleanup();
      await client2.encryption.keyVerificationManager.cleanup();
    });

    test('dispose client', () async {
      await client1.dispose(closeDatabase: true);
      await client2.dispose(closeDatabase: true);
    });
  });
}
