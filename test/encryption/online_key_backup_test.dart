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

import 'dart:convert';

import 'package:olm/olm.dart' as olm;
import 'package:test/test.dart';

import 'package:matrix/matrix.dart';
import '../fake_client.dart';

void main() {
  group('Online Key Backup', tags: 'olm', () {
    Logs().level = Level.error;

    late Client client;

    final roomId = '!726s6s6q:example.com';
    final sessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
    final senderKey = 'JBG7ZaPn54OBC7TuIEiylW3BZ+7WcGQhFBPB9pogbAg';

    setUpAll(() async {
      await olm.init();
      olm.get_library_version();
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
      await client.encryption!.keyManager
          .request(client.getRoomById(roomId)!, sessionId, senderKey);
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
      final session = olm.OutboundGroupSession();
      session.create();
      final inbound = olm.InboundGroupSession();
      inbound.create(session.session_key());
      final senderKey = client.identityKey;
      final roomId = '!someroom:example.org';
      final sessionId = inbound.session_id();
      // set a payload...
      final sessionPayload = <String, dynamic>{
        'algorithm': AlgorithmTypes.megolmV1AesSha2,
        'room_id': roomId,
        'forwarding_curve25519_key_chain': [client.identityKey],
        'session_id': sessionId,
        'session_key': inbound.export_session(1),
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
          .calledEndpoints['/client/v3/room_keys/keys?version=5']!.first;
      dbSessions = await client.database.getInboundGroupSessionsToUpload();
      expect(dbSessions.isEmpty, true);

      final onlineKeys = RoomKeys.fromJson(json.decode(payload));
      client.encryption!.keyManager.clearInboundGroupSessions();
      var ret = client.encryption!.keyManager
          .getInboundGroupSession(roomId, sessionId);
      expect(ret, null);
      await client.encryption!.keyManager.loadFromResponse(onlineKeys);
      ret = client.encryption!.keyManager
          .getInboundGroupSession(roomId, sessionId);
      expect(ret != null, true);
    });

    test('dispose client', () async {
      await client.dispose(closeDatabase: false);
    });
  });
}
