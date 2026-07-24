// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

// Reproduction tests for: "first message in a new room is undecryptable
// (The sender has not sent us the session key.)"
//
// These tests emulate the sender side of the flow as faithfully as possible:
// every simulated /sync is processed inside a database transaction and is
// followed by `updateUserDeviceKeys()`, exactly like `Client._sync()` does.

import 'dart:convert';

import 'package:canonical_json/canonical_json.dart';
import 'package:matrix/fake_matrix_api.dart';
import 'package:matrix/matrix.dart';
import 'package:test/test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'fake_client.dart';

/// A fake remote user with a real vodozemac account so that we can *actually
/// decrypt* what the client under test sends to it.
class FakeRemoteUser {
  final String userId;
  final String deviceId;
  final vod.Account account;

  FakeRemoteUser(this.userId, this.deviceId) : account = vod.Account();

  String get curve25519Key => account.identityKeys.curve25519.toBase64();
  String get ed25519Key => account.identityKeys.ed25519.toBase64();

  Map<String, dynamic> get signedDeviceKeys {
    final keyObj = {
      'user_id': userId,
      'device_id': deviceId,
      'algorithms': ['m.olm.v1.curve25519-aes-sha2', 'm.megolm.v1.aes-sha2'],
      'keys': {
        'curve25519:$deviceId': curve25519Key,
        'ed25519:$deviceId': ed25519Key,
      },
    };
    final signature = account.sign(
      String.fromCharCodes(canonicalJson.encode(keyObj)),
    );
    keyObj['signatures'] = {
      userId: {'ed25519:$deviceId': signature.toBase64()},
    };
    return keyObj;
  }

  Map<String, dynamic> signedOneTimeKey() {
    account.generateOneTimeKeys(1);
    final otk = account.oneTimeKeys.entries.first;
    final keyObj = {'key': otk.value.toBase64()};
    final signature = account.sign(
      String.fromCharCodes(canonicalJson.encode(keyObj)),
    );
    account.markKeysAsPublished();
    return {
      'signed_curve25519:${otk.key}': {
        'key': keyObj['key'],
        'signatures': {
          userId: {'ed25519:$deviceId': signature.toBase64()},
        },
      },
    };
  }

  /// Decrypts an olm to-device message that was sent to this user's device
  /// and returns the decrypted payload (usually the m.room_key event).
  Map<String, dynamic> decryptToDevice(Map<String, dynamic> encryptedContent) {
    final ciphertext =
        encryptedContent['ciphertext'][curve25519Key] as Map<String, dynamic>;
    expect(ciphertext['type'], 0, reason: 'expected a pre-key message');
    final result = account.createInboundSession(
      theirIdentityKey: vod.Curve25519PublicKey.fromBase64(
        encryptedContent['sender_key'],
      ),
      preKeyMessageBase64: ciphertext['body'],
    );
    return json.decode(result.plaintext);
  }
}

void main() {
  group('New room first message reproduction', tags: 'olm', () {
    Logs().level = Level.warning;

    late Client client;
    var roomCounter = 0;

    setUpAll(() async {
      await vod.init(wasmPath: './pkg/', libraryPath: './rust/target/debug/');
    });

    setUp(() async {
      client = await getClient();
    });

    tearDown(() async {
      await client.dispose(closeDatabase: true);
    });

    /// mimics Client._sync(): handleSync in a transaction, then
    /// updateUserDeviceKeys, like the real sync loop does.
    Future<void> emulateSync(SyncUpdate update) async {
      await client.database.transaction(() async {
        await client.handleSync(update, direction: Direction.f);
      });
      await client.updateUserDeviceKeys();
    }

    /// Registers keys/query + keys/claim handlers which behave like a real
    /// server: they only return keys for users that were actually requested.
    void registerRemoteUsers(List<FakeRemoteUser> users) {
      final api = FakeMatrixApi.currentApi!.api;
      final oldQuery = api['POST']!['/client/v3/keys/query'];
      api['POST']!['/client/v3/keys/query'] = (req) {
        final Map<String, dynamic> requested =
            decodeJson(req)['device_keys'] ?? {};
        // deep copy so that we get plain dynamic maps
        final Map<String, dynamic> res = json.decode(
          json.encode(oldQuery(req)),
        );
        // Simulate a real server: only include what was requested.
        (res['device_keys'] as Map<String, dynamic>).removeWhere(
          (userId, _) => !requested.containsKey(userId),
        );
        for (final user in users) {
          if (requested.containsKey(user.userId)) {
            res['device_keys'][user.userId] = {
              user.deviceId: user.signedDeviceKeys,
            };
          }
        }
        return res;
      };
      final oldClaim = api['POST']!['/client/v3/keys/claim'];
      api['POST']!['/client/v3/keys/claim'] = (req) {
        final Map<String, dynamic> requested =
            decodeJson(req)['one_time_keys'] ?? {};
        final Map<String, dynamic> res = json.decode(
          json.encode(oldClaim(req)),
        );
        for (final user in users) {
          if (requested.containsKey(user.userId)) {
            res['one_time_keys'][user.userId] = {
              user.deviceId: user.signedOneTimeKey(),
            };
          }
        }
        return res;
      };
    }

    MatrixEvent memberEvent(String userId, String membership, int ts) =>
        MatrixEvent(
          type: 'm.room.member',
          content: {'membership': membership},
          senderId: userId,
          stateKey: userId,
          eventId: '\$member_${userId.hashCode}_$ts',
          originServerTs: DateTime.fromMillisecondsSinceEpoch(ts),
        );

    /// The initial sync for a freshly created encrypted room, as the room
    /// creator would receive it: everything is in the timeline.
    JoinedRoomUpdate newRoomUpdate({
      required List<String> invited,
      int joined = 1,
    }) => JoinedRoomUpdate(
      summary: RoomSummary.fromJson({
        'm.joined_member_count': joined,
        'm.invited_member_count': invited.length,
      }),
      timeline: TimelineUpdate(
        events: [
          MatrixEvent(
            type: 'm.room.create',
            content: {'creator': client.userID},
            senderId: client.userID!,
            stateKey: '',
            eventId: '\$create_1',
            originServerTs: DateTime.fromMillisecondsSinceEpoch(100),
          ),
          memberEvent(client.userID!, 'join', 101),
          MatrixEvent(
            type: 'm.room.power_levels',
            content: {},
            senderId: client.userID!,
            stateKey: '',
            eventId: '\$pl_1',
            originServerTs: DateTime.fromMillisecondsSinceEpoch(102),
          ),
          MatrixEvent(
            type: 'm.room.encryption',
            content: {'algorithm': AlgorithmTypes.megolmV1AesSha2},
            senderId: client.userID!,
            stateKey: '',
            eventId: '\$enc_1',
            originServerTs: DateTime.fromMillisecondsSinceEpoch(103),
          ),
          for (final userId in invited)
            MatrixEvent(
              type: 'm.room.member',
              content: {'membership': 'invite'},
              senderId: client.userID!,
              stateKey: userId,
              eventId: '\$invite_${userId.hashCode}',
              originServerTs: DateTime.fromMillisecondsSinceEpoch(104),
            ),
        ],
        limited: false,
        prevBatch: 't_new_room',
      ),
    );

    List<Map<String, dynamic>> sentToDeviceMessages() {
      final result = <Map<String, dynamic>>[];
      for (final entry in FakeMatrixApi.calledEndpoints.entries) {
        if (entry.key.startsWith('/client/v3/sendToDevice/m.room.encrypted')) {
          for (final body in entry.value) {
            result.add(decodeJson(body));
          }
        }
      }
      return result;
    }

    Map<String, dynamic>? toDevicePayloadFor(FakeRemoteUser user) {
      for (final body in sentToDeviceMessages()) {
        final content = body['messages']?[user.userId]?[user.deviceId];
        if (content != null) return content as Map<String, dynamic>;
      }
      return null;
    }

    test(
      'Scenario 1: create room with invite in initial sync, first message',
      () async {
        const roomId = '!1234:fakeServer.notExisting';
        roomCounter++;
        final charlie = FakeRemoteUser(
          '@charlie$roomCounter:remote.server',
          'CHARLIEDEV',
        );
        registerRemoteUsers([charlie]);

        // Room creation sync (creator side).
        await emulateSync(
          SyncUpdate(
            nextBatch: 'create_$roomCounter',
            rooms: RoomsUpdate(
              join: {
                roomId: newRoomUpdate(invited: [charlie.userId]),
              },
            ),
          ),
        );

        final room = client.getRoomById(roomId)!;
        expect(room.encrypted, true);

        // Now the app sends the first message.
        FakeMatrixApi.calledEndpoints.clear();
        await room.sendTextEvent('first message');

        final payload = toDevicePayloadFor(charlie);
        expect(
          payload,
          isNotNull,
          reason: 'The room key was never sent to the invited user!',
        );
        final decrypted = charlie.decryptToDevice(payload!);
        expect(decrypted['type'], 'm.room_key');
        final sessionKey = decrypted['content']['session_key'] as String;
        final inbound = vod.InboundGroupSession(sessionKey);
        expect(
          inbound.firstKnownIndex,
          0,
          reason:
              'Invited user did not get the key from index 0, '
              'so the first message is undecryptable for them!',
        );
      },
    );

    test(
      'Scenario 2: user joins (not invited) in a later sync, then first message',
      () async {
        const roomId = '!1234:fakeServer.notExisting';
        roomCounter++;
        final dave = FakeRemoteUser(
          '@dave$roomCounter:remote.server',
          'DAVEDEV',
        );
        registerRemoteUsers([dave]);

        // Sync 1: room creation without any invites (e.g. public room).
        await emulateSync(
          SyncUpdate(
            nextBatch: 'create_$roomCounter',
            rooms: RoomsUpdate(join: {roomId: newRoomUpdate(invited: [])}),
          ),
        );

        final room = client.getRoomById(roomId)!;
        expect(room.encrypted, true);
        expect(
          room.partial,
          true,
          reason: 'Precondition: room was never postLoaded/opened',
        );

        // Sync 2: dave joins the room.
        await emulateSync(
          SyncUpdate(
            nextBatch: 'join_$roomCounter',
            rooms: RoomsUpdate(
              join: {
                roomId: JoinedRoomUpdate(
                  summary: RoomSummary.fromJson({
                    'm.joined_member_count': 2,
                    'm.invited_member_count': 0,
                  }),
                  timeline: TimelineUpdate(
                    events: [memberEvent(dave.userId, 'join', 200)],
                    limited: false,
                  ),
                ),
              },
            ),
          ),
        );

        // Was dave's device list ever fetched?
        final daveKnown =
            client.userDeviceKeys[dave.userId]?.deviceKeys.isNotEmpty ?? false;

        // Now the app sends the first message.
        FakeMatrixApi.calledEndpoints.clear();
        await room.sendTextEvent('first message');

        final payload = toDevicePayloadFor(dave);
        expect(
          daveKnown,
          true,
          reason: 'BUG: The device keys of the joined user were never queried!',
        );
        expect(
          payload,
          isNotNull,
          reason: 'BUG: The room key was never sent to the joined user!',
        );
      },
    );

    test(
      'Scenario 2c: join in later sync WITH device_lists.changed hint',
      () async {
        const roomId = '!1234:fakeServer.notExisting';
        roomCounter++;
        final dave = FakeRemoteUser(
          '@dave$roomCounter:remote.server',
          'DAVEDEV',
        );
        registerRemoteUsers([dave]);

        await emulateSync(
          SyncUpdate(
            nextBatch: 'create_$roomCounter',
            rooms: RoomsUpdate(join: {roomId: newRoomUpdate(invited: [])}),
          ),
        );

        final room = client.getRoomById(roomId)!;
        expect(room.partial, true);

        // A real server would include dave in the /members response:
        FakeMatrixApi
                .currentApi!
                .api['GET']!['/client/v3/rooms/!1234%3AfakeServer.notExisting/members'] =
            (req) => {
              'chunk': [
                {
                  'type': 'm.room.member',
                  'content': {'membership': 'join'},
                  'sender': client.userID!,
                  'state_key': client.userID!,
                  'event_id': '\$abcd',
                  'origin_server_ts': 1,
                },
                {
                  'type': 'm.room.member',
                  'content': {'membership': 'join'},
                  'sender': dave.userId,
                  'state_key': dave.userId,
                  'event_id': '\$abcde',
                  'origin_server_ts': 2,
                },
              ],
            };

        // Sync 2: dave joined during a gappy sync: his join member event was
        // truncated out of the limited timeline. Per spec the server includes
        // dave in device_lists.changed ("users who now share an encrypted
        // room with the client") - this is the *only* hint the client gets.
        await emulateSync(
          SyncUpdate(
            nextBatch: 'join_$roomCounter',
            deviceLists: DeviceListsUpdate(changed: [dave.userId]),
            rooms: RoomsUpdate(
              join: {
                roomId: JoinedRoomUpdate(
                  summary: RoomSummary.fromJson({
                    'm.joined_member_count': 2,
                    'm.invited_member_count': 0,
                  }),
                  timeline: TimelineUpdate(
                    events: [
                      MatrixEvent(
                        type: 'm.room.message',
                        content: {'msgtype': 'm.text', 'body': 'hi'},
                        senderId: dave.userId,
                        eventId: '\$hi_$roomCounter',
                        originServerTs: DateTime.fromMillisecondsSinceEpoch(
                          201,
                        ),
                      ),
                    ],
                    limited: true,
                    prevBatch: 't_gappy',
                  ),
                ),
              },
            ),
          ),
        );

        final daveKnown =
            client.userDeviceKeys[dave.userId]?.deviceKeys.isNotEmpty ?? false;

        FakeMatrixApi.calledEndpoints.clear();
        await room.sendTextEvent('first message');

        final payload = toDevicePayloadFor(dave);
        expect(
          daveKnown,
          true,
          reason:
              'BUG: device_lists.changed hint for an untracked user was '
              'dropped, device keys never queried!',
        );
        expect(payload, isNotNull);
      },
    );

    test(
      'Scenario 2b: same as 2 but room was postLoaded (open in UI)',
      () async {
        const roomId = '!1234:fakeServer.notExisting';
        roomCounter++;
        final dave = FakeRemoteUser(
          '@dave$roomCounter:remote.server',
          'DAVEDEV',
        );
        registerRemoteUsers([dave]);

        await emulateSync(
          SyncUpdate(
            nextBatch: 'create_$roomCounter',
            rooms: RoomsUpdate(join: {roomId: newRoomUpdate(invited: [])}),
          ),
        );

        final room = client.getRoomById(roomId)!;
        await room.postLoad();
        expect(room.partial, false);

        await emulateSync(
          SyncUpdate(
            nextBatch: 'join_$roomCounter',
            rooms: RoomsUpdate(
              join: {
                roomId: JoinedRoomUpdate(
                  summary: RoomSummary.fromJson({
                    'm.joined_member_count': 2,
                    'm.invited_member_count': 0,
                  }),
                  timeline: TimelineUpdate(
                    events: [memberEvent(dave.userId, 'join', 200)],
                    limited: false,
                  ),
                ),
              },
            ),
          ),
        );

        final daveKnown =
            client.userDeviceKeys[dave.userId]?.deviceKeys.isNotEmpty ?? false;

        FakeMatrixApi.calledEndpoints.clear();
        await room.sendTextEvent('first message');

        final payload = toDevicePayloadFor(dave);
        expect(daveKnown, true);
        expect(payload, isNotNull);
      },
    );

    test(
      'Scenario 4: we join a new room ourselves and send the first message',
      () async {
        const roomId = '!1234:fakeServer.notExisting';
        roomCounter++;
        // frank created the room and invited us.
        final frank = FakeRemoteUser(
          '@frank$roomCounter:remote.server',
          'FRANKDEV',
        );
        registerRemoteUsers([frank]);

        FakeMatrixApi
                .currentApi!
                .api['GET']!['/client/v3/rooms/!1234%3AfakeServer.notExisting/members'] =
            (req) => {
              'chunk': [
                {
                  'type': 'm.room.member',
                  'content': {'membership': 'join'},
                  'sender': client.userID!,
                  'state_key': client.userID!,
                  'event_id': '\$abcd',
                  'origin_server_ts': 2,
                },
                {
                  'type': 'm.room.member',
                  'content': {'membership': 'join'},
                  'sender': frank.userId,
                  'state_key': frank.userId,
                  'event_id': '\$abcde',
                  'origin_server_ts': 1,
                },
              ],
            };

        // Sync 1: the invite arrives.
        await emulateSync(
          SyncUpdate(
            nextBatch: 'invited_$roomCounter',
            rooms: RoomsUpdate(
              invite: {
                roomId: InvitedRoomUpdate(
                  inviteState: [
                    StrippedStateEvent(
                      type: 'm.room.create',
                      content: {'creator': frank.userId},
                      senderId: frank.userId,
                      stateKey: '',
                    ),
                    StrippedStateEvent(
                      type: 'm.room.encryption',
                      content: {'algorithm': AlgorithmTypes.megolmV1AesSha2},
                      senderId: frank.userId,
                      stateKey: '',
                    ),
                    StrippedStateEvent(
                      type: 'm.room.member',
                      content: {'membership': 'join'},
                      senderId: frank.userId,
                      stateKey: frank.userId,
                    ),
                    StrippedStateEvent(
                      type: 'm.room.member',
                      content: {'membership': 'invite'},
                      senderId: frank.userId,
                      stateKey: client.userID,
                    ),
                  ],
                ),
              },
            ),
          ),
        );

        // Sync 2: we joined. Worst case: the server does not re-send the
        // m.room.encryption event in the state block (we already know it
        // from the invite), frank's member event is lazy-load-omitted and
        // there is no device_lists hint.
        await emulateSync(
          SyncUpdate(
            nextBatch: 'joined_$roomCounter',
            rooms: RoomsUpdate(
              join: {
                roomId: JoinedRoomUpdate(
                  summary: RoomSummary.fromJson({
                    'm.joined_member_count': 2,
                    'm.invited_member_count': 0,
                  }),
                  timeline: TimelineUpdate(
                    events: [memberEvent(client.userID!, 'join', 300)],
                    limited: false,
                  ),
                ),
              },
            ),
          ),
        );

        final room = client.getRoomById(roomId)!;
        expect(room.membership, Membership.join);
        expect(room.encrypted, true);

        // We send the first message into the new room.
        FakeMatrixApi.calledEndpoints.clear();
        await room.sendTextEvent('hello frank');

        final payload = toDevicePayloadFor(frank);
        expect(
          payload,
          isNotNull,
          reason:
              'BUG: The room key was never sent to the room creator - '
              'they cannot decrypt our first message!',
        );
      },
    );

    test(
      'Scenario 3: invite arrives in a later sync (room.invite after creation)',
      () async {
        const roomId = '!1234:fakeServer.notExisting';
        roomCounter++;
        final erin = FakeRemoteUser(
          '@erin$roomCounter:remote.server',
          'ERINDEV',
        );
        registerRemoteUsers([erin]);

        // Sync 1: room creation without invites.
        await emulateSync(
          SyncUpdate(
            nextBatch: 'create_$roomCounter',
            rooms: RoomsUpdate(join: {roomId: newRoomUpdate(invited: [])}),
          ),
        );

        final room = client.getRoomById(roomId)!;
        expect(room.partial, true);

        // Sync 2: erin gets invited (like room.invite() an instant later).
        await emulateSync(
          SyncUpdate(
            nextBatch: 'invite_$roomCounter',
            rooms: RoomsUpdate(
              join: {
                roomId: JoinedRoomUpdate(
                  summary: RoomSummary.fromJson({
                    'm.joined_member_count': 1,
                    'm.invited_member_count': 1,
                  }),
                  timeline: TimelineUpdate(
                    events: [
                      MatrixEvent(
                        type: 'm.room.member',
                        content: {'membership': 'invite'},
                        senderId: client.userID!,
                        stateKey: erin.userId,
                        eventId: '\$invite_erin_$roomCounter',
                        originServerTs: DateTime.fromMillisecondsSinceEpoch(
                          200,
                        ),
                      ),
                    ],
                    limited: false,
                  ),
                ),
              },
            ),
          ),
        );

        final erinKnown =
            client.userDeviceKeys[erin.userId]?.deviceKeys.isNotEmpty ?? false;

        FakeMatrixApi.calledEndpoints.clear();
        await room.sendTextEvent('first message');

        final payload = toDevicePayloadFor(erin);
        expect(
          erinKnown,
          true,
          reason:
              'BUG: The device keys of the invited user were never queried!',
        );
        expect(
          payload,
          isNotNull,
          reason: 'BUG: The room key was never sent to the invited user!',
        );
      },
    );

    test(
      'Scenario 5: summary under-counts invites (stale participantListComplete)',
      () async {
        // Reproduction of the observed production incident: during a burst of
        // invites right after room creation the server sent a room summary that
        // under-reported the invited member count, and the (incomplete) local
        // member state happened to match those wrong counts. The count based
        // `participantListComplete` heuristic therefore returned `true`, so the
        // authoritative /members list was never fetched and the invited user
        // was silently dropped from the megolm key share - they could never
        // decrypt any message in the room.
        const roomId = '!1234:fakeServer.notExisting';
        roomCounter++;
        // grace is a real, invited member of the room. She is present in the
        // server's /members response but *missing* from the local state we get
        // via sync, and - crucially - not counted in the (stale) summary.
        final grace = FakeRemoteUser(
          '@grace$roomCounter:remote.server',
          'GRACEDEV',
        );
        registerRemoteUsers([grace]);

        // The authoritative member list the server would return from /members:
        // ourselves (join) + grace (invite).
        FakeMatrixApi
                .currentApi!
                .api['GET']!['/client/v3/rooms/!1234%3AfakeServer.notExisting/members'] =
            (req) => {
              'chunk': [
                {
                  'type': 'm.room.member',
                  'content': {'membership': 'join'},
                  'sender': client.userID!,
                  'state_key': client.userID!,
                  'event_id': '\$self_$roomCounter',
                  'origin_server_ts': 100,
                },
                {
                  'type': 'm.room.member',
                  'content': {'membership': 'invite'},
                  'sender': client.userID!,
                  'state_key': grace.userId,
                  'event_id': '\$grace_$roomCounter',
                  'origin_server_ts': 104,
                },
              ],
            };

        // Room creation sync WITHOUT grace's invite in the timeline, and with a
        // summary that under-reports the invite count as 0. Locally we then know
        // 1 joined / 0 invited, which matches the summary exactly, so
        // `participantListComplete` is a (wrong) `true`.
        await emulateSync(
          SyncUpdate(
            nextBatch: 'create_$roomCounter',
            rooms: RoomsUpdate(
              join: {
                roomId: newRoomUpdate(invited: [], joined: 1),
              },
            ),
          ),
        );

        final room = client.getRoomById(roomId)!;
        expect(room.encrypted, true);
        expect(
          room.participantListComplete,
          true,
          reason:
              'Precondition: the count heuristic wrongly believes the local '
              'member list is complete',
        );
        expect(
          room.getParticipants().any((u) => u.id == grace.userId),
          false,
          reason: 'Precondition: grace is not in the local member list',
        );

        // Now the app sends the first message.
        FakeMatrixApi.calledEndpoints.clear();
        await room.sendTextEvent('first message');

        final payload = toDevicePayloadFor(grace);
        expect(
          payload,
          isNotNull,
          reason:
              'BUG: the invited member was dropped from key sharing because '
              'the stale summary made participantListComplete return true, so '
              '/members was never fetched. They can never decrypt this room.',
        );
        // And they must get it from index 0 so the very first message is
        // decryptable for them.
        final decrypted = grace.decryptToDevice(payload!);
        expect(decrypted['type'], 'm.room_key');
        final sessionKey = decrypted['content']['session_key'] as String;
        expect(vod.InboundGroupSession(sessionKey).firstKnownIndex, 0);
      },
    );
  });
}
