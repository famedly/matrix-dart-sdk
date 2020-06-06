import 'package:moor/moor.dart';
import 'dart:convert';

import 'package:famedlysdk/famedlysdk.dart' as sdk;
import 'package:famedlysdk/matrix_api.dart' as api;
import 'package:olm/olm.dart' as olm;

import '../../matrix_api.dart';

part 'database.g.dart';

@UseMoor(
  include: {'database.moor'},
)
class Database extends _$Database {
  Database(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 4;

  int get maxFileSize => 1 * 1024 * 1024;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) {
          return m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // this appears to be only called once, so multiple consecutive upgrades have to be handled appropriately in here
          if (from == 1) {
            await m.createIndex(userDeviceKeysIndex);
            await m.createIndex(userDeviceKeysKeyIndex);
            await m.createIndex(olmSessionsIndex);
            await m.createIndex(outboundGroupSessionsIndex);
            await m.createIndex(inboundGroupSessionsIndex);
            await m.createIndex(roomsIndex);
            await m.createIndex(eventsIndex);
            await m.createIndex(roomStatesIndex);
            await m.createIndex(accountDataIndex);
            await m.createIndex(roomAccountDataIndex);
            await m.createIndex(presencesIndex);
            from++;
          }
          if (from == 2) {
            await m.deleteTable('outbound_group_sessions');
            await m.createTable(outboundGroupSessions);
            from++;
          }
          if (from == 3) {
            await m.createTable(userCrossSigningKeys);
            await m.createIndex(userCrossSigningKeysIndex);
            await m.createTable(ssssCache);
            // mark all keys as outdated so that the cross signing keys will be fetched
            await m.issueCustomQuery(
                'UPDATE user_device_keys SET outdated = true');
            from++;
          }
        },
      );

  Future<DbClient> getClient(String name) async {
    final res = await dbGetClient(name).get();
    if (res.isEmpty) return null;
    return res.first;
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
      } catch (e) {
        print('[LibOlm] Could not unpickle olm session: ' + e.toString());
      }
    }
    return res;
  }

  Future<List<olm.Session>> getSingleOlmSessions(
      int clientId, String identityKey, String userId) async {
    final rows = await dbGetOlmSessions(clientId, identityKey).get();
    final res = <olm.Session>[];
    for (final row in rows) {
      try {
        var session = olm.Session();
        session.unpickle(userId, row.pickle);
        res.add(session);
      } catch (e) {
        print('[LibOlm] Could not unpickle olm session: ' + e.toString());
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
    return res.first;
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
    return res.first;
  }

  Future<DbSSSSCache> getSSSSCache(int clientId, String type) async {
    final res = await dbGetSSSSCache(clientId, type).get();
    if (res.isEmpty) {
      return null;
    }
    return res.first;
  }

  Future<List<sdk.Room>> getRoomList(sdk.Client client,
      {bool onlyLeft = false}) async {
    final res = await (select(rooms)
          ..where((t) => onlyLeft
              ? t.membership.equals('leave')
              : t.membership.equals('leave').not()))
        .get();
    final resStates = await getAllRoomStates(client.id).get();
    final resAccountData = await getAllRoomAccountData(client.id).get();
    final roomList = <sdk.Room>[];
    for (final r in res) {
      final room = await sdk.Room.getRoomFromTableRow(
        r,
        client,
        states: resStates.where((rs) => rs.roomId == r.roomId),
        roomAccountData: resAccountData.where((rs) => rs.roomId == r.roomId),
      );
      roomList.add(room);
    }
    return roomList;
  }

  Future<Map<String, api.BasicEvent>> getAccountData(int clientId) async {
    final newAccountData = <String, api.BasicEvent>{};
    final rawAccountData = await getAllAccountData(clientId).get();
    for (final d in rawAccountData) {
      final content = sdk.Event.getMapFromPayload(d.content);
      newAccountData[d.type] = api.BasicEvent(
        content: content,
        type: d.type,
      );
    }
    return newAccountData;
  }

  Future<Map<String, api.Presence>> getPresences(int clientId) async {
    final newPresences = <String, api.Presence>{};
    final rawPresences = await getAllPresences(clientId).get();
    for (final d in rawPresences) {
      // TODO: Why is this not working?
      try {
        final content = sdk.Event.getMapFromPayload(d.content);
        var presence = api.Presence.fromJson(content);
        presence.senderId = d.sender;
        presence.type = d.type;
        newPresences[d.sender] = api.Presence.fromJson(content);
      } catch (_) {}
    }
    return newPresences;
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
      await removeRoomEvents(clientId, roomUpdate.id);
      await updateRoomSortOrder(0.0, 0.0, clientId, roomUpdate.id);
      await setRoomPrevBatch(roomUpdate.prev_batch, clientId, roomUpdate.id);
    }
  }

  /// Stores an UserUpdate object in the database. Must be called inside of
  /// [transaction].
  Future<void> storeUserEventUpdate(
    int clientId,
    String type,
    String eventType,
    Map<String, dynamic> content,
  ) async {
    if (type == 'account_data') {
      await storeAccountData(
          clientId, eventType, json.encode(content['content']));
    } else if (type == 'presence') {
      await storePresence(clientId, eventType, content['sender'],
          json.encode(content['content']));
    }
  }

  /// Stores an EventUpdate object in the database. Must be called inside of
  /// [transaction].
  Future<void> storeEventUpdate(
      int clientId, sdk.EventUpdate eventUpdate) async {
    if (eventUpdate.type == 'ephemeral') return;
    final eventContent = eventUpdate.content;
    final type = eventUpdate.type;
    final chatId = eventUpdate.roomID;

    // Get the state_key for state events
    var stateKey = '';
    if (eventContent['state_key'] is String) {
      stateKey = eventContent['state_key'];
    }

    if (eventUpdate.eventType == EventTypes.Redaction) {
      await redactMessage(clientId, eventUpdate);
    }

    if (type == 'timeline' || type == 'history') {
      // calculate the status
      var status = 2;
      if (eventContent['status'] is num) status = eventContent['status'];
      if ((status == 1 || status == -1) &&
          eventContent['unsigned'] is Map<String, dynamic> &&
          eventContent['unsigned']['transaction_id'] is String) {
        // status changed and we have an old transaction id --> update event id and stuffs
        await updateEventStatus(status, eventContent['event_id'], clientId,
            eventContent['unsigned']['transaction_id'], chatId);
      } else {
        DbEvent oldEvent;
        if (type == 'history') {
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
          eventContent['origin_server_ts'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  eventContent['origin_server_ts'])
              : DateTime.now(),
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
          eventUpdate.content.containsKey('unsigned') &&
          eventUpdate.content['unsigned']['transaction_id'] is String) {
        await removeEvent(clientId,
            eventUpdate.content['unsigned']['transaction_id'], chatId);
      }
    }

    if (type == 'history') return;

    if (type != 'account_data') {
      final now = DateTime.now();
      await storeRoomState(
        clientId,
        eventContent['event_id'] ?? now.millisecondsSinceEpoch.toString(),
        chatId,
        eventUpdate.sortOrder ?? 0.0,
        eventContent['origin_server_ts'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                eventContent['origin_server_ts'])
            : now,
        eventContent['sender'],
        eventContent['type'],
        json.encode(eventContent['unsigned'] ?? ''),
        json.encode(eventContent['content']),
        json.encode(eventContent['prev_content'] ?? ''),
        stateKey,
      );
    } else if (type == 'account_data') {
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
    return sdk.Event.fromDb(event.first, room);
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
    return sdk.Event.fromDb(res.first, room).asUser;
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
    return res.first.bytes;
  }
}
