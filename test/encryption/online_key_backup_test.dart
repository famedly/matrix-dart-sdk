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
import '../fake_matrix_api.dart';

void main() {
  group('Online Key Backup', () {
    Logs().level = Level.error;
    var olmEnabled = true;

    late Client client;

    final roomId = '!726s6s6q:example.com';
    final sessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
    final senderKey = 'JBG7ZaPn54OBC7TuIEiylW3BZ+7WcGQhFBPB9pogbAg';

    test('setupClient', () async {
      try {
        await olm.init();
        olm.get_library_version();
      } catch (e) {
        olmEnabled = false;
        Logs().w('[LibOlm] Failed to load LibOlm', e);
      }
      Logs().i('[LibOlm] Enabled: $olmEnabled');
      if (!olmEnabled) return;

      client = await getClient();
    });

    test('basic things', () async {
      if (!olmEnabled) return;
      expect(client.encryption!.keyManager.enabled, true);
      expect(await client.encryption!.keyManager.isCached(), false);
      final handle = client.encryption!.ssss.open();
      await handle.unlock(recoveryKey: ssssKey);
      await handle.maybeCacheAll();
      expect(await client.encryption!.keyManager.isCached(), true);
    });

    test('load key', () async {
      if (!olmEnabled) return;
      client.encryption!.keyManager.clearInboundGroupSessions();
      await client.encryption!.keyManager
          .request(client.getRoomById(roomId)!, sessionId, senderKey);
      expect(
          client.encryption!.keyManager
                  .getInboundGroupSession(roomId, sessionId) !=
              null,
          true);
    });

    test('upload key', () async {
      if (!olmEnabled) return;
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
          roomId, sessionId, senderKey, sessionPayload,
          forwarded: true);
      var dbSessions = await client.database!.getInboundGroupSessionsToUpload();
      expect(dbSessions.isNotEmpty, true);
      await client.encryption!.keyManager.backgroundTasks();
      await FakeMatrixApi.firstWhereValue(
          '/client/v3/room_keys/keys?version=5');
      final payload = FakeMatrixApi
          .calledEndpoints['/client/v3/room_keys/keys?version=5']!.first;
      dbSessions = await client.database!.getInboundGroupSessionsToUpload();
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
      if (!olmEnabled) return;
      await client.dispose(closeDatabase: false);
    });
  });
}
