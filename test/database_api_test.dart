// SPDX-FileCopyrightText: 2019, 2020 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:matrix/matrix.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'fake_database.dart';

Future<void>? _vodInit;

/// vodozemac may only be initialised once per isolate.
Future<void> ensureVodozemac() => _vodInit ??= vod.init(
  wasmPath: './pkg/',
  libraryPath: './rust/target/debug/',
);

const testUserId = '@test:fakeServer.notExisting';
const testDeviceId = 'OTHERDEVICE';
const testPublicKey = 'F9ypFzgbISXCzxQhhSnXMkc1vq12Luna3Nw5rqViOJY';

/// A genuinely self-signed device key, so that `DeviceKeys.isValid` passes and
/// the read path does not silently discard it.
final validDeviceKey = <String, dynamic>{
  'user_id': testUserId,
  'device_id': testDeviceId,
  'algorithms': [
    AlgorithmTypes.olmV1Curve25519AesSha2,
    AlgorithmTypes.megolmV1AesSha2,
  ],
  'keys': {
    'curve25519:$testDeviceId': 'R96BA0qE1+QAWLp7E1jyWSTJ1VXMLpEdiM2SZHlKMXM',
    'ed25519:$testDeviceId': 'EQo9eYbSygIbOR+tVJziqAY1NI6Gga+JQOVIqJe4mr4',
  },
  'signatures': {
    testUserId: {
      'ed25519:$testDeviceId':
          '/rT6pVRypJWxGos1QcI7jHL9HwcA83nkHLHqMcRPeLSxXHh4oHWvC0/tl0Xg06ogyiGw4NuB7TpOISvJBdt7BA',
      'ed25519:$testPublicKey':
          'qnjiLl36h/1jlLvcAgt46Igaod2T9lOSnoSVkV0KC+c7vYIjG4QBzXpH+hycfufOT/y+a/kl52dUTLQWctMKCA',
    },
  },
};

final validCrossSigningKey = <String, dynamic>{
  'user_id': testUserId,
  'usage': ['master'],
  'keys': {'ed25519:$testPublicKey': testPublicKey},
  'signatures': <String, Object?>{},
};

String createLargeString(String character, int desiredSize) {
  final buffer = StringBuffer();

  while (buffer.length < desiredSize) {
    buffer.write(character);
  }

  return buffer.toString();
}

void main() {
  final databaseBuilders = {'Matrix SDK Database': getMatrixSdkDatabase};

  for (final databaseBuilder in databaseBuilders.entries) {
    group('Test ${databaseBuilder.key}', tags: 'olm', () {
      late DatabaseApi database;
      late int toDeviceQueueIndex;

      test('Setup', () async {
        // Device key fixtures are signature-checked on read, so vodozemac has
        // to be up before anything touches them.
        await ensureVodozemac();
        database = await databaseBuilder.value();
      });
      test('transaction', () async {
        var counter = 0;
        await database.transaction(() async {
          expect(counter++, 0);
          await database.transaction(() async {
            expect(counter++, 1);
            await Future.delayed(Duration(milliseconds: 50));
            expect(counter++, 2);
          });
          expect(counter++, 3);
        });
      });
      test('insertIntoToDeviceQueue', () async {
        toDeviceQueueIndex = await database.insertIntoToDeviceQueue(
          'm.test',
          'txnId',
          '{"foo":"bar"}',
        );
      });
      test('getToDeviceEventQueue', () async {
        final toDeviceQueue = await database.getToDeviceEventQueue();
        expect(toDeviceQueue.first.type, 'm.test');
      });
      test('deleteFromToDeviceQueue', () async {
        await database.deleteFromToDeviceQueue(toDeviceQueueIndex);
        final toDeviceQueue = await database.getToDeviceEventQueue();
        expect(toDeviceQueue.isEmpty, true);
      });
      test('storeFile and deleteFile', () async {
        await database.storeFile(
          Uri.parse('mxc://test'),
          Uint8List.fromList([0]),
          0,
        );
        final file = await database.getFile(Uri.parse('mxc://test'));
        expect(file != null, database.supportsFileStoring);

        final result = await database.deleteFile(Uri.parse('mxc://test'));
        expect(result, database.supportsFileStoring);
        if (result) {
          final file = await database.getFile(Uri.parse('mxc://test'));
          expect(file, null);
        }
      });
      test('getFile', () async {
        await database.getFile(Uri.parse('mxc://test'));
      });
      test('deleteOldFiles', () async {
        await database.deleteOldFiles(1);
        final file = await database.getFile(Uri.parse('mxc://test'));
        expect(file == null, true);
      });
      test('storeRoomUpdate', () async {
        final roomUpdate = JoinedRoomUpdate.fromJson({
          'highlight_count': 0,
          'notification_count': 0,
          'limited_timeline': false,
          'membership': Membership.join,
        });
        final client = Client(
          'testclient',
          database: await getMatrixSdkDatabase(),
        );
        await database.storeRoomUpdate('!testroom', roomUpdate, null, client);
        final rooms = await database.getRoomList(client);
        expect(rooms.single.id, '!testroom');
      });
      test('getSingleRoom', () async {
        final room = await database.getSingleRoom(
          Client('testclient', database: await getMatrixSdkDatabase()),
          '!testroom',
        );
        expect(room?.id, '!testroom');
      });
      test('storeLatestReceiptState', () async {
        await database.storeLatestReceiptState(
          '!testroom',
          LatestReceiptState(
            global: LatestReceiptStateForTimeline(
              latestOwnReceipt: LatestReceiptStateData(
                '\$1234',
                DateTime.now().millisecondsSinceEpoch,
              ),
              ownPrivate: null,
              ownPublic: null,
              otherUsers: {},
            ),
          ),
        );
        final room = await database.getSingleRoom(
          Client('testclient', database: await getMatrixSdkDatabase()),
          '!testroom',
        );
        expect(room?.id, '!testroom');
        expect(room!.receiptState.global.latestOwnReceipt!.eventId, '\$1234');
        final rooms = await database.getRoomList(
          Client('testclient', database: await getMatrixSdkDatabase()),
        );
        expect(rooms.single.id, '!testroom');
        expect(
          rooms.single.receiptState.global.latestOwnReceipt!.eventId,
          '\$1234',
        );
      });
      test('getRoomList', () async {
        final list = await database.getRoomList(
          Client('testclient', database: await getMatrixSdkDatabase()),
        );
        expect(list.single.id, '!testroom');
      });
      test('setRoomPrevBatch', () async {
        final client = Client(
          'testclient',
          database: await getMatrixSdkDatabase(),
        );
        await database.setRoomPrevBatch('1234', '!testroom', client);
        final rooms = await database.getRoomList(client);
        expect(rooms.single.prev_batch, '1234');
      });
      test('forgetRoom', () async {
        await database.forgetRoom('!testroom');
        final rooms = await database.getRoomList(
          Client('testclient', database: await getMatrixSdkDatabase()),
        );
        expect(rooms.isEmpty, true);
      });
      test('getClient', () async {
        await database.getClient('name');
      });
      test('insertClient', () async {
        final now = DateTime.now();
        await database.insertClient(
          'name',
          'homeserverUrl',
          'token',
          now,
          'refresh_token',
          'userId',
          'deviceId',
          'deviceName',
          'prevBatch',
          'olmAccount',
          'abcd1234',
        );

        final client = await database.getClient('name');
        expect(client?['token'], 'token');
        expect(
          client?['token_expires_at'],
          now.millisecondsSinceEpoch.toString(),
        );
      });
      test('updateClient', () async {
        await database.updateClient(
          'homeserverUrl',
          'token_different',
          DateTime.now(),
          'refresh_token',
          'userId',
          'deviceId',
          'deviceName',
          'prevBatch',
          'olmAccount',
          'abcd1234',
        );
        final client = await database.getClient('name');
        expect(client?['token'], 'token_different');
      });
      test('updateClientKeys', () async {
        await database.updateClientKeys('olmAccount2');
        final client = await database.getClient('name');
        expect(client?['olm_account'], 'olmAccount2');
      });
      test('storeSyncFilterId', () async {
        await database.storeSyncFilterId('1234');
        final client = await database.getClient('name');
        expect(client?['sync_filter_id'], '1234');
      });
      test('getAccountData', () async {
        await database.getAccountData();
      });
      test('storeAccountData', () async {
        await database.storeAccountData('m.test', {'foo': 'bar'});
        final events = await database.getAccountData();
        expect(events.values.single.type, 'm.test');

        await database.storeAccountData('m.abc+de', {'foo': 'bar'});
        final events2 = await database.getAccountData();
        expect(
          events2.values.any((element) => element.type == 'm.abc+de'),
          true,
        );
      });
      test('Database can write and read 5MB data', () async {
        final hugeDataObject = {'foo': createLargeString('A', 5 * 1000 * 1000)};

        await database.storeAccountData('m.huge_data_test', hugeDataObject);

        final events = await database.getAccountData();

        expect(
          events.values.any((data) => data.type == 'm.huge_data_test'),
          true,
        );
      });
      test('storeEventUpdate', () async {
        await database.storeEventUpdate(
          '!testroom:example.com',
          MatrixEvent.fromJson({
            'type': EventTypes.Message,
            'content': {
              'body': '* edit 3',
              'msgtype': 'm.text',
              'm.new_content': {'body': 'edit 3', 'msgtype': 'm.text'},
              'm.relates_to': {
                'event_id': '\$source',
                'rel_type': RelationshipTypes.edit,
              },
            },
            'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
            'event_id': '\$event:example.com',
            'sender': '@bob:example.org',
          }),
          EventUpdateType.timeline,
          Client('testclient', database: await getMatrixSdkDatabase()),
        );
      });
      test('storeEventUpdate (state)', () async {
        const roomid = '!testrooma:example.com';
        final client = Client(
          'testclient',
          database: await getMatrixSdkDatabase(),
        );

        await database.storeRoomUpdate(
          roomid,
          JoinedRoomUpdate(),
          null,
          client,
        );

        await database.storeRoomAccountData(
          roomid,
          BasicEvent(content: {'foo': 'bar'}, type: 'm.test'),
        );

        await database.storeEventUpdate(
          roomid,
          MatrixEvent.fromJson({
            'type': EventTypes.RoomName,
            'content': {'name': 'start'},
            'event_id': '\$eventstart:example.com',
            'sender': '@bob:example.org',
            'state_key': '',
            'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
          }),
          EventUpdateType.timeline,
          client,
        );

        var room = await database.getSingleRoom(client, roomid);

        expect(room, isNotNull);

        expect(room?.name, 'start');

        expect(room?.roomAccountData['m.test']?.content, {'foo': 'bar'});

        await database.storeEventUpdate(
          roomid,
          MatrixEvent.fromJson({
            'type': EventTypes.RoomName,
            'content': {'name': 'update'},
            'event_id': '\$eventupdate:example.com',
            'sender': '@bob:example.org',
            'state_key': '',
            'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
          }),
          EventUpdateType.timeline,
          client,
        );

        room = await database.getSingleRoom(client, roomid);

        expect(room?.name, 'update');

        await database.storeEventUpdate(
          roomid,
          MatrixEvent.fromJson({
            'type': EventTypes.RoomName,
            'content': {'name': 'update2'},
            'event_id': '\$eventupdate2:example.com',
            'sender': '@bob:example.org',
            'state_key': '',
            'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
          }),
          EventUpdateType.state,
          client,
        );

        room = await database.getSingleRoom(client, roomid);

        expect(room?.name, 'update2');

        await database.storeEventUpdate(
          roomid,
          StrippedStateEvent.fromJson({
            'type': EventTypes.RoomName,
            'content': {'name': 'update3'},
            'event_id': '\$eventupdate3:example.com',
            'sender': '@bob:example.org',
            'state_key': '',
          }),
          EventUpdateType.inviteState,
          client,
        );

        room = await database.getSingleRoom(client, roomid);

        expect(room?.name, 'update3');

        await database.storeEventUpdate(
          roomid,
          MatrixEvent.fromJson({
            'type': EventTypes.RoomName,
            'content': {'name': 'notupdate'},
            'event_id': '\$eventnotupdate:example.com',
            'sender': '@bob:example.org',
            'state_key': '',
            'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
          }),
          EventUpdateType.history,
          client,
        );

        room = await database.getSingleRoom(client, roomid);

        expect(room?.name, 'update3');
      });
      test('getEventById', () async {
        final event = await database.getEventById(
          '\$event:example.com',
          Room(
            id: '!testroom:example.com',
            client: Client(
              'testclient',
              database: await getMatrixSdkDatabase(),
            ),
          ),
        );
        expect(event?.type, EventTypes.Message);
      });
      test('getEventList', () async {
        final events = await database.getEventList(
          Room(
            id: '!testroom:example.com',
            client: Client(
              'testclient',
              database: await getMatrixSdkDatabase(),
            ),
          ),
        );
        expect(events.single.type, EventTypes.Message);
      });
      test('getUser', () async {
        final user = await database.getUser(
          '@bob:example.org',
          Room(
            id: '!testroom:example.com',
            client: Client(
              'testclient',
              database: await getMatrixSdkDatabase(),
            ),
          ),
        );
        expect(user, null);
      });
      test('getUsers', () async {
        final users = await database.getUsers(
          Room(
            id: '!testroom:example.com',
            client: Client(
              'testclient',
              database: await getMatrixSdkDatabase(),
            ),
          ),
        );
        expect(users.isEmpty, true);
      });
      test('removeEvent', () async {
        await database.removeEvent(
          '\$event:example.com',
          '!testroom:example.com',
        );
        final event = await database.getEventById(
          '\$event:example.com',
          Room(
            id: '!testroom:example.com',
            client: Client(
              'testclient',
              database: await getMatrixSdkDatabase(),
            ),
          ),
        );
        expect(event, null);
      });
      test('getAllInboundGroupSessions', () async {
        final result = await database.getAllInboundGroupSessions();
        expect(result.isEmpty, true);
      });
      test('getInboundGroupSession', () async {
        await database.getInboundGroupSession(
          '!testroom:example.com',
          'sessionId',
        );
      });
      test('getInboundGroupSessionsToUpload', () async {
        await database.getInboundGroupSessionsToUpload();
      });
      test('storeInboundGroupSession', () async {
        await database.storeInboundGroupSession(
          '!testroom:example.com',
          'sessionId',
          'pickle',
          '{"foo":"bar"}',
          '{}',
          '{}',
          'senderKey',
          '{}',
        );
        final session = await database.getInboundGroupSession(
          '!testroom:example.com',
          'sessionId',
        );
        expect(jsonDecode(session!.content)['foo'], 'bar');
      });
      test('markInboundGroupSessionAsUploaded', () async {
        await database.markInboundGroupSessionAsUploaded(
          '!testroom:example.com',
          'sessionId',
        );
      });
      test('markInboundGroupSessionsAsNeedingUpload', () async {
        await database.markInboundGroupSessionsAsNeedingUpload();
      });
      test('updateInboundGroupSessionAllowedAtIndex', () async {
        await database.updateInboundGroupSessionAllowedAtIndex(
          '{}',
          '!testroom:example.com',
          'sessionId',
        );
      });
      test('updateInboundGroupSessionIndexes', () async {
        await database.updateInboundGroupSessionIndexes(
          '{}',
          '!testroom:example.com',
          'sessionId',
        );
      });
      test('getSSSSCache', () async {
        final cache = await database.getSSSSCache('type');
        expect(cache, null);
      });
      test('storeSSSSCache', () async {
        await database.storeSSSSCache('type', 'keyId', 'ciphertext', '{}');
        final cache = (await database.getSSSSCache('type'))!;
        expect(cache.type, 'type');
        expect(cache.keyId, 'keyId');
        expect(cache.ciphertext, 'ciphertext');
        expect(cache.content, '{}');
      });
      test('getOlmSessions', () async {
        final olm = await database.getOlmSessions('identityKey', 'userId');
        expect(olm.isEmpty, true);
      });
      test('getAllOlmSessions', () async {
        var sessions = await database.getAllOlmSessions();
        expect(sessions.isEmpty, true);
        await database.storeOlmSession('identityKey', 'sessionId', 'pickle', 0);
        await database.storeOlmSession(
          'identityKey',
          'sessionId2',
          'pickle',
          0,
        );
        sessions = await database.getAllOlmSessions();
        expect(sessions, {
          'identityKey': {
            'sessionId': {
              'identity_key': 'identityKey',
              'pickle': 'pickle',
              'session_id': 'sessionId',
              'last_received': 0,
            },
            'sessionId2': {
              'identity_key': 'identityKey',
              'pickle': 'pickle',
              'session_id': 'sessionId2',
              'last_received': 0,
            },
          },
        });
      });
      test('getOlmSessionsForDevices', () async {
        final olm = await database.getOlmSessionsForDevices([
          'identityKeys',
        ], 'userId');
        expect(olm.isEmpty, true);
      });
      test('storeOlmSession', () async {
        await database.storeOlmSession('identityKey', 'sessionId', 'pickle', 0);
        final olm = await database.getOlmSessions('identityKey', 'userId');
        expect(olm.isNotEmpty, true);
      });
      test('getOutboundGroupSession', () async {
        final session = await database.getOutboundGroupSession(
          '!testroom:example.com',
          '@alice:example.com',
        );
        expect(session, null);
      });
      test('storeOutboundGroupSession', () async {
        await database.storeOutboundGroupSession(
          '!testroom:example.com',
          'pickle',
          '{}',
          0,
        );
        final session = await database.getOutboundGroupSession(
          '!testroom:example.com',
          '@alice:example.com',
        );
        expect(session?.devices.isEmpty, true);
      });
      test('getLastSentMessageUserDeviceKey', () async {
        final list = await database.getLastSentMessageUserDeviceKey(
          'userId',
          'deviceId',
        );
        expect(list.isEmpty, true);
      });
      test('getUnimportantRoomEventStatesForRoom', () async {
        final events = await database.getUnimportantRoomEventStatesForRoom(
          ['events'],
          Room(
            id: '!mep',
            client: Client(
              'testclient',
              database: await getMatrixSdkDatabase(),
            ),
          ),
        );
        expect(events.isEmpty, true);
      });
      test('getUserDeviceKeys', () async {
        await database.getUserDeviceKeys(
          Client('testclient', database: await getMatrixSdkDatabase()),
        );
      });
      test('customCacheObject', () async {
        var cache = await database.getCustomCacheObject('test');
        expect(cache, null);
        await database.cacheCustomObject('test', {'foo': 'bar', 'num': 42});
        cache = await database.getCustomCacheObject('test');
        expect(cache!.content, {'foo': 'bar', 'num': 42});

        await database.clearCache();
        cache = await database.getCustomCacheObject('test');
        expect(cache, null);
      });
      test('storeDeviceKeysList keeps trust state', () async {
        final client = Client('testclient', database: database);
        final device = DeviceKeys.fromJson(validDeviceKey, client)
          ..setDirectVerified(true);
        final crossKey = CrossSigningKey.fromJson(validCrossSigningKey, client);
        await crossKey.trustOnFirstUse(
          since: DateTime.fromMillisecondsSinceEpoch(1600000000000),
          updateInDatabase: false,
        );

        await database.storeDeviceKeysList(
          testUserId,
          DeviceKeysList(testUserId, client)
            ..outdated = false
            ..deviceKeys = {testDeviceId: device}
            ..crossSigningKeys = {testPublicKey: crossKey},
        );

        final stored = (await database.getUserDeviceKeys(client))[testUserId];
        expect(stored?.outdated, false);
        expect(stored?.deviceKeys.keys, [testDeviceId]);
        expect(stored?.deviceKeys[testDeviceId]?.directVerified, true);
        expect(stored?.crossSigningKeys.keys, [testPublicKey]);
        expect(
          stored?.crossSigningKeys[testPublicKey]?.trustOnFirstUseSince,
          DateTime.fromMillisecondsSinceEpoch(1600000000000),
        );
      });
      test('storeDeviceKeyTrust updates a single key', () async {
        final client = Client('testclient', database: database);
        await database.storeDeviceKeyTrust(
          testUserId,
          testDeviceId,
          verified: false,
          blocked: true,
        );
        final stored = (await database.getUserDeviceKeys(client))[testUserId];
        expect(stored?.deviceKeys[testDeviceId]?.directVerified, false);
        expect(stored?.deviceKeys[testDeviceId]?.directBlocked, true);
      });
      test('setLastActiveUserDeviceKey is joined back on read', () async {
        final client = Client('testclient', database: database);
        await database.setLastActiveUserDeviceKey(
          1234567890,
          testUserId,
          testDeviceId,
        );
        final stored = (await database.getUserDeviceKeys(client))[testUserId];
        expect(
          stored?.deviceKeys[testDeviceId]?.lastActive,
          DateTime.fromMillisecondsSinceEpoch(1234567890),
        );
      });
      test('lastSentMessageUserDeviceKey', () async {
        expect(
          await database.getLastSentMessageUserDeviceKey(
            testUserId,
            testDeviceId,
          ),
          <String>[],
        );
        await database.setLastSentMessageUserDeviceKey(
          '{"type":"m.dummy"}',
          testUserId,
          testDeviceId,
        );
        expect(
          await database.getLastSentMessageUserDeviceKey(
            testUserId,
            testDeviceId,
          ),
          ['{"type":"m.dummy"}'],
        );
      });
      test('storeUserDeviceKeysInfo', () async {
        final client = Client('testclient', database: database);
        await database.storeUserDeviceKeysInfo(testUserId, true);
        final stored = (await database.getUserDeviceKeys(client))[testUserId];
        expect(stored?.outdated, true);
        // Flipping the flag must not disturb the stored key material.
        expect(stored?.deviceKeys.keys, [testDeviceId]);
      });
      test('getStorePresences', () async {
        const userId = '@alice:example.com';
        final presence = CachedPresence(
          PresenceType.online,
          100,
          'test message',
          true,
          '@alice:example.com',
        );
        await database.storePresence(userId, presence);
        final storedPresence = await database.getPresence(userId);
        expect(presence.toJson(), storedPresence?.toJson());
      });
      test('storeUserProfile', () async {
        final profile1 = await database.getUserProfile('@alice:example.com');
        expect(profile1, null);

        await database.storeUserProfile(
          '@alice:example.com',
          CachedProfileInformation.fromProfile(
            ProfileInformation(
              avatarUrl: Uri.parse('mxc://test'),
              displayname: 'Alice M',
            ),
            outdated: false,
            updated: DateTime.now(),
          ),
        );
        final profile2 = await database.getUserProfile('@alice:example.com');
        expect(profile2?.displayname, 'Alice M');
        expect(profile2?.outdated, false);
        await database.markUserProfileAsOutdated('@alice:example.com');

        final profile3 = await database.getUserProfile('@alice:example.com');
        expect(profile3?.displayname, 'Alice M');
        expect(profile3?.outdated, true);
      });

      // Clearing up from here
      test('clearSSSSCache', () async {
        await database.clearSSSSCache();
      });
      test('clearCache', () async {
        await database.clearCache();
      });
      test('clear', () async {
        await database.clear();
      });
      test('Close', () async {
        await database.close();
      });
      test('Delete', () async {
        final database = await getMatrixSdkDatabase();
        await database.storeAccountData('m.test.data', {'foo': 'bar'});
        await database.delete();

        // Check if previously stored data is gone:
        final reopenedDatabase = await getMatrixSdkDatabase();
        final dump = await reopenedDatabase.getAccountData();
        expect(dump.isEmpty, true);
      });
    });
  }

  // Needs vodozemac, because the assertions go through the real read path and
  // device keys are signature-checked there.
  group('Database migrations', tags: 'olm', () {
    const legacyDeviceKeysBox = 'box_user_device_keys';
    const legacyCrossSigningBox = 'box_cross_signing_keys';
    const legacyOutdatedBox = 'box_user_device_keys_outdated';

    /// Builds a v11 database holding one verified device key and one cross
    /// signing key carrying a TOFU timestamp.
    Future<Database> buildVersion11Database() async {
      final sqliteDb = await databaseFactoryFfi.openDatabase(
        ':memory:',
        options: OpenDatabaseOptions(singleInstance: false),
      );
      for (final name in {
        'box_client',
        legacyDeviceKeysBox,
        legacyCrossSigningBox,
        legacyOutdatedBox,
      }) {
        sqliteDb.execute(
          'CREATE TABLE IF NOT EXISTS $name (k TEXT PRIMARY KEY NOT NULL, v TEXT)',
        );
      }
      await sqliteDb.insert('box_client', {'k': 'version', 'v': '11'});
      await sqliteDb.insert(legacyDeviceKeysBox, {
        'k': TupleKey(testUserId, testDeviceId).toString(),
        'v': jsonEncode({
          'user_id': testUserId,
          'device_id': testDeviceId,
          'content': jsonEncode(validDeviceKey),
          'verified': true,
          'blocked': false,
          'last_active': 1234567890,
          'last_sent_message': '{"type":"m.dummy","content":{}}',
        }),
      });
      await sqliteDb.insert(legacyCrossSigningBox, {
        'k': TupleKey(testUserId, testPublicKey).toString(),
        'v': jsonEncode({
          'user_id': testUserId,
          'public_key': testPublicKey,
          'content': jsonEncode(validCrossSigningKey),
          'verified': true,
          'blocked': false,
          'tofu': 1600000000000,
        }),
      });
      await sqliteDb.insert(legacyOutdatedBox, {'k': testUserId, 'v': 'false'});
      return sqliteDb;
    }

    Future<MatrixSdkDatabase> openOn(Database sqliteDb) =>
        MatrixSdkDatabase.init(
          'unit_test.${DateTime.now().microsecondsSinceEpoch}',
          database: sqliteDb,
          sqfliteFactory: databaseFactoryFfi,
        );

    test('v11 keys keep their trust state', () async {
      await ensureVodozemac();
      final sqliteDb = await buildVersion11Database();
      final database = await openOn(sqliteDb);

      final keys = await database.getUserDeviceKeys(
        Client('testclient', database: database),
      );
      final list = keys[testUserId];

      expect(list?.userId, testUserId);
      expect(list?.outdated, false);

      final device = list?.deviceKeys[testDeviceId];
      expect(device, isNotNull, reason: 'the device key must survive');
      expect(device?.directVerified, true);
      expect(device?.directBlocked, false);
      expect(
        device?.lastActive,
        DateTime.fromMillisecondsSinceEpoch(1234567890),
      );

      final crossKey = list?.crossSigningKeys[testPublicKey];
      expect(crossKey, isNotNull);
      expect(crossKey?.usage, ['master']);
      expect(crossKey?.directVerified, true);
      expect(
        crossKey?.trustOnFirstUseSince,
        DateTime.fromMillisecondsSinceEpoch(1600000000000),
      );

      expect(
        await database.getLastSentMessageUserDeviceKey(
          testUserId,
          testDeviceId,
        ),
        ['{"type":"m.dummy","content":{}}'],
      );

      await database.close();
    });

    test('legacy boxes survive so the copy can be retried', () async {
      await ensureVodozemac();
      final sqliteDb = await buildVersion11Database();
      final database = await openOn(sqliteDb);
      await database.getUserDeviceKeys(
        Client('testclient', database: database),
      );

      for (final box in {legacyDeviceKeysBox, legacyCrossSigningBox}) {
        expect(
          (await sqliteDb.query(box)).length,
          1,
          reason: '$box must not be cleared by the migration',
        );
      }
      await database.close();
    });

    test('migrating twice is a no-op', () async {
      await ensureVodozemac();
      final sqliteDb = await buildVersion11Database();
      final database = await openOn(sqliteDb);
      final client = Client('testclient', database: database);

      await database.getUserDeviceKeys(client);
      // A later verification must not be undone by a second migration pass.
      await database.storeDeviceKeyTrust(
        testUserId,
        testDeviceId,
        verified: false,
        blocked: true,
      );

      final keys = await database.getUserDeviceKeys(client);
      expect(keys[testUserId]?.deviceKeys[testDeviceId]?.directVerified, false);
      expect(keys[testUserId]?.deviceKeys[testDeviceId]?.directBlocked, true);

      await database.close();
    });
  });
}
