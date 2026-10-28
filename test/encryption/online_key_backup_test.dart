// SPDX-FileCopyrightText: 2019-Present, 2020 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:matrix/matrix.dart';
import 'package:matrix/src/models/timeline_chunk.dart';
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
      'searchEvents and Timeline.export decrypt events whose session is only in online key backup',
      () async {
        const backupRoomId = '!searchBackupOnly:example.com';
        const searchBody = 'a needle in the encrypted haystack';
        const timelineBody = 'from the timeline';
        const databaseBody = 'from the database';

        // A room the client already knows (maybeAutoRequest looks it up in
        // client.rooms) and that has no older history to fetch.
        final room = Room(client: client, id: backupRoomId, prev_batch: '');
        client.rooms.add(room);

        // Call before [encryptedEvent]. The backup key is exported at index 0,
        // which is wrong once a message has been encrypted.
        void putInOnlineBackup(vod.GroupSession session) {
          final inbound = vod.InboundGroupSession(session.sessionKey);
          final encryptor = vod.PkEncryption.fromPublicKey(
            vod.Curve25519PublicKey.fromBase64(
              'GXYaxqhNhUK28zUdxOmEsFRguz+PzBsDlTLlF0O0RkM',
            ),
          );
          final (ct, mac, ephemeral) = encryptor
              .encrypt(
                json.encode({
                  'algorithm': AlgorithmTypes.megolmV1AesSha2,
                  'forwarding_curve25519_key_chain': <String>[],
                  'sender_key': client.identityKey,
                  'sender_claimed_keys': {'ed25519': client.fingerprintKey},
                  'session_key': inbound.exportAt(0),
                }),
              )
              .toBase64();
          FakeMatrixApi
                  .currentApi!
                  .api['GET']!['/client/v3/room_keys/keys/${Uri.encodeComponent(backupRoomId)}/${Uri.encodeComponent(session.sessionId)}?version=5'] =
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
        }

        Event encryptedEvent(
          vod.GroupSession session, {
          required String eventId,
          required String body,
        }) => Event(
          eventId: eventId,
          type: EventTypes.Encrypted,
          content: {
            'algorithm': AlgorithmTypes.megolmV1AesSha2,
            'sender_key': client.identityKey,
            'session_id': session.sessionId,
            'ciphertext': session.encrypt(
              json.encode({
                'type': 'm.room.message',
                'content': {'msgtype': 'm.text', 'body': body},
              }),
            ),
            'device_id': client.deviceID,
          },
          senderId: '@alice:example.com',
          originServerTs: DateTime.now(),
          room: room,
        );

        void mockRoomHistory(Event event) {
          FakeMatrixApi
                  .currentApi!
                  .api['GET']!['/client/v3/rooms/${Uri.encodeComponent(backupRoomId)}/messages?from&dir=b&limit=1000&filter=%7B%22types%22%3A%5B%22m.room.message%22%2C%22m.room.encrypted%22%5D%7D'] =
              (_) => {
                'chunk': [event.toJson()],
                'end': 't_search_end',
                'start': 't_search_start',
              };
        }

        // 1. A session this client has never seen.
        final searchSession = vod.GroupSession();

        // 2. Only the online key backup has that session.
        putInOnlineBackup(searchSession);

        // 3. Room history returns one message encrypted with it.
        final searchEvent = encryptedEvent(
          searchSession,
          eventId: '\$search',
          body: searchBody,
        );
        mockRoomHistory(searchEvent);

        // 4. The client has not stored that session.
        expect(
          client.encryption!.keyManager.getInboundGroupSession(
            backupRoomId,
            searchSession.sessionId,
          ),
          isNull,
        );

        // 5. searchEvents decrypts the message using the backup.
        final found = await room.searchEvents(searchFunc: (_) => true);
        expect(found.events.map((event) => event.body), contains(searchBody));

        // 6. Search stored that session, so export needs a new one.
        final exportSession = vod.GroupSession();
        putInOnlineBackup(exportSession);

        // 7. One event is on the timeline and one is only in the database.
        //    Export skips one stored row per event already on the timeline.
        final timelineEvent = encryptedEvent(
          exportSession,
          eventId: '\$timeline',
          body: timelineBody,
        );
        final databaseEvent = encryptedEvent(
          exportSession,
          eventId: '\$database',
          body: databaseBody,
        );
        for (final event in [timelineEvent, databaseEvent]) {
          await client.database.storeEventUpdate(
            backupRoomId,
            event,
            EventUpdateType.history,
            client,
          );
        }

        // 8. Export decrypts both without asking the server.
        room.prev_batch = null;
        final timeline = Timeline(
          room: room,
          chunk: TimelineChunk(events: [timelineEvent]),
        );
        final complete = await timeline.export().last as ExportComplete;
        timeline.cancelSubscriptions();
        expect(complete.events.map((event) => event.body), [
          timelineBody,
          databaseBody,
        ]);
      },
    );

    test('dispose client', () async {
      await client.dispose(closeDatabase: false);
    });
  });
}
