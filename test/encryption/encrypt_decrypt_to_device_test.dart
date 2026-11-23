// SPDX-FileCopyrightText: 2019-Present, 2020 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:matrix/matrix.dart';
import 'package:test/test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import '../fake_client.dart';
import '../fake_database.dart';

void main() async {
  final database = await getDatabase();

  group('Encrypt/Decrypt to-device messages', tags: 'olm', () {
    Logs().level = Level.error;

    late Client client;
    final otherClient = Client(
      'othertestclient',
      httpClient: FakeMatrixApi(),
      database: database,
    );
    late DeviceKeys device;
    late Map<String, dynamic> payload;

    setUpAll(() async {
      await vod.init(wasmPath: './pkg/', libraryPath: './rust/target/debug/');

      client = await getClient();
    });

    test('setupClient', () async {
      client = await getClient();
      await client.abortSync();
      await otherClient.checkHomeserver(
        Uri.parse('https://fakeserver.notexisting'),
        checkWellKnown: false,
      );
      await otherClient.init(
        newToken: 'abc',
        newUserID: '@othertest:fakeServer.notExisting',
        newHomeserver: otherClient.homeserver,
        newDeviceName: 'Text Matrix Client',
        newDeviceID: 'FOXDEVICE',
      );
      await otherClient.abortSync();

      await Future.delayed(Duration(milliseconds: 10));
      device = DeviceKeys.fromJson({
        'user_id': client.userID,
        'device_id': client.deviceID,
        'algorithms': [
          AlgorithmTypes.olmV1Curve25519AesSha2,
          AlgorithmTypes.megolmV1AesSha2,
        ],
        'keys': {
          'curve25519:${client.deviceID}': client.identityKey,
          'ed25519:${client.deviceID}': client.fingerprintKey,
        },
      }, client);
    });

    test('encryptToDeviceMessage', () async {
      payload = await otherClient.encryption!.encryptToDeviceMessage(
        [device],
        'm.to_device',
        {'hello': 'foxies'},
      );
    });

    test('decryptToDeviceEvent', () async {
      final encryptedEvent = ToDeviceEvent(
        sender: '@othertest:fakeServer.notExisting',
        type: EventTypes.Encrypted,
        content: payload[client.userID][client.deviceID],
      );
      final decryptedEvent = await client.encryption!.decryptToDeviceEvent(
        encryptedEvent,
      );
      expect(decryptedEvent.type, 'm.to_device');
      expect(decryptedEvent.content['hello'], 'foxies');
    });

    test('decryptToDeviceEvent nocache', () async {
      client.encryption!.olmManager.olmSessions.clear();
      payload = await otherClient.encryption!.encryptToDeviceMessage(
        [device],
        'm.to_device',
        {'hello': 'superfoxies'},
      );
      final encryptedEvent = ToDeviceEvent(
        sender: '@othertest:fakeServer.notExisting',
        type: EventTypes.Encrypted,
        content: payload[client.userID][client.deviceID],
      );
      final decryptedEvent = await client.encryption!.decryptToDeviceEvent(
        encryptedEvent,
      );
      expect(decryptedEvent.type, 'm.to_device');
      expect(decryptedEvent.content['hello'], 'superfoxies');
    });

    test('room keys that arrive late decrypt the waiting events', () async {
      const roomId = '!726s6s6q:example.com';
      final sessions = [vod.GroupSession(), vod.GroupSession()];
      // Taken before encrypting: a key exported later starts at a later index.
      final sessionKeys = [for (final s in sessions) s.sessionKey];
      MatrixEvent encrypted(int i) => MatrixEvent(
        type: EventTypes.Encrypted,
        content: {
          'algorithm': AlgorithmTypes.megolmV1AesSha2,
          'ciphertext': sessions[i].encrypt(
            json.encode({
              'type': EventTypes.Message,
              'content': {'msgtype': 'm.text', 'body': 'late $i'},
              'room_id': roomId,
            }),
          ),
          'sender_key': otherClient.identityKey,
          'session_id': sessions[i].sessionId,
        },
        senderId: otherClient.userID!,
        eventId: '\$late$i',
        originServerTs: DateTime.now(),
      );
      Future<void> sendKey(int i) async {
        final payload = await otherClient.encryption!.encryptToDeviceMessage(
          [device],
          EventTypes.RoomKey,
          {
            'algorithm': AlgorithmTypes.megolmV1AesSha2,
            'room_id': roomId,
            'session_id': sessions[i].sessionId,
            'session_key': sessionKeys[i],
          },
        );
        await client.handleSync(
          SyncUpdate(
            nextBatch: '',
            toDevice: [
              BasicEventWithSender(
                senderId: otherClient.userID!,
                type: EventTypes.Encrypted,
                content: payload[client.userID]![client.deviceID]!,
              ),
            ],
          ),
        );
      }

      final decrypted = <Event>[];
      final sub = client.onDecryptedTimelineEvent.stream.listen(decrypted.add);
      await client.handleSync(
        SyncUpdate(
          nextBatch: '',
          rooms: RoomsUpdate(
            join: {
              roomId: JoinedRoomUpdate(
                timeline: TimelineUpdate(events: [encrypted(0), encrypted(1)]),
              ),
            },
          ),
        ),
      );
      expect(decrypted, isEmpty);

      await sendKey(0);
      await Future.delayed(Duration.zero);
      expect(decrypted.map((e) => e.body), ['late 0']);
      // The first key must not drop the second event from the queue.
      await sendKey(1);
      await Future.delayed(Duration.zero);
      expect(decrypted.map((e) => e.body), ['late 0', 'late 1']);
      expect(decrypted.map((e) => e.eventId), ['\$late0', '\$late1']);
      await sub.cancel();
    });

    test('dispose client', () async {
      await client.dispose(closeDatabase: true);
      await otherClient.dispose(closeDatabase: true);
    });
  });
}
