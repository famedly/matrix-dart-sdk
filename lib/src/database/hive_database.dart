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

import 'package:hive/hive.dart';

import 'package:matrix/encryption/utils/olm_session.dart';
import 'package:matrix/encryption/utils/outbound_group_session.dart';
import 'package:matrix/encryption/utils/ssss_cache.dart';
import 'package:matrix/encryption/utils/stored_inbound_group_session.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/database/zone_transaction_mixin.dart';
import 'package:matrix/src/utils/copy_map.dart';
import 'package:matrix/src/utils/queued_to_device_event.dart';
import 'package:matrix/src/utils/run_benchmarked.dart';

/// This is a basic database for the Matrix SDK using the hive store. You need
/// to make sure that you perform `Hive.init()` or `Hive.flutterInit()` before
/// you use this.
///
/// This database does not support file caching!
@Deprecated(
    'Use [MatrixSdkDatabase] instead. Don\'t forget to properly migrate!')
class FamedlySdkHiveDatabase extends DatabaseApi with ZoneTransactionMixin {
  static const int version = 6;
  final String name;
  late Box _clientBox;
  late Box _accountDataBox;
  late Box _roomsBox;
  late Box _toDeviceQueueBox;

  /// Key is a tuple as MultiKey(roomId, type) where stateKey can be
  /// an empty string.
  late LazyBox _roomStateBox;

  /// Key is a tuple as MultiKey(roomId, userId)
  late LazyBox _roomMembersBox;

  /// Key is a tuple as MultiKey(roomId, type)
  late LazyBox _roomAccountDataBox;
  late LazyBox _inboundGroupSessionsBox;
  late LazyBox _outboundGroupSessionsBox;
  late LazyBox _olmSessionsBox;

  /// Key is a tuple as MultiKey(userId, deviceId)
  late LazyBox _userDeviceKeysBox;

  /// Key is the user ID as a String
  late LazyBox _userDeviceKeysOutdatedBox;

  /// Key is a tuple as MultiKey(userId, publicKey)
  late LazyBox _userCrossSigningKeysBox;
  late LazyBox _ssssCacheBox;
  late LazyBox _presencesBox;

  /// Key is a tuple as Multikey(roomId, fragmentId) while the default
  /// fragmentId is an empty String
  late LazyBox _timelineFragmentsBox;

  /// Key is a tuple as MultiKey(roomId, eventId)
  late LazyBox _eventsBox;

  /// Key is a tuple as MultiKey(userId, deviceId)
  late LazyBox _seenDeviceIdsBox;

  late LazyBox _seenDeviceKeysBox;

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

  final HiveCipher? encryptionCipher;

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
        action(_seenDeviceIdsBox),
        action(_seenDeviceKeysBox),
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
    _seenDeviceIdsBox = await Hive.openLazyBox(
      _seenDeviceIdsBoxName,
      encryptionCipher: encryptionCipher,
    );
    _seenDeviceKeysBox = await Hive.openLazyBox(
      _seenDeviceKeysBoxName,
      encryptionCipher: encryptionCipher,
    );

    // Check version and check if we need a migration
    final currentVersion = (await _clientBox.get('version') as int?);
    if (currentVersion == null) {
      await _clientBox.put('version', version);
    } else if (currentVersion != version) {
      await _migrateFromVersion(currentVersion);
    }

    return;
  }

  Future<void> _migrateFromVersion(int currentVersion) async {
    Logs().i('Migrate Hive database from version $currentVersion to $version');
    if (version == 5) {
      for (final key in _userDeviceKeysBox.keys) {
        try {
          final raw = await _userDeviceKeysBox.get(key) as Map;
          if (!raw.containsKey('keys')) continue;
          final deviceKeys = DeviceKeys.fromJson(
            convertToJson(raw),
            Client(''),
          );
          await addSeenDeviceId(deviceKeys.userId, deviceKeys.deviceId!,
              deviceKeys.curve25519Key! + deviceKeys.ed25519Key!);
          await addSeenPublicKey(deviceKeys.ed25519Key!, deviceKeys.deviceId!);
          await addSeenPublicKey(
              deviceKeys.curve25519Key!, deviceKeys.deviceId!);
        } catch (e) {
          Logs().w('Can not migrate device $key', e);
        }
      }
    }
    await clearCache();
    await _clientBox.put('version', version);
  }

  @override
  Future<void> clear() async {
    Logs().i('Clear and close hive database...');
    await _actionOnAllBoxes((box) async {
      try {
        await box.deleteAll(box.keys);
        await box.close();
      } catch (e) {
        Logs().v('Unable to clear box ${box.name}', e);
        await box.deleteFromDisk();
      }
    });
    return;
  }

  @override
  Future<void> clearCache() async {
    await _roomsBox.deleteAll(_roomsBox.keys);
    await _accountDataBox.deleteAll(_accountDataBox.keys);
    await _roomAccountDataBox.deleteAll(_roomAccountDataBox.keys);
    await _roomStateBox.deleteAll(_roomStateBox.keys);
    await _roomMembersBox.deleteAll(_roomMembersBox.keys);
    await _eventsBox.deleteAll(_eventsBox.keys);
    await _timelineFragmentsBox.deleteAll(_timelineFragmentsBox.keys);
    await _outboundGroupSessionsBox.deleteAll(_outboundGroupSessionsBox.keys);
    await _presencesBox.deleteAll(_presencesBox.keys);
    await _clientBox.delete('prev_batch');
  }

  @override
  Future<void> clearSSSSCache() async {
    await _ssssCacheBox.deleteAll(_ssssCacheBox.keys);
  }

  @override
  Future<void> close() => _actionOnAllBoxes((box) => box.close());

  @override
  Future<void> deleteFromToDeviceQueue(int id) async {
    await _toDeviceQueueBox.delete(id);
    return;
  }

  @override
  Future<void> deleteOldFiles(int savedAt) async {
    return;
  }

  @override
  Future<void> forgetRoom(String roomId) async {
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
  Future<Map<String, BasicEvent>> getAccountData() =>
      runBenchmarked<Map<String, BasicEvent>>('Get all account data from Hive',
          () async {
        final accountData = <String, BasicEvent>{};
        for (final key in _accountDataBox.keys) {
          final raw = await _accountDataBox.get(key);
          accountData[key.toString().fromHiveKey] = BasicEvent(
            type: key.toString().fromHiveKey,
            content: convertToJson(raw),
          );
        }
        return accountData;
      }, _accountDataBox.keys.length);

  @override
  Future<Map<String, dynamic>?> getClient(String name) =>
      runBenchmarked('Get Client from Hive', () async {
        final map = <String, dynamic>{};
        for (final key in _clientBox.keys) {
          if (key == 'version') continue;
          map[key] = await _clientBox.get(key);
        }
        if (map.isEmpty) return null;
        return map;
      });

  @override
  Future<Event?> getEventById(String eventId, Room room) async {
    final raw = await _eventsBox.get(MultiKey(room.id, eventId).toString());
    if (raw == null) return null;
    return Event.fromJson(convertToJson(raw), room);
  }

  /// Loads a whole list of events at once from the store for a specific room
  Future<List<Event>> _getEventsByIds(List<String> eventIds, Room room) async {
    final events = await Future.wait(eventIds.map((String eventId) async {
      final entry = await _eventsBox.get(MultiKey(room.id, eventId).toString());
      return entry is Map ? Event.fromJson(convertToJson(entry), room) : null;
    }));

    return events.whereType<Event>().toList();
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
        final timelineKey = MultiKey(room.id, '').toString();
        final timelineEventIds = List<String>.from(
            (await _timelineFragmentsBox.get(timelineKey)) ?? []);
        // Get the local stored SENDING events from the store
        late final List sendingEventIds;
        if (start != 0) {
          sendingEventIds = [];
        } else {
          final sendingTimelineKey = MultiKey(room.id, 'SENDING').toString();
          sendingEventIds = List<String>.from(
              (await _timelineFragmentsBox.get(sendingTimelineKey)) ?? []);
        }

        // Combine those two lists while respecting the start and limit parameters.
        final end = min(timelineEventIds.length,
            start + (limit ?? timelineEventIds.length));
        final eventIds = List<String>.from(
          [
            ...sendingEventIds,
            ...(start < timelineEventIds.length && !onlySending
                ? timelineEventIds.getRange(start, end).toList()
                : [])
          ],
        );

        return await _getEventsByIds(eventIds, room);
      });

  @override
  Future<List<String>> getEventIdList(
    Room room, {
    int start = 0,
    bool includeSending = false,
    int? limit,
  }) =>
      runBenchmarked<List<String>>('Get event id list', () async {
        // Get the synced event IDs from the store
        final timelineKey = MultiKey(room.id, '').toString();

        final timelineEventIds = List<String>.from(
            (await _timelineFragmentsBox.get(timelineKey)) ?? []);

        // Get the local stored SENDING events from the store
        late final List<String> sendingEventIds;
        if (!includeSending) {
          sendingEventIds = [];
        } else {
          final sendingTimelineKey = MultiKey(room.id, 'SENDING').toString();
          sendingEventIds = List<String>.from(
              (await _timelineFragmentsBox.get(sendingTimelineKey)) ?? []);
        }

        // Combine those two lists while respecting the start and limit parameters.
        final eventIds = sendingEventIds + timelineEventIds;
        if (limit != null && eventIds.length > limit) {
          eventIds.removeRange(limit, eventIds.length);
        }

        return eventIds;
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
      String userId, String deviceId) async {
    final raw =
        await _userDeviceKeysBox.get(MultiKey(userId, deviceId).toString());
    if (raw == null) return <String>[];
    return <String>[raw['last_sent_message']];
  }

  @override
  Future<void> storeOlmSession(String identityKey, String sessionId,
      String pickle, int lastReceived) async {
    final rawSessions =
        (await _olmSessionsBox.get(identityKey.toHiveKey) as Map?) ?? {};
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
      String identityKey, String userId) async {
    final rawSessions =
        await _olmSessionsBox.get(identityKey.toHiveKey) as Map? ?? {};

    return rawSessions.values
        .map((json) => OlmSession.fromJson(convertToJson(json), userId))
        .toList();
  }

  @override
  Future<Map<String, Map>> getAllOlmSessions() async {
    final backup = Map.fromEntries(
      await Future.wait(
        _olmSessionsBox.keys.map(
          (key) async => MapEntry(
            key,
            await _olmSessionsBox.get(key),
          ),
        ),
      ),
    );
    return backup.cast<String, Map>();
  }

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
    final raw = await _outboundGroupSessionsBox.get(roomId.toHiveKey);
    if (raw == null) return null;
    return OutboundGroupSession.fromJson(convertToJson(raw), userId);
  }

  @override
  Future<Room?> getSingleRoom(Client client, String roomId,
      {bool loadImportantStates = true}) async {
    // Get raw room from database:
    final roomData = await _roomsBox.get(roomId);
    if (roomData == null) return null;
    final room = Room.fromJson(convertToJson(roomData), client);

    // Get important states:
    if (loadImportantStates) {
      final dbKeys = client.importantStateEvents
          .map((state) => TupleKey(roomId, state).toString())
          .toList();
      final rawStates = await Future.wait(
        dbKeys.map((key) => _roomStateBox.get(key)),
      );
      for (final rawState in rawStates) {
        if (rawState == null || rawState[''] == null) continue;
        room.setState(Event.fromJson(convertToJson(rawState['']), room));
      }
    }

    return room;
  }

  @override
  Future<List<Room>> getRoomList(Client client) =>
      runBenchmarked<List<Room>>('Get room list from hive', () async {
        final rooms = <String, Room>{};
        final userID = client.userID;
        final importantRoomStates = client.importantStateEvents;
        for (final key in _roomsBox.keys) {
          // Get the room
          final raw = await _roomsBox.get(key);
          final room = Room.fromJson(convertToJson(raw), client);

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
            final state =
                await _roomMembersBox.get(MultiKey(room.id, userId).toString());
            if (state == null) {
              Logs().w('Unable to post load member $userId');
              continue;
            }
            room.setState(room.membership == Membership.invite
                ? StrippedStateEvent.fromJson(copyMap(raw))
                : Event.fromJson(convertToJson(state), room));
          }

          // Get the "important" room states. All other states will be loaded once
          // `getUnimportantRoomStates()` is called.
          for (final type in importantRoomStates) {
            final states = await _roomStateBox
                .get(MultiKey(room.id, type).toString()) as Map?;
            if (states == null) continue;
            final stateEvents = states.values
                .map((raw) => room.membership == Membership.invite
                    ? StrippedStateEvent.fromJson(copyMap(raw))
                    : Event.fromJson(convertToJson(raw), room))
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
            rooms[roomId]!.roomAccountData[basicRoomEvent.type] =
                basicRoomEvent;
          } else {
            Logs().w(
                'Found account data for unknown room $roomId. Delete now...');
            await _roomAccountDataBox.delete(key);
          }
        }

        return rooms.values.toList();
      }, _roomsBox.keys.length);

  @override
  Future<SSSSCache?> getSSSSCache(String type) async {
    final raw = await _ssssCacheBox.get(type);
    if (raw == null) return null;
    return SSSSCache.fromJson(convertToJson(raw));
  }

  @override
  Future<List<QueuedToDeviceEvent>> getToDeviceEventQueue() async =>
      await Future.wait(_toDeviceQueueBox.keys.map((i) async {
        final raw = await _toDeviceQueueBox.get(i);
        raw['id'] = i;
        return QueuedToDeviceEvent.fromJson(convertToJson(raw));
      }).toList());

  @override
  Future<List<Event>> getUnimportantRoomEventStatesForRoom(
      List<String> events, Room room) async {
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
  Future<User?> getUser(String userId, Room room) async {
    final state =
        await _roomMembersBox.get(MultiKey(room.id, userId).toString());
    if (state == null) return null;
    return Event.fromJson(convertToJson(state), room).asUser;
  }

  @override
  Future<Map<String, DeviceKeysList>> getUserDeviceKeys(Client client) =>
      runBenchmarked<Map<String, DeviceKeysList>>(
          'Get all user device keys from Hive', () async {
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
              await Future.wait(deviceKeysBoxKeys.map((key) async =>
                  convertToJson(await _userDeviceKeysBox.get(key)))),
              await Future.wait(crossSigningKeysBoxKeys.map((key) async =>
                  convertToJson(await _userCrossSigningKeysBox.get(key)))),
              client);
        }
        return res;
      }, _userDeviceKeysBox.keys.length);

  @override
  Future<List<User>> getUsers(Room room) async {
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
      DateTime? tokenExpiresAt,
      String? refreshToken,
      String userId,
      String? deviceId,
      String? deviceName,
      String? prevBatch,
      String? olmAccount) async {
    await _clientBox.put('homeserver_url', homeserverUrl);
    await _clientBox.put('token', token);
    await _clientBox.put(
        'token_expires_at', tokenExpiresAt?.millisecondsSinceEpoch.toString());
    await _clientBox.put('refresh_token', refreshToken);
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
      String type, String txnId, String content) async {
    return await _toDeviceQueueBox.add(<String, dynamic>{
      'type': type,
      'txn_id': txnId,
      'content': content,
    });
  }

  @override
  Future<void> markInboundGroupSessionAsUploaded(
      String roomId, String sessionId) async {
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
  Future<void> markInboundGroupSessionsAsNeedingUpload() async {
    for (final sessionId in _inboundGroupSessionsBox.keys) {
      final raw = await _inboundGroupSessionsBox.get(sessionId);
      raw['uploaded'] = false;
      await _inboundGroupSessionsBox.put(sessionId, raw);
    }
    return;
  }

  @override
  Future<void> removeEvent(String eventId, String roomId) async {
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
  Future<void> removeOutboundGroupSession(String roomId) async {
    await _outboundGroupSessionsBox.delete(roomId.toHiveKey);
    return;
  }

  @override
  Future<void> removeUserCrossSigningKey(
      String userId, String publicKey) async {
    await _userCrossSigningKeysBox
        .delete(MultiKey(userId, publicKey).toString());
    return;
  }

  @override
  Future<void> removeUserDeviceKey(String userId, String deviceId) async {
    await _userDeviceKeysBox.delete(MultiKey(userId, deviceId).toString());
    return;
  }

  @override
  Future<void> setBlockedUserCrossSigningKey(
      bool blocked, String userId, String publicKey) async {
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
      bool blocked, String userId, String deviceId) async {
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
      int lastActive, String userId, String deviceId) async {
    final raw =
        await _userDeviceKeysBox.get(MultiKey(userId, deviceId).toString());
    raw['last_active'] = lastActive;
    await _userDeviceKeysBox.put(
      MultiKey(userId, deviceId).toString(),
      raw,
    );
  }

  @override
  Future<void> setLastSentMessageUserDeviceKey(
      String lastSentMessage, String userId, String deviceId) async {
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
      String? prevBatch, String roomId, Client client) async {
    final raw = await _roomsBox.get(roomId.toHiveKey);
    if (raw == null) return;
    final room = Room.fromJson(convertToJson(raw), client);
    room.prev_batch = prevBatch;
    await _roomsBox.put(roomId.toHiveKey, room.toJson());
    return;
  }

  @override
  Future<void> setVerifiedUserCrossSigningKey(
      bool verified, String userId, String publicKey) async {
    final raw = (await _userCrossSigningKeysBox
            .get(MultiKey(userId, publicKey).toString()) as Map?) ??
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
      bool verified, String userId, String deviceId) async {
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
  Future<void> storeAccountData(String type, String content) async {
    await _accountDataBox.put(
        type.toHiveKey, convertToJson(jsonDecode(content)));
    return;
  }

  @override
  Future<void> storeEventUpdate(EventUpdate eventUpdate, Client client) async {
    // Ephemerals should not be stored
    if (eventUpdate.type == EventUpdateType.ephemeral) return;

    // In case of this is a redaction event
    if (eventUpdate.content['type'] == EventTypes.Redaction) {
      final tmpRoom = client.getRoomById(eventUpdate.roomID) ??
          Room(id: eventUpdate.roomID, client: client);
      final eventId = eventUpdate.content.tryGet<String>('redacts');
      final event =
          eventId != null ? await getEventById(eventId, tmpRoom) : null;
      if (event != null) {
        event.setRedactionEvent(Event.fromJson(eventUpdate.content, tmpRoom));
        await _eventsBox.put(
            MultiKey(eventUpdate.roomID, event.eventId).toString(),
            event.toJson());

        if (tmpRoom.lastEvent?.eventId == event.eventId) {
          await _roomStateBox.put(
            MultiKey(eventUpdate.roomID, event.type).toString(),
            {'': event.toJson()},
          );
        }
      }
    }

    // Store a common message event
    if ({
      EventUpdateType.timeline,
      EventUpdateType.history,
      EventUpdateType.decryptedTimelineQueue
    }.contains(eventUpdate.type)) {
      final eventId = eventUpdate.content['event_id'];
      // Is this ID already in the store?
      final Map? prevEvent = await _eventsBox
          .get(MultiKey(eventUpdate.roomID, eventId).toString());
      final prevStatus = prevEvent == null
          ? null
          : () {
              final json = convertToJson(prevEvent);
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

      await _eventsBox.put(MultiKey(eventUpdate.roomID, eventId).toString(),
          eventUpdate.content);

      // Update timeline fragments
      final key = MultiKey(eventUpdate.roomID, status.isSent ? '' : 'SENDING')
          .toString();

      final List eventIds = (await _timelineFragmentsBox.get(key) ?? []);

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
        final key = MultiKey(eventUpdate.roomID, 'SENDING').toString();
        final List eventIds = (await _timelineFragmentsBox.get(key) ?? []);
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

        stateMap[stateKey] = eventUpdate.content;
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
    await _inboundGroupSessionsBox.put(
        sessionId.toHiveKey,
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
    await _outboundGroupSessionsBox.put(roomId.toHiveKey, <String, dynamic>{
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
    if (_clientBox.keys.isEmpty) return;
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
    if (!_roomsBox.containsKey(roomId.toHiveKey)) {
      await _roomsBox.put(
          roomId.toHiveKey,
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
      final currentRawRoom = await _roomsBox.get(roomId.toHiveKey);
      final currentRoom = Room.fromJson(convertToJson(currentRawRoom), client);
      await _roomsBox.put(
          roomId.toHiveKey,
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
  Future<void> storeUserDeviceKey(String userId, String deviceId,
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
  Future<void> storeUserDeviceKeysInfo(String userId, bool outdated) async {
    await _userDeviceKeysOutdatedBox.put(userId.toHiveKey, outdated);
    return;
  }

  @override
  Future<void> transaction(Future<void> Function() action) =>
      zoneTransaction(action);

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
    await _clientBox.put('homeserver_url', homeserverUrl);
    await _clientBox.put('token', token);
    await _clientBox.put(
        'token_expires_at', tokenExpiresAt?.millisecondsSinceEpoch.toString());
    await _clientBox.put('refresh_token', refreshToken);
    await _clientBox.put('user_id', userId);
    await _clientBox.put('device_id', deviceId);
    await _clientBox.put('device_name', deviceName);
    await _clientBox.put('prev_batch', prevBatch);
    await _clientBox.put('olm_account', olmAccount);
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
      String indexes, String roomId, String sessionId) async {
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
  Future<List<StoredInboundGroupSession>> getAllInboundGroupSessions() async {
    final rawSessions = await Future.wait(_inboundGroupSessionsBox.keys
        .map((key) => _inboundGroupSessionsBox.get(key)));
    return rawSessions
        .map((raw) => StoredInboundGroupSession.fromJson(convertToJson(raw)))
        .toList();
  }

  @override
  Future<void> addSeenDeviceId(
    String userId,
    String deviceId,
    String publicKeys,
  ) =>
      _seenDeviceIdsBox.put(MultiKey(userId, deviceId).toString(), publicKeys);

  @override
  Future<void> addSeenPublicKey(
    String publicKey,
    String deviceId,
  ) =>
      _seenDeviceKeysBox.put(publicKey.toHiveKey, deviceId);

  @override
  Future<String?> deviceIdSeen(userId, deviceId) async {
    final raw =
        await _seenDeviceIdsBox.get(MultiKey(userId, deviceId).toString());
    if (raw == null) return null;
    return raw as String;
  }

  @override
  Future<String?> publicKeySeen(String publicKey) async {
    final raw = await _seenDeviceKeysBox.get(publicKey.toHiveKey);
    if (raw == null) return null;
    return raw as String;
  }

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
  Future<String> exportDump() {
    // see no need to implement this in a deprecated part
    throw UnimplementedError();
  }

  @override
  Future<bool> importDump(String export) {
    // see no need to implement this in a deprecated part
    throw UnimplementedError();
  }

  @override
  Future<void> delete() => Hive.deleteFromDisk();
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

  MultiKey(String key1, [String? key2, String? key3])
      : parts = [
          key1,
          if (key2 != null) key2,
          if (key3 != null) key3,
        ];

  const MultiKey.byParts(this.parts);

  MultiKey.fromString(String multiKeyString)
      : parts = multiKeyString.split('|').map((s) => s.fromHiveKey).toList();

  @override
  String toString() => parts.map((s) => s.toHiveKey).join('|');

  @override
  bool operator ==(other) => parts.toString() == other.toString();

  @override
  int get hashCode => Object.hashAll(parts);
}

extension HiveKeyExtension on String {
  String get toHiveKey => isValidMatrixId
      ? '$sigil${Uri.encodeComponent(localpart!)}:${Uri.encodeComponent(domain!)}'
      : Uri.encodeComponent(this);
}

extension FromHiveKeyExtension on String {
  String get fromHiveKey => Uri.decodeComponent(this);
}
