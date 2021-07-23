import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:matrix/encryption/utils/stored_inbound_group_session.dart';
import 'package:matrix/encryption/utils/ssss_cache.dart';
import 'package:matrix/encryption/utils/outbound_group_session.dart';
import 'package:matrix/encryption/utils/olm_session.dart';
import 'dart:typed_data';

import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/QueuedToDeviceEvent.dart';
import 'package:hive/hive.dart';

/// This is a basic database for the Matrix SDK using the hive store. You need
/// to make sure that you perform `Hive.init()` or `Hive.flutterInit()` before
/// you use this.
///
/// This database does not support file caching!
class FamedlySdkHiveDatabase extends DatabaseApi {
  static const int version = 3;
  final String name;
  Box _clientBox;
  Box _accountDataBox;
  Box _roomsBox;
  Box _toDeviceQueueBox;

  /// Key is a tuple as MultiKey(roomId, type) where stateKey can be
  /// an empty string.
  LazyBox _roomStateBox;

  /// Key is a tuple as MultiKey(roomId, userId)
  LazyBox _roomMembersBox;

  /// Key is a tuple as MultiKey(roomId, type)
  LazyBox _roomAccountDataBox;
  LazyBox _inboundGroupSessionsBox;
  LazyBox _outboundGroupSessionsBox;
  LazyBox _olmSessionsBox;

  /// Key is a tuple as MultiKey(userId, deviceId)
  LazyBox _userDeviceKeysBox;

  /// Key is the user ID as a String
  LazyBox _userDeviceKeysOutdatedBox;

  /// Key is a tuple as MultiKey(userId, publicKey)
  LazyBox _userCrossSigningKeysBox;
  LazyBox _ssssCacheBox;
  LazyBox _presencesBox;

  /// Key is a tuple as Multikey(roomId, fragmentId) while the default
  /// fragmentId is an empty String
  LazyBox _timelineFragmentsBox;

  /// Key is a tuple as MultiKey(roomId, eventId)
  LazyBox _eventsBox;

  String get _clientBoxName => '$name.box.client';
  String get _accountDataBoxName => '$name.box.account_data';
  String get _roomsBoxName => '$name.box.rooms';
  String get _toDeviceQueueBoxName => '$name.box.to_device_queue';
  String get _roomStateBoxName => '$name.box.room_states';
  String get _roomMembersBoxName => '$name.box.room_members';
  String get _roomAccountDataBoxName => '$name.box.room_account_data';
  String get _inboundGroupSessionsBoxName => '$name.box.inbound_group_session';
  String get _outboundGroupSessionsBoxName =>
      '$name.box.outbound_group_session';
  String get _olmSessionsBoxName => '$name.box.olm_session';
  String get _userDeviceKeysBoxName => '$name.box.user_device_keys';
  String get _userDeviceKeysOutdatedBoxName =>
      '$name.box.user_device_keys_outdated';
  String get _userCrossSigningKeysBoxName => '$name.box.cross_signing_keys';
  String get _ssssCacheBoxName => '$name.box.ssss_cache';
  String get _presencesBoxName => '$name.box.presences';
  String get _timelineFragmentsBoxName => '$name.box.timeline_fragments';
  String get _eventsBoxName => '$name.box.events';

  final HiveCipher encryptionCipher;

  FamedlySdkHiveDatabase(this.name, {this.encryptionCipher});

  @override
  int get maxFileSize => 0;

  Future<void> _actionOnAllBoxes(Future<void> Function(BoxBase box) action) =>
      Future.wait([
        action(_clientBox),
        action(_accountDataBox),
        action(_roomsBox),
        action(_roomStateBox),
        action(_roomMembersBox),
        action(_toDeviceQueueBox),
        action(_roomAccountDataBox),
        action(_inboundGroupSessionsBox),
        action(_outboundGroupSessionsBox),
        action(_olmSessionsBox),
        action(_userDeviceKeysBox),
        action(_userDeviceKeysOutdatedBox),
        action(_userCrossSigningKeysBox),
        action(_ssssCacheBox),
        action(_presencesBox),
        action(_timelineFragmentsBox),
        action(_eventsBox),
      ]);

  Future<void> open() async {
    _clientBox = await Hive.openBox(
      _clientBoxName,
      encryptionCipher: encryptionCipher,
    );
    _accountDataBox = await Hive.openBox(
      _accountDataBoxName,
      encryptionCipher: encryptionCipher,
    );
    _roomsBox = await Hive.openBox(
      _roomsBoxName,
      encryptionCipher: encryptionCipher,
    );
    _roomStateBox = await Hive.openLazyBox(
      _roomStateBoxName,
      encryptionCipher: encryptionCipher,
    );
    _roomMembersBox = await Hive.openLazyBox(
      _roomMembersBoxName,
      encryptionCipher: encryptionCipher,
    );
    _toDeviceQueueBox = await Hive.openBox(
      _toDeviceQueueBoxName,
      encryptionCipher: encryptionCipher,
    );
    _roomAccountDataBox = await Hive.openLazyBox(
      _roomAccountDataBoxName,
      encryptionCipher: encryptionCipher,
    );
    _inboundGroupSessionsBox = await Hive.openLazyBox(
      _inboundGroupSessionsBoxName,
      encryptionCipher: encryptionCipher,
    );
    _outboundGroupSessionsBox = await Hive.openLazyBox(
      _outboundGroupSessionsBoxName,
      encryptionCipher: encryptionCipher,
    );
    _olmSessionsBox = await Hive.openLazyBox(
      _olmSessionsBoxName,
      encryptionCipher: encryptionCipher,
    );
    _userDeviceKeysBox = await Hive.openLazyBox(
      _userDeviceKeysBoxName,
      encryptionCipher: encryptionCipher,
    );
    _userDeviceKeysOutdatedBox = await Hive.openLazyBox(
      _userDeviceKeysOutdatedBoxName,
      encryptionCipher: encryptionCipher,
    );
    _userCrossSigningKeysBox = await Hive.openLazyBox(
      _userCrossSigningKeysBoxName,
      encryptionCipher: encryptionCipher,
    );
    _ssssCacheBox = await Hive.openLazyBox(
      _ssssCacheBoxName,
      encryptionCipher: encryptionCipher,
    );
    _presencesBox = await Hive.openLazyBox(
      _presencesBoxName,
      encryptionCipher: encryptionCipher,
    );
    _timelineFragmentsBox = await Hive.openLazyBox(
      _timelineFragmentsBoxName,
      encryptionCipher: encryptionCipher,
    );
    _eventsBox = await Hive.openLazyBox(
      _eventsBoxName,
      encryptionCipher: encryptionCipher,
    );

    // Check version and check if we need a migration
    final currentVersion = (await _clientBox.get('version') as int);
    if (currentVersion == null) {
      await _clientBox.put('version', version);
    } else if (currentVersion != version) {
      await _migrateFromVersion(currentVersion);
    }

    return;
  }

  Future<void> _migrateFromVersion(int currentVersion) async {
    Logs().i('Migrate Hive database from version $currentVersion to $version');
    await clearCache(0);
    await _clientBox.put('version', version);
  }

  @override
  Future<void> clear(int clientId) async {
    Logs().i('Clear and close hive database...');
    await _actionOnAllBoxes((box) async {
      await box.deleteAll(box.keys);
      await box.close();
    });
    return;
  }

  @override
  Future<void> clearCache(int clientId) async {
    await _roomsBox.deleteAll(_roomsBox.keys);
    await _accountDataBox.deleteAll(_accountDataBox.keys);
    await _roomStateBox.deleteAll(_roomStateBox.keys);
    await _roomMembersBox.deleteAll(_roomMembersBox.keys);
    await _eventsBox.deleteAll(_eventsBox.keys);
    await _timelineFragmentsBox.deleteAll(_timelineFragmentsBox.keys);
    await _outboundGroupSessionsBox.deleteAll(_outboundGroupSessionsBox.keys);
    await _presencesBox.deleteAll(_presencesBox.keys);
    await _clientBox.delete('prev_batch');
  }

  @override
  Future<void> clearSSSSCache(int clientId) async {
    await _ssssCacheBox.deleteAll(_ssssCacheBox.keys);
  }

  @override
  Future<void> close() => _actionOnAllBoxes((box) => box.close());

  @override
  Future<void> deleteFromToDeviceQueue(int clientId, int id) async {
    await _toDeviceQueueBox.delete(id);
    return;
  }

  @override
  Future<void> deleteOldFiles(int savedAt) async {
    return;
  }

  @override
  Future<void> forgetRoom(int clientId, String roomId) async {
    await _timelineFragmentsBox.delete(MultiKey(roomId, '').toString());
    for (final key in _eventsBox.keys) {
      final multiKey = MultiKey.fromString(key);
      if (multiKey.parts.first != roomId) continue;
      await _eventsBox.delete(key);
    }
    for (final key in _roomStateBox.keys) {
      final multiKey = MultiKey.fromString(key);
      if (multiKey.parts.first != roomId) continue;
      await _roomStateBox.delete(key);
    }
    for (final key in _roomMembersBox.keys) {
      final multiKey = MultiKey.fromString(key);
      if (multiKey.parts.first != roomId) continue;
      await _roomMembersBox.delete(key);
    }
    for (final key in _roomAccountDataBox.keys) {
      final multiKey = MultiKey.fromString(key);
      if (multiKey.parts.first != roomId) continue;
      await _roomAccountDataBox.delete(key);
    }
    await _roomsBox.delete(roomId.toHiveKey);
  }

  @override
  Future<Map<String, BasicEvent>> getAccountData(int clientId) async {
    final accountData = <String, BasicEvent>{};
    for (final key in _accountDataBox.keys) {
      final raw = await _accountDataBox.get(key);
      accountData[key] = BasicEvent(
        type: key,
        content: convertToJson(raw),
      );
    }
    return accountData;
  }

  @override
  Future<Map<String, dynamic>> getClient(String name) async {
    final map = <String, dynamic>{};
    for (final key in _clientBox.keys) {
      if (key == 'version') continue;
      map[key] = await _clientBox.get(key);
    }
    if (map.isEmpty) return null;
    return map;
  }

  @override
  Future<Event> getEventById(int clientId, String eventId, Room room) async {
    final raw = await _eventsBox.get(MultiKey(room.id, eventId).toString());
    if (raw == null) return null;
    return Event.fromJson(convertToJson(raw), room);
  }

  @override
  Future<List<Event>> getEventList(int clientId, Room room) async {
    final List eventIds =
        (await _timelineFragmentsBox.get(MultiKey(room.id, '').toString()) ??
            []);
    final events = await Future.wait(eventIds
        .map(
          (eventId) async => Event.fromJson(
            convertToJson(
              await _eventsBox.get(MultiKey(room.id, eventId).toString()),
            ),
            room,
          ),
        )
        .toList());
    events.sort((a, b) => b.sortOrder.compareTo(a.sortOrder));
    return events;
  }

  @override
  Future<Uint8List> getFile(String mxcUri) async {
    return null;
  }

  @override
  Future<StoredInboundGroupSession> getInboundGroupSession(
    int clientId,
    String roomId,
    String sessionId,
  ) async {
    final raw = await _inboundGroupSessionsBox.get(sessionId.toHiveKey);
    if (raw == null) return null;
    return StoredInboundGroupSession.fromJson(convertToJson(raw));
  }

  @override
  Future<List<StoredInboundGroupSession>>
      getInboundGroupSessionsToUpload() async {
    final sessions = (await Future.wait(_inboundGroupSessionsBox.keys.map(
            (sessionId) async =>
                await _inboundGroupSessionsBox.get(sessionId))))
        .where((rawSession) => rawSession['uploaded'] == false)
        .take(500)
        .map(
          (json) => StoredInboundGroupSession.fromJson(
            convertToJson(json),
          ),
        )
        .toList();
    return sessions;
  }

  @override
  Future<List<String>> getLastSentMessageUserDeviceKey(
      int clientId, String userId, String deviceId) async {
    final raw =
        await _userDeviceKeysBox.get(MultiKey(userId, deviceId).toString());
    if (raw == null) return <String>[];
    return <String>[raw['last_sent_message']];
  }

  @override
  Future<void> storeOlmSession(int clientId, String identityKey,
      String sessionId, String pickle, int lastReceived) async {
    final rawSessions =
        (await _olmSessionsBox.get(identityKey.toHiveKey) as Map) ?? {};
    rawSessions[sessionId] = <String, dynamic>{
      'identity_key': identityKey,
      'pickle': pickle,
      'session_id': sessionId,
      'last_received': lastReceived,
    };
    await _olmSessionsBox.put(identityKey.toHiveKey, rawSessions);
    return;
  }

  @override
  Future<List<OlmSession>> getOlmSessions(
      int clientId, String identityKey, String userId) async {
    final rawSessions = await _olmSessionsBox.get(identityKey.toHiveKey) as Map;
    if (rawSessions?.isEmpty ?? true) return <OlmSession>[];
    return rawSessions.values
        .map((json) => OlmSession.fromJson(convertToJson(json), userId))
        .toList();
  }

  @override
  Future<List<OlmSession>> getOlmSessionsForDevices(
      int clientId, List<String> identityKey, String userId) async {
    final sessions = await Future.wait(identityKey
        .map((identityKey) => getOlmSessions(clientId, identityKey, userId)));
    return <OlmSession>[for (final sublist in sessions) ...sublist];
  }

  @override
  Future<OutboundGroupSession> getOutboundGroupSession(
      int clientId, String roomId, String userId) async {
    final raw = await _outboundGroupSessionsBox.get(roomId.toHiveKey);
    if (raw == null) return null;
    return OutboundGroupSession.fromJson(convertToJson(raw), userId);
  }

  @override
  Future<List<Room>> getRoomList(Client client) async {
    final rooms = <String, Room>{};
    final importantRoomStates = client.importantStateEvents;
    for (final key in _roomsBox.keys) {
      // Get the room
      final raw = await _roomsBox.get(key);
      final room = Room.fromJson(convertToJson(raw), client);

      // let's see if we need any m.room.member events
      // We always need the member event for ourself
      final membersToPostload = <String>{client.userID};
      // If the room is a direct chat, those IDs should be there too
      if (room.isDirectChat) membersToPostload.add(room.directChatMatrixID);
      // the lastEvent message preview might have an author we need to fetch, if it is a group chat
      if (room.getState(EventTypes.Message) != null && !room.isDirectChat) {
        membersToPostload.add(room.getState(EventTypes.Message).senderId);
      }
      // if the room has no name and no canonical alias, its name is calculated
      // based on the heroes of the room
      if (room.getState(EventTypes.RoomName) == null &&
          room.getState(EventTypes.RoomCanonicalAlias) == null) {
        // we don't have a name and no canonical alias, so we'll need to
        // post-load the heroes
        membersToPostload.addAll(room.summary?.mHeroes ?? []);
      }
      // Load members
      for (final userId in membersToPostload) {
        final state =
            await _roomMembersBox.get(MultiKey(room.id, userId).toString());
        if (state == null) {
          Logs().w('Unable to post load member $userId');
          continue;
        }
        room.setState(Event.fromJson(convertToJson(state), room));
      }

      // Get the "important" room states. All other states will be loaded once
      // `getUnimportantRoomStates()` is called.
      for (final type in importantRoomStates) {
        final Map states =
            await _roomStateBox.get(MultiKey(room.id, type).toString());
        if (states == null) continue;
        final stateEvents = states.values
            .map((raw) => Event.fromJson(convertToJson(raw), room))
            .toList();
        for (final state in stateEvents) {
          room.setState(state);
        }
      }

      // Add to the list and continue.
      rooms[room.id] = room;
    }

    // Get the room account data
    for (final key in _roomAccountDataBox.keys) {
      final roomId = MultiKey.fromString(key).parts.first;
      if (rooms.containsKey(roomId)) {
        final raw = await _roomAccountDataBox.get(key);
        final basicRoomEvent = BasicRoomEvent.fromJson(
          convertToJson(raw),
        );
        rooms[roomId].roomAccountData[basicRoomEvent.type] = basicRoomEvent;
      } else {
        Logs().w('Found account data for unknown room $roomId. Delete now...');
        await _roomAccountDataBox.delete(key);
      }
    }

    return rooms.values.toList();
  }

  @override
  Future<SSSSCache> getSSSSCache(int clientId, String type) async {
    final raw = await _ssssCacheBox.get(type);
    if (raw == null) return null;
    return SSSSCache.fromJson(convertToJson(raw));
  }

  @override
  Future<List<QueuedToDeviceEvent>> getToDeviceEventQueue(int clientId) async =>
      await Future.wait(_toDeviceQueueBox.keys.map((i) async {
        final raw = await _toDeviceQueueBox.get(i);
        raw['id'] = i;
        return QueuedToDeviceEvent.fromJson(convertToJson(raw));
      }).toList());

  @override
  Future<List<Event>> getUnimportantRoomEventStatesForRoom(
      int clientId, List<String> events, Room room) async {
    final keys = _roomStateBox.keys.where((key) {
      final tuple = MultiKey.fromString(key);
      return tuple.parts.first == room.id && !events.contains(tuple.parts[1]);
    });

    final unimportantEvents = <Event>[];
    for (final key in keys) {
      final Map states = await _roomStateBox.get(key);
      unimportantEvents.addAll(
          states.values.map((raw) => Event.fromJson(convertToJson(raw), room)));
    }
    return unimportantEvents;
  }

  @override
  Future<User> getUser(int clientId, String userId, Room room) async {
    final state =
        await _roomMembersBox.get(MultiKey(room.id, userId).toString());
    if (state == null) return null;
    return Event.fromJson(convertToJson(state), room).asUser;
  }

  @override
  Future<Map<String, DeviceKeysList>> getUserDeviceKeys(Client client) async {
    final deviceKeysOutdated = _userDeviceKeysOutdatedBox.keys;
    if (deviceKeysOutdated.isEmpty) {
      return {};
    }
    final res = <String, DeviceKeysList>{};
    for (final userId in deviceKeysOutdated) {
      final deviceKeysBoxKeys = _userDeviceKeysBox.keys.where((tuple) {
        final tupleKey = MultiKey.fromString(tuple);
        return tupleKey.parts.first == userId;
      });
      final crossSigningKeysBoxKeys =
          _userCrossSigningKeysBox.keys.where((tuple) {
        final tupleKey = MultiKey.fromString(tuple);
        return tupleKey.parts.first == userId;
      });
      res[userId] = DeviceKeysList.fromDbJson(
          {
            'client_id': client.id,
            'user_id': userId,
            'outdated': await _userDeviceKeysOutdatedBox.get(userId),
          },
          await Future.wait(deviceKeysBoxKeys.map(
              (key) async => convertToJson(await _userDeviceKeysBox.get(key)))),
          await Future.wait(crossSigningKeysBoxKeys.map((key) async =>
              convertToJson(await _userCrossSigningKeysBox.get(key)))),
          client);
    }
    return res;
  }

  @override
  Future<List<User>> getUsers(int clientId, Room room) async {
    final users = <User>[];
    for (final key in _roomMembersBox.keys) {
      final statesKey = MultiKey.fromString(key);
      if (statesKey.parts[0] != room.id) continue;
      final state = await _roomMembersBox.get(key);
      users.add(Event.fromJson(convertToJson(state), room).asUser);
    }
    return users;
  }

  @override
  Future<void> insertClient(
      String name,
      String homeserverUrl,
      String token,
      String userId,
      String deviceId,
      String deviceName,
      String prevBatch,
      String olmAccount) async {
    await _clientBox.put('homeserver_url', homeserverUrl);
    await _clientBox.put('token', token);
    await _clientBox.put('user_id', userId);
    await _clientBox.put('device_id', deviceId);
    await _clientBox.put('device_name', deviceName);
    await _clientBox.put('prev_batch', prevBatch);
    await _clientBox.put('olm_account', olmAccount);
    await _clientBox.put('sync_filter_id', null);
    return;
  }

  @override
  Future<int> insertIntoToDeviceQueue(
      int clientId, String type, String txnId, String content) async {
    return await _toDeviceQueueBox.add(<String, dynamic>{
      'type': type,
      'txn_id': txnId,
      'content': content,
    });
  }

  @override
  Future<void> markInboundGroupSessionAsUploaded(
      int clientId, String roomId, String sessionId) async {
    final raw = await _inboundGroupSessionsBox.get(sessionId.toHiveKey);
    if (raw == null) {
      Logs().w(
          'Tried to mark inbound group session as uploaded which was not found in the database!');
      return;
    }
    raw['uploaded'] = true;
    await _inboundGroupSessionsBox.put(sessionId.toHiveKey, raw);
    return;
  }

  @override
  Future<void> markInboundGroupSessionsAsNeedingUpload(int clientId) async {
    for (final sessionId in _inboundGroupSessionsBox.keys) {
      final raw = await _inboundGroupSessionsBox.get(sessionId);
      raw['uploaded'] = false;
      await _inboundGroupSessionsBox.put(sessionId, raw);
    }
    return;
  }

  @override
  Future<void> removeEvent(int clientId, String eventId, String roomId) async {
    await _eventsBox.delete(MultiKey(roomId, eventId).toString());
    for (final key in _timelineFragmentsBox.keys) {
      final multiKey = MultiKey.fromString(key);
      if (multiKey.parts.first != roomId) continue;
      final List eventIds = await _timelineFragmentsBox.get(key) ?? [];
      final prevLength = eventIds.length;
      eventIds.removeWhere((id) => id == eventId);
      if (eventIds.length < prevLength) {
        await _timelineFragmentsBox.put(key, eventIds);
      }
    }
    return;
  }

  @override
  Future<void> removeOutboundGroupSession(int clientId, String roomId) async {
    await _outboundGroupSessionsBox.delete(roomId.toHiveKey);
    return;
  }

  @override
  Future<void> removeUserCrossSigningKey(
      int clientId, String userId, String publicKey) async {
    await _userCrossSigningKeysBox
        .delete(MultiKey(userId, publicKey).toString());
    return;
  }

  @override
  Future<void> removeUserDeviceKey(
      int clientId, String userId, String deviceId) async {
    await _userDeviceKeysBox.delete(MultiKey(userId, deviceId).toString());
    return;
  }

  @override
  Future<void> resetNotificationCount(int clientId, String roomId) async {
    final raw = await _roomsBox.get(roomId.toHiveKey);
    if (raw == null) return;
    raw['notification_count'] = raw['highlight_count'] = 0;
    await _roomsBox.put(roomId.toHiveKey, raw);
    return;
  }

  @override
  Future<void> setBlockedUserCrossSigningKey(
      bool blocked, int clientId, String userId, String publicKey) async {
    final raw = await _userCrossSigningKeysBox
        .get(MultiKey(userId, publicKey).toString());
    raw['blocked'] = blocked;
    await _userCrossSigningKeysBox.put(
      MultiKey(userId, publicKey).toString(),
      raw,
    );
    return;
  }

  @override
  Future<void> setBlockedUserDeviceKey(
      bool blocked, int clientId, String userId, String deviceId) async {
    final raw =
        await _userDeviceKeysBox.get(MultiKey(userId, deviceId).toString());
    raw['blocked'] = blocked;
    await _userDeviceKeysBox.put(
      MultiKey(userId, deviceId).toString(),
      raw,
    );
    return;
  }

  @override
  Future<void> setLastActiveUserDeviceKey(
      int lastActive, int clientId, String userId, String deviceId) async {
    final raw =
        await _userDeviceKeysBox.get(MultiKey(userId, deviceId).toString());
    raw['last_active'] = lastActive;
    await _userDeviceKeysBox.put(
      MultiKey(userId, deviceId).toString(),
      raw,
    );
  }

  @override
  Future<void> setLastSentMessageUserDeviceKey(String lastSentMessage,
      int clientId, String userId, String deviceId) async {
    final raw =
        await _userDeviceKeysBox.get(MultiKey(userId, deviceId).toString());
    raw['last_sent_message'] = lastSentMessage;
    await _userDeviceKeysBox.put(
      MultiKey(userId, deviceId).toString(),
      raw,
    );
  }

  @override
  Future<void> setRoomPrevBatch(
      String prevBatch, int clientId, String roomId) async {
    final raw = await _roomsBox.get(roomId.toHiveKey);
    if (raw == null) return;
    final room = Room.fromJson(convertToJson(raw));
    room.prev_batch = prevBatch;
    await _roomsBox.put(roomId.toHiveKey, room.toJson());
    return;
  }

  @override
  Future<void> setVerifiedUserCrossSigningKey(
      bool verified, int clientId, String userId, String publicKey) async {
    final raw = (await _userCrossSigningKeysBox
            .get(MultiKey(userId, publicKey).toString()) as Map) ??
        {};
    raw['verified'] = verified;
    await _userCrossSigningKeysBox.put(
      MultiKey(userId, publicKey).toString(),
      raw,
    );
    return;
  }

  @override
  Future<void> setVerifiedUserDeviceKey(
      bool verified, int clientId, String userId, String deviceId) async {
    final raw =
        await _userDeviceKeysBox.get(MultiKey(userId, deviceId).toString());
    raw['verified'] = verified;
    await _userDeviceKeysBox.put(
      MultiKey(userId, deviceId).toString(),
      raw,
    );
    return;
  }

  @override
  Future<void> storeAccountData(
      int clientId, String type, String content) async {
    await _accountDataBox.put(
        type.toHiveKey, convertToJson(jsonDecode(content)));
    return;
  }

  @override
  Future<void> storeEventUpdate(int clientId, EventUpdate eventUpdate) async {
    // Ephemerals should not be stored
    if (eventUpdate.type == EventUpdateType.ephemeral) return;

    // In case of this is a redaction event
    if (eventUpdate.content['type'] == EventTypes.Redaction) {
      final tmpRoom = Room(id: eventUpdate.roomID);
      final event =
          await getEventById(clientId, eventUpdate.content['redacts'], tmpRoom);
      if (event != null) {
        event.setRedactionEvent(Event.fromJson(eventUpdate.content, tmpRoom));
        await _eventsBox.put(
            MultiKey(eventUpdate.roomID, event.eventId).toString(),
            event.toJson());
      }
    }

    // Store a common message event
    if ({EventUpdateType.timeline, EventUpdateType.history}
        .contains(eventUpdate.type)) {
      final eventId = eventUpdate.content['event_id'];
      // Is this ID already in the store?
      final prevEvent = _eventsBox
              .containsKey(MultiKey(eventUpdate.roomID, eventId).toString())
          ? Event.fromJson(
              convertToJson(await _eventsBox
                  .get(MultiKey(eventUpdate.roomID, eventId).toString())),
              null)
          : null;

      // calculate the status
      final newStatus =
          eventUpdate.content.tryGet<int>('status', TryGet.optional) ??
              eventUpdate.content
                  .tryGetMap<String, dynamic>('unsigned', TryGet.optional)
                  ?.tryGet<int>(messageSendingStatusKey, TryGet.optional) ??
              2;

      final status = newStatus == -1 || prevEvent?.status == null
          ? newStatus
          : max(prevEvent.status, newStatus);

      // Add the status and the sort order to the content so it get stored
      eventUpdate.content['unsigned'] ??= <String, dynamic>{};
      eventUpdate.content['unsigned'][messageSendingStatusKey] =
          eventUpdate.content['status'] = status;
      eventUpdate.content['unsigned'][sortOrderKey] = eventUpdate.sortOrder;

      // In case this event has sent from this account we have a transaction ID
      final transactionId = eventUpdate.content
          .tryGetMap<String, dynamic>('unsigned', TryGet.optional)
          ?.tryGet<String>('transaction_id', TryGet.optional);

      await _eventsBox.put(MultiKey(eventUpdate.roomID, eventId).toString(),
          eventUpdate.content);

      // Update timeline fragments
      final key = MultiKey(eventUpdate.roomID, '').toString();
      final List eventIds = (await _timelineFragmentsBox.get(key) ?? []);
      if (!eventIds.any((id) => id == eventId)) {
        eventIds.add(eventId);
        await _timelineFragmentsBox.put(key, eventIds);
      }

      // Is there a transaction id? Then delete the event with this id.
      if (status != -1 && status != 0 && transactionId != null) {
        await removeEvent(clientId, transactionId, eventUpdate.roomID);
      }
    }

    // Store a common state event
    if ({EventUpdateType.timeline, EventUpdateType.state}
        .contains(eventUpdate.type)) {
      if (eventUpdate.content['type'] == EventTypes.RoomMember) {
        await _roomMembersBox.put(
            MultiKey(
              eventUpdate.roomID,
              eventUpdate.content['state_key'],
            ).toString(),
            eventUpdate.content);
      } else {
        final key = MultiKey(
          eventUpdate.roomID,
          eventUpdate.content['type'],
        ).toString();
        final Map stateMap = await _roomStateBox.get(key) ?? {};
        stateMap[eventUpdate.content['state_key']] = eventUpdate.content;
        await _roomStateBox.put(key, stateMap);
      }
    }

    // Store a room account data event
    if (eventUpdate.type == EventUpdateType.accountData) {
      await _roomAccountDataBox.put(
        MultiKey(
          eventUpdate.roomID,
          eventUpdate.content['type'],
        ).toString(),
        eventUpdate.content,
      );
    }
  }

  @override
  Future<void> storeFile(String mxcUri, Uint8List bytes, int time) async {
    return;
  }

  @override
  Future<void> storeInboundGroupSession(
      int clientId,
      String roomId,
      String sessionId,
      String pickle,
      String content,
      String indexes,
      String allowedAtIndex,
      String senderKey,
      String senderClaimedKey) async {
    await _inboundGroupSessionsBox.put(
        sessionId.toHiveKey,
        StoredInboundGroupSession(
          clientId: clientId,
          roomId: roomId,
          sessionId: sessionId,
          pickle: pickle,
          content: content,
          indexes: indexes,
          allowedAtIndex: allowedAtIndex,
          senderKey: senderKey,
          senderClaimedKeys: senderClaimedKey,
          uploaded: false,
        ).toJson());
    return;
  }

  @override
  Future<void> storeOutboundGroupSession(
      int clientId,
      String roomId,
      String pickle,
      String deviceIds,
      int creationTime,
      int sentMessages) async {
    await _outboundGroupSessionsBox.put(roomId.toHiveKey, <String, dynamic>{
      'room_id': roomId,
      'pickle': pickle,
      'device_ids': deviceIds,
      'creation_time': creationTime,
      'sent_messages': sentMessages ?? 0,
    });
    return;
  }

  @override
  Future<void> storePrevBatch(String prevBatch, int clientId) async {
    if (_clientBox.keys.isEmpty) return;
    await _clientBox.put('prev_batch', prevBatch);
    return;
  }

  @override
  Future<void> storeRoomUpdate(int clientId, RoomUpdate roomUpdate, [_]) async {
    // Leave room if membership is leave
    if ({Membership.leave, Membership.ban}.contains(roomUpdate.membership)) {
      await forgetRoom(clientId, roomUpdate.id);
      return;
    }
    // Make sure room exists
    if (!_roomsBox.containsKey(roomUpdate.id.toHiveKey)) {
      await _roomsBox.put(
          roomUpdate.id.toHiveKey,
          Room(
            id: roomUpdate.id,
            membership: roomUpdate.membership,
            highlightCount: roomUpdate.highlight_count,
            notificationCount: roomUpdate.notification_count,
            prev_batch: roomUpdate.prev_batch,
            summary: roomUpdate.summary,
          ).toJson());
    } else {
      final currentRawRoom = await _roomsBox.get(roomUpdate.id.toHiveKey);
      final currentRoom = Room.fromJson(convertToJson(currentRawRoom));
      await _roomsBox.put(
          roomUpdate.id.toHiveKey,
          Room(
            id: roomUpdate.id,
            membership: roomUpdate.membership ?? currentRoom.membership,
            highlightCount:
                roomUpdate.highlight_count ?? currentRoom.highlightCount,
            notificationCount:
                roomUpdate.notification_count ?? currentRoom.notificationCount,
            prev_batch: roomUpdate.prev_batch ?? currentRoom.prev_batch,
            summary: RoomSummary.fromJson(currentRoom.summary.toJson()
              ..addAll(roomUpdate.summary?.toJson() ?? {})),
            newestSortOrder:
                roomUpdate.limitedTimeline ? 0.0 : currentRoom.newSortOrder,
            oldestSortOrder:
                roomUpdate.limitedTimeline ? 0.0 : currentRoom.oldSortOrder,
          ).toJson());
    }

    // Is the timeline limited? Then all previous messages should be
    // removed from the database!
    if (roomUpdate.limitedTimeline) {
      await _timelineFragmentsBox
          .delete(MultiKey(roomUpdate.id, '').toString());
    }
  }

  @override
  Future<void> storeSSSSCache(int clientId, String type, String keyId,
      String ciphertext, String content) async {
    await _ssssCacheBox.put(
        type,
        SSSSCache(
          type: type,
          keyId: keyId,
          ciphertext: ciphertext,
          content: content,
        ).toJson());
  }

  @override
  Future<void> storeSyncFilterId(String syncFilterId, int clientId) async {
    await _clientBox.put('sync_filter_id', syncFilterId);
  }

  @override
  Future<void> storeUserCrossSigningKey(int clientId, String userId,
      String publicKey, String content, bool verified, bool blocked) async {
    await _userCrossSigningKeysBox.put(
      MultiKey(userId, publicKey).toString(),
      {
        'user_id': userId,
        'public_key': publicKey,
        'content': content,
        'verified': verified,
        'blocked': blocked,
      },
    );
  }

  @override
  Future<void> storeUserDeviceKey(int clientId, String userId, String deviceId,
      String content, bool verified, bool blocked, int lastActive) async {
    await _userDeviceKeysBox.put(MultiKey(userId, deviceId).toString(), {
      'user_id': userId,
      'device_id': deviceId,
      'content': content,
      'verified': verified,
      'blocked': blocked,
      'last_active': lastActive,
      'last_sent_message': '',
    });
    return;
  }

  @override
  Future<void> storeUserDeviceKeysInfo(
      int clientId, String userId, bool outdated) async {
    await _userDeviceKeysOutdatedBox.put(userId.toHiveKey, outdated);
    return;
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) => action();

  @override
  Future<void> updateClient(
      String homeserverUrl,
      String token,
      String userId,
      String deviceId,
      String deviceName,
      String prevBatch,
      String olmAccount,
      int clientId) async {
    await _clientBox.put('homeserver_url', homeserverUrl);
    await _clientBox.put('token', token);
    await _clientBox.put('user_id', userId);
    await _clientBox.put('device_id', deviceId);
    await _clientBox.put('device_name', deviceName);
    await _clientBox.put('prev_batch', prevBatch);
    await _clientBox.put('olm_account', olmAccount);
    return;
  }

  @override
  Future<void> updateClientKeys(String olmAccount, int clientId) async {
    await _clientBox.put('olm_account', olmAccount);
    return;
  }

  @override
  Future<void> updateInboundGroupSessionAllowedAtIndex(String allowedAtIndex,
      int clientId, String roomId, String sessionId) async {
    final raw = await _inboundGroupSessionsBox.get(sessionId.toHiveKey);
    if (raw == null) {
      Logs().w(
          'Tried to update inbound group session as uploaded which wasnt found in the database!');
      return;
    }
    raw['allowed_at_index'] = allowedAtIndex;
    await _inboundGroupSessionsBox.put(sessionId.toHiveKey, raw);
    return;
  }

  @override
  Future<void> updateInboundGroupSessionIndexes(
      String indexes, int clientId, String roomId, String sessionId) async {
    final raw = await _inboundGroupSessionsBox.get(sessionId.toHiveKey);
    if (raw == null) {
      Logs().w(
          'Tried to update inbound group session indexes of a session which was not found in the database!');
      return;
    }
    raw['indexes'] = indexes;
    await _inboundGroupSessionsBox.put(sessionId.toHiveKey, raw);
    return;
  }

  @override
  Future<void> updateRoomSortOrder(double oldestSortOrder,
      double newestSortOrder, int clientId, String roomId) async {
    final raw = await _roomsBox.get(roomId.toHiveKey);
    raw['oldest_sort_order'] = oldestSortOrder;
    raw['newest_sort_order'] = newestSortOrder;
    await _roomsBox.put(roomId.toHiveKey, raw);
    return;
  }

  @override
  Future<List<StoredInboundGroupSession>> getAllInboundGroupSessions(
      int clientId) async {
    final rawSessions = await Future.wait(_inboundGroupSessionsBox.keys
        .map((key) => _inboundGroupSessionsBox.get(key)));
    return rawSessions
        .map((raw) => StoredInboundGroupSession.fromJson(convertToJson(raw)))
        .toList();
  }
}

dynamic _castValue(dynamic value) {
  if (value is Map) {
    return convertToJson(value);
  }
  if (value is List) {
    return value.map(_castValue).toList();
  }
  return value;
}

/// Hive always gives back an `_InternalLinkedHasMap<dynamic, dynamic>`. This
/// creates a deep copy of the json and makes sure that the format is always
/// `Map<String, dynamic>`.
Map<String, dynamic> convertToJson(Map map) {
  final copy = Map<String, dynamic>.from(map);
  for (final entry in copy.entries) {
    copy[entry.key] = _castValue(entry.value);
  }
  return copy;
}

class MultiKey {
  final List<String> parts;
  MultiKey(String key1, [String key2, String key3])
      : parts = [
          key1,
          if (key2 != null) key2,
          if (key3 != null) key3,
        ];
  const MultiKey.byParts(this.parts);

  MultiKey.fromString(String multiKeyString)
      : parts = multiKeyString.split('|');

  @override
  String toString() => parts.map((s) => s.toHiveKey).join('|');

  @override
  bool operator ==(other) => parts.toString() == other.toString();
}

extension HiveKeyExtension on String {
  String get toHiveKey => isValidMatrixId
      ? '$sigil${Uri.encodeComponent(localpart)}:${Uri.encodeComponent(domain)}'
      : Uri.encodeComponent(this);
}
