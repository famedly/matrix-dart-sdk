// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';

import 'package:canonical_json/canonical_json.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/encryption/utils/session_key.dart';
import 'package:matrix/matrix.dart';
import 'package:test/test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import '../fake_client.dart';
import '../fake_database.dart';

const roomId = '!history:fakeServer.notExisting';
const aliceId = '@alice:fakeServer.notExisting';
const bobId = '@test:fakeServer.notExisting';

/// Cross-signs the device of [client] and returns the keys as they would be
/// returned by `/keys/query`.
Map<String, Map<String, Object?>> crossSign(Client client) {
  final userId = client.userID!;
  final master = vod.PkSigning();
  final selfSigning = vod.PkSigning();
  final masterPub = master.publicKey.toBase64();
  final selfSigningPub = selfSigning.publicKey.toBase64();

  Map<String, Object?> sign(
    vod.PkSigning key,
    String keyId,
    Map<String, Object?> json,
  ) {
    final signable = Map<String, Object?>.from(json)..remove('signatures');
    final signature = key
        .sign(String.fromCharCodes(canonicalJson.encode(signable)))
        .toBase64();
    final signatures = Map<String, Object?>.from(
      (json['signatures'] as Map?) ?? {},
    );
    signatures[userId] = {
      ...?(signatures[userId] as Map?),
      'ed25519:$keyId': signature,
    };
    return {...json, 'signatures': signatures};
  }

  return {
    'master_keys': {
      userId: {
        'user_id': userId,
        'usage': ['master'],
        'keys': {'ed25519:$masterPub': masterPub},
        'signatures': <String, Object?>{},
      },
    },
    'self_signing_keys': {
      userId: sign(master, masterPub, {
        'user_id': userId,
        'usage': ['self_signing'],
        'keys': {'ed25519:$selfSigningPub': selfSigningPub},
      }),
    },
    'device_keys': {
      userId: {
        client.deviceID!: sign(
          selfSigning,
          selfSigningPub,
          client.encryption!.olmManager.signedDeviceKeys(),
        ),
      },
    },
  };
}

/// Adds the [keys] of another user to the `/keys/query` response of [api].
void addToKeysQuery(FakeMatrixApi api, Map<String, Map<String, Object?>> keys) {
  final original = api.api['POST']!['/client/v3/keys/query'];
  api.api['POST']!['/client/v3/keys/query'] = (req) {
    // Round-trip through JSON as the fake maps have narrower types.
    final response = json.decode(json.encode(original(req))) as Map;
    for (final entry in keys.entries) {
      (response[entry.key] as Map).addAll(entry.value);
    }
    return response;
  };
}

Future<T> waitFor<T>(FutureOr<T?> Function() check) async {
  for (var i = 0; i < 200; i++) {
    final result = await check();
    if (result != null) return result;
    await Future.delayed(Duration(milliseconds: 10));
  }
  throw TimeoutException('Condition was not fulfilled');
}

MatrixEvent stateEvent(
  String type,
  Map<String, Object?> content, {
  String stateKey = '',
  String sender = aliceId,
}) => MatrixEvent(
  type: type,
  content: content,
  senderId: sender,
  stateKey: stateKey,
  eventId: '\$${type}_${stateKey}_${DateTime.now().microsecondsSinceEpoch}',
  originServerTs: DateTime.now(),
);

/// Syncs a single state [event] of the room like the server would.
Future<void> syncState(Client client, MatrixEvent event) => client.handleSync(
  SyncUpdate(
    nextBatch: '',
    rooms: RoomsUpdate(
      join: {
        roomId: JoinedRoomUpdate(timeline: TimelineUpdate(events: [event])),
      },
    ),
  ),
);

Future<void> setHistoryVisibility(Client client, String visibility) =>
    syncState(
      client,
      stateEvent(EventTypes.HistoryVisibility, {
        'history_visibility': visibility,
      }),
    );

Event encryptedEvent(
  Room room,
  Map<String, Object?> content, {
  Map<String, Object?>? unsigned,
}) => Event(
  type: EventTypes.Encrypted,
  content: content,
  senderId: aliceId,
  eventId: '\$sent_before_invite',
  // Fixed, as decrypting the same message index for another event or time
  // counts as a replay.
  originServerTs: DateTime.fromMillisecondsSinceEpoch(1),
  unsigned: unsigned,
  room: room,
);

/// Uploads [bundle] like a sender would and returns the bundle details to
/// store for the recipient.
Future<Map<String, Object?>> uploadBundle(
  Map<String, Object?> bundle,
  String senderKey,
) async {
  final encryptedFile = await encryptFile(utf8.encode(json.encode(bundle)));
  final mxc = 'mxc://fakeserver.notexisting/test${FakeMatrixApi.media.length}';
  FakeMatrixApi.media[mxc] = encryptedFile.data;
  return {
    'sender_key': senderKey,
    'file': encryptedFile.toJson(Uri.parse(mxc)),
  };
}

bool called(bool Function(String action) test) =>
    FakeMatrixApi.calledEndpoints.keys.any(test);

/// Whether the current fake API was asked to share a key bundle.
bool sharedKeyBundle() => called(
  (action) =>
      action.startsWith('/media/v3/upload') ||
      action.startsWith('/client/v3/sendToDevice/'),
);

bool invited() => called((action) => action.endsWith('/invite'));

Map<String, Object?> roomKey(vod.GroupSession session, String senderKey) => {
  'algorithm': AlgorithmTypes.megolmV1AesSha2,
  'room_id': roomId,
  'sender_key': senderKey,
  'sender_claimed_keys': {},
  'session_id': session.sessionId,
  'session_key': vod.InboundGroupSession(
    session.sessionKey,
  ).exportAtFirstKnownIndex(),
};

void main() {
  group('MSC4268 room key bundles', tags: 'olm', () {
    Logs().level = Level.error;

    late Client alice;
    late Client bob;
    late FakeMatrixApi aliceApi;
    late FakeMatrixApi bobApi;
    late Map<String, Object?> encryptedMessage;
    late String sharedSessionId;
    late String notSharedSessionId;

    setUpAll(() async {
      await vod.init(wasmPath: './pkg/', libraryPath: './rust/target/debug/');

      bob = await getClient();
      bobApi = FakeMatrixApi.currentApi!;

      aliceApi = FakeMatrixApi();
      alice = Client(
        'alice',
        httpClient: aliceApi,
        database: await getDatabase(),
      );
      FakeMatrixApi.client = alice;
      await alice.checkHomeserver(
        Uri.parse('https://fakeServer.notExisting'),
        checkWellKnown: false,
      );
      await alice.init(
        newToken: 'abcd',
        newUserID: aliceId,
        newHomeserver: alice.homeserver,
        newDeviceName: 'Alice',
        newDeviceID: 'ALICEDEVICE',
      );
      await alice.abortSync();

      final aliceKeys = crossSign(alice);
      addToKeysQuery(aliceApi, aliceKeys);
      addToKeysQuery(bobApi, aliceKeys);
      final encodedRoomId = Uri.encodeComponent(roomId);
      aliceApi.api['POST']!['/client/v3/rooms/$encodedRoomId/invite'] = (_) =>
          {};
      bobApi.api['POST']!['/client/v3/rooms/$encodedRoomId/join'] = (_) => {
        'room_id': roomId,
      };
      await alice.updateUserDeviceKeys(additionalUsers: {aliceId, bobId});

      await alice.handleSync(
        SyncUpdate(
          nextBatch: '',
          rooms: RoomsUpdate(
            join: {
              roomId: JoinedRoomUpdate(
                state: [
                  stateEvent(EventTypes.Encryption, {
                    'algorithm': AlgorithmTypes.megolmV1AesSha2,
                  }),
                  stateEvent(EventTypes.HistoryVisibility, {
                    'history_visibility': 'shared',
                  }),
                  stateEvent(EventTypes.RoomMember, {
                    'membership': 'join',
                  }, stateKey: aliceId),
                ],
              ),
            },
          ),
        ),
      );
    });

    tearDownAll(() async {
      await alice.dispose(closeDatabase: true);
      await bob.dispose(closeDatabase: true);
    });

    test('own room keys are marked as shared history', () async {
      encryptedMessage = await alice.encryption!.encryptGroupMessagePayload(
        roomId,
        {'msgtype': MessageTypes.Text, 'body': 'Sent before the invite'},
      );
      sharedSessionId = encryptedMessage['session_id'] as String;
      final session = alice.encryption!.keyManager.getInboundGroupSession(
        roomId,
        sharedSessionId,
      )!;
      expect(session.sharedHistory, true);
      expect(session.content['shared_history'], true);
      expect(session.content['org.matrix.msc3061.shared_history'], true);
    });

    test('received room keys keep the shared history flag', () async {
      final keyManager = alice.encryption!.keyManager;
      for (final flag in [
        'shared_history',
        'm.shared_history',
        'org.matrix.msc3061.shared_history',
      ]) {
        final session = vod.GroupSession();
        await keyManager.handleToDeviceEvent(
          ToDeviceEvent(
            sender: bobId,
            type: EventTypes.RoomKey,
            content: {
              'algorithm': AlgorithmTypes.megolmV1AesSha2,
              'room_id': '!other:fakeServer.notExisting',
              'session_id': session.sessionId,
              'session_key': session.sessionKey,
              flag: true,
              // Nobody but ourselves may claim who shared a session.
              'com.famedly.msc4268.shared_by': '@mallory:example.com',
            },
            encryptedContent: {'sender_key': bob.identityKey},
          ),
        );
        final stored = keyManager.getInboundGroupSession(
          '!other:fakeServer.notExisting',
          session.sessionId,
        )!;
        expect(stored.sharedHistory, true, reason: flag);
        expect(stored.sharedBy, null);
      }
    });

    test('backup contains the shared history flag', () async {
      final decryption = vod.PkDecryption();
      final dbSession = await alice.database.getInboundGroupSession(
        roomId,
        sharedSessionId,
      );
      final roomKeys = generateUploadKeysImplementation(
        GenerateUploadKeysArgs(
          pubkey: decryption.publicKey,
          dbSessions: [
            DbInboundGroupSessionBundle(dbSession: dbSession!, verified: true),
          ],
          userId: aliceId,
        ),
      );
      final sessionData =
          roomKeys.rooms[roomId]!.sessions[sharedSessionId]!.sessionData;
      final decrypted = json.decode(
        decryption.decrypt(
          vod.PkMessage.fromBase64(
            ciphertext: sessionData['ciphertext'] as String,
            mac: sessionData['mac'] as String,
            ephemeralKey: sessionData['ephemeral'] as String,
          ),
        ),
      );
      expect(decrypted['shared_history'], true);
      expect(decrypted['org.matrix.msc3061.shared_history'], true);
    });

    test('buildRoomKeyBundle', () async {
      // Someone shared this session without the flag.
      final notShared = vod.GroupSession();
      notSharedSessionId = notShared.sessionId;
      await alice.encryption!.keyManager.handleToDeviceEvent(
        ToDeviceEvent(
          sender: bobId,
          type: EventTypes.RoomKey,
          content: {
            'algorithm': AlgorithmTypes.megolmV1AesSha2,
            'room_id': roomId,
            'session_id': notShared.sessionId,
            'session_key': notShared.sessionKey,
          },
          encryptedContent: {'sender_key': bob.identityKey},
        ),
      );

      final bundle = await alice.encryption!.keyManager.buildRoomKeyBundle(
        roomId,
      );
      final roomKeys = bundle['room_keys'] as List<Map<String, Object?>>;
      final withheld = bundle['withheld'] as List<Map<String, Object?>>;
      expect(roomKeys.map((key) => key['session_id']), [sharedSessionId]);
      expect(roomKeys.single['room_id'], roomId);
      expect(roomKeys.single['sender_key'], alice.identityKey);
      expect(
        (roomKeys.single['sender_claimed_keys'] as Map)['ed25519'],
        alice.fingerprintKey,
      );
      expect(roomKeys.single.containsKey('shared_history'), false);
      expect(withheld.map((key) => key['session_id']), [notSharedSessionId]);
      expect(withheld.single['code'], 'm.history_not_shared');
    });

    test('no history is shared if it is not shared', () async {
      FakeMatrixApi.currentApi = aliceApi;
      FakeMatrixApi.calledEndpoints.clear();
      await setHistoryVisibility(alice, 'joined');
      expect(alice.getRoomById(roomId)!.isHistoryShared, false);
      await alice.inviteUser(roomId, bobId);
      await setHistoryVisibility(alice, 'shared');
      expect(sharedKeyBundle(), false);
      expect(invited(), true);
    });

    test(
      'the outbound session is rotated when the history visibility changes',
      () async {
        final keyManager = alice.encryption!.keyManager;
        await alice.encryption!.encryptGroupMessagePayload(roomId, {
          'msgtype': MessageTypes.Text,
          'body': 'While the history is shared',
        });
        await setHistoryVisibility(alice, 'joined');
        expect(
          await keyManager.clearOrUseOutboundGroupSession(roomId, use: false),
          true,
        );
        expect(keyManager.getOutboundGroupSession(roomId), null);
        await setHistoryVisibility(alice, 'shared');
      },
    );

    test('no history is shared if disabled', () async {
      FakeMatrixApi.calledEndpoints.clear();
      alice.shareHistoryOnInvite = false;
      await alice.inviteUser(roomId, bobId);
      alice.shareHistoryOnInvite = true;
      expect(sharedKeyBundle(), false);
    });

    test(
      'no history is shared with devices which are not cross-signed',
      () async {
        FakeMatrixApi.calledEndpoints.clear();
        // @othertest has no valid self-signing key in the fake API.
        await alice.inviteUser(roomId, '@othertest:fakeServer.notExisting');
        expect(sharedKeyBundle(), false);
      },
    );

    test(
      'no history is shared with devices excluded by shareKeysWith',
      () async {
        FakeMatrixApi.calledEndpoints.clear();
        alice.shareKeysWith = ShareKeysWith.directlyVerifiedOnly;
        await alice.inviteUser(roomId, bobId);
        alice.shareKeysWith = ShareKeysWith.crossVerifiedIfEnabled;
        expect(sharedKeyBundle(), false);
      },
    );

    test(
      'no history is shared from a device which is not cross-signed',
      () async {
        FakeMatrixApi.calledEndpoints.clear();
        final ownKeys = alice.userDeviceKeys[aliceId]!;
        ownKeys.selfSigningKey!.blocked = true;
        await alice.inviteUser(roomId, bobId);
        ownKeys.selfSigningKey!.blocked = false;
        expect(sharedKeyBundle(), false);
      },
    );

    test(
      'a bundle above the upload limit does not prevent the invite',
      () async {
        FakeMatrixApi.calledEndpoints.clear();
        const upload = '/media/v3/upload?filename=room_key_bundle';
        aliceApi.api['POST']![upload] = (_) => {
          'errcode': 'M_TOO_LARGE',
          'error': 'Cannot upload files larger than 1 B',
        };
        await alice.inviteUser(roomId, bobId);
        aliceApi.api['POST']!.remove(upload);
        expect(called((action) => action == upload), true);
        expect(
          called((action) => action.startsWith('/client/v3/sendToDevice/')),
          false,
        );
        expect(invited(), true);
      },
    );

    test('inviting shares the key bundle before the invite', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await alice.inviteUser(roomId, bobId);
      final actions = FakeMatrixApi.calledEndpoints.keys.toList();
      final upload = actions.indexWhere(
        (action) => action.startsWith('/media/v3/upload'),
      );
      final sendToDevice = actions.indexWhere(
        (action) =>
            action.startsWith('/client/v3/sendToDevice/m.room.encrypted/'),
      );
      final invite = actions.indexWhere((action) => action.endsWith('/invite'));
      expect(upload, isNot(-1));
      expect(sendToDevice, greaterThan(upload));
      expect(invite, greaterThan(sendToDevice));

      final body = json.decode(
        FakeMatrixApi.calledEndpoints[actions[sendToDevice]]!.single,
      );
      final messages = body['messages'] as Map<String, Object?>;
      // OTHERDEVICE is cross-signed but has no one-time keys.
      expect(messages.keys, [bobId]);
      expect((messages[bobId] as Map).keys, ['GHTYAJCE']);

      await bob.handleSync(
        SyncUpdate(
          nextBatch: '',
          rooms: RoomsUpdate(
            invite: {
              roomId: InvitedRoomUpdate(
                inviteState: [
                  StrippedStateEvent(
                    type: EventTypes.RoomMember,
                    content: {'membership': 'invite'},
                    senderId: aliceId,
                    stateKey: bobId,
                  ),
                  StrippedStateEvent(
                    type: EventTypes.Encryption,
                    content: {'algorithm': AlgorithmTypes.megolmV1AesSha2},
                    senderId: aliceId,
                    stateKey: '',
                  ),
                ],
              ),
            },
          ),
          toDevice: [
            BasicEventWithSender(
              type: EventTypes.Encrypted,
              content: (messages[bobId] as Map)['GHTYAJCE'],
              senderId: aliceId,
            ),
          ],
        ),
      );
    });

    test('the bundle is not imported before accepting the invite', () async {
      final bundleInfo = await waitFor(
        () => bob.database.getRoomKeyBundle(roomId, aliceId),
      );
      expect(bundleInfo['sender_key'], alice.identityKey);
      expect(
        bob.encryption!.keyManager.getInboundGroupSession(
          roomId,
          sharedSessionId,
        ),
        null,
      );
    });

    test('the bundle is imported after accepting the invite', () async {
      await bob.getRoomById(roomId)!.join();
      final session = await waitFor(
        () => bob.encryption!.keyManager.getInboundGroupSession(
          roomId,
          sharedSessionId,
        ),
      );
      expect(session.sharedBy, aliceId);
      // Keys from a bundle may be shared again.
      expect(session.sharedHistory, true);
      expect(
        bob.encryption!.keyManager.getInboundGroupSession(
          roomId,
          notSharedSessionId,
        ),
        null,
      );

      final event = await bob.encryption!.decryptRoomEvent(
        encryptedEvent(bob.getRoomById(roomId)!, encryptedMessage),
      );
      expect(event.body, 'Sent before the invite');
      expect(event.keysSharedBy, aliceId);

      await waitFor(
        () async => (await bob.database.getPendingRoomKeyBundles()).isEmpty
            ? true
            : null,
      );
      expect(await bob.database.getRoomKeyBundle(roomId, aliceId), null);
    });

    test('keysSharedBy survives a restart', () async {
      final room = bob.getRoomById(roomId)!;
      final event = await bob.encryption!.decryptRoomEvent(
        encryptedEvent(room, encryptedMessage),
      );
      await bob.database.storeEventUpdate(
        roomId,
        event,
        EventUpdateType.timeline,
        bob,
      );
      bob.encryption!.keyManager.clearInboundGroupSessions();
      final stored = await bob.database.getEventById(event.eventId, room);
      expect(stored?.body, 'Sent before the invite');
      expect(stored?.keysSharedBy, aliceId);
    });

    test('the server can not claim that keys were shared', () async {
      const unsigned = {
        'com.famedly.msc4268.shared_by': '@mallory:example.com',
      };
      final room = alice.getRoomById(roomId)!;
      final spoofed = await alice.encryption!.decryptRoomEvent(
        encryptedEvent(room, encryptedMessage, unsigned: unsigned),
      );
      expect(spoofed.type, EventTypes.Message);
      expect(spoofed.keysSharedBy, null);
      final plain = Event(
        type: EventTypes.Message,
        content: {'msgtype': MessageTypes.Text, 'body': 'Not encrypted'},
        senderId: aliceId,
        eventId: '\$plain',
        originServerTs: DateTime.now(),
        unsigned: unsigned,
        room: room,
      );
      expect(plain.keysSharedBy, null);
    });

    test('a bundle which arrives after the join is imported', () async {
      final session = vod.GroupSession();
      await bob.database.storePendingRoomKeyBundle(roomId, {
        'inviter': aliceId,
        'invite_accepted_at': DateTime.now().millisecondsSinceEpoch,
      });
      final bundleInfo = await uploadBundle({
        'room_keys': [roomKey(session, alice.identityKey)],
        'withheld': [],
      }, alice.identityKey);
      await bob.encryption!.keyManager.handleToDeviceEvent(
        ToDeviceEvent(
          sender: aliceId,
          type: EventTypes.RoomKeyBundleUnstable,
          content: {'room_id': roomId, 'file': bundleInfo['file']},
          encryptedContent: {'sender_key': alice.identityKey},
          senderDeviceKeys:
              alice.userDeviceKeys[aliceId]!.deviceKeys.values.single,
        ),
      );
      final imported = await waitFor(
        () => bob.encryption!.keyManager.getInboundGroupSession(
          roomId,
          session.sessionId,
        ),
      );
      expect(imported.sharedBy, aliceId);
    });

    test('bundles without sender_device_keys are ignored', () async {
      await bob.encryption!.keyManager.handleToDeviceEvent(
        ToDeviceEvent(
          sender: '@mallory:fakeServer.notExisting',
          type: EventTypes.RoomKeyBundle,
          content: {
            'room_id': roomId,
            'file': {'url': 'mxc://fakeserver.notexisting/x'},
          },
          encryptedContent: {'sender_key': alice.identityKey},
        ),
      );
      expect(
        await bob.database.getRoomKeyBundle(
          roomId,
          '@mallory:fakeServer.notExisting',
        ),
        null,
      );
    });

    group('importPendingRoomKeyBundle', () {
      /// Stores a received bundle and an accepted invite, returns the id of
      /// the session in the bundle.
      Future<String> prepareBundle({
        String inviter = aliceId,
        String sender = aliceId,
        String? senderKey,
        String bundleRoomId = roomId,
        DateTime? acceptedAt,
      }) async {
        final session = vod.GroupSession();
        final key = roomKey(session, alice.identityKey)
          ..['room_id'] = bundleRoomId;
        await bob.database.storeRoomKeyBundle(
          roomId,
          sender,
          await uploadBundle({
            'room_keys': [key],
            'withheld': [],
          }, senderKey ?? alice.identityKey),
        );
        await bob.database.storePendingRoomKeyBundle(roomId, {
          'inviter': inviter,
          'invite_accepted_at':
              (acceptedAt ?? DateTime.now()).millisecondsSinceEpoch,
        });
        return session.sessionId;
      }

      Future<String> importBundle({
        String inviter = aliceId,
        String sender = aliceId,
        String? senderKey,
        String bundleRoomId = roomId,
        DateTime? acceptedAt,
      }) async {
        final sessionId = await prepareBundle(
          inviter: inviter,
          sender: sender,
          senderKey: senderKey,
          bundleRoomId: bundleRoomId,
          acceptedAt: acceptedAt,
        );
        await bob.encryption!.keyManager.importPendingRoomKeyBundles();
        return sessionId;
      }

      SessionKey? getSession(String sessionId) =>
          bob.encryption!.keyManager.getInboundGroupSession(roomId, sessionId);

      tearDown(() async {
        await bob.database.removePendingRoomKeyBundle(roomId);
        await bob.database.removeRoomKeyBundle(roomId, aliceId);
      });

      test('imports the bundle of the inviter', () async {
        final sessionId = await importBundle();
        expect(getSession(sessionId)?.sharedBy, aliceId);
        expect(await bob.database.getPendingRoomKeyBundles(), isEmpty);
      });

      test('downloads a bundle only once for parallel imports', () async {
        final sessionId = await prepareBundle();
        FakeMatrixApi.currentApi = bobApi;
        FakeMatrixApi.calledEndpoints.clear();
        final keyManager = bob.encryption!.keyManager;
        await Future.wait([
          keyManager.importPendingRoomKeyBundle(roomId),
          keyManager.importPendingRoomKeyBundles(),
        ]);
        expect(
          FakeMatrixApi.calledEndpoints.keys
              .where((action) => action.contains('/download/'))
              .expand((action) => FakeMatrixApi.calledEndpoints[action]!),
          hasLength(1),
        );
        expect(getSession(sessionId)?.sharedBy, aliceId);
      });

      test('waits for the rooms to be loaded', () async {
        final sessionId = await prepareBundle();
        final roomsLoading = bob.roomsLoading;
        final loaded = Completer<void>();
        bob.roomsLoading = loaded.future;
        final room = bob.getRoomById(roomId)!;
        bob.rooms.remove(room);
        final import = bob.encryption!.keyManager.importPendingRoomKeyBundles();
        await Future.delayed(const Duration(milliseconds: 100));
        bob.rooms.add(room);
        loaded.complete();
        await import;
        bob.roomsLoading = roomsLoading;
        expect(getSession(sessionId)?.sharedBy, aliceId);
      });

      test('ignores keys for other rooms', () async {
        final sessionId = await importBundle(
          bundleRoomId: '!other:fakeServer.notExisting',
        );
        expect(getSession(sessionId), null);
        expect(
          bob.encryption!.keyManager.getInboundGroupSession(
            '!other:fakeServer.notExisting',
            sessionId,
          ),
          null,
        );
      });

      test('ignores bundles from others than the inviter', () async {
        const mallory = '@mallory:fakeServer.notExisting';
        final sessionId = await importBundle(sender: mallory);
        expect(getSession(sessionId), null);
        // Still waiting for the bundle of the inviter.
        expect((await bob.database.getPendingRoomKeyBundles()).keys, {roomId});
        await bob.database.removeRoomKeyBundle(roomId, mallory);
      });

      test('ignores bundles after a day', () async {
        final sessionId = await importBundle(
          acceptedAt: DateTime.now().subtract(Duration(days: 2)),
        );
        expect(getSession(sessionId), null);
        expect(await bob.database.getPendingRoomKeyBundles(), isEmpty);
      });

      test('ignores bundles from devices which are not cross-signed', () async {
        const otherTest = '@othertest:fakeServer.notExisting';
        await bob.updateUserDeviceKeys(additionalUsers: {otherTest});
        final sessionId = await importBundle(
          inviter: otherTest,
          sender: otherTest,
          senderKey: bob
              .userDeviceKeys[otherTest]!
              .deviceKeys['FOXDEVICE']!
              .curve25519Key,
        );
        expect(getSession(sessionId), null);
        expect(await bob.database.getPendingRoomKeyBundles(), isEmpty);
        expect(await bob.database.getRoomKeyBundle(roomId, otherTest), null);
      });

      test('gives up on expired bundles', () async {
        await prepareBundle();
        FakeMatrixApi.media.clear();
        await bob.encryption!.keyManager.importPendingRoomKeyBundle(roomId);
        expect(await bob.database.getPendingRoomKeyBundles(), isEmpty);
        expect(await bob.database.getRoomKeyBundle(roomId, aliceId), null);
      });
    });

    // Bob left again before we noticed that he was invited. In a limited sync
    // an invite or knock may hide a join and leave as well.
    for (final membership in ['leave', 'ban', 'invite', 'knock']) {
      test('the outbound session is rotated on $membership', () async {
        await alice.encryption!.encryptGroupMessagePayload(roomId, {
          'msgtype': MessageTypes.Text,
          'body': 'After the invite',
        });
        expect(
          alice.encryption!.keyManager.getOutboundGroupSession(roomId),
          isNotNull,
        );
        await syncState(
          alice,
          stateEvent(
            EventTypes.RoomMember,
            {'membership': membership},
            stateKey: bobId,
            sender: bobId,
          ),
        );
        expect(
          alice.encryption!.keyManager.getOutboundGroupSession(roomId),
          null,
        );
        expect(
          await alice.database.getOutboundGroupSession(roomId, aliceId),
          null,
        );
      });
    }

    test(
      'the outbound session is rotated if the invite fails after sharing the bundle',
      () async {
        FakeMatrixApi.currentApi = aliceApi;
        final keyManager = alice.encryption!.keyManager;
        await alice.encryption!.encryptGroupMessagePayload(roomId, {
          'msgtype': MessageTypes.Text,
          'body': 'Before the failed invite',
        });
        expect(keyManager.getOutboundGroupSession(roomId), isNotNull);
        FakeMatrixApi.calledEndpoints.clear();
        final invite = '/client/v3/rooms/${Uri.encodeComponent(roomId)}/invite';
        final original = aliceApi.api['POST']![invite];
        aliceApi.api['POST']![invite] = (_) => {
          'errcode': 'M_FORBIDDEN',
          'error': 'You are not allowed to invite',
        };
        try {
          await expectLater(
            alice.inviteUser(roomId, bobId),
            throwsA(
              isA<MatrixException>().having(
                (e) => e.errcode,
                'errcode',
                'M_FORBIDDEN',
              ),
            ),
          );
        } finally {
          aliceApi.api['POST']![invite] = original;
        }
        expect(
          called(
            (action) =>
                action.startsWith('/client/v3/sendToDevice/m.room.encrypted/'),
          ),
          true,
        );
        expect(keyManager.getOutboundGroupSession(roomId), null);
        expect(
          await alice.database.getOutboundGroupSession(roomId, aliceId),
          null,
        );
      },
    );

    test('the outbound session is kept if the invite succeeds', () async {
      FakeMatrixApi.currentApi = aliceApi;
      final keyManager = alice.encryption!.keyManager;
      await alice.encryption!.encryptGroupMessagePayload(roomId, {
        'msgtype': MessageTypes.Text,
        'body': 'Before the invite',
      });
      FakeMatrixApi.calledEndpoints.clear();
      await alice.inviteUser(roomId, bobId);
      expect(sharedKeyBundle(), true);
      expect(invited(), true);
      expect(keyManager.getOutboundGroupSession(roomId), isNotNull);
    });

    test('the outbound session is kept on a join', () async {
      await alice.encryption!.encryptGroupMessagePayload(roomId, {
        'msgtype': MessageTypes.Text,
        'body': 'Before a join',
      });
      await syncState(
        alice,
        stateEvent(
          EventTypes.RoomMember,
          {'membership': 'join'},
          stateKey: bobId,
          sender: bobId,
        ),
      );
      expect(
        alice.encryption!.keyManager.getOutboundGroupSession(roomId),
        isNotNull,
      );
    });
  });
}
