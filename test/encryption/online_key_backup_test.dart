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

    test(
      'Room.searchEvents decrypts an event whose session is only in online key backup',
      () async {
        // 1. Fresh outbound + inbound megolm session the client has never seen.
        final outbound = vod.GroupSession();
        final inbound = vod.InboundGroupSession(outbound.sessionKey);
        final newSessionId = inbound.sessionId;
        final newSenderKey = client.identityKey;

        // 2. Real ciphertext that the matching inbound session can decrypt.
        final ciphertext = outbound.encrypt(
          json.encode({
            'type': 'm.room.message',
            'content': {
              'msgtype': 'm.text',
              'body': 'a needle in the encrypted haystack',
            },
          }),
        );

        // 3. Encrypt the inbound session for the FakeMatrixApi backup using
        //    the same backup public key the FakeMatrixApi advertises.
        const backupPubKey = 'GXYaxqhNhUK28zUdxOmEsFRguz+PzBsDlTLlF0O0RkM';
        final encryptor = vod.PkEncryption.fromPublicKey(
          vod.Curve25519PublicKey.fromBase64(backupPubKey),
        );
        final encryptedSession = encryptor.encrypt(
          json.encode({
            'algorithm': AlgorithmTypes.megolmV1AesSha2,
            'forwarding_curve25519_key_chain': <String>[],
            'sender_key': newSenderKey,
            'sender_claimed_keys': {'ed25519': client.fingerprintKey},
            'session_key': inbound.exportAt(0),
          }),
        );
        final (ct, mac, ephemeral) = encryptedSession.toBase64();

        // 4. A fresh room that exists in client.rooms (required for
        //    keyManager.maybeAutoRequest's lookup) and has no DB history.
        const newRoomId = '!searchBackupOnly:example.com';
        final newRoom = Room(client: client, id: newRoomId, prev_batch: '');
        client.rooms.add(newRoom);

        // 5. Mock the online key backup GET for this specific session.
        FakeMatrixApi
                .currentApi!
                .api['GET']!['/client/v3/room_keys/keys/${Uri.encodeComponent(newRoomId)}/${Uri.encodeComponent(newSessionId)}?version=5'] =
            (_) => {
              'first_message_index': 0,
              'forwarded_count': 0,
              'is_verified': true,
              'session_data': {
                'ephemeral': ephemeral,
                'ciphertext': ct,
                'mac': mac,
              },
            };

        // 6. Mock /messages with our encrypted event.
        FakeMatrixApi
                .currentApi!
                .api['GET']!['/client/v3/rooms/${Uri.encodeComponent(newRoomId)}/messages?from&dir=b&limit=1000&filter=%7B%22types%22%3A%5B%22m.room.message%22%2C%22m.room.encrypted%22%5D%7D'] =
            (_) => {
              'chunk': [
                {
                  'content': {
                    'algorithm': AlgorithmTypes.megolmV1AesSha2,
                    'sender_key': newSenderKey,
                    'session_id': newSessionId,
                    'ciphertext': ciphertext,
                    'device_id': client.deviceID,
                  },
                  'type': EventTypes.Encrypted,
                  'event_id': '\$searchEnc',
                  'origin_server_ts': 1432735824653,
                  'sender': '@alice:example.com',
                },
              ],
              'end': 't_search_end',
              'start': 't_search_start',
            };

        // Pre-condition: the session is in neither memory nor DB.
        expect(
          client.encryption!.keyManager.getInboundGroupSession(
            newRoomId,
            newSessionId,
          ),
          isNull,
        );

        final result = await newRoom.searchEvents(searchFunc: (_) => true);

        // The event was decrypted via the backup-load path that searchEvents
        // performs internally.
        final decrypted = result.events.where(
          (e) => e.eventId == '\$searchEnc',
        );
        expect(decrypted, isNotEmpty);
        expect(decrypted.first.body, 'a needle in the encrypted haystack');
      },
    );

    test('dispose client', () async {
      await client.dispose(closeDatabase: false);
    });
  });
}
