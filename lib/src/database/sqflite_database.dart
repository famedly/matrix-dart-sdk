/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2021 Famedly GmbH
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
import 'dart:io';
import 'dart:typed_data';

import 'package:sqflite_common/sqflite.dart';

import 'package:matrix/encryption/utils/olm_session.dart';
import 'package:matrix/encryption/utils/outbound_group_session.dart';
import 'package:matrix/encryption/utils/ssss_cache.dart';
import 'package:matrix/encryption/utils/stored_inbound_group_session.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/queued_to_device_event.dart';
import 'package:matrix/src/utils/run_benchmarked.dart';

class SqfliteDatabase extends DatabaseApi {
  final Database database;

  Transaction? _currentTransaction;

  final Duration? deleteFilesAfterDuration;

  DatabaseExecutor get _executor => _currentTransaction ?? database;

  @override
  bool get supportsFileStoring => fileStoragePath != null;
  @override
  final int maxFileSize;
  final Directory? fileStoragePath;

  SqfliteDatabase(
    this.database, {
    required this.fileStoragePath,
    required this.maxFileSize,
    this.deleteFilesAfterDuration,
  });

  static Future<SqfliteDatabase> databaseBuilder(
    String path, {
    Directory? fileStoragePath,
    int maxFileSize = 1 * 1024 * 1024,
    Duration? deleteFilesAfterDuration,
  }) async =>
      SqfliteDatabase(
        await openDatabase(
          path,
          version: 1,
          onCreate: DbTablesExtension.create,
        ),
        fileStoragePath: fileStoragePath,
        maxFileSize: maxFileSize,
        deleteFilesAfterDuration: deleteFilesAfterDuration,
      );

  @override
  Future<void> addSeenDeviceId(
          String userId, String deviceId, String publicKeys) =>
      _executor.insert(
        DbTables.seenDeviceIds.name,
        {
          'user_id': userId,
          'device_id': deviceId,
          'public_key': publicKeys,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future<void> addSeenPublicKey(String publicKey, String deviceId) =>
      _executor.insert(
        DbTables.seenDeviceKeys.name,
        {
          'public_key': publicKey,
          'device_id': deviceId,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future<void> clear() => transaction(() async {
        for (final table in DbTables.values) {
          await _executor.delete(table.name);
        }
      });

  @override
  Future<void> clearCache() async {
    final batch = _executor.batch();
    const cacheTables = [
      DbTables.rooms,
      DbTables.accountData,
      DbTables.stateEvents,
      DbTables.timelineEvents,
      DbTables.outboundGroupSessions,
    ];
    for (final table in cacheTables) {
      batch.delete(table.name);
    }
    batch.delete(
      DbTables.client.name,
      where: 'key = ?',
      whereArgs: ['prev_batch'],
    );
    await batch.commit(noResult: true);
  }

  @override
  Future clearSSSSCache() => _executor.delete(DbTables.ssssCache.name);

  @override
  Future<void> close() => database.close();

  @override
  Future deleteFromToDeviceQueue(int id) => _executor.delete(
        DbTables.toDeviceQueue.name,
        where: 'id=?',
        whereArgs: [id],
      );

  @override
  Future<void> deleteOldFiles(int savedAt) async {
    final dir = fileStoragePath;
    final deleteFilesAfterDuration = this.deleteFilesAfterDuration;
    if (!supportsFileStoring ||
        dir == null ||
        deleteFilesAfterDuration == null) {
      return;
    }
    final entities = await dir.list().toList();
    for (final file in entities) {
      final stat = await file.stat();
      if (DateTime.now().difference(stat.modified) > deleteFilesAfterDuration) {
        Logs().v('Delete old file', file.path);
        await file.delete();
      }
    }
  }

  @override
  Future<String?> deviceIdSeen(userId, deviceId) => _executor.query(
        DbTables.seenDeviceIds.name,
        where: 'user_id = ? AND device_id = ?',
        whereArgs: [userId, deviceId],
      ).then(
          (rows) => rows.isEmpty ? null : rows.first['public_key'] as String);

  @override
  Future<String> exportDump() {
    // TODO: implement exportDump
    throw UnimplementedError();
  }

  @override
  Future<void> forgetRoom(String roomId) async {
    final batch = _executor.batch();
    batch.delete(
      DbTables.timelineEvents.name,
      where: 'room_id = ?',
      whereArgs: [roomId],
    );
    batch.delete(
      DbTables.stateEvents.name,
      where: 'room_id = ?',
      whereArgs: [roomId],
    );
    batch.delete(
      DbTables.roomAccountData.name,
      where: 'room_id = ?',
      whereArgs: [roomId],
    );
    batch.delete(
      DbTables.rooms.name,
      where: 'id = ?',
      whereArgs: [roomId],
    );
    await batch.commit(noResult: true);
  }

  @override
  Future<Map<String, BasicEvent>> getAccountData() =>
      runBenchmarked<Map<String, BasicEvent>>(
        'Get all account data from store',
        () => _executor.query(DbTables.accountData.name).then(
              (rows) => Map.fromEntries(
                rows.map(
                  (row) {
                    final accountData = BasicEvent(
                      type: row['type'] as String,
                      content: jsonDecode(row['content'] as String),
                    );
                    return MapEntry(accountData.type, accountData);
                  },
                ),
              ),
            ),
      );

  @override
  Future<List<StoredInboundGroupSession>> getAllInboundGroupSessions() =>
      _executor.query(DbTables.inboundGroupSessions.name).then((rows) =>
          rows.map((row) => StoredInboundGroupSession.fromJson(row)).toList());

  @override
  Future<Map<String, Map>> getAllOlmSessions() => _executor
          .query(
        DbTables.olmSessions.name,
      )
          .then((rows) {
        final map = <String, Map>{};
        for (final row in rows) {
          map[row['identity_key'] as String] ??= {};
          map[row['identity_key'] as String]![row['session_id'] as String] =
              row;
        }
        return map;
      });

  @override
  Future<Map<String, dynamic>?> getClient(String name) async {
    final rows = await _executor.query(DbTables.client.name);
    if (rows.isEmpty) return null;
    return Map.fromEntries(
      rows.map(
        (row) => MapEntry(
          row['key'].toString(),
          row['value'].toString(),
        ),
      ),
    );
  }

  @override
  Future<Event?> getEventById(String eventId, Room room) => _executor
      .query(
        DbTables.timelineEvents.name,
        where: 'event_id = ?',
        whereArgs: [eventId],
        orderBy: 'sort_order',
      )
      .then((rows) =>
          rows.isEmpty ? null : EventAdapter.fromRow(rows.single, room));

  @override
  Future<List<String>> getEventIdList(Room room,
          {int start = 0, bool includeSending = false, int? limit}) =>
      _executor
          .query(
            DbTables.timelineEvents.name,
            columns: ['event_id'],
            where: 'room_id = ?',
            whereArgs: [room.id],
            limit: limit,
            offset: start == 0 ? null : start,
            orderBy: 'sort_order DESC',
          )
          .then(
              (rows) => rows.map((row) => row['event_id'] as String).toList());

  @override
  Future<List<Event>> getEventList(Room room,
          {int start = 0, bool onlySending = false, int? limit}) =>
      runBenchmarked<List<Event>>(
          'Get event list',
          () => _executor
              .query(
                DbTables.timelineEvents.name,
                where: 'room_id = ?',
                whereArgs: [room.id],
                limit: limit,
                offset: start == 0 ? null : start,
                orderBy: 'sort_order DESC',
              )
              .then((rows) =>
                  rows.map((row) => EventAdapter.fromRow(row, room)).toList()));

  @override
  Future<Uint8List?> getFile(Uri mxcUri) async {
    final fileStoragePath = this.fileStoragePath;
    if (!supportsFileStoring || fileStoragePath == null) return null;

    final file =
        File('${fileStoragePath.path}/${mxcUri.toString().split('/').last}');

    if (await file.exists()) return await file.readAsBytes();
    return null;
  }

  @override
  Future<StoredInboundGroupSession?> getInboundGroupSession(
          String roomId, String sessionId) =>
      _executor.query(
        DbTables.inboundGroupSessions.name,
        where: 'room_id = ? AND session_id = ?',
        whereArgs: [roomId, sessionId],
      ).then(
        (rows) => rows.isEmpty
            ? null
            : StoredInboundGroupSession.fromJson(rows.first),
      );

  @override
  Future<List<StoredInboundGroupSession>> getInboundGroupSessionsToUpload() =>
      _executor.query(
        DbTables.inboundGroupSessions.name,
        where: 'uploaded = ?',
        whereArgs: ['false'],
      ).then((rows) =>
          rows.map((row) => StoredInboundGroupSession.fromJson(row)).toList());

  @override
  Future<List<String>> getLastSentMessageUserDeviceKey(
          String userId, String deviceId) =>
      _executor
          .query(
            DbTables.userDeviceKeys.name,
            columns: ['last_sent_message'],
            where: 'user_id = ? AND device_id = ?',
            whereArgs: [userId, deviceId],
          )
          .then((rows) => rows.isEmpty
              ? <String>[]
              : <String>[rows.first['last_sent_message'] as String]);

  @override
  Future<List<OlmSession>> getOlmSessions(String identityKey, String userId) =>
      _executor.query(
        DbTables.olmSessions.name,
        where: 'identity_key = ?',
        whereArgs: [identityKey],
      ).then((rows) =>
          rows.map((row) => OlmSession.fromJson(row, userId)).toList());

  @override
  Future<List<OlmSession>> getOlmSessionsForDevices(
          List<String> identityKeys, String userId) =>
      _executor
          .query(
            DbTables.olmSessions.name,
            where:
                'identity_key IN (${identityKeys.map((_) => '?').join(', ')})',
            whereArgs: identityKeys,
          )
          .then((rows) =>
              rows.map((row) => OlmSession.fromJson(row, userId)).toList());

  @override
  Future<OutboundGroupSession?> getOutboundGroupSession(
          String roomId, String userId) =>
      _executor.query(DbTables.outboundGroupSessions.name,
          where: 'room_id = ?', whereArgs: [roomId]).then((rows) => rows
              .isEmpty
          ? null
          : OutboundGroupSession.fromJson(rows.first, userId));

  @override
  Future<List<Room>> getRoomList(Client client) =>
      runBenchmarked<List<Room>>('Get room list from store', () async {
        // Query raw data (without members yet)
        final rawRooms = await _executor.query(DbTables.rooms.name);

        final rawRoomAccountData =
            await _executor.query(DbTables.roomAccountData.name);

        final importantRoomStates = await _executor.query(
          DbTables.stateEvents.name,
          where:
              'type IN (${client.importantStateEvents.map((_) => '?').join(', ')})',
          whereArgs: client.importantStateEvents.toList(),
        );

        // Create rooms Map
        final rooms = Map<String, Room>.fromEntries(
          rawRooms.map(
            (rawRoom) => MapEntry(
              rawRoom['id'] as String,
              RoomAdapter.fromRow(rawRoom, client),
            ),
          ),
        );

        // Add room account data
        for (final rawData in rawRoomAccountData) {
          final data = BasicRoomEvent(
            type: rawData['type'] as String,
            roomId: rawData['room_id'] as String,
            content: jsonDecode(rawData['content'] as String),
          );
          rooms[data.roomId]?.roomAccountData[data.type] = data;
        }

        // Add important room states
        for (final rawData in importantRoomStates) {
          final roomId = rawData['room_id'] as String;
          rooms[roomId]
              ?.setState(EventAdapter.fromRow(rawData, rooms[roomId]!));
        }

        return rooms.values.toList();
      });

  @override
  Future<SSSSCache?> getSSSSCache(String type) => _executor.query(
        DbTables.ssssCache.name,
        where: 'type = ?',
        whereArgs: [type],
      ).then((rows) => rows.isEmpty ? null : SSSSCache.fromJson(rows.first));

  @override
  Future<Room?> getSingleRoom(Client client, String roomId,
      {bool loadImportantStates = true}) async {
    // Get raw room from database:
    final room = await _executor.query(
      DbTables.rooms.name,
      where: 'id = ?',
      whereArgs: [roomId],
    ).then(
      (rows) => rows.isEmpty ? null : RoomAdapter.fromRow(rows.first, client),
    );
    if (room == null) return null;

    // Get important states:
    if (loadImportantStates) {
      final states = await _executor
          .query(
            DbTables.stateEvents.name,
            where:
                'type IN (${client.importantStateEvents.map((_) => '?').join(', ')})',
            whereArgs: client.importantStateEvents.toList(),
          )
          .then((rows) => rows.map((row) => EventAdapter.fromRow(row, room)));
      states.forEach(room.setState);
    }

    return room;
  }

  @override
  Future<List<QueuedToDeviceEvent>> getToDeviceEventQueue() =>
      _executor.query(DbTables.toDeviceQueue.name).then((rows) =>
          rows.map((row) => QueuedToDeviceEvent.fromJson(row)).toList());

  @override
  Future<List<Event>> getUnimportantRoomEventStatesForRoom(
          List<String> events, Room room) =>
      _executor.query(
        DbTables.stateEvents.name,
        where:
            'room_id = ? AND type NOT IN (?, ${room.client.importantStateEvents.map((_) => '?').join(', ')})',
        whereArgs: [
          room.id,
          EventTypes.RoomMember,
          ...room.client.importantStateEvents
        ],
      ).then((rows) =>
          rows.map((row) => EventAdapter.fromRow(row, room)).toList());

  @override
  Future<User?> getUser(String userId, Room room) => _executor.query(
        DbTables.stateEvents.name,
        where: 'room_id = ? AND state_key = ? AND type = ?',
        whereArgs: [room.id, userId, EventTypes.RoomMember],
      ).then(
        (rows) =>
            rows.isEmpty ? null : EventAdapter.fromRow(rows.first, room).asUser,
      );

  @override
  Future<Map<String, DeviceKeysList>> getUserDeviceKeys(Client client) =>
      runBenchmarked<Map<String, DeviceKeysList>>(
          'Get all user device keys from store', () async {
        final userDeviceKeysInfo =
            await _executor.query(DbTables.userDeviceKeysInfo.name);
        final userDeviceKeys =
            await _executor.query(DbTables.userDeviceKeys.name);
        final userCrossSigningKeys =
            await _executor.query(DbTables.userCrossSigningKeys.name);

        final userDeviceKeysMap = <String, DeviceKeysList>{};

        for (final info in userDeviceKeysInfo) {
          final userId = info['user_id'] as String;
          userDeviceKeysMap[userId] = DeviceKeysList.fromDbJson(
            {
              'user_id': info['user_id'],
              'outdated': info['outdated'] == 'true',
            },
            userDeviceKeys.where((row) => row['user_id'] == userId).toList(),
            userCrossSigningKeys
                .where((row) => row['user_id'] == userId)
                .toList(),
            client,
          );
        }

        return userDeviceKeysMap;
      });

  @override
  Future<List<User>> getUsers(Room room) => _executor.query(
        DbTables.stateEvents.name,
        where: 'room_id = ? AND type = ?',
        whereArgs: [room.id, EventTypes.RoomMember],
      ).then(
        (rows) =>
            rows.map((row) => EventAdapter.fromRow(row, room).asUser).toList(),
      );

  @override
  Future<bool> importDump(String export) {
    // TODO: implement importDump
    throw UnimplementedError();
  }

  @override
  Future insertClient(
          String name,
          String homeserverUrl,
          String token,
          String userId,
          String? deviceId,
          String? deviceName,
          String? prevBatch,
          String? olmAccount) =>
      transaction(() async {
        final batch = _executor.batch();
        batch.insert(
          DbTables.client.name,
          {'key': 'name', 'value': name},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        batch.insert(
          DbTables.client.name,
          {'key': 'homeserver_url', 'value': homeserverUrl},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        batch.insert(
          DbTables.client.name,
          {'key': 'token', 'value': token},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        batch.insert(
          DbTables.client.name,
          {'key': 'user_id', 'value': userId},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        if (deviceId != null) {
          batch.insert(
            DbTables.client.name,
            {'key': 'device_id', 'value': deviceId},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        if (deviceName != null) {
          batch.insert(
            DbTables.client.name,
            {'key': 'device_name', 'value': deviceName},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        if (prevBatch != null) {
          batch.insert(
            DbTables.client.name,
            {'key': 'prev_batch', 'value': prevBatch},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        if (olmAccount != null) {
          batch.insert(
            DbTables.client.name,
            {'key': 'olm_account', 'value': olmAccount},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });

  @override
  Future insertIntoToDeviceQueue(String type, String txnId, String content) =>
      _executor.insert(DbTables.toDeviceQueue.name, {
        'type': type,
        'txn_id': txnId,
        'content': content,
      });

  @override
  Future markInboundGroupSessionAsUploaded(String roomId, String sessionId) =>
      _executor.update(
        DbTables.inboundGroupSessions.name,
        {'uploaded': 'true'},
        where: 'room_id = ? AND session_id = ?',
        whereArgs: [roomId, sessionId],
      );

  @override
  Future markInboundGroupSessionsAsNeedingUpload() => _executor.update(
        DbTables.inboundGroupSessions.name,
        {'uploaded': false.toString()},
      );

  @override
  Future<String?> publicKeySeen(String publicKey) => _executor.query(
        DbTables.seenDeviceKeys.name,
        where: 'public_key = ?',
        whereArgs: [publicKey],
      ).then((rows) => rows.isEmpty ? null : rows.first['device_id'] as String);

  @override
  Future removeEvent(String eventId, String roomId) => _executor.delete(
        DbTables.timelineEvents.name,
        where: 'event_id = ?',
        whereArgs: [eventId],
      );

  @override
  Future removeOutboundGroupSession(String roomId) => _executor.delete(
        DbTables.outboundGroupSessions.name,
        where: 'room_id = ?',
        whereArgs: [roomId],
      );

  @override
  Future removeUserCrossSigningKey(String userId, String publicKey) =>
      _executor.delete(
        DbTables.userCrossSigningKeys.name,
        where: 'user_id = ? AND public_key = ?',
        whereArgs: [userId, publicKey],
      );

  @override
  Future removeUserDeviceKey(String userId, String deviceId) =>
      _executor.delete(
        DbTables.userDeviceKeys.name,
        where: 'user_id = ? AND device_id = ?',
        whereArgs: [userId, deviceId],
      );

  @override
  Future setBlockedUserCrossSigningKey(
          bool blocked, String userId, String publicKey) =>
      _executor.update(
        DbTables.userCrossSigningKeys.name,
        {'blocked': blocked.toString()},
        where: 'user_id = ? AND public_key = ?',
        whereArgs: [userId, publicKey],
      );

  @override
  Future setBlockedUserDeviceKey(
          bool blocked, String userId, String deviceId) =>
      _executor.update(
        DbTables.userDeviceKeys.name,
        {'blocked': blocked.toString()},
        where: 'user_id = ? AND device_id = ?',
        whereArgs: [userId, deviceId],
      );

  @override
  Future setLastActiveUserDeviceKey(
          int lastActive, String userId, String deviceId) =>
      _executor.update(
        DbTables.userDeviceKeys.name,
        {'last_active': lastActive},
        where: 'user_id = ? AND device_id = ?',
        whereArgs: [userId, deviceId],
      );

  @override
  Future setLastSentMessageUserDeviceKey(
          String lastSentMessage, String userId, String deviceId) =>
      _executor.update(
        DbTables.userDeviceKeys.name,
        {'last_sent_message': lastSentMessage},
        where: 'user_id = ? AND device_id = ?',
        whereArgs: [userId, deviceId],
      );

  @override
  Future setRoomPrevBatch(String? prevBatch, String roomId, Client client) =>
      _executor.update(
        DbTables.rooms.name,
        {'prev_batch': prevBatch},
        where: 'id = ?',
        whereArgs: [roomId],
      );

  @override
  Future setVerifiedUserCrossSigningKey(
          bool verified, String userId, String publicKey) =>
      _executor.update(
        DbTables.userCrossSigningKeys.name,
        {'verified': verified.toString()},
        where: 'user_id = ? AND public_key = ?',
        whereArgs: [userId, publicKey],
      );

  @override
  Future setVerifiedUserDeviceKey(
          bool verified, String userId, String deviceId) =>
      _executor.update(
        DbTables.userDeviceKeys.name,
        {'verified': verified.toString()},
        where: 'user_id = ? AND device_id = ?',
        whereArgs: [userId, deviceId],
      );

  @override
  Future storeAccountData(String type, String content) => _executor.insert(
        DbTables.accountData.name,
        {'type': type, 'content': content},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<int> _getMinSortOrder(String roomId) async {
    return (await _executor
        .query(
          DbTables.timelineEvents.name,
          columns: ['MIN(sort_order)'],
          where: 'room_id = ?',
          whereArgs: [roomId],
        )
        .then((rows) => rows.first['MIN(sort_order)'] as int? ?? 0));
  }

  Future<int> _getMaxSortOrder(String roomId) async {
    return (await _executor
        .query(
          DbTables.timelineEvents.name,
          columns: ['MAX(sort_order)'],
          where: 'room_id = ?',
          whereArgs: [roomId],
        )
        .then((rows) => rows.first['MAX(sort_order)'] as int? ?? 0));
  }

  @override
  Future<void> storeEventUpdate(EventUpdate eventUpdate, Client client) async {
    final eventId = eventUpdate.content['event_id'];

    // Ephemerals should not be stored
    if (eventUpdate.type == EventUpdateType.ephemeral) return;
    final tmpRoom = Room(id: eventUpdate.roomID, client: client);

    // In case of this is a redaction event
    if (eventUpdate.content['type'] == EventTypes.Redaction) {
      final eventId = eventUpdate.content.tryGet<String>('redacts');
      final event =
          eventId != null ? await getEventById(eventId, tmpRoom) : null;
      if (event != null) {
        event.setRedactionEvent(event);
        await _executor.update(
          DbTables.timelineEvents.name,
          event.toRow(),
          where: 'event_id = ? AND room_id = ?',
          whereArgs: [event.eventId, event.roomId],
        );
        await _executor.update(
          DbTables.stateEvents.name,
          event.toRow(),
          where: 'event_id = ? AND room_id = ?',
          whereArgs: [event.eventId, event.roomId],
        );
      }
    }

    // Store a common message event
    if ({
      EventUpdateType.timeline,
      EventUpdateType.history,
      EventUpdateType.decryptedTimelineQueue
    }.contains(eventUpdate.type)) {
      final event = Event.fromJson(eventUpdate.content, tmpRoom);
      var sortOrder = 0;
      if (eventUpdate.type == EventUpdateType.history) {
        sortOrder = await _getMinSortOrder(tmpRoom.id) - 1;
      } else {
        sortOrder = await _getMaxSortOrder(tmpRoom.id) + 1;
      }

      final insertResult = await _executor.insert(
        DbTables.timelineEvents.name,
        {
          ...event.toRow(),
          'sort_order': sortOrder,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      // Does this event replace a SENDING event with transaction ID?
      final transactionId = eventUpdate.content
          .tryGetMap<String, dynamic>('unsigned')
          ?.tryGet<String>('transaction_id');
      if (transactionId != null) {
        await removeEvent(transactionId, eventUpdate.roomID);
      }

      if (insertResult == 0) {
        // Event already exists. Compare status
        final newStatus = event.status.intValue;
        await _executor.update(
          DbTables.timelineEvents.name,
          event.toRow(),
          where:
              'event_id = ? AND room_id = ? AND (status <= ? OR (status == 0 AND ? == -1))',
          whereArgs: [eventId, tmpRoom.id, newStatus, newStatus],
        );
      }
    }

    // Store a common state event
    if ({
      EventUpdateType.timeline,
      EventUpdateType.state,
      EventUpdateType.inviteState
    }.contains(eventUpdate.type)) {
      final event = Event.fromJson(eventUpdate.content, tmpRoom);
      await _executor.insert(
        DbTables.stateEvents.name,
        event.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // Store a room account data event
    if (eventUpdate.type == EventUpdateType.accountData) {
      await _executor.insert(
        DbTables.roomAccountData.name,
        {
          'type': eventUpdate.content['type'],
          'content': jsonEncode(eventUpdate.content['content']),
          'room_id': tmpRoom.id,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  @override
  Future<void> storeFile(Uri mxcUri, Uint8List bytes, int time) async {
    final fileStoragePath = this.fileStoragePath;
    if (!supportsFileStoring || fileStoragePath == null) return;

    final file =
        File('${fileStoragePath.path}/${mxcUri.toString().split('/').last}');

    if (await file.exists()) return;
    await file.writeAsBytes(bytes);
  }

  @override
  Future storeInboundGroupSession(
          String roomId,
          String sessionId,
          String pickle,
          String content,
          String indexes,
          String allowedAtIndex,
          String senderKey,
          String senderClaimedKey) =>
      _executor.insert(
        DbTables.inboundGroupSessions.name,
        StoredInboundGroupSession(
          roomId: roomId,
          sessionId: sessionId,
          pickle: pickle,
          content: content,
          indexes: indexes,
          allowedAtIndex: allowedAtIndex,
          senderKey: senderKey,
          senderClaimedKeys: senderClaimedKey,
          uploaded: false,
        ).toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future storeOlmSession(String identityKey, String sessionId, String pickle,
          int lastReceived) =>
      _executor.insert(
        DbTables.olmSessions.name,
        {
          'session_id': sessionId,
          'identity_key': identityKey,
          'pickle': pickle,
          'last_received': lastReceived,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future storeOutboundGroupSession(
          String roomId, String pickle, String deviceIds, int creationTime) =>
      _executor.insert(
        DbTables.outboundGroupSessions.name,
        {
          'room_id': roomId,
          'pickle': pickle,
          'device_ids': deviceIds,
          'creation_time': creationTime,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future storePrevBatch(String prevBatch) => _executor.insert(
        DbTables.client.name,
        {'key': 'prev_batch', 'value': prevBatch},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future<void> storeRoomUpdate(
      String roomId, SyncRoomUpdate roomUpdate, Client client) async {
    // Leave room if membership is leave
    if (roomUpdate is LeftRoomUpdate) {
      await forgetRoom(roomId);
      return;
    }
    final membership = roomUpdate is LeftRoomUpdate
        ? Membership.leave
        : roomUpdate is InvitedRoomUpdate
            ? Membership.invite
            : Membership.join;

    final room = roomUpdate is JoinedRoomUpdate
        ? Room(
            client: client,
            id: roomId,
            membership: membership,
            highlightCount:
                roomUpdate.unreadNotifications?.highlightCount?.toInt() ?? 0,
            notificationCount:
                roomUpdate.unreadNotifications?.notificationCount?.toInt() ?? 0,
            prev_batch: roomUpdate.timeline?.prevBatch,
            summary: roomUpdate.summary,
          )
        : Room(
            client: client,
            id: roomId,
            membership: membership,
          );

    final roomExists = await _executor.insert(
      DbTables.rooms.name,
      room.toRow(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // If room already exists, update changes
    if (roomExists == 0) {
      await _executor.update(
        DbTables.rooms.name,
        {
          'membership': membership.name,
          if (room.prev_batch != null) 'prev_batch': room.prev_batch,
          if (roomUpdate is JoinedRoomUpdate &&
              roomUpdate.unreadNotifications?.notificationCount != null)
            'notification_count':
                roomUpdate.unreadNotifications?.notificationCount,
          if (roomUpdate is JoinedRoomUpdate &&
              roomUpdate.unreadNotifications?.highlightCount != null)
            'highlight_count': roomUpdate.unreadNotifications?.highlightCount,
          if (roomUpdate is JoinedRoomUpdate && roomUpdate.summary != null)
            'summary': jsonEncode(roomUpdate.summary?.toJson()),
        },
        where: 'id = ?',
        whereArgs: [roomId],
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // Is the timeline limited? Then all previous messages should be
    // removed from the database!
    if (roomUpdate is JoinedRoomUpdate &&
        roomUpdate.timeline?.limited == true) {
      await _executor.delete(
        DbTables.timelineEvents.name,
        where: 'room_id = ?',
        whereArgs: [roomId],
      );
    }
  }

  @override
  Future storeSSSSCache(
          String type, String keyId, String ciphertext, String content) =>
      _executor.insert(
        DbTables.ssssCache.name,
        SSSSCache(
          type: type,
          keyId: keyId,
          ciphertext: ciphertext,
          content: content,
        ).toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future storeSyncFilterId(String syncFilterId) => _executor.insert(
        DbTables.client.name,
        {'key': 'sync_filter_id', 'value': syncFilterId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future storeUserCrossSigningKey(String userId, String publicKey,
          String content, bool verified, bool blocked) =>
      _executor.insert(
        DbTables.userCrossSigningKeys.name,
        {
          'user_id': userId,
          'public_key': publicKey,
          'content': content,
          'verified': verified.toString(),
          'blocked': blocked.toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future storeUserDeviceKey(String userId, String deviceId, String content,
          bool verified, bool blocked, int lastActive) =>
      _executor.insert(
        DbTables.userDeviceKeys.name,
        {
          'user_id': userId,
          'device_id': deviceId,
          'content': content,
          'verified': verified.toString(),
          'blocked': blocked.toString(),
          'last_active': lastActive,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future storeUserDeviceKeysInfo(String userId, bool outdated) =>
      _executor.insert(
        DbTables.userDeviceKeysInfo.name,
        {
          'user_id': userId,
          'outdated': outdated.toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Completer<void>? _transactionLock;
  final _transactionZones = <Zone>{};

  @override
  Future<void> transaction(Future<void> Function() action) async {
    // we want transactions to lock, however NOT if transactoins are run inside of each other.
    // to be able to do this, we use dart zones (https://dart.dev/articles/archive/zones).
    // _transactionZones holds a set of all zones which are currently running a transaction.
    // _transactionLock holds the lock.

    // first we try to determine if we are inside of a transaction currently
    var isInTransaction = false;
    Zone? zone = Zone.current;
    // for that we keep on iterating to the parent zone until there is either no zone anymore
    // or we have found a zone inside of _transactionZones.
    while (zone != null) {
      if (_transactionZones.contains(zone)) {
        isInTransaction = true;
        break;
      }
      zone = zone.parent;
    }
    // if we are inside a transaction....just run the action
    if (isInTransaction) {
      return await action();
    }
    // if we are *not* in a transaction, time to wait for the lock!
    while (_transactionLock != null) {
      await _transactionLock!.future;
    }
    // claim the lock
    final lock = Completer<void>();
    _transactionLock = lock;
    try {
      // run the action inside of a new zone
      return await runZoned(() async {
        try {
          // don't forget to add the new zone to _transactionZones!
          _transactionZones.add(Zone.current);
          await database.transaction((txn) async {
            _currentTransaction = txn;
            await action();
          });
        } finally {
          // aaaand remove the zone from _transactionZones again
          _currentTransaction = null;
          _transactionZones.remove(Zone.current);
        }
      });
    } finally {
      // aaaand finally release the lock
      _transactionLock = null;
      lock.complete();
    }
  }

  @override
  Future updateClient(
          String homeserverUrl,
          String token,
          String userId,
          String? deviceId,
          String? deviceName,
          String? prevBatch,
          String? olmAccount) =>
      transaction(() async {
        final batch = _executor.batch();
        batch.update(
          DbTables.client.name,
          {'value': homeserverUrl},
          where: 'key = ?',
          whereArgs: ['homeserver_url'],
        );
        batch.update(
          DbTables.client.name,
          {'value': token},
          where: 'key = ?',
          whereArgs: ['token'],
        );
        batch.update(
          DbTables.client.name,
          {'value': userId},
          where: 'key = ?',
          whereArgs: ['user_id'],
        );
        if (deviceId != null) {
          batch.update(
            DbTables.client.name,
            {'value': deviceId},
            where: 'key = ?',
            whereArgs: ['device_id'],
          );
        }
        if (deviceName != null) {
          batch.update(
            DbTables.client.name,
            {'value': deviceName},
            where: 'key = ?',
            whereArgs: ['device_name'],
          );
        }
        if (prevBatch != null) {
          batch.update(
            DbTables.client.name,
            {'value': prevBatch},
            where: 'key = ?',
            whereArgs: ['prev_batch'],
          );
        }
        if (olmAccount != null) {
          batch.update(
            DbTables.client.name,
            {'value': olmAccount},
            where: 'key = ?',
            whereArgs: ['olm_account'],
          );
        }
        await batch.commit(noResult: true);
      });

  @override
  Future updateClientKeys(String olmAccount) => _executor.update(
        DbTables.client.name,
        {'value': olmAccount},
        where: 'key = ?',
        whereArgs: ['olm_account'],
      );

  @override
  Future updateInboundGroupSessionAllowedAtIndex(
          String allowedAtIndex, String roomId, String sessionId) =>
      _executor.update(
        DbTables.inboundGroupSessions.name,
        {'allowed_at_index': allowedAtIndex},
        where: 'room_id = ? AND session_id = ?',
        whereArgs: [roomId, sessionId],
      );

  @override
  Future updateInboundGroupSessionIndexes(
          String indexes, String roomId, String sessionId) =>
      _executor.update(
        DbTables.inboundGroupSessions.name,
        {'indexes': indexes},
        where: 'room_id = ? AND session_id = ?',
        whereArgs: [roomId, sessionId],
      );

  @override
  Future<CachedPresence?> getPresence(String userId) => _executor.query(
        DbTables.presences.name,
        where: 'user_id = ?',
        whereArgs: [userId],
      ).then(
        (rows) => rows.isEmpty ? null : PresenceAdapter.fromRow(rows.first),
      );

  @override
  Future<void> storePresence(String userId, CachedPresence presence) =>
      _executor.insert(
        DbTables.presences.name,
        presence.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
}

extension PresenceAdapter on CachedPresence {
  static CachedPresence fromRow(Map<String, Object?> json) =>
      CachedPresence.fromJson({
        ...json,
        if (json['currently_active'] != null)
          'currently_active': json['currently_active'] == 'true',
      });

  Map<String, Object?> toRow() => {
        'user_id': userid,
        'presence': presence.name,
        if (lastActiveTimestamp != null)
          'last_active_timestamp': lastActiveTimestamp?.millisecondsSinceEpoch,
        if (statusMsg != null) 'status_msg': statusMsg,
        if (currentlyActive != null)
          'currently_active': currentlyActive.toString(),
      };
}

extension RoomAdapter on Room {
  static Room fromRow(Map<String, Object?> row, Client client) {
    return Room.fromJson(
      {
        ...row,
        'summary': row['summary'] is String
            ? jsonDecode(row['summary'] as String)
            : {},
      },
      client,
    );
  }

  Map<String, Object?> toRow() => {
        ...toJson(),
        'summary': jsonEncode(summary.toJson()),
      };
}

extension EventAdapter on Event {
  static Event fromRow(Map<String, Object?> row, Room room) => Event.fromJson(
        {
          ...row,
          'content': jsonDecode(row['content'] as String),
          if (row['prev_content'] != null)
            'prev_content': jsonDecode(row['prev_content'] as String),
          if (row['unsigned'] != null)
            'unsigned': jsonDecode(row['unsigned'] as String),
          if (row['original_source'] != null)
            'original_source': jsonDecode(row['original_source'] as String),
        },
        room,
      );

  Map<String, Object?> toRow() => {
        ...toJson(),
        if (stateKey != null) 'state_key': stateKey,
        if (prevContent?.isNotEmpty == true)
          'prev_content': jsonEncode(prevContent),
        'content': jsonEncode(content),
        if (unsigned != null) 'unsigned': jsonEncode(unsigned),
        if (originalSource != null)
          'original_source': jsonEncode(originalSource),
        'status': status.intValue,
      };
}

extension on StoredInboundGroupSession {
  Map<String, Object?> toRow() => {
        ...toJson(),
        'uploaded': uploaded.toString(),
      };
}
