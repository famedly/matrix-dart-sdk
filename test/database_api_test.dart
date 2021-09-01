// @dart=2.9
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
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

import 'package:matrix/matrix.dart';
import 'package:test/test.dart';
import 'package:olm/olm.dart' as olm;

import 'fake_database.dart';

void main() {
  /// All Tests related to the ChatTime
  group('Hive Database Test', () {
    testDatabase(getHiveDatabase(null), 0);
  });
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

void testDatabase(Future<DatabaseApi> futureDatabase, int clientId) {
  DatabaseApi database;
  int toDeviceQueueIndex;
  test('Open', () async {
    database = await futureDatabase;
  });
  test('transaction', () async {
    print('Starting test...');
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

    // we can't use Zone.root.run inside of tests so we abuse timers instead
    Timer(Duration(milliseconds: 50), () async {
      await database.transaction(() async {
        expect(counter++, 6);
      });
    });
    await database.transaction(() async {
      expect(counter++, 4);
      await Future.delayed(Duration(milliseconds: 100));
      expect(counter++, 5);
    });
  });
  test('insertIntoToDeviceQueue', () async {
    toDeviceQueueIndex = await database.insertIntoToDeviceQueue(
      clientId,
      'm.test',
      'txnId',
      '{"foo":"bar"}',
    );
  });
  test('getToDeviceEventQueue', () async {
    final toDeviceQueue = await database.getToDeviceEventQueue(clientId);
    expect(toDeviceQueue.first.type, 'm.test');
  });
  test('deleteFromToDeviceQueue', () async {
    await database.deleteFromToDeviceQueue(clientId, toDeviceQueueIndex);
    final toDeviceQueue = await database.getToDeviceEventQueue(clientId);
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
    await database.storeRoomUpdate(
        clientId,
        RoomUpdate(
          id: '!testroom',
          highlight_count: 0,
          notification_count: 0,
          limitedTimeline: false,
          membership: Membership.join,
        ));
    final rooms = await database.getRoomList(Client('testclient'));
    expect(rooms.single.id, '!testroom');
  });
  test('getRoomList', () async {
    final list = await database.getRoomList(Client('testclient'));
    expect(list.single.id, '!testroom');
  });
  test('setRoomPrevBatch', () async {
    await database.setRoomPrevBatch('1234', clientId, '!testroom');
    final rooms = await database.getRoomList(Client('testclient'));
    expect(rooms.single.prev_batch, '1234');
  });
  test('forgetRoom', () async {
    await database.forgetRoom(clientId, '!testroom');
    final rooms = await database.getRoomList(Client('testclient'));
    expect(rooms.isEmpty, true);
  });
  test('getClient', () async {
    await database.getClient('name');
  });
  test('insertClient', () async {
    clientId = await database.insertClient(
      'name',
      'homeserverUrl',
      'token',
      'userId',
      'deviceId',
      'deviceName',
      'prevBatch',
      'olmAccount',
    );
    final client = await database.getClient('name');
    expect(client['token'], 'token');
  });
  test('updateClient', () async {
    await database.updateClient(
      'homeserverUrl',
      'token_different',
      'userId',
      'deviceId',
      'deviceName',
      'prevBatch',
      'olmAccount',
      clientId,
    );
    final client = await database.getClient('name');
    expect(client['token'], 'token_different');
  });
  test('updateClientKeys', () async {
    await database.updateClientKeys('olmAccount2', clientId);
    final client = await database.getClient('name');
    expect(client['olm_account'], 'olmAccount2');
  });
  test('storeSyncFilterId', () async {
    await database.storeSyncFilterId('1234', clientId);
    final client = await database.getClient('name');
    expect(client['sync_filter_id'], '1234');
  });
  test('getAccountData', () async {
    await database.getAccountData(clientId);
  });
  test('storeAccountData', () async {
    await database.storeAccountData(clientId, 'm.test', '{"foo":"bar"}');
    final events = await database.getAccountData(clientId);
    expect(events.values.single.type, 'm.test');

    await database.storeAccountData(clientId, 'm.abc+de', '{"foo":"bar"}');
    final events2 = await database.getAccountData(clientId);
    expect(events2.values.any((element) => element.type == 'm.abc+de'), true);
  });
  test('storeEventUpdate', () async {
    await database.storeEventUpdate(
      clientId,
      EventUpdate(
        roomID: '!testroom:example.com',
        type: EventUpdateType.timeline,
        sortOrder: DateTime.now().millisecondsSinceEpoch.toDouble(),
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
    );
  });
  test('getEventById', () async {
    final event = await database.getEventById(
        clientId, '\$event:example.com', Room(id: '!testroom:example.com'));
    expect(event.type, EventTypes.Message);
  });
  test('getEventList', () async {
    final events = await database.getEventList(
        clientId, Room(id: '!testroom:example.com'));
    expect(events.single.type, EventTypes.Message);
  });
  test('getUser', () async {
    final user = await database.getUser(
        clientId, '@bob:example.org', Room(id: '!testroom:example.com'));
    expect(user, null);
  });
  test('getUsers', () async {
    final users =
        await database.getUsers(clientId, Room(id: '!testroom:example.com'));
    expect(users.isEmpty, true);
  });
  test('removeEvent', () async {
    await database.removeEvent(
        clientId, '\$event:example.com', '!testroom:example.com');
    final event = await database.getEventById(
        clientId, '\$event:example.com', Room(id: '!testroom:example.com'));
    expect(event, null);
  });
  test('getAllInboundGroupSessions', () async {
    final result = await database.getAllInboundGroupSessions(clientId);
    expect(result.isEmpty, true);
  });
  test('getInboundGroupSession', () async {
    await database.getInboundGroupSession(
        clientId, '!testroom:example.com', 'sessionId');
  });
  test('getInboundGroupSessionsToUpload', () async {
    await database.getInboundGroupSessionsToUpload();
  });
  test('storeInboundGroupSession', () async {
    await database.storeInboundGroupSession(
      clientId,
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
      clientId,
      '!testroom:example.com',
      'sessionId',
    );
    expect(jsonDecode(session.content)['foo'], 'bar');
  });
  test('markInboundGroupSessionAsUploaded', () async {
    await database.markInboundGroupSessionAsUploaded(
        clientId, '!testroom:example.com', 'sessionId');
  });
  test('markInboundGroupSessionsAsNeedingUpload', () async {
    await database.markInboundGroupSessionsAsNeedingUpload(clientId);
  });
  test('updateInboundGroupSessionAllowedAtIndex', () async {
    await database.updateInboundGroupSessionAllowedAtIndex(
      '{}',
      clientId,
      '!testroom:example.com',
      'sessionId',
    );
  });
  test('updateInboundGroupSessionIndexes', () async {
    await database.updateInboundGroupSessionIndexes(
      '{}',
      clientId,
      '!testroom:example.com',
      'sessionId',
    );
  });
  test('getSSSSCache', () async {
    final cache = await database.getSSSSCache(clientId, 'type');
    expect(cache, null);
  });
  test('storeSSSSCache', () async {
    await database.storeSSSSCache(
        clientId, 'type', 'keyId', 'ciphertext', '{}');
    final cache = await database.getSSSSCache(clientId, 'type');
    expect(cache.type, 'type');
    expect(cache.keyId, 'keyId');
    expect(cache.ciphertext, 'ciphertext');
    expect(cache.content, '{}');
  });
  test('getOlmSessions', () async {
    final olm = await database.getOlmSessions(
      clientId,
      'identityKey',
      'userId',
    );
    expect(olm.isEmpty, true);
  });
  test('getOlmSessionsForDevices', () async {
    final olm = await database.getOlmSessionsForDevices(
      clientId,
      ['identityKeys'],
      'userId',
    );
    expect(olm.isEmpty, true);
  });
  test('storeOlmSession', () async {
    if (!(await olmEnabled())) return;
    await database.storeOlmSession(
      clientId,
      'identityKey',
      'sessionId',
      'pickle',
      0,
    );
    final olm = await database.getOlmSessions(
      clientId,
      'identityKey',
      'userId',
    );
    expect(olm.isNotEmpty, true);
  });
  test('getOutboundGroupSession', () async {
    final session = await database.getOutboundGroupSession(
      clientId,
      '!testroom:example.com',
      '@alice:example.com',
    );
    expect(session, null);
  });
  test('storeOutboundGroupSession', () async {
    if (!(await olmEnabled())) return;
    await database.storeOutboundGroupSession(
      clientId,
      '!testroom:example.com',
      'pickle',
      '{}',
      0,
      0,
    );
    final session = await database.getOutboundGroupSession(
      clientId,
      '!testroom:example.com',
      '@alice:example.com',
    );
    expect(session.devices.isEmpty, true);
  });
  test('getLastSentMessageUserDeviceKey', () async {
    final list = await database.getLastSentMessageUserDeviceKey(
      clientId,
      'userId',
      'deviceId',
    );
    expect(list.isEmpty, true);
  });
  test('getUnimportantRoomEventStatesForRoom', () async {
    final events = await database.getUnimportantRoomEventStatesForRoom(
      clientId,
      ['events'],
      Room(id: '!mep'),
    );
    expect(events.isEmpty, true);
  });
  test('getUserDeviceKeys', () async {
    await database.getUserDeviceKeys(Client('testclient'));
  });
  test('storeUserCrossSigningKey', () async {
    await database.storeUserCrossSigningKey(
      clientId,
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
      clientId,
      '@alice:example.com',
      'publicKey',
    );
  });
  test('setBlockedUserCrossSigningKey', () async {
    await database.setBlockedUserCrossSigningKey(
      true,
      clientId,
      '@alice:example.com',
      'publicKey',
    );
  });
  test('removeUserCrossSigningKey', () async {
    await database.removeUserCrossSigningKey(
      clientId,
      '@alice:example.com',
      'publicKey',
    );
  });
  test('storeUserDeviceKeysInfo', () async {
    await database.storeUserDeviceKeysInfo(
      clientId,
      '@alice:example.com',
      true,
    );
  });
  test('storeUserDeviceKey', () async {
    await database.storeUserDeviceKey(
      clientId,
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
      clientId,
      '@alice:example.com',
      'deviceId',
    );
  });
  test('setBlockedUserDeviceKey', () async {
    await database.setBlockedUserDeviceKey(
      true,
      clientId,
      '@alice:example.com',
      'deviceId',
    );
  });

  // Clearing up from here
  test('clearSSSSCache', () async {
    await database.clearSSSSCache(clientId);
  });
  test('clearCache', () async {
    await database.clearCache(clientId);
  });
  test('clear', () async {
    await database.clear(clientId);
  });
  test('Close', () async {
    await database.close();
  });
  return;
}
