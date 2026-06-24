// SPDX-FileCopyrightText: 2019-Present, 2020 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:matrix/matrix.dart';
import 'package:test/test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import '../fake_client.dart';

void main() {
  group('Online Key Backup', tags: 'olm', () {
    Logs().level = Level.error;

    late Client client;

    const roomId = '!726s6s6q:example.com';
    const sessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
    const senderKey = 'JBG7ZaPn54OBC7TuIEiylW3BZ+7WcGQhFBPB9pogbAg';

    setUpAll(() async {
      await vod.init(wasmPath: './pkg/', libraryPath: './rust/target/debug/');

      client = await getClient();
    });

    test('basic things', () async {
      expect(client.encryption!.keyManager.enabled, true);
      expect(await client.encryption!.keyManager.isCached(), false);
      final handle = client.encryption!.ssss.open();
      await handle.unlock(recoveryKey: ssssKey);
      await handle.maybeCacheAll();
      expect(await client.encryption!.keyManager.isCached(), true);
    });

    test('load key', () async {
      client.encryption!.keyManager.clearInboundGroupSessions();
      await client.encryption!.keyManager.request(
        client.getRoomById(roomId)!,
        sessionId,
        senderKey,
      );
      expect(
        client.encryption!.keyManager
            .getInboundGroupSession(roomId, sessionId)
            ?.sessionId,
        sessionId,
      );
    });

    test('Load all Room Keys', () async {
      final keyManager = client.encryption!.keyManager;
      const roomId = '!getroomkeys726s6s6q:example.com';
      const sessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
      expect(keyManager.getInboundGroupSession(roomId, sessionId), null);
      await client.encryption!.keyManager.loadAllKeysFromRoom(roomId);
      expect(
        keyManager.getInboundGroupSession(roomId, sessionId)?.sessionId,
        sessionId,
      );
    });

    test('Load all Keys', () async {
      final keyManager = client.encryption!.keyManager;
      const roomId = '!getallkeys726s6s6q:example.com';
      const sessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
      expect(keyManager.getInboundGroupSession(roomId, sessionId), null);
      await client.encryption!.keyManager.loadAllKeys();
      expect(
        keyManager.getInboundGroupSession(roomId, sessionId)?.sessionId,
        sessionId,
      );
    });

    test('upload key', () async {
      final session = vod.GroupSession();
      final inbound = vod.InboundGroupSession(session.sessionKey);

      final senderKey = client.identityKey;
      const roomId = '!someroom:example.org';
      final sessionId = inbound.sessionId;
      // set a payload...
      final sessionPayload = <String, dynamic>{
        'algorithm': AlgorithmTypes.megolmV1AesSha2,
        'room_id': roomId,
        'forwarding_curve25519_key_chain': [client.identityKey],
        'session_id': sessionId,
        'session_key': inbound.exportAt(1),
        'sender_key': senderKey,
        'sender_claimed_ed25519_key': client.fingerprintKey,
      };
      FakeMatrixApi.calledEndpoints.clear();
      await client.encryption!.keyManager.setInboundGroupSession(
        roomId,
        sessionId,
        senderKey,
        sessionPayload,
        forwarded: true,
      );
      var dbSessions = await client.database.getInboundGroupSessionsToUpload();
      expect(dbSessions.isNotEmpty, true);
      await client.encryption!.keyManager.uploadInboundGroupSessions();
      await FakeMatrixApi.firstWhereValue(
        '/client/v3/room_keys/keys?version=5',
      );
      final payload = FakeMatrixApi
          .calledEndpoints['/client/v3/room_keys/keys?version=5']!
          .first;
      dbSessions = await client.database.getInboundGroupSessionsToUpload();
      expect(dbSessions.isEmpty, true);

      final onlineKeys = RoomKeys.fromJson(json.decode(payload));
      client.encryption!.keyManager.clearInboundGroupSessions();
      var ret = client.encryption!.keyManager.getInboundGroupSession(
        roomId,
        sessionId,
      );
      expect(ret, null);
      await client.encryption!.keyManager.loadFromResponse(onlineKeys);
      ret = client.encryption!.keyManager.getInboundGroupSession(
        roomId,
        sessionId,
      );
      expect(ret != null, true);
    });

    test('dispose client', () async {
      await client.dispose(closeDatabase: false);
    });
  });
}
