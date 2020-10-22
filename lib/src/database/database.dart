import 'dart:async';
import 'dart:convert';

import 'package:moor/moor.dart';
import 'package:olm/olm.dart' as olm;

import '../../famedlysdk.dart' as sdk;
import '../../matrix_api.dart' as api;
import '../client.dart';
import '../room.dart';
import '../utils/logs.dart';

part 'database.g.dart';

extension MigratorExtension on Migrator {
  Future<void> createIndexIfNotExists(Index index) async {
    try {
      await createIndex(index);
    } catch (err) {
      if (!err.toString().toLowerCase().contains('already exists')) {
        rethrow;
      }
    }
  }

  Future<void> createTableIfNotExists(TableInfo<Table, DataClass> table) async {
    try {
      await createTable(table);
    } catch (err) {
      if (!err.toString().toLowerCase().contains('already exists')) {
        rethrow;
      }
    }
  }

  Future<void> addColumnIfNotExists(
      TableInfo<Table, DataClass> table, GeneratedColumn column) async {
    try {
      await addColumn(table, column);
    } catch (err) {
      if (!err.toString().toLowerCase().contains('duplicate column name')) {
        rethrow;
      }
    }
  }
}

@UseMoor(
  include: {'database.moor'},
)
class Database extends _$Database {
  Database(QueryExecutor e) : super(e);

  Database.connect(DatabaseConnection connection) : super.connect(connection);

  @override
  int get schemaVersion => 7;

  int get maxFileSize => 1 * 1024 * 1024;

  /// Update errors are coming here.
  final StreamController<SdkError> onError = StreamController.broadcast();

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          try {
            await m.createAll();
          } catch (e, s) {
            Logs.error(e, s);
            onError.add(SdkError(exception: e, stackTrace: s));
            rethrow;
          }
        },
        onUpgrade: (Migrator m, int from, int to) async {
          try {
            // this appears to be only called once, so multiple consecutive upgrades have to be handled appropriately in here
            if (from == 1) {
              await m.createIndexIfNotExists(userDeviceKeysIndex);
              await m.createIndexIfNotExists(userDeviceKeysKeyIndex);
              await m.createIndexIfNotExists(olmSessionsIndex);
              await m.createIndexIfNotExists(outboundGroupSessionsIndex);
              await m.createIndexIfNotExists(inboundGroupSessionsIndex);
              await m.createIndexIfNotExists(roomsIndex);
              await m.createIndexIfNotExists(eventsIndex);
              await m.createIndexIfNotExists(roomStatesIndex);
              await m.createIndexIfNotExists(accountDataIndex);
              await m.createIndexIfNotExists(roomAccountDataIndex);
              await m.createIndexIfNotExists(presencesIndex);
              from++;
            }
            if (from == 2) {
              await m.deleteTable('outbound_group_sessions');
              await m.createTable(outboundGroupSessions);
              from++;
            }
            if (from == 3) {
              await m.createTableIfNotExists(userCrossSigningKeys);
              await m.createTableIfNotExists(ssssCache);
              // mark all keys as outdated so that the cross signing keys will be fetched
              await customStatement(
                  'UPDATE user_device_keys SET outdated = true');
              from++;
            }
            if (from == 4) {
              await m.addColumnIfNotExists(
                  olmSessions, olmSessions.lastReceived);
              from++;
            }
            if (from == 5) {
              await m.addColumnIfNotExists(
                  inboundGroupSessions, inboundGroupSessions.uploaded);
              await m.addColumnIfNotExists(
                  inboundGroupSessions, inboundGroupSessions.senderKey);
              await m.addColumnIfNotExists(
                  inboundGroupSessions, inboundGroupSessions.senderClaimedKeys);
              from++;
            }
            if (from == 6) {
              // DATETIME was internally an int, so we should be able to re-use the
              // olm_sessions table.
              await m.deleteTable('outbound_group_sessions');
              await m.createTable(outboundGroupSessions);
              await m.deleteTable('events');
              await m.createTable(events);
              await m.deleteTable('room_states');
              await m.createTable(roomStates);
              await m.deleteTable('files');
              await m.createTable(files);
              // and now clear cache
              await delete(presences).go();
              await delete(roomAccountData).go();
              await delete(accountData).go();
              await delete(roomStates).go();
              await delete(events).go();
              await delete(rooms).go();
              await delete(outboundGroupSessions).go();
              await customStatement('UPDATE clients SET prev_batch = null');
            }
          } catch (e, s) {
            Logs.error(e, s);
            onError.add(SdkError(exception: e, stackTrace: s));
            rethrow;
          }
        },
        beforeOpen: (_) async {
          try {
            if (executor.dialect == SqlDialect.sqlite) {
              final ret = await customSelect('PRAGMA journal_mode=WAL').get();
              if (ret.isNotEmpty) {
                Logs.info('[Moor] Switched database to mode ' +
                    ret.first.data['journal_mode'].toString());
              }
            }
          } catch (e, s) {
            Logs.error(e, s);
            onError.add(SdkError(exception: e, stackTrace: s));
            rethrow;
          }
        },
      );

  Future<DbClient> getClient(String name) async {
    final res = await dbGetClient(name).get();
    if (res.isEmpty) return null;
    await markPendingEventsAsError(res.single.clientId);
    return res.single;
  }

  Future<Map<String, sdk.DeviceKeysList>> getUserDeviceKeys(
      sdk.Client client) async {
    final deviceKeys = await getAllUserDeviceKeys(client.id).get();
    if (deviceKeys.isEmpty) {
      return {};
    }
    final deviceKeysKeys = await getAllUserDeviceKeysKeys(client.id).get();
    final crossSigningKeys = await getAllUserCrossSigningKeys(client.id).get();
    final res = <String, sdk.DeviceKeysList>{};
    for (final entry in deviceKeys) {
      res[entry.userId] = sdk.DeviceKeysList.fromDb(
          entry,
          deviceKeysKeys.where((k) => k.userId == entry.userId).toList(),
          crossSigningKeys.where((k) => k.userId == entry.userId).toList(),
          client);
    }
    return res;
  }

  Future<Map<String, List<olm.Session>>> getOlmSessions(
      int clientId, String userId) async {
    final raw = await getAllOlmSessions(clientId).get();
    if (raw.isEmpty) {
      return {};
    }
    final res = <String, List<olm.Session>>{};
    for (final row in raw) {
      if (!res.containsKey(row.identityKey)) {
        res[row.identityKey] = [];
      }
      try {
        var session = olm.Session();
        session.unpickle(userId, row.pickle);
        res[row.identityKey].add(session);
      } catch (e, s) {
        Logs.error(
            '[LibOlm] Could not unpickle olm session: ' + e.toString(), s);
      }
    }
    return res;
  }

  Future<DbOutboundGroupSession> getDbOutboundGroupSession(
      int clientId, String roomId) async {
    final res = await dbGetOutboundGroupSession(clientId, roomId).get();
    if (res.isEmpty) {
      return null;
    }
    return res.single;
  }

  Future<List<DbInboundGroupSession>> getDbInboundGroupSessions(
      int clientId, String roomId) async {
    return await dbGetInboundGroupSessionKeys(clientId, roomId).get();
  }

  Future<DbInboundGroupSession> getDbInboundGroupSession(
      int clientId, String roomId, String sessionId) async {
    final res =
        await dbGetInboundGroupSessionKey(clientId, roomId, sessionId).get();
    if (res.isEmpty) {
      return null;
    }
    return res.single;
  }

  Future<DbSSSSCache> getSSSSCache(int clientId, String type) async {
    final res = await dbGetSSSSCache(clientId, type).get();
    if (res.isEmpty) {
      return null;
    }
    return res.single;
  }

  Future<List<sdk.Room>> getRoomList(sdk.Client client,
      {bool onlyLeft = false}) async {
    final res = await (select(rooms)
          ..where((t) => onlyLeft
              ? t.membership.equals('leave')
              : t.membership.equals('leave').not()))
        .get();
    final resStates = await getImportantRoomStates(
            client.id, client.importantStateEvents.toList())
        .get();
    final resAccountData = await getAllRoomAccountData(client.id).get();
    final roomList = <sdk.Room>[];
    final allMembersToPostload = <String, Set<String>>{};
    for (final r in res) {
      final room = await sdk.Room.getRoomFromTableRow(
        r,
        client,
        states: resStates.where((rs) => rs.roomId == r.roomId),
        roomAccountData: resAccountData.where((rs) => rs.roomId == r.roomId),
      );
      roomList.add(room);
      // let's see if we need any m.room.member events
      final membersToPostload = <String>{};
      // the lastEvent message preview might have an author we need to fetch, if it is a group chat
      if (room.getState(api.EventTypes.Message) != null && !room.isDirectChat) {
        membersToPostload.add(room.getState(api.EventTypes.Message).senderId);
      }
      // if the room has no name and no canonical alias, its name is calculated
      // based on the heroes of the room
      if (room.getState(api.EventTypes.RoomName) == null &&
          room.getState(api.EventTypes.RoomCanonicalAlias) == null &&
          room.mHeroes != null) {
        // we don't have a name and no canonical alias, so we'll need to
        // post-load the heroes
        membersToPostload.addAll(room.mHeroes.where((h) => h.isNotEmpty));
      }
      // okay, only load from the database if we actually have stuff to load
      if (membersToPostload.isNotEmpty) {
        // save it for loading later
        allMembersToPostload[room.id] = membersToPostload;
      }
    }
    // now we postload all members, if thre are any
    if (allMembersToPostload.isNotEmpty) {
      // we will generate a query to fetch as many events as possible at once, as that
      // significantly improves performance. However, to prevent too large queries from being constructed,
      // we limit to only fetching 500 rooms at once.
      // This value might be fine-tune-able to be larger (and thus increase performance more for very large accounts),
      // however this very conservative value should be on the safe side.
      const MAX_ROOMS_PER_QUERY = 500;
      // as we iterate over our entries in separate chunks one-by-one we use an iterator
      // which persists accross the chunks, and thus we just re-sume iteration at the place
      // we prreviously left off.
      final entriesIterator = allMembersToPostload.entries.iterator;
      // now we iterate over all our 500-room-chunks...
      for (var i = 0;
          i < allMembersToPostload.keys.length;
          i += MAX_ROOMS_PER_QUERY) {
        // query the current chunk and build the query
        final membersRes = await (select(roomStates)
              ..where((s) {
                // all chunks have to have the reight client id and must be of type `m.room.member`
                final basequery = s.clientId.equals(client.id) &
                    s.type.equals('m.room.member');
                // this is where the magic happens. Here we build a query with the form
                // OR room_id = '!roomId1' AND state_key IN ('@member') OR room_id = '!roomId2' AND state_key IN ('@member')
                // subqueries holds our query fragment
                Expression<bool> subqueries;
                // here we iterate over our chunk....we musn't forget to progress our iterator!
                // we must check for if our chunk is done *before* progressing the
                // iterator, else we might progress it twice around chunk edges, missing on rooms
                for (var j = 0;
                    j < MAX_ROOMS_PER_QUERY && entriesIterator.moveNext();
                    j++) {
                  final entry = entriesIterator.current;
                  // builds room_id = '!roomId1' AND state_key IN ('@member')
                  final q =
                      s.roomId.equals(entry.key) & s.stateKey.isIn(entry.value);
                  // adds it either as the start of subqueries or as a new OR condition to it
                  if (subqueries == null) {
                    subqueries = q;
                  } else {
                    subqueries = subqueries | q;
                  }
                }
                // combinde the basequery with the subquery together, giving our final query
                return basequery & subqueries;
              }))
            .get();
        // now that we got all the entries from the database, set them as room states
        for (final dbMember in membersRes) {
          final room = roomList.firstWhere((r) => r.id == dbMember.roomId);
          final event = sdk.Event.fromDb(dbMember, room);
          room.setState(event);
        }
      }
    }
    return roomList;
  }

  Future<Map<String, api.BasicEvent>> getAccountData(int clientId) async {
    final newAccountData = <String, api.BasicEvent>{};
    final rawAccountData = await getAllAccountData(clientId).get();
    for (final d in rawAccountData) {
      var content = sdk.Event.getMapFromPayload(d.content);
      // there was a bug where it stored the entire event, not just the content
      // in the databse. This is the temporary fix for those affected by the bug
      if (content['content'] is Map && content['type'] is String) {
        content = content['content'];
        // and save
        await storeAccountData(clientId, d.type, jsonEncode(content));
      }
      newAccountData[d.type] = api.BasicEvent(
        content: content,
        type: d.type,
      );
    }
    return newAccountData;
  }

  /// Stores a RoomUpdate object in the database. Must be called inside of
  /// [transaction].
  final Set<String> _ensuredRooms = {};
  Future<void> storeRoomUpdate(int clientId, sdk.RoomUpdate roomUpdate,
      [sdk.Room oldRoom]) async {
    final setKey = '${clientId};${roomUpdate.id}';
    if (roomUpdate.membership != api.Membership.leave) {
      if (!_ensuredRooms.contains(setKey)) {
        await ensureRoomExists(clientId, roomUpdate.id,
            roomUpdate.membership.toString().split('.').last);
        _ensuredRooms.add(setKey);
      }
    } else {
      _ensuredRooms.remove(setKey);
      await removeRoom(clientId, roomUpdate.id);
      return;
    }

    var doUpdate = oldRoom == null;
    if (!doUpdate) {
      doUpdate = roomUpdate.highlight_count != oldRoom.highlightCount ||
          roomUpdate.notification_count != oldRoom.notificationCount ||
          roomUpdate.membership.toString().split('.').last !=
              oldRoom.membership.toString().split('.').last ||
          (roomUpdate.summary?.mJoinedMemberCount != null &&
              roomUpdate.summary.mJoinedMemberCount !=
                  oldRoom.mInvitedMemberCount) ||
          (roomUpdate.summary?.mInvitedMemberCount != null &&
              roomUpdate.summary.mJoinedMemberCount !=
                  oldRoom.mJoinedMemberCount) ||
          (roomUpdate.summary?.mHeroes != null &&
              roomUpdate.summary.mHeroes.join(',') !=
                  oldRoom.mHeroes.join(','));
    }

    if (doUpdate) {
      await (update(rooms)
            ..where((r) =>
                r.roomId.equals(roomUpdate.id) & r.clientId.equals(clientId)))
          .write(RoomsCompanion(
        highlightCount: Value(roomUpdate.highlight_count),
        notificationCount: Value(roomUpdate.notification_count),
        membership: Value(roomUpdate.membership.toString().split('.').last),
        joinedMemberCount: roomUpdate.summary?.mJoinedMemberCount != null
            ? Value(roomUpdate.summary.mJoinedMemberCount)
            : Value.absent(),
        invitedMemberCount: roomUpdate.summary?.mInvitedMemberCount != null
            ? Value(roomUpdate.summary.mInvitedMemberCount)
            : Value.absent(),
        heroes: roomUpdate.summary?.mHeroes != null
            ? Value(roomUpdate.summary.mHeroes.join(','))
            : Value.absent(),
      ));
    }

    // Is the timeline limited? Then all previous messages should be
    // removed from the database!
    if (roomUpdate.limitedTimeline) {
      await removeSuccessfulRoomEvents(clientId, roomUpdate.id);
      await updateRoomSortOrder(0.0, 0.0, clientId, roomUpdate.id);
      await setRoomPrevBatch(roomUpdate.prev_batch, clientId, roomUpdate.id);
    }
  }

  /// Stores an EventUpdate object in the database. Must be called inside of
  /// [transaction].
  Future<void> storeEventUpdate(
      int clientId, sdk.EventUpdate eventUpdate) async {
    if (eventUpdate.type == sdk.EventUpdateType.ephemeral) return;
    final eventContent = eventUpdate.content;
    final type = eventUpdate.type;
    final chatId = eventUpdate.roomID;

    // Get the state_key for state events
    String stateKey;
    if (eventContent['state_key'] is String) {
      stateKey = eventContent['state_key'];
    }

    if (eventUpdate.eventType == api.EventTypes.Redaction) {
      await redactMessage(clientId, eventUpdate);
    }

    if (type == sdk.EventUpdateType.timeline ||
        type == sdk.EventUpdateType.history) {
      // calculate the status
      var status = 2;
      if (eventContent['unsigned'] is Map<String, dynamic> &&
          eventContent['unsigned'][MessageSendingStatusKey] is num) {
        status = eventContent['unsigned'][MessageSendingStatusKey];
      }
      if (eventContent['status'] is num) status = eventContent['status'];
      var storeNewEvent = !((status == 1 || status == -1) &&
          eventContent['unsigned'] is Map<String, dynamic> &&
          eventContent['unsigned']['transaction_id'] is String);
      if (!storeNewEvent) {
        final allOldEvents =
            await getEvent(clientId, eventContent['event_id'], chatId).get();
        if (allOldEvents.isNotEmpty) {
          // we were likely unable to change transaction_id -> event_id.....because the event ID already exists!
          // So, we try to fetch the old event
          // the transaction id event will automatically be deleted further down
          final oldEvent = allOldEvents.first;
          // do we update the status? We should allow 0 -> -1 updates and status increases
          if (status > oldEvent.status ||
              (oldEvent.status == 0 && status == -1)) {
            // update the status
            await updateEventStatusOnly(
                status, clientId, eventContent['event_id'], chatId);
          }
        } else {
          // status changed and we have an old transaction id --> update event id and stuffs
          try {
            final updated = await updateEventStatus(
                status,
                eventContent['event_id'],
                clientId,
                eventContent['unsigned']['transaction_id'],
                chatId);
            if (updated == 0) {
              storeNewEvent = true;
            }
          } catch (err) {
            // we could not update the transaction id to the event id....so it already exists
            // as we just tried to fetch the event previously this is a race condition if the event comes down sync in the mean time
            // that means that the status we already have in the database is likely more accurate
            // than our status. So, we just ignore this error
          }
        }
      }
      if (storeNewEvent) {
        DbEvent oldEvent;
        if (type == sdk.EventUpdateType.history) {
          final allOldEvents =
              await getEvent(clientId, eventContent['event_id'], chatId).get();
          if (allOldEvents.isNotEmpty) {
            oldEvent = allOldEvents.first;
          }
        }
        await storeEvent(
          clientId,
          eventContent['event_id'],
          chatId,
          oldEvent?.sortOrder ?? eventUpdate.sortOrder,
          eventContent['origin_server_ts'] ??
              DateTime.now().millisecondsSinceEpoch,
          eventContent['sender'],
          eventContent['type'],
          json.encode(eventContent['unsigned'] ?? ''),
          json.encode(eventContent['content']),
          json.encode(eventContent['prevContent']),
          eventContent['state_key'],
          status,
        );
      }

      // is there a transaction id? Then delete the event with this id.
      if (status != -1 &&
          status != 0 &&
          eventUpdate.content['unsigned'] is Map &&
          eventUpdate.content['unsigned']['transaction_id'] is String) {
        await removeEvent(clientId,
            eventUpdate.content['unsigned']['transaction_id'], chatId);
      }
    }

    if (type == sdk.EventUpdateType.history) return;

    if (type != sdk.EventUpdateType.accountData &&
        ((stateKey is String) ||
            [
              api.EventTypes.Message,
              api.EventTypes.Sticker,
              api.EventTypes.Encrypted
            ].contains(eventUpdate.eventType))) {
      final now = DateTime.now();
      await storeRoomState(
        clientId,
        eventContent['event_id'] ?? now.millisecondsSinceEpoch.toString(),
        chatId,
        eventUpdate.sortOrder ?? 0.0,
        eventContent['origin_server_ts'] ?? now.millisecondsSinceEpoch,
        eventContent['sender'],
        eventContent['type'],
        json.encode(eventContent['unsigned'] ?? ''),
        json.encode(eventContent['content']),
        json.encode(eventContent['prev_content'] ?? ''),
        stateKey ?? '',
      );
    } else if (type == sdk.EventUpdateType.accountData) {
      await storeRoomAccountData(
        clientId,
        eventContent['type'],
        chatId,
        json.encode(eventContent['content']),
      );
    }
  }

  Future<sdk.Event> getEventById(
      int clientId, String eventId, sdk.Room room) async {
    final event = await getEvent(clientId, eventId, room.id).get();
    if (event.isEmpty) {
      return null;
    }
    return sdk.Event.fromDb(event.single, room);
  }

  Future<bool> redactMessage(int clientId, sdk.EventUpdate eventUpdate) async {
    final events = await getEvent(
            clientId, eventUpdate.content['redacts'], eventUpdate.roomID)
        .get();
    var success = false;
    for (final dbEvent in events) {
      final event = sdk.Event.fromDb(dbEvent, null);
      event.setRedactionEvent(sdk.Event.fromJson(eventUpdate.content, null));
      final changes1 = await updateEvent(
        json.encode(event.unsigned ?? ''),
        json.encode(event.content ?? ''),
        json.encode(event.prevContent ?? ''),
        clientId,
        event.eventId,
        eventUpdate.roomID,
      );
      final changes2 = await updateEvent(
        json.encode(event.unsigned ?? ''),
        json.encode(event.content ?? ''),
        json.encode(event.prevContent ?? ''),
        clientId,
        event.eventId,
        eventUpdate.roomID,
      );
      if (changes1 == 1 && changes2 == 1) success = true;
    }
    return success;
  }

  Future<void> forgetRoom(int clientId, String roomId) async {
    final setKey = '${clientId};${roomId}';
    _ensuredRooms.remove(setKey);
    await (delete(rooms)
          ..where((r) => r.roomId.equals(roomId) & r.clientId.equals(clientId)))
        .go();
    await (delete(events)
          ..where((r) => r.roomId.equals(roomId) & r.clientId.equals(clientId)))
        .go();
    await (delete(roomStates)
          ..where((r) => r.roomId.equals(roomId) & r.clientId.equals(clientId)))
        .go();
    await (delete(roomAccountData)
          ..where((r) => r.roomId.equals(roomId) & r.clientId.equals(clientId)))
        .go();
  }

  Future<void> clearCache(int clientId) async {
    await (delete(presences)..where((r) => r.clientId.equals(clientId))).go();
    await (delete(roomAccountData)..where((r) => r.clientId.equals(clientId)))
        .go();
    await (delete(accountData)..where((r) => r.clientId.equals(clientId))).go();
    await (delete(roomStates)..where((r) => r.clientId.equals(clientId))).go();
    await (delete(events)..where((r) => r.clientId.equals(clientId))).go();
    await (delete(rooms)..where((r) => r.clientId.equals(clientId))).go();
    await (delete(outboundGroupSessions)
          ..where((r) => r.clientId.equals(clientId)))
        .go();
    await storePrevBatch(null, clientId);
  }

  Future<void> clear(int clientId) async {
    await clearCache(clientId);
    await (delete(inboundGroupSessions)
          ..where((r) => r.clientId.equals(clientId)))
        .go();
    await (delete(ssssCache)..where((r) => r.clientId.equals(clientId))).go();
    await (delete(olmSessions)..where((r) => r.clientId.equals(clientId))).go();
    await (delete(userCrossSigningKeys)
          ..where((r) => r.clientId.equals(clientId)))
        .go();
    await (delete(userDeviceKeysKey)..where((r) => r.clientId.equals(clientId)))
        .go();
    await (delete(userDeviceKeys)..where((r) => r.clientId.equals(clientId)))
        .go();
    await (delete(ssssCache)..where((r) => r.clientId.equals(clientId))).go();
    await (delete(clients)..where((r) => r.clientId.equals(clientId))).go();
  }

  Future<sdk.User> getUser(int clientId, String userId, sdk.Room room) async {
    final res = await dbGetUser(clientId, userId, room.id).get();
    if (res.isEmpty) {
      return null;
    }
    return sdk.Event.fromDb(res.single, room).asUser;
  }

  Future<List<sdk.User>> getUsers(int clientId, sdk.Room room) async {
    final res = await dbGetUsers(clientId, room.id).get();
    final ret = <sdk.User>[];
    for (final r in res) {
      ret.add(sdk.Event.fromDb(r, room).asUser);
    }
    return ret;
  }

  Future<List<sdk.Event>> getEventList(int clientId, sdk.Room room) async {
    final res = await dbGetEventList(clientId, room.id).get();
    final eventList = <sdk.Event>[];
    for (final r in res) {
      eventList.add(sdk.Event.fromDb(r, room));
    }
    return eventList;
  }

  Future<Uint8List> getFile(String mxcUri) async {
    final res = await dbGetFile(mxcUri).get();
    if (res.isEmpty) return null;
    return res.single.bytes;
  }
}
