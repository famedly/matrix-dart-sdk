/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020, 2021 Famedly GmbH
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
import 'dart:math';

import 'package:sqflite_common/sqflite.dart';

import 'package:matrix/encryption/utils/olm_session.dart';
import 'package:matrix/encryption/utils/outbound_group_session.dart';
import 'package:matrix/encryption/utils/ssss_cache.dart';
import 'package:matrix/encryption/utils/stored_inbound_group_session.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/copy_map.dart';
import 'package:matrix/src/utils/queued_to_device_event.dart';
import 'package:matrix/src/utils/run_benchmarked.dart';

import 'package:matrix/src/database/indexeddb_box.dart'
    if (dart.library.io) 'package:matrix/src/database/sqflite_box.dart';

import 'package:matrix/src/database/database_file_storage_stub.dart'
    if (dart.library.io) 'package:matrix/src/database/database_file_storage_io.dart';

/// Database based on SQlite3 on native and IndexedDB on web. For native you
/// have to pass a `Database` object, which can be created with the sqflite
/// package like this:
/// ```dart
/// final database = await openDatabase('path/to/your/database');
/// ```
///
/// **WARNING**: For android it seems like that the CursorWindow is too small for
/// large amounts of data if you are using SQFlite. Consider using a different
///  package to open the database like
/// [sqflite_sqlcipher](https://pub.dev/packages/sqflite_sqlcipher) or
/// [sqflite_common_ffi](https://pub.dev/packages/sqflite_common_ffi).
/// Learn more at:
/// https://github.com/famedly/matrix-dart-sdk/issues/1642#issuecomment-1865827227
class MatrixSdkDatabase extends DatabaseApi with DatabaseFileStorage {
  static const int version = 9;
  final String name;

  late BoxCollection _collection;
  late Box<String> _clientBox;
  late Box<Map> _accountDataBox;
  late Box<Map> _roomsBox;
  late Box<Map> _toDeviceQueueBox;

  /// Key is a tuple as TupleKey(roomId, type) where stateKey can be
  /// an empty string. Must contain only states of type
  /// client.importantRoomStates.
  late Box<Map> _preloadRoomStateBox;

  /// Key is a tuple as TupleKey(roomId, type) where stateKey can be
  /// an empty string. Must NOT contain states of a type from
  /// client.importantRoomStates.
  late Box<Map> _nonPreloadRoomStateBox;

  /// Key is a tuple as TupleKey(roomId, userId)
  late Box<Map> _roomMembersBox;

  /// Key is a tuple as TupleKey(roomId, type)
  late Box<Map> _roomAccountDataBox;
  late Box<Map> _inboundGroupSessionsBox;
  late Box<String> _inboundGroupSessionsUploadQueueBox;
  late Box<Map> _outboundGroupSessionsBox;
  late Box<Map> _olmSessionsBox;

  /// Key is a tuple as TupleKey(userId, deviceId)
  late Box<Map> _userDeviceKeysBox;

  /// Key is the user ID as a String
  late Box<bool> _userDeviceKeysOutdatedBox;

  /// Key is a tuple as TupleKey(userId, publicKey)
  late Box<Map> _userCrossSigningKeysBox;
  late Box<Map> _ssssCacheBox;
  late Box<Map> _presencesBox;

  /// Key is a tuple as Multikey(roomId, fragmentId) while the default
  /// fragmentId is an empty String
  late Box<List> _timelineFragmentsBox;

  /// Key is a tuple as TupleKey(roomId, eventId)
  late Box<Map> _eventsBox;

  /// Key is a tuple as TupleKey(userId, deviceId)
  late Box<String> _seenDeviceIdsBox;

  late Box<String> _seenDeviceKeysBox;

  late Box<Map> _userProfilesBox;

  @override
  final int maxFileSize;

  // there was a field of type `dart:io:Directory` here. This one broke the
  // dart js standalone compiler. Migration via URI as file system identifier.
  @Deprecated(
      'Breaks support for web standalone. Use [fileStorageLocation] instead.')
  Object? get fileStoragePath => fileStorageLocation?.toFilePath();

  static const String _clientBoxName = 'box_client';

  static const String _accountDataBoxName = 'box_account_data';

  static const String _roomsBoxName = 'box_rooms';

  static const String _toDeviceQueueBoxName = 'box_to_device_queue';

  static const String _preloadRoomStateBoxName = 'box_preload_room_states';

  static const String _nonPreloadRoomStateBoxName =
      'box_non_preload_room_states';

  static const String _roomMembersBoxName = 'box_room_members';

  static const String _roomAccountDataBoxName = 'box_room_account_data';

  static const String _inboundGroupSessionsBoxName =
      'box_inbound_group_session';

  static const String _inboundGroupSessionsUploadQueueBoxName =
      'box_inbound_group_sessions_upload_queue';

  static const String _outboundGroupSessionsBoxName =
      'box_outbound_group_session';

  static const String _olmSessionsBoxName = 'box_olm_session';

  static const String _userDeviceKeysBoxName = 'box_user_device_keys';

  static const String _userDeviceKeysOutdatedBoxName =
      'box_user_device_keys_outdated';

  static const String _userCrossSigningKeysBoxName = 'box_cross_signing_keys';

  static const String _ssssCacheBoxName = 'box_ssss_cache';

  static const String _presencesBoxName = 'box_presences';

  static const String _timelineFragmentsBoxName = 'box_timeline_fragments';

  static const String _eventsBoxName = 'box_events';

  static const String _seenDeviceIdsBoxName = 'box_seen_device_ids';

  static const String _seenDeviceKeysBoxName = 'box_seen_device_keys';

  static const String _userProfilesBoxName = 'box_user_profiles';

  Database? database;

  /// Custom IdbFactory used to create the indexedDB. On IO platforms it would
  /// lead to an error to import "dart:indexed_db" so this is dynamically
  /// typed.
  final dynamic idbFactory;

  /// Custom SQFlite Database Factory used for high level operations on IO
  /// like delete. Set it if you want to use sqlite FFI.
  final DatabaseFactory? sqfliteFactory;

  MatrixSdkDatabase(
    this.name, {
    this.database,
    this.idbFactory,
    this.sqfliteFactory,
    this.maxFileSize = 0,
    // TODO : remove deprecated member migration on next major release
    @Deprecated(
        'Breaks support for web standalone. Use [fileStorageLocation] instead.')
    dynamic fileStoragePath,
    Uri? fileStorageLocation,
    Duration? deleteFilesAfterDuration,
  }) {
    final legacyPath = fileStoragePath?.path;
    this.fileStorageLocation = fileStorageLocation ??
        (legacyPath is String ? Uri.tryParse(legacyPath) : null);
    this.deleteFilesAfterDuration = deleteFilesAfterDuration;
  }

  Future<void> open() async {
    _collection = await BoxCollection.open(
      name,
      {
        _clientBoxName,
        _accountDataBoxName,
        _roomsBoxName,
        _toDeviceQueueBoxName,
        _preloadRoomStateBoxName,
        _nonPreloadRoomStateBoxName,
        _roomMembersBoxName,
        _roomAccountDataBoxName,
        _inboundGroupSessionsBoxName,
        _inboundGroupSessionsUploadQueueBoxName,
        _outboundGroupSessionsBoxName,
        _olmSessionsBoxName,
        _userDeviceKeysBoxName,
        _userDeviceKeysOutdatedBoxName,
        _userCrossSigningKeysBoxName,
        _ssssCacheBoxName,
        _presencesBoxName,
        _timelineFragmentsBoxName,
        _eventsBoxName,
        _seenDeviceIdsBoxName,
        _seenDeviceKeysBoxName,
        _userProfilesBoxName,
      },
      sqfliteDatabase: database,
      sqfliteFactory: sqfliteFactory,
      idbFactory: idbFactory,
      version: version,
    );
    _clientBox = _collection.openBox<String>(
      _clientBoxName,
    );
    _accountDataBox = _collection.openBox<Map>(
      _accountDataBoxName,
    );
    _roomsBox = _collection.openBox<Map>(
      _roomsBoxName,
    );
    _preloadRoomStateBox = _collection.openBox(
      _preloadRoomStateBoxName,
    );
    _nonPreloadRoomStateBox = _collection.openBox(
      _nonPreloadRoomStateBoxName,
    );
    _roomMembersBox = _collection.openBox(
      _roomMembersBoxName,
    );
    _toDeviceQueueBox = _collection.openBox(
      _toDeviceQueueBoxName,
    );
    _roomAccountDataBox = _collection.openBox(
      _roomAccountDataBoxName,
    );
    _inboundGroupSessionsBox = _collection.openBox(
      _inboundGroupSessionsBoxName,
    );
    _inboundGroupSessionsUploadQueueBox = _collection.openBox(
      _inboundGroupSessionsUploadQueueBoxName,
    );
    _outboundGroupSessionsBox = _collection.openBox(
      _outboundGroupSessionsBoxName,
    );
    _olmSessionsBox = _collection.openBox(
      _olmSessionsBoxName,
    );
    _userDeviceKeysBox = _collection.openBox(
      _userDeviceKeysBoxName,
    );
    _userDeviceKeysOutdatedBox = _collection.openBox(
      _userDeviceKeysOutdatedBoxName,
    );
    _userCrossSigningKeysBox = _collection.openBox(
      _userCrossSigningKeysBoxName,
    );
    _ssssCacheBox = _collection.openBox(
      _ssssCacheBoxName,
    );
    _presencesBox = _collection.openBox(
      _presencesBoxName,
    );
    _timelineFragmentsBox = _collection.openBox(
      _timelineFragmentsBoxName,
    );
    _eventsBox = _collection.openBox(
      _eventsBoxName,
    );
    _seenDeviceIdsBox = _collection.openBox(
      _seenDeviceIdsBoxName,
    );
    _seenDeviceKeysBox = _collection.openBox(
      _seenDeviceKeysBoxName,
    );
    _userProfilesBox = _collection.openBox(
      _userProfilesBoxName,
    );

    // Check version and check if we need a migration
    final currentVersion = int.tryParse(await _clientBox.get('version') ?? '');
    if (currentVersion == null) {
      await _clientBox.put('version', version.toString());
    } else if (currentVersion != version) {
      await _migrateFromVersion(currentVersion);
    }

    return;
  }

  Future<void> _migrateFromVersion(int currentVersion) async {
    Logs().i('Migrate store database from version $currentVersion to $version');

    if (version == 8) {
      // Migrate to inbound group sessions upload queue:
      final allInboundGroupSessions = await getAllInboundGroupSessions();
      final sessionsToUpload = allInboundGroupSessions
          // ignore: deprecated_member_use_from_same_package
          .where((session) => session.uploaded == false)
          .toList();
      Logs().i(
          'Move ${allInboundGroupSessions.length} inbound group sessions to upload to their own queue...');
      await transaction(() async {
        for (final session in sessionsToUpload) {
          await _inboundGroupSessionsUploadQueueBox.put(
            session.sessionId,
            session.roomId,
          );
        }
      });
      if (currentVersion == 7) {
        await _clientBox.put('version', version.toString());
        return;
      }
    }
    // The default version upgrade:
    await clearCache();
    await _clientBox.put('version', version.toString());
  }

  @override
  Future<void> clear() => _collection.clear();

  @override
  Future<void> clearCache() => transaction(() async {
        await _roomsBox.clear();
        await _accountDataBox.clear();
        await _roomAccountDataBox.clear();
        await _preloadRoomStateBox.clear();
        await _nonPreloadRoomStateBox.clear();
        await _roomMembersBox.clear();
        await _eventsBox.clear();
        await _timelineFragmentsBox.clear();
        await _outboundGroupSessionsBox.clear();
        await _presencesBox.clear();
        await _userProfilesBox.clear();
        await _clientBox.delete('prev_batch');
      });

  @override
  Future<void> clearSSSSCache() => _ssssCacheBox.clear();

  @override
  Future<void> close() async => _collection.close();

  @override
  Future<void> deleteFromToDeviceQueue(int id) async {
    await _toDeviceQueueBox.delete(id.toString());
    return;
  }

  @override
  Future<void> forgetRoom(String roomId) async {
    await _timelineFragmentsBox.delete(TupleKey(roomId, '').toString());
    final eventsBoxKeys = await _eventsBox.getAllKeys();
    for (final key in eventsBoxKeys) {
      final multiKey = TupleKey.fromString(key);
      if (multiKey.parts.first != roomId) continue;
      await _eventsBox.delete(key);
    }
    final preloadRoomStateBoxKeys = await _preloadRoomStateBox.getAllKeys();
    for (final key in preloadRoomStateBoxKeys) {
      final multiKey = TupleKey.fromString(key);
      if (multiKey.parts.first != roomId) continue;
      await _preloadRoomStateBox.delete(key);
    }
    final nonPreloadRoomStateBoxKeys =
        await _nonPreloadRoomStateBox.getAllKeys();
    for (final key in nonPreloadRoomStateBoxKeys) {
      final multiKey = TupleKey.fromString(key);
      if (multiKey.parts.first != roomId) continue;
      await _nonPreloadRoomStateBox.delete(key);
    }
    final roomMembersBoxKeys = await _roomMembersBox.getAllKeys();
    for (final key in roomMembersBoxKeys) {
      final multiKey = TupleKey.fromString(key);
      if (multiKey.parts.first != roomId) continue;
      await _roomMembersBox.delete(key);
    }
    final roomAccountDataBoxKeys = await _roomAccountDataBox.getAllKeys();
    for (final key in roomAccountDataBoxKeys) {
      final multiKey = TupleKey.fromString(key);
      if (multiKey.parts.first != roomId) continue;
      await _roomAccountDataBox.delete(key);
    }
    await _roomsBox.delete(roomId);
  }

  @override
  Future<Map<String, BasicEvent>> getAccountData() =>
      runBenchmarked<Map<String, BasicEvent>>('Get all account data from store',
          () async {
        final accountData = <String, BasicEvent>{};
        final raws = await _accountDataBox.getAllValues();
        for (final entry in raws.entries) {
          accountData[entry.key] = BasicEvent(
            type: entry.key,
            content: copyMap(entry.value),
          );
        }
        return accountData;
      });

  @override
  Future<Map<String, dynamic>?> getClient(String name) =>
      runBenchmarked('Get Client from store', () async {
        final map = <String, dynamic>{};
        final keys = await _clientBox.getAllKeys();
        for (final key in keys) {
          if (key == 'version') continue;
          final value = await _clientBox.get(key);
          if (value != null) map[key] = value;
        }
        if (map.isEmpty) return null;
        return map;
      });

  @override
  Future<Event?> getEventById(String eventId, Room room) async {
    final raw = await _eventsBox.get(TupleKey(room.id, eventId).toString());
    if (raw == null) return null;
    return Event.fromJson(copyMap(raw), room);
  }

  /// Loads a whole list of events at once from the store for a specific room
  Future<List<Event>> _getEventsByIds(List<String> eventIds, Room room) async {
    final keys = eventIds
        .map(
          (eventId) => TupleKey(room.id, eventId).toString(),
        )
        .toList();
    final rawEvents = await _eventsBox.getAll(keys);
    return rawEvents
        .whereType<Map>()
        .map((rawEvent) => Event.fromJson(copyMap(rawEvent), room))
        .toList();
  }

  @override
  Future<List<Event>> getEventList(
    Room room, {
    int start = 0,
    bool onlySending = false,
    int? limit,
  }) =>
      runBenchmarked<List<Event>>('Get event list', () async {
        // Get the synced event IDs from the store
        final timelineKey = TupleKey(room.id, '').toString();
        final timelineEventIds =
            (await _timelineFragmentsBox.get(timelineKey) ?? []);

        // Get the local stored SENDING events from the store
        late final List sendingEventIds;
        if (start != 0) {
          sendingEventIds = [];
        } else {
          final sendingTimelineKey = TupleKey(room.id, 'SENDING').toString();
          sendingEventIds =
              (await _timelineFragmentsBox.get(sendingTimelineKey) ?? []);
        }

        // Combine those two lists while respecting the start and limit parameters.
        final end = min(timelineEventIds.length,
            start + (limit ?? timelineEventIds.length));
        final eventIds = [
          ...sendingEventIds,
          if (!onlySending && start < timelineEventIds.length)
            ...timelineEventIds.getRange(start, end),
        ];

        return await _getEventsByIds(eventIds.cast<String>(), room);
      });

  @override
  Future<StoredInboundGroupSession?> getInboundGroupSession(
    String roomId,
    String sessionId,
  ) async {
    final raw = await _inboundGroupSessionsBox.get(sessionId);
    if (raw == null) return null;
    return StoredInboundGroupSession.fromJson(copyMap(raw));
  }

  @override
  Future<List<StoredInboundGroupSession>>
      getInboundGroupSessionsToUpload() async {
    final uploadQueue =
        await _inboundGroupSessionsUploadQueueBox.getAllValues();
    final sessionFutures = uploadQueue.entries
        .take(50)
        .map((entry) => getInboundGroupSession(entry.value, entry.key));
    final sessions = await Future.wait(sessionFutures);
    return sessions.whereType<StoredInboundGroupSession>().toList();
  }

  @override
  Future<List<String>> getLastSentMessageUserDeviceKey(
      String userId, String deviceId) async {
    final raw =
        await _userDeviceKeysBox.get(TupleKey(userId, deviceId).toString());
    if (raw == null) return <String>[];
    return <String>[raw['last_sent_message']];
  }

  @override
  Future<void> storeOlmSession(String identityKey, String sessionId,
      String pickle, int lastReceived) async {
    final rawSessions = copyMap((await _olmSessionsBox.get(identityKey)) ?? {});
    rawSessions[sessionId] = {
      'identity_key': identityKey,
      'pickle': pickle,
      'session_id': sessionId,
      'last_received': lastReceived,
    };
    await _olmSessionsBox.put(identityKey, rawSessions);
    return;
  }

  @override
  Future<List<OlmSession>> getOlmSessions(
      String identityKey, String userId) async {
    final rawSessions = await _olmSessionsBox.get(identityKey);
    if (rawSessions == null || rawSessions.isEmpty) return <OlmSession>[];
    return rawSessions.values
        .map((json) => OlmSession.fromJson(copyMap(json), userId))
        .toList();
  }

  @override
  Future<Map<String, Map>> getAllOlmSessions() =>
      _olmSessionsBox.getAllValues();

  @override
  Future<List<OlmSession>> getOlmSessionsForDevices(
      List<String> identityKeys, String userId) async {
    final sessions = await Future.wait(
        identityKeys.map((identityKey) => getOlmSessions(identityKey, userId)));
    return <OlmSession>[for (final sublist in sessions) ...sublist];
  }

  @override
  Future<OutboundGroupSession?> getOutboundGroupSession(
      String roomId, String userId) async {
    final raw = await _outboundGroupSessionsBox.get(roomId);
    if (raw == null) return null;
    return OutboundGroupSession.fromJson(copyMap(raw), userId);
  }

  @override
  Future<Room?> getSingleRoom(Client client, String roomId,
      {bool loadImportantStates = true}) async {
    // Get raw room from database:
    final roomData = await _roomsBox.get(roomId);
    if (roomData == null) return null;
    final room = Room.fromJson(copyMap(roomData), client);

    // Get important states:
    if (loadImportantStates) {
      final dbKeys = client.importantStateEvents
          .map((state) => TupleKey(roomId, state).toString())
          .toList();
      final rawStates = await _preloadRoomStateBox.getAll(dbKeys);
      for (final rawState in rawStates) {
        if (rawState == null || rawState[''] == null) continue;
        room.setState(Event.fromJson(copyMap(rawState['']), room));
      }
    }

    return room;
  }

  @override
  Future<List<Room>> getRoomList(Client client) =>
      runBenchmarked<List<Room>>('Get room list from store', () async {
        final rooms = <String, Room>{};

        final rawRooms = await _roomsBox.getAllValues();

        for (final raw in rawRooms.values) {
          // Get the room
          final room = Room.fromJson(copyMap(raw), client);

          // Add to the list and continue.
          rooms[room.id] = room;
        }

        final roomStatesDataRaws = await _preloadRoomStateBox.getAllValues();
        for (final entry in roomStatesDataRaws.entries) {
          final keys = TupleKey.fromString(entry.key);
          final roomId = keys.parts.first;
          final room = rooms[roomId];
          if (room == null) {
            Logs().w('Found event in store for unknown room', entry.value);
            continue;
          }
          final states = entry.value;
          final stateEvents = states.values
              .map((raw) => room.membership == Membership.invite
                  ? StrippedStateEvent.fromJson(copyMap(raw))
                  : Event.fromJson(copyMap(raw), room))
              .toList();
          for (final state in stateEvents) {
            room.setState(state);
          }
        }

        // Get the room account data
        final roomAccountDataRaws = await _roomAccountDataBox.getAllValues();
        for (final entry in roomAccountDataRaws.entries) {
          final keys = TupleKey.fromString(entry.key);
          final basicRoomEvent = BasicRoomEvent.fromJson(
            copyMap(entry.value),
          );
          final roomId = keys.parts.first;
          if (rooms.containsKey(roomId)) {
            rooms[roomId]!.roomAccountData[basicRoomEvent.type] =
                basicRoomEvent;
          } else {
            Logs().w(
                'Found account data for unknown room $roomId. Delete now...');
            await _roomAccountDataBox
                .delete(TupleKey(roomId, basicRoomEvent.type).toString());
          }
        }

        return rooms.values.toList();
      });

  @override
  Future<SSSSCache?> getSSSSCache(String type) async {
    final raw = await _ssssCacheBox.get(type);
    if (raw == null) return null;
    return SSSSCache.fromJson(copyMap(raw));
  }

  @override
  Future<List<QueuedToDeviceEvent>> getToDeviceEventQueue() async {
    final raws = await _toDeviceQueueBox.getAllValues();
    final copiedRaws = raws.entries.map((entry) {
      final copiedRaw = copyMap(entry.value);
      copiedRaw['id'] = int.parse(entry.key);
      copiedRaw['content'] = jsonDecode(copiedRaw['content'] as String);
      return copiedRaw;
    }).toList();
    return copiedRaws.map((raw) => QueuedToDeviceEvent.fromJson(raw)).toList();
  }

  @override
  Future<List<Event>> getUnimportantRoomEventStatesForRoom(
      List<String> events, Room room) async {
    final keys = (await _nonPreloadRoomStateBox.getAllKeys()).where((key) {
      final tuple = TupleKey.fromString(key);
      return tuple.parts.first == room.id && !events.contains(tuple.parts[1]);
    });

    final unimportantEvents = <Event>[];
    for (final key in keys) {
      final states = await _nonPreloadRoomStateBox.get(key);
      if (states == null) continue;
      unimportantEvents.addAll(
          states.values.map((raw) => Event.fromJson(copyMap(raw), room)));
    }

    return unimportantEvents.where((event) => event.stateKey != null).toList();
  }

  @override
  Future<User?> getUser(String userId, Room room) async {
    final state =
        await _roomMembersBox.get(TupleKey(room.id, userId).toString());
    if (state == null) return null;
    return Event.fromJson(copyMap(state), room).asUser;
  }

  @override
  Future<Map<String, DeviceKeysList>> getUserDeviceKeys(Client client) =>
      runBenchmarked<Map<String, DeviceKeysList>>(
          'Get all user device keys from store', () async {
        final deviceKeysOutdated =
            await _userDeviceKeysOutdatedBox.getAllValues();
        if (deviceKeysOutdated.isEmpty) {
          return {};
        }
        final res = <String, DeviceKeysList>{};
        final userDeviceKeys = await _userDeviceKeysBox.getAllValues();
        final userCrossSigningKeys =
            await _userCrossSigningKeysBox.getAllValues();
        for (final userId in deviceKeysOutdated.keys) {
          final deviceKeysBoxKeys = userDeviceKeys.keys.where((tuple) {
            final tupleKey = TupleKey.fromString(tuple);
            return tupleKey.parts.first == userId;
          });
          final crossSigningKeysBoxKeys =
              userCrossSigningKeys.keys.where((tuple) {
            final tupleKey = TupleKey.fromString(tuple);
            return tupleKey.parts.first == userId;
          });
          final childEntries = deviceKeysBoxKeys.map(
            (key) {
              final userDeviceKey = userDeviceKeys[key];
              if (userDeviceKey == null) return null;
              return copyMap(userDeviceKey);
            },
          );
          final crossSigningEntries = crossSigningKeysBoxKeys.map(
            (key) {
              final crossSigningKey = userCrossSigningKeys[key];
              if (crossSigningKey == null) return null;
              return copyMap(crossSigningKey);
            },
          );
          res[userId] = DeviceKeysList.fromDbJson(
              {
                'client_id': client.id,
                'user_id': userId,
                'outdated': deviceKeysOutdated[userId],
              },
              childEntries
                  .where((c) => c != null)
                  .toList()
                  .cast<Map<String, dynamic>>(),
              crossSigningEntries
                  .where((c) => c != null)
                  .toList()
                  .cast<Map<String, dynamic>>(),
              client);
        }
        return res;
      });

  @override
  Future<List<User>> getUsers(Room room) async {
    final users = <User>[];
    final keys = (await _roomMembersBox.getAllKeys())
        .where((key) => TupleKey.fromString(key).parts.first == room.id)
        .toList();
    final states = await _roomMembersBox.getAll(keys);
    states.removeWhere((state) => state == null);
    for (final state in states) {
      users.add(Event.fromJson(copyMap(state!), room).asUser);
    }

    return users;
  }

  @override
  Future<int> insertClient(
      String name,
      String homeserverUrl,
      String token,
      DateTime? tokenExpiresAt,
      String? refreshToken,
      String userId,
      String? deviceId,
      String? deviceName,
      String? prevBatch,
      String? olmAccount) async {
    await transaction(() async {
      await _clientBox.put('homeserver_url', homeserverUrl);
      await _clientBox.put('token', token);
      if (tokenExpiresAt == null) {
        await _clientBox.delete('token_expires_at');
      } else {
        await _clientBox.put('token_expires_at',
            tokenExpiresAt.millisecondsSinceEpoch.toString());
      }
      if (refreshToken == null) {
        await _clientBox.delete('refresh_token');
      } else {
        await _clientBox.put('refresh_token', refreshToken);
      }
      await _clientBox.put('user_id', userId);
      if (deviceId == null) {
        await _clientBox.delete('device_id');
      } else {
        await _clientBox.put('device_id', deviceId);
      }
      if (deviceName == null) {
        await _clientBox.delete('device_name');
      } else {
        await _clientBox.put('device_name', deviceName);
      }
      if (prevBatch == null) {
        await _clientBox.delete('prev_batch');
      } else {
        await _clientBox.put('prev_batch', prevBatch);
      }
      if (olmAccount == null) {
        await _clientBox.delete('olm_account');
      } else {
        await _clientBox.put('olm_account', olmAccount);
      }
      await _clientBox.delete('sync_filter_id');
    });
    return 0;
  }

  @override
  Future<int> insertIntoToDeviceQueue(
      String type, String txnId, String content) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    await _toDeviceQueueBox.put(id.toString(), {
      'type': type,
      'txn_id': txnId,
      'content': content,
    });
    return id;
  }

  @override
  Future<void> markInboundGroupSessionAsUploaded(
      String roomId, String sessionId) async {
    await _inboundGroupSessionsUploadQueueBox.delete(sessionId);
    return;
  }

  @override
  Future<void> markInboundGroupSessionsAsNeedingUpload() async {
    final keys = await _inboundGroupSessionsBox.getAllKeys();
    for (final sessionId in keys) {
      final raw = copyMap(
        await _inboundGroupSessionsBox.get(sessionId) ?? {},
      );
      if (raw.isEmpty) continue;
      final roomId = raw.tryGet<String>('room_id');
      if (roomId == null) continue;
      await _inboundGroupSessionsUploadQueueBox.put(sessionId, roomId);
    }
    return;
  }

  @override
  Future<void> removeEvent(String eventId, String roomId) async {
    await _eventsBox.delete(TupleKey(roomId, eventId).toString());
    final keys = await _timelineFragmentsBox.getAllKeys();
    for (final key in keys) {
      final multiKey = TupleKey.fromString(key);
      if (multiKey.parts.first != roomId) continue;
      final eventIds =
          List<String>.from(await _timelineFragmentsBox.get(key) ?? []);
      final prevLength = eventIds.length;
      eventIds.removeWhere((id) => id == eventId);
      if (eventIds.length < prevLength) {
        await _timelineFragmentsBox.put(key, eventIds);
      }
    }
    return;
  }

  @override
  Future<void> removeOutboundGroupSession(String roomId) async {
    await _outboundGroupSessionsBox.delete(roomId);
    return;
  }

  @override
  Future<void> removeUserCrossSigningKey(
      String userId, String publicKey) async {
    await _userCrossSigningKeysBox
        .delete(TupleKey(userId, publicKey).toString());
    return;
  }

  @override
  Future<void> removeUserDeviceKey(String userId, String deviceId) async {
    await _userDeviceKeysBox.delete(TupleKey(userId, deviceId).toString());
    return;
  }

  @override
  Future<void> setBlockedUserCrossSigningKey(
      bool blocked, String userId, String publicKey) async {
    final raw = copyMap(
      await _userCrossSigningKeysBox
              .get(TupleKey(userId, publicKey).toString()) ??
          {},
    );
    raw['blocked'] = blocked;
    await _userCrossSigningKeysBox.put(
      TupleKey(userId, publicKey).toString(),
      raw,
    );
    return;
  }

  @override
  Future<void> setBlockedUserDeviceKey(
      bool blocked, String userId, String deviceId) async {
    final raw = copyMap(
      await _userDeviceKeysBox.get(TupleKey(userId, deviceId).toString()) ?? {},
    );
    raw['blocked'] = blocked;
    await _userDeviceKeysBox.put(
      TupleKey(userId, deviceId).toString(),
      raw,
    );
    return;
  }

  @override
  Future<void> setLastActiveUserDeviceKey(
      int lastActive, String userId, String deviceId) async {
    final raw = copyMap(
      await _userDeviceKeysBox.get(TupleKey(userId, deviceId).toString()) ?? {},
    );

    raw['last_active'] = lastActive;
    await _userDeviceKeysBox.put(
      TupleKey(userId, deviceId).toString(),
      raw,
    );
  }

  @override
  Future<void> setLastSentMessageUserDeviceKey(
      String lastSentMessage, String userId, String deviceId) async {
    final raw = copyMap(
      await _userDeviceKeysBox.get(TupleKey(userId, deviceId).toString()) ?? {},
    );
    raw['last_sent_message'] = lastSentMessage;
    await _userDeviceKeysBox.put(
      TupleKey(userId, deviceId).toString(),
      raw,
    );
  }

  @override
  Future<void> setRoomPrevBatch(
      String? prevBatch, String roomId, Client client) async {
    final raw = await _roomsBox.get(roomId);
    if (raw == null) return;
    final room = Room.fromJson(copyMap(raw), client);
    room.prev_batch = prevBatch;
    await _roomsBox.put(roomId, room.toJson());
    return;
  }

  @override
  Future<void> setVerifiedUserCrossSigningKey(
      bool verified, String userId, String publicKey) async {
    final raw = copyMap(
      (await _userCrossSigningKeysBox
              .get(TupleKey(userId, publicKey).toString())) ??
          {},
    );
    raw['verified'] = verified;
    await _userCrossSigningKeysBox.put(
      TupleKey(userId, publicKey).toString(),
      raw,
    );
    return;
  }

  @override
  Future<void> setVerifiedUserDeviceKey(
      bool verified, String userId, String deviceId) async {
    final raw = copyMap(
      await _userDeviceKeysBox.get(TupleKey(userId, deviceId).toString()) ?? {},
    );
    raw['verified'] = verified;
    await _userDeviceKeysBox.put(
      TupleKey(userId, deviceId).toString(),
      raw,
    );
    return;
  }

  @override
  Future<void> storeAccountData(String type, String content) async {
    await _accountDataBox.put(type, jsonDecode(content));
    return;
  }

  @override
  Future<void> storeEventUpdate(EventUpdate eventUpdate, Client client) async {
    // Ephemerals should not be stored
    if (eventUpdate.type == EventUpdateType.ephemeral) return;
    final tmpRoom = client.getRoomById(eventUpdate.roomID) ??
        Room(id: eventUpdate.roomID, client: client);

    // In case of this is a redaction event
    if (eventUpdate.content['type'] == EventTypes.Redaction) {
      final eventId = eventUpdate.content.tryGet<String>('redacts');
      final event =
          eventId != null ? await getEventById(eventId, tmpRoom) : null;
      if (event != null) {
        event.setRedactionEvent(Event.fromJson(eventUpdate.content, tmpRoom));
        await _eventsBox.put(
            TupleKey(eventUpdate.roomID, event.eventId).toString(),
            event.toJson());

        if (tmpRoom.lastEvent?.eventId == event.eventId) {
          if (client.importantStateEvents.contains(event.type)) {
            await _preloadRoomStateBox.put(
              TupleKey(eventUpdate.roomID, event.type).toString(),
              {'': event.toJson()},
            );
          } else {
            await _nonPreloadRoomStateBox.put(
              TupleKey(eventUpdate.roomID, event.type).toString(),
              {'': event.toJson()},
            );
          }
        }
      }
    }

    // Store a common message event
    if ({EventUpdateType.timeline, EventUpdateType.history}
        .contains(eventUpdate.type)) {
      final eventId = eventUpdate.content['event_id'];
      // Is this ID already in the store?
      final prevEvent = await _eventsBox
          .get(TupleKey(eventUpdate.roomID, eventId).toString());
      final prevStatus = prevEvent == null
          ? null
          : () {
              final json = copyMap(prevEvent);
              final statusInt = json.tryGet<int>('status') ??
                  json
                      .tryGetMap<String, dynamic>('unsigned')
                      ?.tryGet<int>(messageSendingStatusKey);
              return statusInt == null ? null : eventStatusFromInt(statusInt);
            }();

      // calculate the status
      final newStatus = eventStatusFromInt(
        eventUpdate.content.tryGet<int>('status') ??
            eventUpdate.content
                .tryGetMap<String, dynamic>('unsigned')
                ?.tryGet<int>(messageSendingStatusKey) ??
            EventStatus.synced.intValue,
      );

      // Is this the response to a sending event which is already synced? Then
      // there is nothing to do here.
      if (!newStatus.isSynced && prevStatus != null && prevStatus.isSynced) {
        return;
      }

      final status = newStatus.isError || prevStatus == null
          ? newStatus
          : latestEventStatus(
              prevStatus,
              newStatus,
            );

      // Add the status and the sort order to the content so it get stored
      eventUpdate.content['unsigned'] ??= <String, dynamic>{};
      eventUpdate.content['unsigned'][messageSendingStatusKey] =
          eventUpdate.content['status'] = status.intValue;

      // In case this event has sent from this account we have a transaction ID
      final transactionId = eventUpdate.content
          .tryGetMap<String, dynamic>('unsigned')
          ?.tryGet<String>('transaction_id');
      await _eventsBox.put(TupleKey(eventUpdate.roomID, eventId).toString(),
          eventUpdate.content);

      // Update timeline fragments
      final key = TupleKey(eventUpdate.roomID, status.isSent ? '' : 'SENDING')
          .toString();

      final eventIds =
          List<String>.from(await _timelineFragmentsBox.get(key) ?? []);

      if (!eventIds.contains(eventId)) {
        if (eventUpdate.type == EventUpdateType.history) {
          eventIds.add(eventId);
        } else {
          eventIds.insert(0, eventId);
        }
        await _timelineFragmentsBox.put(key, eventIds);
      } else if (status.isSynced &&
          prevStatus != null &&
          prevStatus.isSent &&
          eventUpdate.type != EventUpdateType.history) {
        // Status changes from 1 -> 2? Make sure event is correctly sorted.
        eventIds.remove(eventId);
        eventIds.insert(0, eventId);
      }

      // If event comes from server timeline, remove sending events with this ID
      if (status.isSent) {
        final key = TupleKey(eventUpdate.roomID, 'SENDING').toString();
        final eventIds =
            List<String>.from(await _timelineFragmentsBox.get(key) ?? []);
        final i = eventIds.indexWhere((id) => id == eventId);
        if (i != -1) {
          await _timelineFragmentsBox.put(key, eventIds..removeAt(i));
        }
      }

      // Is there a transaction id? Then delete the event with this id.
      if (!status.isError && !status.isSending && transactionId != null) {
        await removeEvent(transactionId, eventUpdate.roomID);
      }
    }

    final stateKey = eventUpdate.content['state_key'];
    // Store a common state event
    if (stateKey != null &&
        // Don't store events as state updates when paginating backwards.
        (eventUpdate.type == EventUpdateType.timeline ||
            eventUpdate.type == EventUpdateType.state ||
            eventUpdate.type == EventUpdateType.inviteState)) {
      if (eventUpdate.content['type'] == EventTypes.RoomMember) {
        await _roomMembersBox.put(
            TupleKey(
              eventUpdate.roomID,
              eventUpdate.content['state_key'],
            ).toString(),
            eventUpdate.content);
      } else {
        final type = eventUpdate.content['type'] as String;
        final roomStateBox = client.importantStateEvents.contains(type)
            ? _preloadRoomStateBox
            : _nonPreloadRoomStateBox;
        final key = TupleKey(
          eventUpdate.roomID,
          type,
        ).toString();
        final stateMap = copyMap(await roomStateBox.get(key) ?? {});

        stateMap[stateKey] = eventUpdate.content;
        await roomStateBox.put(key, stateMap);
      }
    }

    // Store a room account data event
    if (eventUpdate.type == EventUpdateType.accountData) {
      await _roomAccountDataBox.put(
        TupleKey(
          eventUpdate.roomID,
          eventUpdate.content['type'],
        ).toString(),
        eventUpdate.content,
      );
    }
  }

  @override
  Future<void> storeInboundGroupSession(
      String roomId,
      String sessionId,
      String pickle,
      String content,
      String indexes,
      String allowedAtIndex,
      String senderKey,
      String senderClaimedKey) async {
    final json = StoredInboundGroupSession(
      roomId: roomId,
      sessionId: sessionId,
      pickle: pickle,
      content: content,
      indexes: indexes,
      allowedAtIndex: allowedAtIndex,
      senderKey: senderKey,
      senderClaimedKeys: senderClaimedKey,
    ).toJson();
    await _inboundGroupSessionsBox.put(
      sessionId,
      json,
    );
    // Mark this session as needing upload too
    await _inboundGroupSessionsUploadQueueBox.put(sessionId, roomId);
    return;
  }

  @override
  Future<void> storeOutboundGroupSession(
      String roomId, String pickle, String deviceIds, int creationTime) async {
    await _outboundGroupSessionsBox.put(roomId, <String, dynamic>{
      'room_id': roomId,
      'pickle': pickle,
      'device_ids': deviceIds,
      'creation_time': creationTime,
    });
    return;
  }

  @override
  Future<void> storePrevBatch(
    String prevBatch,
  ) async {
    if ((await _clientBox.getAllKeys()).isEmpty) return;
    await _clientBox.put('prev_batch', prevBatch);
    return;
  }

  @override
  Future<void> storeRoomUpdate(String roomId, SyncRoomUpdate roomUpdate,
      Event? lastEvent, Client client) async {
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
    // Make sure room exists
    final currentRawRoom = await _roomsBox.get(roomId);
    if (currentRawRoom == null) {
      await _roomsBox.put(
          roomId,
          roomUpdate is JoinedRoomUpdate
              ? Room(
                  client: client,
                  id: roomId,
                  membership: membership,
                  highlightCount:
                      roomUpdate.unreadNotifications?.highlightCount?.toInt() ??
                          0,
                  notificationCount: roomUpdate
                          .unreadNotifications?.notificationCount
                          ?.toInt() ??
                      0,
                  prev_batch: roomUpdate.timeline?.prevBatch,
                  summary: roomUpdate.summary,
                  lastEvent: lastEvent,
                ).toJson()
              : Room(
                  client: client,
                  id: roomId,
                  membership: membership,
                  lastEvent: lastEvent,
                ).toJson());
    } else if (roomUpdate is JoinedRoomUpdate) {
      final currentRoom = Room.fromJson(copyMap(currentRawRoom), client);
      await _roomsBox.put(
          roomId,
          Room(
            client: client,
            id: roomId,
            membership: membership,
            highlightCount:
                roomUpdate.unreadNotifications?.highlightCount?.toInt() ??
                    currentRoom.highlightCount,
            notificationCount:
                roomUpdate.unreadNotifications?.notificationCount?.toInt() ??
                    currentRoom.notificationCount,
            prev_batch:
                roomUpdate.timeline?.prevBatch ?? currentRoom.prev_batch,
            summary: RoomSummary.fromJson(currentRoom.summary.toJson()
              ..addAll(roomUpdate.summary?.toJson() ?? {})),
            lastEvent: lastEvent,
          ).toJson());
    }
  }

  @override
  Future<void> deleteTimelineForRoom(String roomId) =>
      _timelineFragmentsBox.delete(TupleKey(roomId, '').toString());

  @override
  Future<void> storeSSSSCache(
      String type, String keyId, String ciphertext, String content) async {
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
  Future<void> storeSyncFilterId(
    String syncFilterId,
  ) async {
    await _clientBox.put('sync_filter_id', syncFilterId);
  }

  @override
  Future<void> storeUserCrossSigningKey(String userId, String publicKey,
      String content, bool verified, bool blocked) async {
    await _userCrossSigningKeysBox.put(
      TupleKey(userId, publicKey).toString(),
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
  Future<void> storeUserDeviceKey(String userId, String deviceId,
      String content, bool verified, bool blocked, int lastActive) async {
    await _userDeviceKeysBox.put(TupleKey(userId, deviceId).toString(), {
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
  Future<void> storeUserDeviceKeysInfo(String userId, bool outdated) async {
    await _userDeviceKeysOutdatedBox.put(userId, outdated);
    return;
  }

  @override
  Future<void> transaction(Future<void> Function() action) =>
      _collection.transaction(action);

  @override
  Future<void> updateClient(
    String homeserverUrl,
    String token,
    DateTime? tokenExpiresAt,
    String? refreshToken,
    String userId,
    String? deviceId,
    String? deviceName,
    String? prevBatch,
    String? olmAccount,
  ) async {
    await transaction(() async {
      await _clientBox.put('homeserver_url', homeserverUrl);
      await _clientBox.put('token', token);
      if (tokenExpiresAt == null) {
        await _clientBox.delete('token_expires_at');
      } else {
        await _clientBox.put('token_expires_at',
            tokenExpiresAt.millisecondsSinceEpoch.toString());
      }
      if (refreshToken == null) {
        await _clientBox.delete('refresh_token');
      } else {
        await _clientBox.put('refresh_token', refreshToken);
      }
      await _clientBox.put('user_id', userId);
      if (deviceId == null) {
        await _clientBox.delete('device_id');
      } else {
        await _clientBox.put('device_id', deviceId);
      }
      if (deviceName == null) {
        await _clientBox.delete('device_name');
      } else {
        await _clientBox.put('device_name', deviceName);
      }
      if (prevBatch == null) {
        await _clientBox.delete('prev_batch');
      } else {
        await _clientBox.put('prev_batch', prevBatch);
      }
      if (olmAccount == null) {
        await _clientBox.delete('olm_account');
      } else {
        await _clientBox.put('olm_account', olmAccount);
      }
    });
    return;
  }

  @override
  Future<void> updateClientKeys(
    String olmAccount,
  ) async {
    await _clientBox.put('olm_account', olmAccount);
    return;
  }

  @override
  Future<void> updateInboundGroupSessionAllowedAtIndex(
      String allowedAtIndex, String roomId, String sessionId) async {
    final raw = await _inboundGroupSessionsBox.get(sessionId);
    if (raw == null) {
      Logs().w(
          'Tried to update inbound group session as uploaded which wasnt found in the database!');
      return;
    }
    raw['allowed_at_index'] = allowedAtIndex;
    await _inboundGroupSessionsBox.put(sessionId, raw);
    return;
  }

  @override
  Future<void> updateInboundGroupSessionIndexes(
      String indexes, String roomId, String sessionId) async {
    final raw = await _inboundGroupSessionsBox.get(sessionId);
    if (raw == null) {
      Logs().w(
          'Tried to update inbound group session indexes of a session which was not found in the database!');
      return;
    }
    final json = copyMap(raw);
    json['indexes'] = indexes;
    await _inboundGroupSessionsBox.put(sessionId, json);
    return;
  }

  @override
  Future<List<StoredInboundGroupSession>> getAllInboundGroupSessions() async {
    final rawSessions = await _inboundGroupSessionsBox.getAllValues();
    return rawSessions.values
        .map((raw) => StoredInboundGroupSession.fromJson(copyMap(raw)))
        .toList();
  }

  @override
  Future<void> addSeenDeviceId(
    String userId,
    String deviceId,
    String publicKeys,
  ) =>
      _seenDeviceIdsBox.put(TupleKey(userId, deviceId).toString(), publicKeys);

  @override
  Future<void> addSeenPublicKey(
    String publicKey,
    String deviceId,
  ) =>
      _seenDeviceKeysBox.put(publicKey, deviceId);

  @override
  Future<String?> deviceIdSeen(userId, deviceId) async {
    final raw =
        await _seenDeviceIdsBox.get(TupleKey(userId, deviceId).toString());
    if (raw == null) return null;
    return raw;
  }

  @override
  Future<String?> publicKeySeen(String publicKey) async {
    final raw = await _seenDeviceKeysBox.get(publicKey);
    if (raw == null) return null;
    return raw;
  }

  @override
  Future<String> exportDump() async {
    final dataMap = {
      _clientBoxName: await _clientBox.getAllValues(),
      _accountDataBoxName: await _accountDataBox.getAllValues(),
      _roomsBoxName: await _roomsBox.getAllValues(),
      _preloadRoomStateBoxName: await _preloadRoomStateBox.getAllValues(),
      _nonPreloadRoomStateBoxName: await _nonPreloadRoomStateBox.getAllValues(),
      _roomMembersBoxName: await _roomMembersBox.getAllValues(),
      _toDeviceQueueBoxName: await _toDeviceQueueBox.getAllValues(),
      _roomAccountDataBoxName: await _roomAccountDataBox.getAllValues(),
      _inboundGroupSessionsBoxName:
          await _inboundGroupSessionsBox.getAllValues(),
      _inboundGroupSessionsUploadQueueBoxName:
          await _inboundGroupSessionsUploadQueueBox.getAllValues(),
      _outboundGroupSessionsBoxName:
          await _outboundGroupSessionsBox.getAllValues(),
      _olmSessionsBoxName: await _olmSessionsBox.getAllValues(),
      _userDeviceKeysBoxName: await _userDeviceKeysBox.getAllValues(),
      _userDeviceKeysOutdatedBoxName:
          await _userDeviceKeysOutdatedBox.getAllValues(),
      _userCrossSigningKeysBoxName:
          await _userCrossSigningKeysBox.getAllValues(),
      _ssssCacheBoxName: await _ssssCacheBox.getAllValues(),
      _presencesBoxName: await _presencesBox.getAllValues(),
      _timelineFragmentsBoxName: await _timelineFragmentsBox.getAllValues(),
      _eventsBoxName: await _eventsBox.getAllValues(),
      _seenDeviceIdsBoxName: await _seenDeviceIdsBox.getAllValues(),
      _seenDeviceKeysBoxName: await _seenDeviceKeysBox.getAllValues(),
    };
    final json = jsonEncode(dataMap);
    await clear();
    return json;
  }

  @override
  Future<bool> importDump(String export) async {
    try {
      await clear();
      await open();
      final json = Map.from(jsonDecode(export)).cast<String, Map>();
      for (final key in json[_clientBoxName]!.keys) {
        await _clientBox.put(key, json[_clientBoxName]![key]);
      }
      for (final key in json[_accountDataBoxName]!.keys) {
        await _accountDataBox.put(key, json[_accountDataBoxName]![key]);
      }
      for (final key in json[_roomsBoxName]!.keys) {
        await _roomsBox.put(key, json[_roomsBoxName]![key]);
      }
      for (final key in json[_preloadRoomStateBoxName]!.keys) {
        await _preloadRoomStateBox.put(
            key, json[_preloadRoomStateBoxName]![key]);
      }
      for (final key in json[_nonPreloadRoomStateBoxName]!.keys) {
        await _nonPreloadRoomStateBox.put(
            key, json[_nonPreloadRoomStateBoxName]![key]);
      }
      for (final key in json[_roomMembersBoxName]!.keys) {
        await _roomMembersBox.put(key, json[_roomMembersBoxName]![key]);
      }
      for (final key in json[_toDeviceQueueBoxName]!.keys) {
        await _toDeviceQueueBox.put(key, json[_toDeviceQueueBoxName]![key]);
      }
      for (final key in json[_roomAccountDataBoxName]!.keys) {
        await _roomAccountDataBox.put(key, json[_roomAccountDataBoxName]![key]);
      }
      for (final key in json[_inboundGroupSessionsBoxName]!.keys) {
        await _inboundGroupSessionsBox.put(
            key, json[_inboundGroupSessionsBoxName]![key]);
      }
      for (final key in json[_inboundGroupSessionsUploadQueueBoxName]!.keys) {
        await _inboundGroupSessionsUploadQueueBox.put(
            key, json[_inboundGroupSessionsUploadQueueBoxName]![key]);
      }
      for (final key in json[_outboundGroupSessionsBoxName]!.keys) {
        await _outboundGroupSessionsBox.put(
            key, json[_outboundGroupSessionsBoxName]![key]);
      }
      for (final key in json[_olmSessionsBoxName]!.keys) {
        await _olmSessionsBox.put(key, json[_olmSessionsBoxName]![key]);
      }
      for (final key in json[_userDeviceKeysBoxName]!.keys) {
        await _userDeviceKeysBox.put(key, json[_userDeviceKeysBoxName]![key]);
      }
      for (final key in json[_userDeviceKeysOutdatedBoxName]!.keys) {
        await _userDeviceKeysOutdatedBox.put(
            key, json[_userDeviceKeysOutdatedBoxName]![key]);
      }
      for (final key in json[_userCrossSigningKeysBoxName]!.keys) {
        await _userCrossSigningKeysBox.put(
            key, json[_userCrossSigningKeysBoxName]![key]);
      }
      for (final key in json[_ssssCacheBoxName]!.keys) {
        await _ssssCacheBox.put(key, json[_ssssCacheBoxName]![key]);
      }
      for (final key in json[_presencesBoxName]!.keys) {
        await _presencesBox.put(key, json[_presencesBoxName]![key]);
      }
      for (final key in json[_timelineFragmentsBoxName]!.keys) {
        await _timelineFragmentsBox.put(
            key, json[_timelineFragmentsBoxName]![key]);
      }
      for (final key in json[_seenDeviceIdsBoxName]!.keys) {
        await _seenDeviceIdsBox.put(key, json[_seenDeviceIdsBoxName]![key]);
      }
      for (final key in json[_seenDeviceKeysBoxName]!.keys) {
        await _seenDeviceKeysBox.put(key, json[_seenDeviceKeysBoxName]![key]);
      }
      return true;
    } catch (e, s) {
      Logs().e('Database import error: ', e, s);
      return false;
    }
  }

  @override
  Future<List<String>> getEventIdList(
    Room room, {
    int start = 0,
    bool includeSending = false,
    int? limit,
  }) =>
      runBenchmarked<List<String>>('Get event id list', () async {
        // Get the synced event IDs from the store
        final timelineKey = TupleKey(room.id, '').toString();
        final timelineEventIds = List<String>.from(
            (await _timelineFragmentsBox.get(timelineKey)) ?? []);

        // Get the local stored SENDING events from the store
        late final List<String> sendingEventIds;
        if (!includeSending) {
          sendingEventIds = [];
        } else {
          final sendingTimelineKey = TupleKey(room.id, 'SENDING').toString();
          sendingEventIds = List<String>.from(
              (await _timelineFragmentsBox.get(sendingTimelineKey)) ?? []);
        }

        // Combine those two lists while respecting the start and limit parameters.
        // Create a new list object instead of concatonating list to prevent
        // random type errors.
        final eventIds = [
          ...sendingEventIds,
          ...timelineEventIds,
        ];
        if (limit != null && eventIds.length > limit) {
          eventIds.removeRange(limit, eventIds.length);
        }

        return eventIds;
      });

  @override
  Future<void> storePresence(String userId, CachedPresence presence) =>
      _presencesBox.put(userId, presence.toJson());

  @override
  Future<CachedPresence?> getPresence(String userId) async {
    final rawPresence = await _presencesBox.get(userId);
    if (rawPresence == null) return null;

    return CachedPresence.fromJson(copyMap(rawPresence));
  }

  @override
  Future<void> storeWellKnown(DiscoveryInformation? discoveryInformation) {
    if (discoveryInformation == null) {
      return _clientBox.delete('discovery_information');
    }
    return _clientBox.put(
      'discovery_information',
      jsonEncode(discoveryInformation.toJson()),
    );
  }

  @override
  Future<DiscoveryInformation?> getWellKnown() async {
    final rawDiscoveryInformation =
        await _clientBox.get('discovery_information');
    if (rawDiscoveryInformation == null) return null;
    return DiscoveryInformation.fromJson(jsonDecode(rawDiscoveryInformation));
  }

  @override
  Future<void> delete() async {
    // database?.path is null on web
    await _collection.deleteDatabase(
      database?.path ?? name,
      sqfliteFactory ?? idbFactory,
    );
  }

  @override
  Future<void> markUserProfileAsOutdated(userId) async {
    final profile = await getUserProfile(userId);
    if (profile == null) return;
    await _userProfilesBox.put(
      userId,
      CachedProfileInformation.fromProfile(
        profile as ProfileInformation,
        outdated: true,
        updated: profile.updated,
      ).toJson(),
    );
  }

  @override
  Future<CachedProfileInformation?> getUserProfile(String userId) =>
      _userProfilesBox.get(userId).then((json) => json == null
          ? null
          : CachedProfileInformation.fromJson(copyMap(json)));

  @override
  Future<void> storeUserProfile(
          String userId, CachedProfileInformation profile) =>
      _userProfilesBox.put(
        userId,
        profile.toJson(),
      );
}
