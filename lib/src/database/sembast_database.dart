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
import 'dart:typed_data';

import 'package:sembast/sembast.dart';
import 'package:matrix/encryption/utils/olm_session.dart';
import 'package:matrix/encryption/utils/outbound_group_session.dart';
import 'package:matrix/encryption/utils/ssss_cache.dart';
import 'package:matrix/encryption/utils/stored_inbound_group_session.dart';
import 'package:matrix/matrix.dart' hide Filter;
import 'package:matrix/src/event_status.dart';
import 'package:matrix/src/utils/queued_to_device_event.dart';
import 'package:matrix/src/utils/run_benchmarked.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/utils/value_utils.dart';

/// Sembast implementation of the DatabaseAPI. You need to pass through the
/// correct dbfactory. By default it uses an in-memory database so there is no
/// persistent storage. Learn more on: https://pub.dev/packages/sembast
class MatrixSembastDatabase extends DatabaseApi {
  static const int version = 5;
  final String name;
  final String path;
  late final Database _database;
  Transaction? _currentTransaction;

  /// The transaction to use here. If there is a real transaction ongoing it
  /// will use it and otherwise just use the default which is the database
  /// object itself.
  DatabaseClient get txn => (_transactionLock?.isCompleted ?? true)
      ? _database
      : _currentTransaction ?? _database;

  final DatabaseFactory _dbFactory;

  late final StoreRef<String, dynamic> _clientBox = StoreRef(_clientBoxName);
  late final StoreRef<String, Map<String, Object?>> _accountDataBox =
      StoreRef(_accountDataBoxName);
  late final StoreRef<String, Map<String, Object?>> _roomsBox =
      StoreRef(_roomsBoxName);
  late final StoreRef<int, Map<String, dynamic>> _toDeviceQueueBox =
      StoreRef(_toDeviceQueueBoxName);

  /// Key is a tuple as SembastKey(roomId, type) where stateKey can be
  /// an empty string.
  late final StoreRef<String, Map<String, Object?>> _roomStateBox =
      StoreRef(_roomStateBoxName);

  /// Key is a tuple as SembastKey(roomId, userId)
  late final StoreRef<String, Map<String, Object?>> _roomMembersBox =
      StoreRef(_roomMembersBoxName);

  /// Key is a tuple as SembastKey(roomId, type)
  late final StoreRef<String, Map<String, Object?>> _roomAccountDataBox =
      StoreRef(_roomAccountDataBoxName);
  late final StoreRef<String, Map<String, Object?>> _inboundGroupSessionsBox =
      StoreRef(_inboundGroupSessionsBoxName);
  late final StoreRef<String, Map<String, Object?>> _outboundGroupSessionsBox =
      StoreRef(_outboundGroupSessionsBoxName);
  late final StoreRef<String, Map<String, Object?>> _olmSessionsBox =
      StoreRef(_olmSessionsBoxName);

  /// Key is a tuple as SembastKey(userId, deviceId)
  late final StoreRef<String, Map<String, Object?>> _userDeviceKeysBox =
      StoreRef(_userDeviceKeysBoxName);

  /// Key is the user ID as a String
  late final StoreRef<String, bool> _userDeviceKeysOutdatedBox =
      StoreRef(_userDeviceKeysOutdatedBoxName);

  /// Key is a tuple as SembastKey(userId, publicKey)
  late final StoreRef<String, Map<String, Object?>> _userCrossSigningKeysBox =
      StoreRef(_userCrossSigningKeysBoxName);
  late final StoreRef<String, Map<String, Object?>> _ssssCacheBox =
      StoreRef(_ssssCacheBoxName);
  late final StoreRef<String, Map<String, Object?>> _presencesBox =
      StoreRef(_presencesBoxName);

  /// Key is a tuple as Multikey(roomId, fragmentId) while the default
  /// fragmentId is an empty String
  late final StoreRef<String, List<Object?>> _timelineFragmentsBox =
      StoreRef(_timelineFragmentsBoxName);

  /// Key is a tuple as SembastKey(roomId, eventId)
  late final StoreRef<String, Map<String, Object?>> _eventsBox =
      StoreRef(_eventsBoxName);

  /// Key is a tuple as SembastKey(userId, deviceId)
  late final StoreRef<String, String> _seenDeviceIdsBox =
      StoreRef(_seenDeviceIdsBoxName);

  late final StoreRef<String, String> _seenDeviceKeysBox =
      StoreRef(_seenDeviceKeysBoxName);

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

  String get _seenDeviceIdsBoxName => '$name.box.seen_device_ids';

  String get _seenDeviceKeysBoxName => '$name.box.seen_device_keys';

  final SembastCodec? codec;

  MatrixSembastDatabase(
    this.name, {
    this.path = './database.db',
    this.codec,
    DatabaseFactory? dbFactory,
  }) : _dbFactory = dbFactory ?? databaseFactoryMemory;

  @override
  int get maxFileSize => 0;

  Future<void> _actionOnAllBoxes(Future<void> Function(StoreRef box) action) =>
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
        action(_seenDeviceIdsBox),
        action(_seenDeviceKeysBox),
      ]);

  Future<void> open() async {
    _database = await _dbFactory.openDatabase(path, codec: codec);

    // Check version and check if we need a migration
    final currentVersion =
        (await _clientBox.record('version').get(txn) as int?);
    if (currentVersion == null) {
      await _clientBox.record('version').put(txn, version);
    } else if (currentVersion != version) {
      await _migrateFromVersion(currentVersion);
    }

    return;
  }

  Future<void> _migrateFromVersion(int currentVersion) async {
    Logs()
        .i('Migrate Sembast database from version $currentVersion to $version');
    if (version == 5) {
      await _database.transaction((txn) async {
        final keys = await _userDeviceKeysBox.findKeys(txn);
        for (final key in keys) {
          try {
            final raw = await _userDeviceKeysBox.record(key).get(txn) as Map;
            if (!raw.containsKey('keys')) continue;
            final deviceKeys = DeviceKeys.fromJson(
              cloneMap(raw),
              Client(''),
            );
            await addSeenDeviceId(deviceKeys.userId, deviceKeys.deviceId!,
                deviceKeys.curve25519Key! + deviceKeys.ed25519Key!);
            await addSeenPublicKey(
                deviceKeys.ed25519Key!, deviceKeys.deviceId!);
            await addSeenPublicKey(
                deviceKeys.curve25519Key!, deviceKeys.deviceId!);
          } catch (e) {
            Logs().w('Can not migrate device $key', e);
          }
        }
      });
    }
    await clearCache();
    await _clientBox.record('version').put(txn, version);
  }

  @override
  Future<void> clear() async {
    Logs().i('Clear and close Sembast database...');
    await _actionOnAllBoxes((box) => box.delete(txn));
    return;
  }

  @override
  Future<void> clearCache() async {
    await _roomsBox.delete(txn);
    await _accountDataBox.delete(txn);
    await _roomStateBox.delete(txn);
    await _roomMembersBox.delete(txn);
    await _eventsBox.delete(txn);
    await _timelineFragmentsBox.delete(txn);
    await _outboundGroupSessionsBox.delete(txn);
    await _presencesBox.delete(txn);
    await _clientBox.record('prev_batch').delete(txn);
  }

  @override
  Future<void> clearSSSSCache() async {
    await _ssssCacheBox.delete(txn);
  }

  @override
  Future<void> close() async {
    // We never close a sembast database
    // https://github.com/tekartik/sembast.dart/issues/219
  }

  @override
  Future<void> deleteFromToDeviceQueue(int id) async {
    await _toDeviceQueueBox.record(id).delete(txn);
    return;
  }

  @override
  Future<void> deleteOldFiles(int savedAt) async {
    return;
  }

  @override
  Future<void> forgetRoom(String roomId) async {
    await _timelineFragmentsBox
        .record(SembastKey(roomId, '').toString())
        .delete(txn);
    final eventKeys = await _eventsBox.findKeys(txn);
    for (final key in eventKeys) {
      final multiKey = SembastKey.fromString(key);
      if (multiKey.parts.first != roomId) continue;
      await _eventsBox.record(key).delete(txn);
    }
    final roomStateKeys = await _roomStateBox.findKeys(txn);
    for (final key in roomStateKeys) {
      final multiKey = SembastKey.fromString(key);
      if (multiKey.parts.first != roomId) continue;
      await _roomStateBox.record(key).delete(txn);
    }
    final roomMembersKeys = await _roomMembersBox.findKeys(txn);
    for (final key in roomMembersKeys) {
      final multiKey = SembastKey.fromString(key);
      if (multiKey.parts.first != roomId) continue;
      await _roomMembersBox.record(key).delete(txn);
    }
    final roomAccountData = await _roomAccountDataBox.findKeys(txn);
    for (final key in roomAccountData) {
      final multiKey = SembastKey.fromString(key);
      if (multiKey.parts.first != roomId) continue;
      await _roomAccountDataBox.record(key).delete(txn);
    }
    await _roomsBox.record(roomId).delete(txn);
  }

  @override
  Future<Map<String, BasicEvent>> getAccountData() async {
    // We can probably remove this benchmark once we know that findKeys is
    // nearly instant anyway.
    final keys = await runBenchmarked(
      'Get account data keys from Sembast',
      () => _accountDataBox.findKeys(txn),
    );
    return runBenchmarked<Map<String, BasicEvent>>(
        'Get all account data from Sembast', () async {
      final accountData = <String, BasicEvent>{};
      await _database.transaction((txn) async {
        for (final key in keys) {
          final raw = await _accountDataBox.record(key).get(txn);
          if (raw == null) continue;
          accountData[key.toString()] = BasicEvent(
            type: key.toString(),
            content: cloneMap(raw),
          );
        }
      });
      return accountData;
    }, keys.length);
  }

  @override
  Future<Map<String, dynamic>?> getClient(String name) =>
      runBenchmarked('Get Client from Sembast', () async {
        final map = <String, dynamic>{};
        final keys = await _clientBox.findKeys(txn);
        for (final key in keys) {
          if (key == 'version') continue;
          map[key] = await _clientBox.record(key).get(txn);
        }
        if (map.isEmpty) return null;
        return map;
      });

  @override
  Future<Event?> getEventById(String eventId, Room room) async {
    final raw = await _eventsBox
        .record(SembastKey(room.id, eventId).toString())
        .get(txn);
    if (raw == null) return null;
    return Event.fromJson(cloneMap(raw), room);
  }

  /// Loads a whole list of events at once from the store for a specific room
  Future<List<Event>> _getEventsByIds(List<String> eventIds, Room room) =>
      Future.wait(eventIds
          .map(
            (eventId) async => Event.fromJson(
              cloneMap(
                (await _eventsBox
                    .record(SembastKey(room.id, eventId).toString())
                    .get(txn))!,
              ),
              room,
            ),
          )
          .toList());

  @override
  Future<List<Event>> getEventList(
    Room room, {
    int start = 0,
    int? limit,
  }) =>
      runBenchmarked<List<Event>>('Get event list', () async {
        // Get the synced event IDs from the store
        final timelineKey = SembastKey(room.id, '').toString();
        final timelineEventIds =
            (await _timelineFragmentsBox.record(timelineKey).get(txn) ?? []);

        // Get the local stored SENDING events from the store
        late final List sendingEventIds;
        if (start != 0) {
          sendingEventIds = [];
        } else {
          final sendingTimelineKey = SembastKey(room.id, 'SENDING').toString();
          sendingEventIds = (await _timelineFragmentsBox
                  .record(sendingTimelineKey)
                  .get(txn) ??
              []);
        }

        // Combine those two lists while respecting the start and limit parameters.
        final end = min(timelineEventIds.length,
            start + (limit ?? timelineEventIds.length));
        final eventIds = sendingEventIds +
            (start < timelineEventIds.length
                ? timelineEventIds.getRange(start, end).toList()
                : []);

        return await _getEventsByIds(eventIds.cast<String>(), room);
      });

  @override
  Future<Uint8List?> getFile(Uri mxcUri) async {
    return null;
  }

  @override
  Future<StoredInboundGroupSession?> getInboundGroupSession(
    String roomId,
    String sessionId,
  ) async {
    final raw = await _inboundGroupSessionsBox.record(sessionId).get(txn);
    if (raw == null) return null;
    return StoredInboundGroupSession.fromJson(cloneMap(raw));
  }

  @override
  Future<List<StoredInboundGroupSession>>
      getInboundGroupSessionsToUpload() async {
    final sessions = await _inboundGroupSessionsBox.find(
      txn,
      finder: Finder(
        limit: 50,
        filter: Filter.equals('uploaded', false),
      ),
    );
    return sessions
        .map((json) => StoredInboundGroupSession.fromJson(cloneMap(json.value)))
        .toList();
  }

  @override
  Future<List<String>> getLastSentMessageUserDeviceKey(
      String userId, String deviceId) async {
    final raw = await _userDeviceKeysBox
        .record(SembastKey(userId, deviceId).toString())
        .get(txn);
    if (raw == null) return <String>[];
    return [raw['last_sent_message'] as String];
  }

  @override
  Future<void> storeOlmSession(String identityKey, String sessionId,
      String pickle, int lastReceived) async {
    final rawSessions =
        cloneMap(await _olmSessionsBox.record(identityKey).get(txn) ?? {});
    rawSessions[sessionId] = <String, dynamic>{
      'identity_key': identityKey,
      'pickle': pickle,
      'session_id': sessionId,
      'last_received': lastReceived,
    };
    await _olmSessionsBox.record(identityKey).put(txn, rawSessions);
    return;
  }

  @override
  Future<List<OlmSession>> getOlmSessions(
      String identityKey, String userId) async {
    final rawSessions = await _olmSessionsBox.record(identityKey).get(txn);
    if (rawSessions == null || rawSessions.isEmpty) return <OlmSession>[];
    return rawSessions.values
        .map((json) => OlmSession.fromJson(cloneMap(json as Map), userId))
        .toList();
  }

  @override
  Future<List<OlmSession>> getOlmSessionsForDevices(
      List<String> identityKey, String userId) async {
    final sessions = await Future.wait(
        identityKey.map((identityKey) => getOlmSessions(identityKey, userId)));
    return <OlmSession>[for (final sublist in sessions) ...sublist];
  }

  @override
  Future<OutboundGroupSession?> getOutboundGroupSession(
      String roomId, String userId) async {
    final raw = await _outboundGroupSessionsBox.record(roomId).get(txn);
    if (raw == null) return null;
    return OutboundGroupSession.fromJson(cloneMap(raw), userId);
  }

  @override
  Future<List<Room>> getRoomList(Client client) async {
    // We can probably remove this benchmark once we know that findKeys is
    // nearly instant anyway.
    final keys = await runBenchmarked(
      'Get rooms box keys',
      () => _roomsBox.findKeys(txn),
    );
    return runBenchmarked<List<Room>>('Get room list from Sembast', () async {
      final rooms = <String, Room>{};
      await _database.transaction((txn) async {
        final userID = client.userID;
        final importantRoomStates = client.importantStateEvents;
        for (final key in keys) {
          // Get the room
          final raw = await _roomsBox.record(key).get(txn);
          if (raw == null) continue;
          final room = Room.fromJson(cloneMap(raw), client);

          // let's see if we need any m.room.member events
          // We always need the member event for ourself
          final membersToPostload = <String>{if (userID != null) userID};
          // If the room is a direct chat, those IDs should be there too
          if (room.isDirectChat) {
            membersToPostload.add(room.directChatMatrixID!);
          }
          // the lastEvent message preview might have an author we need to fetch, if it is a group chat
          final lastEvent = room.getState(EventTypes.Message);
          if (lastEvent != null && !room.isDirectChat) {
            membersToPostload.add(lastEvent.senderId);
          }
          // if the room has no name and no canonical alias, its name is calculated
          // based on the heroes of the room
          if (room.getState(EventTypes.RoomName) == null &&
              room.getState(EventTypes.RoomCanonicalAlias) == null) {
            // we don't have a name and no canonical alias, so we'll need to
            // post-load the heroes
            membersToPostload.addAll(room.summary.mHeroes ?? []);
          }
          // Load members
          for (final userId in membersToPostload) {
            final state = await _roomMembersBox
                .record(SembastKey(room.id, userId).toString())
                .get(txn);
            if (state == null) {
              Logs().w('Unable to post load member $userId');
              continue;
            }
            room.setState(Event.fromJson(cloneMap(state), room));
          }

          // Get the "important" room states. All other states will be loaded once
          // `getUnimportantRoomStates()` is called.
          for (final type in importantRoomStates) {
            final states = await _roomStateBox
                .record(SembastKey(room.id, type).toString())
                .get(txn);
            if (states == null) continue;
            final stateEvents = states.values
                .map((raw) => Event.fromJson(cloneMap(raw as Map), room))
                .toList();
            for (final state in stateEvents) {
              room.setState(state);
            }
          }

          // Add to the list and continue.
          rooms[room.id] = room;
        }

        // Get the room account data
        final accountDataKeys = await _roomAccountDataBox.findKeys(txn);
        for (final key in accountDataKeys) {
          final roomId = SembastKey.fromString(key).parts.first;
          if (rooms.containsKey(roomId)) {
            final raw = await _roomAccountDataBox.record(key).get(txn);
            if (raw == null) continue;
            final basicRoomEvent = BasicRoomEvent.fromJson(
              cloneMap(raw),
            );
            rooms[roomId]!.roomAccountData[basicRoomEvent.type] =
                basicRoomEvent;
          } else {
            Logs().w(
                'Found account data for unknown room $roomId. Delete now...');
            await _roomAccountDataBox.record(key).delete(txn);
          }
        }
      });
      return rooms.values.toList();
    }, keys.length);
  }

  @override
  Future<SSSSCache?> getSSSSCache(String type) async {
    final raw = await _ssssCacheBox.record(type).get(txn);
    if (raw == null) return null;
    return SSSSCache.fromJson(cloneMap(raw));
  }

  @override
  Future<List<QueuedToDeviceEvent>> getToDeviceEventQueue() async {
    final keys = await _toDeviceQueueBox.findKeys(txn);
    return await Future.wait(keys.map((i) async {
      final raw = await _toDeviceQueueBox.record(i).get(txn);
      final json = cloneMap(raw!);
      json['id'] = i;
      return QueuedToDeviceEvent.fromJson(json);
    }).toList());
  }

  @override
  Future<List<Event>> getUnimportantRoomEventStatesForRoom(
      List<String> events, Room room) async {
    final keys = (await _roomStateBox.findKeys(txn)).where((key) {
      final tuple = SembastKey.fromString(key);
      return tuple.parts.first == room.id && !events.contains(tuple.parts[1]);
    });

    final unimportantEvents = <Event>[];
    for (final key in keys) {
      final states = await _roomStateBox.record(key).get(txn);
      if (states == null) continue;
      unimportantEvents.addAll(states.values
          .map((raw) => Event.fromJson(cloneMap(raw as Map), room)));
    }
    return unimportantEvents;
  }

  @override
  Future<User?> getUser(String userId, Room room) async {
    final state = await _roomMembersBox
        .record(SembastKey(room.id, userId).toString())
        .get(txn);
    if (state == null) return null;
    return Event.fromJson(cloneMap(state), room).asUser;
  }

  @override
  Future<Map<String, DeviceKeysList>> getUserDeviceKeys(Client client) async {
    // We can probably remove this benchmark once we know that findKeys is
    // nearly instant anyway.
    final keys = await runBenchmarked(
      'Get user device keys box keys',
      () => _userDeviceKeysBox.findKeys(txn),
    );
    return runBenchmarked<Map<String, DeviceKeysList>>(
        'Get all user device keys from Sembast', () async {
      final deviceKeysOutdated = await _userDeviceKeysOutdatedBox.findKeys(txn);
      if (deviceKeysOutdated.isEmpty) {
        return {};
      }
      final res = <String, DeviceKeysList>{};
      await _database.transaction((txn) async {
        for (final userId in deviceKeysOutdated) {
          final deviceKeysBoxKeys = keys.where((tuple) {
            final tupleKey = SembastKey.fromString(tuple);
            return tupleKey.parts.first == userId;
          });
          final crossSigningKeysBoxKeys =
              (await _userCrossSigningKeysBox.findKeys(txn)).where((tuple) {
            final tupleKey = SembastKey.fromString(tuple);
            return tupleKey.parts.first == userId;
          });
          res[userId] = DeviceKeysList.fromDbJson(
              {
                'client_id': client.id,
                'user_id': userId,
                'outdated':
                    await _userDeviceKeysOutdatedBox.record(userId).get(txn),
              },
              await Future.wait(deviceKeysBoxKeys.map((key) async =>
                  cloneMap((await _userDeviceKeysBox.record(key).get(txn))!))),
              await Future.wait(crossSigningKeysBoxKeys.map((key) async =>
                  cloneMap(
                      (await _userCrossSigningKeysBox.record(key).get(txn))!))),
              client);
        }
      });
      return res;
    }, keys.length);
  }

  @override
  Future<List<User>> getUsers(Room room) async {
    final users = <User>[];
    await _database.transaction((txn) async {
      final keys = await _roomMembersBox.findKeys(txn);
      for (final key in keys) {
        final statesKey = SembastKey.fromString(key);
        if (statesKey.parts[0] != room.id) continue;
        final state = await _roomMembersBox.record(key).get(txn);
        if (state == null) continue;
        users.add(Event.fromJson(cloneMap(state), room).asUser);
      }
    });
    return users;
  }

  @override
  Future<void> insertClient(
          String name,
          String homeserverUrl,
          String token,
          String userId,
          String? deviceId,
          String? deviceName,
          String? prevBatch,
          String? olmAccount) =>
      _database.transaction((txn) async {
        await _clientBox.record('homeserver_url').put(txn, homeserverUrl);
        await _clientBox.record('token').put(txn, token);
        await _clientBox.record('user_id').put(txn, userId);
        if (deviceId == null) {
          await _clientBox.record('device_id').delete(txn);
        } else {
          await _clientBox.record('device_id').put(txn, deviceId);
        }
        if (deviceName == null) {
          await _clientBox.record('device_name').delete(txn);
        } else {
          await _clientBox.record('device_name').put(txn, deviceName);
        }
        if (prevBatch == null) {
          await _clientBox.record('prev_batch').delete(txn);
        } else {
          await _clientBox.record('prev_batch').put(txn, prevBatch);
        }
        if (olmAccount == null) {
          await _clientBox.record('olm_account').delete(txn);
        } else {
          await _clientBox.record('olm_account').put(txn, olmAccount);
        }
        await _clientBox.record('sync_filter_id').delete(txn);
      });

  @override
  Future<int> insertIntoToDeviceQueue(
      String type, String txnId, String content) async {
    return await _toDeviceQueueBox.add(txn, <String, dynamic>{
      'type': type,
      'txn_id': txnId,
      'content': content,
    });
  }

  @override
  Future<void> markInboundGroupSessionAsUploaded(
      String roomId, String sessionId) async {
    final raw = await _inboundGroupSessionsBox.record(sessionId).get(txn);
    if (raw == null) {
      Logs().w(
          'Tried to mark inbound group session as uploaded which was not found in the database!');
      return;
    }
    final json = cloneMap(raw);
    json['uploaded'] = true;
    await _inboundGroupSessionsBox.record(sessionId).put(txn, json);
    return;
  }

  @override
  Future<void> markInboundGroupSessionsAsNeedingUpload() async {
    await _database.transaction((txn) async {
      final keys = await _inboundGroupSessionsBox.findKeys(txn);
      for (final sessionId in keys) {
        final raw = await _inboundGroupSessionsBox.record(sessionId).get(txn);
        if (raw == null) continue;
        final json = cloneMap(raw);
        json['uploaded'] = false;
        await _inboundGroupSessionsBox.record(sessionId).put(txn, json);
      }
    });
    return;
  }

  @override
  Future<void> removeEvent(String eventId, String roomId) async {
    await _eventsBox.record(SembastKey(roomId, eventId).toString()).delete(txn);
    final keys = await _timelineFragmentsBox.findKeys(txn);
    for (final key in keys) {
      final multiKey = SembastKey.fromString(key);
      if (multiKey.parts.first != roomId) continue;
      final eventIds = List<String>.from(
          await _timelineFragmentsBox.record(key).get(txn) ?? []);
      final prevLength = eventIds.length;
      eventIds.removeWhere((id) => id == eventId);
      if (eventIds.length < prevLength) {
        await _timelineFragmentsBox.record(key).put(txn, eventIds);
      }
    }
    return;
  }

  @override
  Future<void> removeOutboundGroupSession(String roomId) async {
    await _outboundGroupSessionsBox.record(roomId).delete(txn);
    return;
  }

  @override
  Future<void> removeUserCrossSigningKey(
      String userId, String publicKey) async {
    await _userCrossSigningKeysBox
        .record(SembastKey(userId, publicKey).toString())
        .delete(txn);
    return;
  }

  @override
  Future<void> removeUserDeviceKey(String userId, String deviceId) async {
    await _userDeviceKeysBox
        .record(SembastKey(userId, deviceId).toString())
        .delete(txn);
    return;
  }

  @override
  Future<void> resetNotificationCount(String roomId) async {
    final raw = await _roomsBox.record(roomId).get(txn);
    if (raw == null) return;
    final json = cloneMap(raw);
    json['notification_count'] = json['highlight_count'] = 0;
    await _roomsBox.record(roomId).put(txn, json);
    return;
  }

  @override
  Future<void> setBlockedUserCrossSigningKey(
      bool blocked, String userId, String publicKey) async {
    final raw = await _userCrossSigningKeysBox
        .record(SembastKey(userId, publicKey).toString())
        .get(txn);
    if (raw == null) {
      Logs().w('User cross signing key $publicKey of $userId not found');
      return;
    }
    final json = cloneMap(raw);
    json['blocked'] = blocked;
    await _userCrossSigningKeysBox
        .record(SembastKey(userId, publicKey).toString())
        .put(
          txn,
          json,
        );
    return;
  }

  @override
  Future<void> setBlockedUserDeviceKey(
      bool blocked, String userId, String deviceId) async {
    final raw = await _userDeviceKeysBox
        .record(SembastKey(userId, deviceId).toString())
        .get(txn);
    if (raw == null) {
      Logs().w('Device key $deviceId of $userId not found');
      return;
    }
    final json = cloneMap(raw);
    json['blocked'] = blocked;
    await _userDeviceKeysBox
        .record(SembastKey(userId, deviceId).toString())
        .put(
          txn,
          json,
        );
    return;
  }

  @override
  Future<void> setLastActiveUserDeviceKey(
      int lastActive, String userId, String deviceId) async {
    final raw = await _userDeviceKeysBox
        .record(SembastKey(userId, deviceId).toString())
        .get(txn);
    if (raw == null) {
      Logs().w('Device key $deviceId of $userId not found');
      return;
    }
    final json = cloneMap(raw);
    json['last_active'] = lastActive;
    await _userDeviceKeysBox
        .record(SembastKey(userId, deviceId).toString())
        .put(
          txn,
          json,
        );
  }

  @override
  Future<void> setLastSentMessageUserDeviceKey(
      String lastSentMessage, String userId, String deviceId) async {
    final raw = await _userDeviceKeysBox
        .record(SembastKey(userId, deviceId).toString())
        .get(txn);
    if (raw == null) {
      Logs().w('Device key $deviceId of $userId not found');
      return;
    }
    final json = cloneMap(raw);
    json['last_sent_message'] = lastSentMessage;
    await _userDeviceKeysBox
        .record(SembastKey(userId, deviceId).toString())
        .put(
          txn,
          json,
        );
  }

  @override
  Future<void> setRoomPrevBatch(
      String prevBatch, String roomId, Client client) async {
    final raw = await _roomsBox.record(roomId).get(txn);
    if (raw == null) return;
    final room = Room.fromJson(cloneMap(raw), client);
    room.prev_batch = prevBatch;
    await _roomsBox.record(roomId).put(txn, room.toJson());
    return;
  }

  @override
  Future<void> setVerifiedUserCrossSigningKey(
      bool verified, String userId, String publicKey) async {
    final raw = await _userCrossSigningKeysBox
            .record(SembastKey(userId, publicKey).toString())
            .get(txn) ??
        {};
    final json = cloneMap(raw);
    json['verified'] = verified;
    await _userCrossSigningKeysBox
        .record(SembastKey(userId, publicKey).toString())
        .put(
          txn,
          json,
        );
    return;
  }

  @override
  Future<void> setVerifiedUserDeviceKey(
      bool verified, String userId, String deviceId) async {
    final raw = await _userDeviceKeysBox
        .record(SembastKey(userId, deviceId).toString())
        .get(txn);
    if (raw == null) {
      Logs().w('Device key $deviceId of $userId not found');
      return;
    }
    final json = cloneMap(raw);
    json['verified'] = verified;
    await _userDeviceKeysBox
        .record(SembastKey(userId, deviceId).toString())
        .put(
          txn,
          json,
        );
    return;
  }

  @override
  Future<void> storeAccountData(String type, String content) async {
    await _accountDataBox.record(type).put(txn, cloneMap(jsonDecode(content)));
    return;
  }

  @override
  Future<void> storeEventUpdate(EventUpdate eventUpdate, Client client) async {
    // Ephemerals should not be stored
    if (eventUpdate.type == EventUpdateType.ephemeral) return;
    final tmpRoom = Room(id: eventUpdate.roomID, client: client);

    // In case of this is a redaction event
    if (eventUpdate.content['type'] == EventTypes.Redaction) {
      final event = await getEventById(eventUpdate.content['redacts'], tmpRoom);
      if (event != null) {
        event.setRedactionEvent(Event.fromJson(eventUpdate.content, tmpRoom));
        await _eventsBox
            .record(SembastKey(eventUpdate.roomID, event.eventId).toString())
            .put(txn, event.toJson());
      }
    }

    // Store a common message event
    if ({EventUpdateType.timeline, EventUpdateType.history}
        .contains(eventUpdate.type)) {
      final eventId = eventUpdate.content['event_id'];
      // Is this ID already in the store?
      final prevEvent = await _eventsBox
          .record(SembastKey(eventUpdate.roomID, eventId).toString())
          .get(txn);
      final prevStatus = prevEvent == null
          ? null
          : () {
              final json = cloneMap(prevEvent);
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

      await _eventsBox
          .record(SembastKey(eventUpdate.roomID, eventId).toString())
          .put(txn, eventUpdate.content);

      // Update timeline fragments
      final key = SembastKey(eventUpdate.roomID, status.isSent ? '' : 'SENDING')
          .toString();

      final eventIds = List<String>.from(
          await _timelineFragmentsBox.record(key).get(txn) ?? []);

      if (!eventIds.contains(eventId)) {
        if (eventUpdate.type == EventUpdateType.history) {
          eventIds.add(eventId);
        } else {
          eventIds.insert(0, eventId);
        }
        await _timelineFragmentsBox.record(key).put(txn, eventIds);
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
        final key = SembastKey(eventUpdate.roomID, 'SENDING').toString();
        final eventIds = List<String>.from(
            await _timelineFragmentsBox.record(key).get(txn) ?? []);
        final i = eventIds.indexWhere((id) => id == eventId);
        if (i != -1) {
          await _timelineFragmentsBox
              .record(key)
              .put(txn, eventIds..removeAt(i));
        }
      }

      // Is there a transaction id? Then delete the event with this id.
      if (!status.isError && !status.isSending && transactionId != null) {
        await removeEvent(transactionId, eventUpdate.roomID);
      }
    }

    // Store a common state event
    if ({
      EventUpdateType.timeline,
      EventUpdateType.state,
      EventUpdateType.inviteState
    }.contains(eventUpdate.type)) {
      if (eventUpdate.content['type'] == EventTypes.RoomMember) {
        await _roomMembersBox
            .record(SembastKey(
              eventUpdate.roomID,
              eventUpdate.content['state_key'],
            ).toString())
            .put(txn, eventUpdate.content);
      } else {
        final key = SembastKey(
          eventUpdate.roomID,
          eventUpdate.content['type'],
        ).toString();
        final stateMap =
            cloneMap(await _roomStateBox.record(key).get(txn) ?? {});
        // store state events and new messages, that either are not an edit or an edit of the lastest message
        // An edit is an event, that has an edit relation to the latest event. In some cases for the second edit, we need to compare if both have an edit relation to the same event instead.
        if (eventUpdate.content
                .tryGetMap<String, dynamic>('content')
                ?.tryGetMap<String, dynamic>('m.relates_to') ==
            null) {
          stateMap[eventUpdate.content['state_key'] ?? ''] =
              eventUpdate.content;
          await _roomStateBox.record(key).put(txn, stateMap);
        } else {
          final editedEventRelationshipEventId = eventUpdate.content
              .tryGetMap<String, dynamic>('content')
              ?.tryGetMap<String, dynamic>('m.relates_to')
              ?.tryGet<String>('event_id');
          final state = stateMap[''] == null
              ? null
              : Event.fromJson(stateMap[''] as Map<String, dynamic>, tmpRoom);
          if (eventUpdate.content['type'] != EventTypes.Message ||
              eventUpdate.content
                      .tryGetMap<String, dynamic>('content')
                      ?.tryGetMap<String, dynamic>('m.relates_to')
                      ?.tryGet<String>('rel_type') !=
                  RelationshipTypes.edit ||
              editedEventRelationshipEventId == state?.eventId ||
              ((state?.relationshipType == RelationshipTypes.edit &&
                  editedEventRelationshipEventId ==
                      state?.relationshipEventId))) {
            stateMap[eventUpdate.content['state_key'] ?? ''] =
                eventUpdate.content;
            await _roomStateBox.record(key).put(txn, stateMap);
          }
        }
      }
    }

    // Store a room account data event
    if (eventUpdate.type == EventUpdateType.accountData) {
      await _roomAccountDataBox
          .record(SembastKey(
            eventUpdate.roomID,
            eventUpdate.content['type'],
          ).toString())
          .put(
            txn,
            eventUpdate.content,
          );
    }
  }

  @override
  Future<void> storeFile(Uri mxcUri, Uint8List bytes, int time) async {
    return;
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
    await _inboundGroupSessionsBox.record(sessionId).put(
        txn,
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
        ).toJson());
    return;
  }

  @override
  Future<void> storeOutboundGroupSession(
      String roomId, String pickle, String deviceIds, int creationTime) async {
    await _outboundGroupSessionsBox.record(roomId).put(txn, <String, dynamic>{
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
    final keys = await _clientBox.findKeys(txn);
    if (keys.isEmpty) return;
    await _clientBox.record('prev_batch').put(txn, prevBatch);
    return;
  }

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
    // Make sure room exists
    final roomsBoxKeys = await _roomsBox.findKeys(txn);
    if (!roomsBoxKeys.contains(roomId)) {
      await _roomsBox.record(roomId).put(
          txn,
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
                ).toJson()
              : Room(
                  client: client,
                  id: roomId,
                  membership: membership,
                ).toJson());
    } else if (roomUpdate is JoinedRoomUpdate) {
      final currentRawRoom = await _roomsBox.record(roomId).get(txn);
      final currentRoom = Room.fromJson(cloneMap(currentRawRoom!), client);
      await _roomsBox.record(roomId).put(
          txn,
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
          ).toJson());
    }

    // Is the timeline limited? Then all previous messages should be
    // removed from the database!
    if (roomUpdate is JoinedRoomUpdate &&
        roomUpdate.timeline?.limited == true) {
      await _timelineFragmentsBox
          .record(SembastKey(roomId, '').toString())
          .delete(txn);
    }
  }

  @override
  Future<void> storeSSSSCache(
      String type, String keyId, String ciphertext, String content) async {
    await _ssssCacheBox.record(type).put(
        txn,
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
    await _clientBox.record('sync_filter_id').put(txn, syncFilterId);
  }

  @override
  Future<void> storeUserCrossSigningKey(String userId, String publicKey,
      String content, bool verified, bool blocked) async {
    await _userCrossSigningKeysBox
        .record(SembastKey(userId, publicKey).toString())
        .put(
      txn,
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
    await _userDeviceKeysBox
        .record(SembastKey(userId, deviceId).toString())
        .put(txn, {
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
    await _userDeviceKeysOutdatedBox.record(userId).put(txn, outdated);
    return;
  }

  Completer<void>? _transactionLock;
  final _transactionZones = <Zone>{};

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
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
          var future;
          await _database.transaction((txn) async {
            _currentTransaction = txn;
            try {
              future = await action();
            } finally {
              _currentTransaction = null;
            }
          });
          return future;
        } finally {
          // aaaand remove the zone from _transactionZones again
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
  Future<void> updateClient(
    String homeserverUrl,
    String token,
    String userId,
    String? deviceId,
    String? deviceName,
    String? prevBatch,
    String? olmAccount,
  ) =>
      _database.transaction((txn) async {
        await _clientBox.record('homeserver_url').put(txn, homeserverUrl);
        await _clientBox.record('token').put(txn, token);
        await _clientBox.record('user_id').put(txn, userId);
        if (deviceId == null) {
          await _clientBox.record('device_id').delete(txn);
        } else {
          await _clientBox.record('device_id').put(txn, deviceId);
        }
        if (deviceName == null) {
          await _clientBox.record('device_name').delete(txn);
        } else {
          await _clientBox.record('device_name').put(txn, deviceName);
        }
        if (prevBatch == null) {
          await _clientBox.record('prev_batch').delete(txn);
        } else {
          await _clientBox.record('prev_batch').put(txn, prevBatch);
        }
        if (olmAccount == null) {
          await _clientBox.record('olm_account').delete(txn);
        } else {
          await _clientBox.record('olm_account').put(txn, olmAccount);
        }
      });

  @override
  Future<void> updateClientKeys(
    String olmAccount,
  ) async {
    await _clientBox.record('olm_account').put(txn, olmAccount);
    return;
  }

  @override
  Future<void> updateInboundGroupSessionAllowedAtIndex(
      String allowedAtIndex, String roomId, String sessionId) async {
    final raw = await _inboundGroupSessionsBox.record(sessionId).get(txn);
    if (raw == null) {
      Logs().w(
          'Tried to update inbound group session as uploaded which wasnt found in the database!');
      return;
    }
    final json = cloneMap(raw);
    json['allowed_at_index'] = allowedAtIndex;
    await _inboundGroupSessionsBox.record(sessionId).put(txn, json);
    return;
  }

  @override
  Future<void> updateInboundGroupSessionIndexes(
      String indexes, String roomId, String sessionId) async {
    final raw = await _inboundGroupSessionsBox.record(sessionId).get(txn);
    if (raw == null) {
      Logs().w(
          'Tried to update inbound group session indexes of a session which was not found in the database!');
      return;
    }
    final json = cloneMap(raw);
    json['indexes'] = indexes;
    await _inboundGroupSessionsBox.record(sessionId).put(txn, json);
    return;
  }

  @override
  Future<void> updateRoomSortOrder(
      double oldestSortOrder, double newestSortOrder, String roomId) async {
    final raw = await _roomsBox.record(roomId).get(txn);
    if (raw == null) return;
    final json = cloneMap(raw);
    json['oldest_sort_order'] = oldestSortOrder;
    json['newest_sort_order'] = newestSortOrder;
    await _roomsBox.record(roomId).put(txn, json);
    return;
  }

  @override
  Future<List<StoredInboundGroupSession>> getAllInboundGroupSessions() async {
    final keys = await _inboundGroupSessionsBox.findKeys(txn);
    final rawSessions = await Future.wait(
        keys.map((key) => _inboundGroupSessionsBox.record(key).get(txn)));
    return rawSessions
        .map((raw) => StoredInboundGroupSession.fromJson(cloneMap(raw!)))
        .toList();
  }

  @override
  Future<void> addSeenDeviceId(
    String userId,
    String deviceId,
    String publicKeysHash,
  ) =>
      _seenDeviceIdsBox
          .record(SembastKey(userId, deviceId).toString())
          .put(txn, publicKeysHash);

  @override
  Future<void> addSeenPublicKey(
    String publicKey,
    String deviceId,
  ) =>
      _seenDeviceKeysBox.record(publicKey).put(txn, deviceId);

  @override
  Future<String?> deviceIdSeen(userId, deviceId) async {
    final raw = await _seenDeviceIdsBox
        .record(SembastKey(userId, deviceId).toString())
        .get(txn);
    if (raw == null) return null;
    return raw;
  }

  @override
  Future<String?> publicKeySeen(String publicKey) async {
    final raw = await _seenDeviceKeysBox.record(publicKey).get(txn);
    if (raw == null) return null;
    return raw;
  }
}

class SembastKey {
  final List<String> parts;

  SembastKey(String key1, [String? key2, String? key3])
      : parts = [
          key1,
          if (key2 != null) key2,
          if (key3 != null) key3,
        ];

  const SembastKey.byParts(this.parts);

  SembastKey.fromString(String multiKeyString)
      : parts = multiKeyString.split('|').toList();

  @override
  String toString() => parts.join('|');

  @override
  bool operator ==(other) => parts.toString() == other.toString();
}
