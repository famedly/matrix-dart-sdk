/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020 Famedly GmbH
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

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:olm/olm.dart' as olm;
import 'package:test/test.dart';

import 'package:matrix/matrix.dart';
import 'fake_database.dart';

String createLargeString(String character, int desiredSize) {
  final buffer = StringBuffer();

  while (buffer.length < desiredSize) {
    buffer.write(character);
  }

  return buffer.toString();
}

void main() {
  final databaseBuilders = {
    'Matrix SDK Database': getMatrixSdkDatabase,
    'Hive Database': getHiveDatabase,
    'Hive Collections Database': getHiveCollectionsDatabase,
  };

  for (final databaseBuilder in databaseBuilders.entries) {
    group('Test ${databaseBuilder.key}', () {
      late DatabaseApi database;
      late int toDeviceQueueIndex;

      test('Setup', () async {
        database = await databaseBuilder.value(null);
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
      test('storeFile', () async {
        await database.storeFile(
            Uri.parse('mxc://test'), Uint8List.fromList([0]), 0);
        final file = await database.getFile(Uri.parse('mxc://test'));
        expect(file != null, database.supportsFileStoring);
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
        final client = Client('testclient');
        await database.storeRoomUpdate('!testroom', roomUpdate, client);
        final rooms = await database.getRoomList(client);
        expect(rooms.single.id, '!testroom');
      });
      test('getRoomList', () async {
        final room =
            await database.getSingleRoom(Client('testclient'), '!testroom');
        expect(room?.id, '!testroom');
      });
      test('getRoomList', () async {
        final list = await database.getRoomList(Client('testclient'));
        expect(list.single.id, '!testroom');
      });
      test('setRoomPrevBatch', () async {
        final client = Client('testclient');
        await database.setRoomPrevBatch('1234', '!testroom', client);
        final rooms = await database.getRoomList(client);
        expect(rooms.single.prev_batch, '1234');
      });
      test('forgetRoom', () async {
        await database.forgetRoom('!testroom');
        final rooms = await database.getRoomList(Client('testclient'));
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
        );
        final client = await database.getClient('name');
        expect(client?['token'], 'token_different');
      });
      test('updateClientKeys', () async {
        await database.updateClientKeys(
          'olmAccount2',
        );
        final client = await database.getClient('name');
        expect(client?['olm_account'], 'olmAccount2');
      });
      test('storeSyncFilterId', () async {
        await database.storeSyncFilterId(
          '1234',
        );
        final client = await database.getClient('name');
        expect(client?['sync_filter_id'], '1234');
      });
      test('getAccountData', () async {
        await database.getAccountData();
      });
      test('storeAccountData', () async {
        await database.storeAccountData('m.test', '{"foo":"bar"}');
        final events = await database.getAccountData();
        expect(events.values.single.type, 'm.test');

        await database.storeAccountData('m.abc+de', '{"foo":"bar"}');
        final events2 = await database.getAccountData();
        expect(
            events2.values.any((element) => element.type == 'm.abc+de'), true);
      });
      test('Database can write and read 5MB data', () async {
        final hugeDataObject = {'foo': createLargeString('A', 5 * 1024 * 1024)};

        await database.storeAccountData(
          'm.huge_data_test',
          jsonEncode(hugeDataObject),
        );

        final events = await database.getAccountData();

        expect(
          events.values.any((data) => data.type == 'm.huge_data_test'),
          true,
        );
      });
      test('storeEventUpdate', () async {
        await database.storeEventUpdate(
            EventUpdate(
              roomID: '!testroom:example.com',
              type: EventUpdateType.timeline,
              content: {
                'type': EventTypes.Message,
                'content': {
                  'body': '* edit 3',
                  'msgtype': 'm.text',
                  'm.new_content': {
                    'body': 'edit 3',
                    'msgtype': 'm.text',
                  },
                  'm.relates_to': {
                    'event_id': '\$source',
                    'rel_type': RelationshipTypes.edit,
                  },
                },
                'event_id': '\$event:example.com',
                'sender': '@bob:example.org',
              },
            ),
            Client('testclient'));
      });
      test('getEventById', () async {
        final event = await database.getEventById('\$event:example.com',
            Room(id: '!testroom:example.com', client: Client('testclient')));
        expect(event?.type, EventTypes.Message);
      });
      test('getEventList', () async {
        final events = await database.getEventList(
          Room(id: '!testroom:example.com', client: Client('testclient')),
        );
        expect(events.single.type, EventTypes.Message);
      });
      test('getUser', () async {
        final user = await database.getUser('@bob:example.org',
            Room(id: '!testroom:example.com', client: Client('testclient')));
        expect(user, null);
      });
      test('getUsers', () async {
        final users = await database.getUsers(
            Room(id: '!testroom:example.com', client: Client('testclient')));
        expect(users.isEmpty, true);
      });
      test('removeEvent', () async {
        await database.removeEvent(
            '\$event:example.com', '!testroom:example.com');
        final event = await database.getEventById('\$event:example.com',
            Room(id: '!testroom:example.com', client: Client('testclient')));
        expect(event, null);
      });
      test('getAllInboundGroupSessions', () async {
        final result = await database.getAllInboundGroupSessions();
        expect(result.isEmpty, true);
      });
      test('getInboundGroupSession', () async {
        await database.getInboundGroupSession(
            '!testroom:example.com', 'sessionId');
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
            '!testroom:example.com', 'sessionId');
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
        final olm = await database.getOlmSessions(
          'identityKey',
          'userId',
        );
        expect(olm.isEmpty, true);
      });
      test('getAllOlmSessions', () async {
        var sessions = await database.getAllOlmSessions();
        expect(sessions.isEmpty, true);
        await database.storeOlmSession(
          'identityKey',
          'sessionId',
          'pickle',
          0,
        );
        await database.storeOlmSession(
          'identityKey',
          'sessionId2',
          'pickle',
          0,
        );
        sessions = await database.getAllOlmSessions();
        expect(
          sessions,
          {
            'identityKey': {
              'sessionId': {
                'identity_key': 'identityKey',
                'pickle': 'pickle',
                'session_id': 'sessionId',
                'last_received': 0
              },
              'sessionId2': {
                'identity_key': 'identityKey',
                'pickle': 'pickle',
                'session_id': 'sessionId2',
                'last_received': 0
              }
            }
          },
        );
      });
      test('getOlmSessionsForDevices', () async {
        final olm = await database.getOlmSessionsForDevices(
          ['identityKeys'],
          'userId',
        );
        expect(olm.isEmpty, true);
      });
      test('storeOlmSession', () async {
        if (!(await olmEnabled())) return;
        await database.storeOlmSession(
          'identityKey',
          'sessionId',
          'pickle',
          0,
        );
        final olm = await database.getOlmSessions(
          'identityKey',
          'userId',
        );
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
        if (!(await olmEnabled())) return;
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
          Room(id: '!mep', client: Client('testclient')),
        );
        expect(events.isEmpty, true);
      });
      test('getUserDeviceKeys', () async {
        await database.getUserDeviceKeys(Client('testclient'));
      });
      test('storeUserCrossSigningKey', () async {
        await database.storeUserCrossSigningKey(
          '@alice:example.com',
          'publicKey',
          '{}',
          false,
          false,
        );
      });
      test('setVerifiedUserCrossSigningKey', () async {
        await database.setVerifiedUserCrossSigningKey(
          true,
          '@alice:example.com',
          'publicKey',
        );
      });
      test('setBlockedUserCrossSigningKey', () async {
        await database.setBlockedUserCrossSigningKey(
          true,
          '@alice:example.com',
          'publicKey',
        );
      });
      test('removeUserCrossSigningKey', () async {
        await database.removeUserCrossSigningKey(
          '@alice:example.com',
          'publicKey',
        );
      });
      test('storeUserDeviceKeysInfo', () async {
        await database.storeUserDeviceKeysInfo(
          '@alice:example.com',
          true,
        );
      });
      test('storeUserDeviceKey', () async {
        await database.storeUserDeviceKey(
          '@alice:example.com',
          'deviceId',
          '{}',
          false,
          false,
          0,
        );
      });
      test('setVerifiedUserDeviceKey', () async {
        await database.setVerifiedUserDeviceKey(
          true,
          '@alice:example.com',
          'deviceId',
        );
      });
      test('setBlockedUserDeviceKey', () async {
        await database.setBlockedUserDeviceKey(
          true,
          '@alice:example.com',
          'deviceId',
        );
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
        await database.storePresence(
          userId,
          presence,
        );
        final storedPresence = await database.getPresence(userId);
        expect(
          presence.toJson(),
          storedPresence?.toJson(),
        );
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
        final database = await getMatrixSdkDatabase(null);
        await database.storeAccountData(
          'm.test.data',
          jsonEncode({'foo': 'bar'}),
        );
        await database.delete();

        // Check if previously stored data is gone:
        final reopenedDatabase = await getMatrixSdkDatabase(null);
        final dump = await reopenedDatabase.getAccountData();
        expect(dump.isEmpty, true);
      });
    });
  }
}

Future<bool> olmEnabled() async {
  var olmEnabled = true;
  try {
    await olm.init();
    olm.get_library_version();
  } catch (e) {
    olmEnabled = false;
  }
  return olmEnabled;
}
