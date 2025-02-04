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

import 'package:collection/collection.dart';
import 'package:olm/olm.dart' as olm;

import 'package:matrix/encryption/encryption.dart';
import 'package:matrix/encryption/utils/base64_unpadded.dart';
import 'package:matrix/encryption/utils/outbound_group_session.dart';
import 'package:matrix/encryption/utils/session_key.dart';
import 'package:matrix/encryption/utils/stored_inbound_group_session.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/run_in_root.dart';

const megolmKey = EventTypes.MegolmBackup;

class KeyManager {
  final Encryption encryption;

  Client get client => encryption.client;
  final outgoingShareRequests = <String, KeyManagerKeyShareRequest>{};
  final incomingShareRequests = <String, KeyManagerKeyShareRequest>{};
  final _inboundGroupSessions = <String, Map<String, SessionKey>>{};
  final _outboundGroupSessions = <String, OutboundGroupSession>{};
  final Set<String> _loadedOutboundGroupSessions = <String>{};
  final Set<String> _requestedSessionIds = <String>{};

  KeyManager(this.encryption) {
    encryption.ssss.setValidator(megolmKey, (String secret) async {
      final keyObj = olm.PkDecryption();
      try {
        final info = await getRoomKeysBackupInfo(false);
        if (info.algorithm !=
            BackupAlgorithm.mMegolmBackupV1Curve25519AesSha2) {
          return false;
        }
        return keyObj.init_with_private_key(base64decodeUnpadded(secret)) ==
            info.authData['public_key'];
      } catch (_) {
        return false;
      } finally {
        keyObj.free();
      }
    });
    encryption.ssss.setCacheCallback(megolmKey, (String secret) {
      // we got a megolm key cached, clear our requested keys and try to re-decrypt
      // last events
      _requestedSessionIds.clear();
      for (final room in client.rooms) {
        final lastEvent = room.lastEvent;
        if (lastEvent != null &&
            lastEvent.type == EventTypes.Encrypted &&
            lastEvent.content['can_request_session'] == true) {
          final sessionId = lastEvent.content.tryGet<String>('session_id');
          final senderKey = lastEvent.content.tryGet<String>('sender_key');
          if (sessionId != null && senderKey != null) {
            maybeAutoRequest(
              room.id,
              sessionId,
              senderKey,
            );
          }
        }
      }
    });
  }

  bool get enabled => encryption.ssss.isSecret(megolmKey);

  /// clear all cached inbound group sessions. useful for testing
  void clearInboundGroupSessions() {
    _inboundGroupSessions.clear();
  }

  Future<void> setInboundGroupSession(
    String roomId,
    String sessionId,
    String senderKey,
    Map<String, dynamic> content, {
    bool forwarded = false,
    Map<String, String>? senderClaimedKeys,
    bool uploaded = false,
    Map<String, Map<String, int>>? allowedAtIndex,
  }) async {
    final senderClaimedKeys_ = senderClaimedKeys ?? <String, String>{};
    final allowedAtIndex_ = allowedAtIndex ?? <String, Map<String, int>>{};
    final userId = client.userID;
    if (userId == null) return Future.value();

    if (!senderClaimedKeys_.containsKey('ed25519')) {
      final device = client.getUserDeviceKeysByCurve25519Key(senderKey);
      if (device != null && device.ed25519Key != null) {
        senderClaimedKeys_['ed25519'] = device.ed25519Key!;
      }
    }
    final oldSession = getInboundGroupSession(
      roomId,
      sessionId,
    );
    if (content['algorithm'] != AlgorithmTypes.megolmV1AesSha2) {
      return;
    }
    late olm.InboundGroupSession inboundGroupSession;
    try {
      inboundGroupSession = olm.InboundGroupSession();
      if (forwarded) {
        inboundGroupSession.import_session(content['session_key']);
      } else {
        inboundGroupSession.create(content['session_key']);
      }
    } catch (e, s) {
      inboundGroupSession.free();
      Logs().e('[LibOlm] Could not create new InboundGroupSession', e, s);
      return Future.value();
    }
    final newSession = SessionKey(
      content: content,
      inboundGroupSession: inboundGroupSession,
      indexes: {},
      roomId: roomId,
      sessionId: sessionId,
      key: userId,
      senderKey: senderKey,
      senderClaimedKeys: senderClaimedKeys_,
      allowedAtIndex: allowedAtIndex_,
    );
    final oldFirstIndex =
        oldSession?.inboundGroupSession?.first_known_index() ?? 0;
    final newFirstIndex = newSession.inboundGroupSession!.first_known_index();
    if (oldSession == null ||
        newFirstIndex < oldFirstIndex ||
        (oldFirstIndex == newFirstIndex &&
            newSession.forwardingCurve25519KeyChain.length <
                oldSession.forwardingCurve25519KeyChain.length)) {
      // use new session
      oldSession?.dispose();
    } else {
      // we are gonna keep our old session
      newSession.dispose();
      return;
    }

    final roomInboundGroupSessions =
        _inboundGroupSessions[roomId] ??= <String, SessionKey>{};
    roomInboundGroupSessions[sessionId] = newSession;
    if (!client.isLogged() || client.encryption == null) {
      return;
    }

    final storeFuture = client.database
        ?.storeInboundGroupSession(
      roomId,
      sessionId,
      inboundGroupSession.pickle(userId),
      json.encode(content),
      json.encode({}),
      json.encode(allowedAtIndex_),
      senderKey,
      json.encode(senderClaimedKeys_),
    )
        .then((_) async {
      if (!client.isLogged() || client.encryption == null) {
        return;
      }
      if (uploaded) {
        await client.database
            ?.markInboundGroupSessionAsUploaded(roomId, sessionId);
      }
    });
    final room = client.getRoomById(roomId);
    if (room != null) {
      // attempt to decrypt the last event
      final event = room.lastEvent;
      if (event != null &&
          event.type == EventTypes.Encrypted &&
          event.content['session_id'] == sessionId) {
        final decrypted = encryption.decryptRoomEventSync(event);
        if (decrypted.type != EventTypes.Encrypted) {
          // Update the last event in memory first
          room.lastEvent = decrypted;

          // To persist it in database and trigger UI updates:
          await client.database?.transaction(() async {
            await client.handleSync(
              SyncUpdate(
                nextBatch: '',
                rooms: switch (room.membership) {
                  Membership.join =>
                    RoomsUpdate(join: {room.id: JoinedRoomUpdate()}),
                  Membership.ban ||
                  Membership.leave =>
                    RoomsUpdate(leave: {room.id: LeftRoomUpdate()}),
                  Membership.invite =>
                    RoomsUpdate(invite: {room.id: InvitedRoomUpdate()}),
                  Membership.knock =>
                    RoomsUpdate(knock: {room.id: KnockRoomUpdate()}),
                },
              ),
            );
          });
        }
      }
      // and finally broadcast the new session
      room.onSessionKeyReceived.add(sessionId);
    }

    return storeFuture ?? Future.value();
  }

  SessionKey? getInboundGroupSession(String roomId, String sessionId) {
    final sess = _inboundGroupSessions[roomId]?[sessionId];
    if (sess != null) {
      if (sess.sessionId != sessionId && sess.sessionId.isNotEmpty) {
        return null;
      }
      return sess;
    }
    return null;
  }

  /// Attempt auto-request for a key
  void maybeAutoRequest(
    String roomId,
    String sessionId,
    String? senderKey, {
    bool tryOnlineBackup = true,
    bool onlineKeyBackupOnly = true,
  }) {
    final room = client.getRoomById(roomId);
    final requestIdent = '$roomId|$sessionId';
    if (room != null &&
        !_requestedSessionIds.contains(requestIdent) &&
        !client.isUnknownSession) {
      // do e2ee recovery
      _requestedSessionIds.add(requestIdent);

      runInRoot(
        () async => request(
          room,
          sessionId,
          senderKey,
          tryOnlineBackup: tryOnlineBackup,
          onlineKeyBackupOnly: onlineKeyBackupOnly,
        ),
      );
    }
  }

  /// Loads an inbound group session
  Future<SessionKey?> loadInboundGroupSession(
    String roomId,
    String sessionId,
  ) async {
    final sess = _inboundGroupSessions[roomId]?[sessionId];
    if (sess != null) {
      if (sess.sessionId != sessionId && sess.sessionId.isNotEmpty) {
        return null; // session_id does not match....better not do anything
      }
      return sess; // nothing to do
    }
    final session =
        await client.database?.getInboundGroupSession(roomId, sessionId);
    if (session == null) return null;
    final userID = client.userID;
    if (userID == null) return null;
    final dbSess = SessionKey.fromDb(session, userID);
    final roomInboundGroupSessions =
        _inboundGroupSessions[roomId] ??= <String, SessionKey>{};
    if (!dbSess.isValid ||
        dbSess.sessionId.isEmpty ||
        dbSess.sessionId != sessionId) {
      return null;
    }
    return roomInboundGroupSessions[sessionId] = dbSess;
  }

  void _sendEncryptionInfoEvent({
    required String roomId,
    required List<String> userIds,
    List<String>? deviceIds,
  }) async {
    await client.database?.transaction(() async {
      await client.handleSync(
        SyncUpdate(
          nextBatch: '',
          rooms: RoomsUpdate(
            join: {
              roomId: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    MatrixEvent(
                      eventId:
                          'fake_event_${client.generateUniqueTransactionId()}',
                      content: {
                        'body':
                            '${userIds.join(', ')} can now read along${deviceIds != null ? ' on ${deviceIds.length} new device(s)' : ''}',
                        if (deviceIds != null) 'devices': deviceIds,
                        'users': userIds,
                      },
                      type: EventTypes.encryptionInfo,
                      senderId: client.userID!,
                      originServerTs: DateTime.now(),
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      );
    });
  }

  Map<String, Map<String, bool>> _getDeviceKeyIdMap(
    List<DeviceKeys> deviceKeys,
  ) {
    final deviceKeyIds = <String, Map<String, bool>>{};
    for (final device in deviceKeys) {
      final deviceId = device.deviceId;
      if (deviceId == null) {
        Logs().w('[KeyManager] ignoring device without deviceid');
        continue;
      }
      final userDeviceKeyIds = deviceKeyIds[device.userId] ??= <String, bool>{};
      userDeviceKeyIds[deviceId] = !device.encryptToDevice;
    }
    return deviceKeyIds;
  }

  /// clear all cached inbound group sessions. useful for testing
  void clearOutboundGroupSessions() {
    _outboundGroupSessions.clear();
  }

  /// Clears the existing outboundGroupSession but first checks if the participating
  /// devices have been changed. Returns false if the session has not been cleared because
  /// it wasn't necessary. Otherwise returns true.
  Future<bool> clearOrUseOutboundGroupSession(
    String roomId, {
    bool wipe = false,
    bool use = true,
  }) async {
    final room = client.getRoomById(roomId);
    final sess = getOutboundGroupSession(roomId);
    if (room == null || sess == null || sess.outboundGroupSession == null) {
      return true;
    }

    final inboundSess = await loadInboundGroupSession(
      room.id,
      sess.outboundGroupSession!.session_id(),
    );
    if (inboundSess == null) {
      Logs().w('No inbound megolm session found for outbound session!');
      assert(inboundSess != null);
      wipe = true;
    }

    // next check if the devices in the room changed
    final devicesToReceive = <DeviceKeys>[];
    final newDeviceKeys = await room.getUserDeviceKeys();
    final newDeviceKeyIds = _getDeviceKeyIdMap(newDeviceKeys);
    // first check for user differences
    final oldUserIds = sess.devices.keys.toSet();
    final newUserIds = newDeviceKeyIds.keys.toSet();
    if (oldUserIds.difference(newUserIds).isNotEmpty) {
      // a user left the room, we must wipe the session
      wipe = true;
    } else {
      final newUsers = newUserIds.difference(oldUserIds);
      if (newUsers.isNotEmpty) {
        // new user! Gotta send the megolm session to them
        devicesToReceive
            .addAll(newDeviceKeys.where((d) => newUsers.contains(d.userId)));
        _sendEncryptionInfoEvent(roomId: roomId, userIds: newUsers.toList());
      }
      // okay, now we must test all the individual user devices, if anything new got blocked
      // or if we need to send to any new devices.
      // for this it is enough if we iterate over the old user Ids, as the new ones already have the needed keys in the list.
      // we also know that all the old user IDs appear in the old one, else we have already wiped the session
      for (final userId in oldUserIds) {
        final oldBlockedDevices = sess.devices.containsKey(userId)
            ? sess.devices[userId]!.entries
                .where((e) => e.value)
                .map((e) => e.key)
                .toSet()
            : <String>{};
        final newBlockedDevices = newDeviceKeyIds.containsKey(userId)
            ? newDeviceKeyIds[userId]!
                .entries
                .where((e) => e.value)
                .map((e) => e.key)
                .toSet()
            : <String>{};
        // we don't really care about old devices that got dropped (deleted), we only care if new ones got added and if new ones got blocked
        // check if new devices got blocked
        if (newBlockedDevices.difference(oldBlockedDevices).isNotEmpty) {
          wipe = true;
        }
        // and now add all the new devices!
        final oldDeviceIds = sess.devices.containsKey(userId)
            ? sess.devices[userId]!.entries
                .where((e) => !e.value)
                .map((e) => e.key)
                .toSet()
            : <String>{};
        final newDeviceIds = newDeviceKeyIds.containsKey(userId)
            ? newDeviceKeyIds[userId]!
                .entries
                .where((e) => !e.value)
                .map((e) => e.key)
                .toSet()
            : <String>{};

        // check if a device got removed
        if (oldDeviceIds.difference(newDeviceIds).isNotEmpty) {
          wipe = true;
        }

        // check if any new devices need keys
        final newDevices = newDeviceIds.difference(oldDeviceIds);
        if (newDeviceIds.isNotEmpty) {
          devicesToReceive.addAll(
            newDeviceKeys.where(
              (d) => d.userId == userId && newDevices.contains(d.deviceId),
            ),
          );
          if (userId != client.userID && newDevices.isNotEmpty) {
            _sendEncryptionInfoEvent(
              roomId: roomId,
              userIds: [userId],
              deviceIds: newDevices.toList(),
            );
          }
        }
      }

      if (!wipe) {
        // first check if it needs to be rotated
        final encryptionContent =
            room.getState(EventTypes.Encryption)?.parsedRoomEncryptionContent;
        final maxMessages = encryptionContent?.rotationPeriodMsgs ?? 100;
        final maxAge = encryptionContent?.rotationPeriodMs ??
            604800000; // default of one week
        if ((sess.sentMessages ?? maxMessages) >= maxMessages ||
            sess.creationTime
                .add(Duration(milliseconds: maxAge))
                .isBefore(DateTime.now())) {
          wipe = true;
        }
      }

      if (!wipe) {
        if (!use) {
          return false;
        }
        // okay, we use the outbound group session!
        sess.devices = newDeviceKeyIds;
        final rawSession = <String, dynamic>{
          'algorithm': AlgorithmTypes.megolmV1AesSha2,
          'room_id': room.id,
          'session_id': sess.outboundGroupSession!.session_id(),
          'session_key': sess.outboundGroupSession!.session_key(),
        };
        try {
          devicesToReceive.removeWhere((k) => !k.encryptToDevice);
          if (devicesToReceive.isNotEmpty) {
            // update allowedAtIndex
            for (final device in devicesToReceive) {
              inboundSess!.allowedAtIndex[device.userId] ??= <String, int>{};
              if (!inboundSess.allowedAtIndex[device.userId]!
                      .containsKey(device.curve25519Key) ||
                  inboundSess.allowedAtIndex[device.userId]![
                          device.curve25519Key]! >
                      sess.outboundGroupSession!.message_index()) {
                inboundSess
                        .allowedAtIndex[device.userId]![device.curve25519Key!] =
                    sess.outboundGroupSession!.message_index();
              }
            }
            await client.database?.updateInboundGroupSessionAllowedAtIndex(
              json.encode(inboundSess!.allowedAtIndex),
              room.id,
              sess.outboundGroupSession!.session_id(),
            );
            // send out the key
            await client.sendToDeviceEncryptedChunked(
              devicesToReceive,
              EventTypes.RoomKey,
              rawSession,
            );
          }
        } catch (e, s) {
          Logs().e(
            '[LibOlm] Unable to re-send the session key at later index to new devices',
            e,
            s,
          );
        }
        return false;
      }
    }
    sess.dispose();
    _outboundGroupSessions.remove(roomId);
    await client.database?.removeOutboundGroupSession(roomId);
    return true;
  }

  /// Store an outbound group session in the database
  Future<void> storeOutboundGroupSession(
    String roomId,
    OutboundGroupSession sess,
  ) async {
    final userID = client.userID;
    if (userID == null) return;
    await client.database?.storeOutboundGroupSession(
      roomId,
      sess.outboundGroupSession!.pickle(userID),
      json.encode(sess.devices),
      sess.creationTime.millisecondsSinceEpoch,
    );
  }

  final Map<String, Future<OutboundGroupSession>>
      _pendingNewOutboundGroupSessions = {};

  /// Creates an outbound group session for a given room id
  Future<OutboundGroupSession> createOutboundGroupSession(String roomId) async {
    final sess = _pendingNewOutboundGroupSessions[roomId];
    if (sess != null) {
      return sess;
    }
    final newSess = _pendingNewOutboundGroupSessions[roomId] =
        _createOutboundGroupSession(roomId);

    try {
      await newSess;
    } finally {
      _pendingNewOutboundGroupSessions
          .removeWhere((_, value) => value == newSess);
    }

    return newSess;
  }

  /// Prepares an outbound group session for a given room ID. That is, load it from
  /// the database, cycle it if needed and create it if absent.
  Future<void> prepareOutboundGroupSession(String roomId) async {
    if (getOutboundGroupSession(roomId) == null) {
      await loadOutboundGroupSession(roomId);
    }
    await clearOrUseOutboundGroupSession(roomId, use: false);
    if (getOutboundGroupSession(roomId) == null) {
      await createOutboundGroupSession(roomId);
    }
  }

  Future<OutboundGroupSession> _createOutboundGroupSession(
    String roomId,
  ) async {
    await clearOrUseOutboundGroupSession(roomId, wipe: true);
    await client.firstSyncReceived;
    final room = client.getRoomById(roomId);
    if (room == null) {
      throw Exception(
        'Tried to create a megolm session in a non-existing room ($roomId)!',
      );
    }
    final userID = client.userID;
    if (userID == null) {
      throw Exception(
        'Tried to create a megolm session without being logged in!',
      );
    }

    final deviceKeys = await room.getUserDeviceKeys();
    final deviceKeyIds = _getDeviceKeyIdMap(deviceKeys);
    deviceKeys.removeWhere((k) => !k.encryptToDevice);
    final outboundGroupSession = olm.OutboundGroupSession();
    try {
      outboundGroupSession.create();
    } catch (e, s) {
      outboundGroupSession.free();
      Logs().e('[LibOlm] Unable to create new outboundGroupSession', e, s);
      rethrow;
    }
    final rawSession = <String, dynamic>{
      'algorithm': AlgorithmTypes.megolmV1AesSha2,
      'room_id': room.id,
      'session_id': outboundGroupSession.session_id(),
      'session_key': outboundGroupSession.session_key(),
    };
    final allowedAtIndex = <String, Map<String, int>>{};
    for (final device in deviceKeys) {
      if (!device.isValid) {
        Logs().e('Skipping invalid device');
        continue;
      }
      allowedAtIndex[device.userId] ??= <String, int>{};
      allowedAtIndex[device.userId]![device.curve25519Key!] =
          outboundGroupSession.message_index();
    }
    await setInboundGroupSession(
      roomId,
      rawSession['session_id'],
      encryption.identityKey!,
      rawSession,
      allowedAtIndex: allowedAtIndex,
    );
    final sess = OutboundGroupSession(
      devices: deviceKeyIds,
      creationTime: DateTime.now(),
      outboundGroupSession: outboundGroupSession,
      key: userID,
    );
    try {
      await client.sendToDeviceEncryptedChunked(
        deviceKeys,
        EventTypes.RoomKey,
        rawSession,
      );
      await storeOutboundGroupSession(roomId, sess);
      _outboundGroupSessions[roomId] = sess;
    } catch (e, s) {
      Logs().e(
        '[LibOlm] Unable to send the session key to the participating devices',
        e,
        s,
      );
      sess.dispose();
      rethrow;
    }
    return sess;
  }

  /// Get an outbound group session for a room id
  OutboundGroupSession? getOutboundGroupSession(String roomId) {
    return _outboundGroupSessions[roomId];
  }

  /// Load an outbound group session from database
  Future<void> loadOutboundGroupSession(String roomId) async {
    final database = client.database;
    final userID = client.userID;
    if (_loadedOutboundGroupSessions.contains(roomId) ||
        _outboundGroupSessions.containsKey(roomId) ||
        database == null ||
        userID == null) {
      return; // nothing to do
    }
    _loadedOutboundGroupSessions.add(roomId);
    final sess = await database.getOutboundGroupSession(
      roomId,
      userID,
    );
    if (sess == null || !sess.isValid) {
      return;
    }
    _outboundGroupSessions[roomId] = sess;
  }

  Future<bool> isCached() async {
    await client.accountDataLoading;
    if (!enabled) {
      return false;
    }
    await client.userDeviceKeysLoading;
    return (await encryption.ssss.getCached(megolmKey)) != null;
  }

  GetRoomKeysVersionCurrentResponse? _roomKeysVersionCache;
  DateTime? _roomKeysVersionCacheDate;

  Future<GetRoomKeysVersionCurrentResponse> getRoomKeysBackupInfo([
    bool useCache = true,
  ]) async {
    if (_roomKeysVersionCache != null &&
        _roomKeysVersionCacheDate != null &&
        useCache &&
        DateTime.now()
            .subtract(Duration(minutes: 5))
            .isBefore(_roomKeysVersionCacheDate!)) {
      return _roomKeysVersionCache!;
    }
    _roomKeysVersionCache = await client.getRoomKeysVersionCurrent();
    _roomKeysVersionCacheDate = DateTime.now();
    return _roomKeysVersionCache!;
  }

  Future<void> loadFromResponse(RoomKeys keys) async {
    if (!(await isCached())) {
      return;
    }
    final privateKey =
        base64decodeUnpadded((await encryption.ssss.getCached(megolmKey))!);
    final decryption = olm.PkDecryption();
    final info = await getRoomKeysBackupInfo();
    String backupPubKey;
    try {
      backupPubKey = decryption.init_with_private_key(privateKey);

      if (info.algorithm != BackupAlgorithm.mMegolmBackupV1Curve25519AesSha2 ||
          info.authData['public_key'] != backupPubKey) {
        return;
      }
      for (final roomEntry in keys.rooms.entries) {
        final roomId = roomEntry.key;
        for (final sessionEntry in roomEntry.value.sessions.entries) {
          final sessionId = sessionEntry.key;
          final session = sessionEntry.value;
          final sessionData = session.sessionData;
          Map<String, Object?>? decrypted;
          try {
            decrypted = json.decode(
              decryption.decrypt(
                sessionData['ephemeral'] as String,
                sessionData['mac'] as String,
                sessionData['ciphertext'] as String,
              ),
            );
          } catch (e, s) {
            Logs().e('[LibOlm] Error decrypting room key', e, s);
          }
          final senderKey = decrypted?.tryGet<String>('sender_key');
          if (decrypted != null && senderKey != null) {
            decrypted['session_id'] = sessionId;
            decrypted['room_id'] = roomId;
            await setInboundGroupSession(
              roomId,
              sessionId,
              senderKey,
              decrypted,
              forwarded: true,
              senderClaimedKeys:
                  decrypted.tryGetMap<String, String>('sender_claimed_keys') ??
                      <String, String>{},
              uploaded: true,
            );
          }
        }
      }
    } finally {
      decryption.free();
    }
  }

  /// Loads and stores all keys from the online key backup. This may take a
  /// while for older and big accounts.
  Future<void> loadAllKeys() async {
    final info = await getRoomKeysBackupInfo();
    final ret = await client.getRoomKeys(info.version);
    await loadFromResponse(ret);
  }

  /// Loads all room keys for a single room and stores them. This may take a
  /// while for older and big rooms.
  Future<void> loadAllKeysFromRoom(String roomId) async {
    final info = await getRoomKeysBackupInfo();
    final ret = await client.getRoomKeysByRoomId(roomId, info.version);
    final keys = RoomKeys.fromJson({
      'rooms': {
        roomId: {
          'sessions': ret.sessions.map((k, s) => MapEntry(k, s.toJson())),
        },
      },
    });
    await loadFromResponse(keys);
  }

  /// Loads a single key for the specified room from the online key backup
  /// and stores it.
  Future<void> loadSingleKey(String roomId, String sessionId) async {
    final info = await getRoomKeysBackupInfo();
    final ret =
        await client.getRoomKeyBySessionId(roomId, sessionId, info.version);
    final keys = RoomKeys.fromJson({
      'rooms': {
        roomId: {
          'sessions': {
            sessionId: ret.toJson(),
          },
        },
      },
    });
    await loadFromResponse(keys);
  }

  /// Request a certain key from another device
  Future<void> request(
    Room room,
    String sessionId,
    String? senderKey, {
    bool tryOnlineBackup = true,
    bool onlineKeyBackupOnly = false,
  }) async {
    if (tryOnlineBackup && await isCached()) {
      // let's first check our online key backup store thingy...
      final hadPreviously = getInboundGroupSession(room.id, sessionId) != null;
      try {
        await loadSingleKey(room.id, sessionId);
      } catch (err, stacktrace) {
        if (err is MatrixException && err.errcode == 'M_NOT_FOUND') {
          Logs().i(
            '[KeyManager] Key not in online key backup, requesting it from other devices...',
          );
        } else {
          Logs().e(
            '[KeyManager] Failed to access online key backup',
            err,
            stacktrace,
          );
        }
      }
      // TODO: also don't request from others if we have an index of 0 now
      if (!hadPreviously &&
          getInboundGroupSession(room.id, sessionId) != null) {
        return; // we managed to load the session from online backup, no need to care about it now
      }
    }
    if (onlineKeyBackupOnly) {
      return; // we only want to do the online key backup
    }
    try {
      // while we just send the to-device event to '*', we still need to save the
      // devices themself to know where to send the cancel to after receiving a reply
      final devices = await room.getUserDeviceKeys();
      final requestId = client.generateUniqueTransactionId();
      final request = KeyManagerKeyShareRequest(
        requestId: requestId,
        devices: devices,
        room: room,
        sessionId: sessionId,
      );
      final userList = await room.requestParticipants();
      await client.sendToDevicesOfUserIds(
        userList.map<String>((u) => u.id).toSet(),
        EventTypes.RoomKeyRequest,
        {
          'action': 'request',
          'body': {
            'algorithm': AlgorithmTypes.megolmV1AesSha2,
            'room_id': room.id,
            'session_id': sessionId,
            if (senderKey != null) 'sender_key': senderKey,
          },
          'request_id': requestId,
          'requesting_device_id': client.deviceID,
        },
      );
      outgoingShareRequests[request.requestId] = request;
    } catch (e, s) {
      Logs().e('[Key Manager] Sending key verification request failed', e, s);
    }
  }

  Future<void>? _uploadingFuture;

  void startAutoUploadKeys() {
    _uploadKeysOnSync = encryption.client.onSync.stream.listen(
      (_) async => uploadInboundGroupSessions(skipIfInProgress: true),
    );
  }

  /// This task should be performed after sync processing but should not block
  /// the sync. To make sure that it never gets executed multiple times, it is
  /// skipped when an upload task is already in progress. Set `skipIfInProgress`
  /// to `false` to await the pending upload task instead.
  Future<void> uploadInboundGroupSessions({
    bool skipIfInProgress = false,
  }) async {
    final database = client.database;
    final userID = client.userID;
    if (database == null || userID == null) {
      return;
    }

    // Make sure to not run in parallel
    if (_uploadingFuture != null) {
      if (skipIfInProgress) return;
      try {
        await _uploadingFuture;
      } finally {
        // shouldn't be necessary, since it will be unset already by the other process that started it, but just to be safe, also unset the future here
        _uploadingFuture = null;
      }
    }

    Future<void> uploadInternal() async {
      try {
        await client.userDeviceKeysLoading;

        if (!(await isCached())) {
          return; // we can't backup anyways
        }
        final dbSessions = await database.getInboundGroupSessionsToUpload();
        if (dbSessions.isEmpty) {
          return; // nothing to do
        }
        final privateKey =
            base64decodeUnpadded((await encryption.ssss.getCached(megolmKey))!);
        // decryption is needed to calculate the public key and thus see if the claimed information is in fact valid
        final decryption = olm.PkDecryption();
        final info = await getRoomKeysBackupInfo(false);
        String backupPubKey;
        try {
          backupPubKey = decryption.init_with_private_key(privateKey);

          if (info.algorithm !=
                  BackupAlgorithm.mMegolmBackupV1Curve25519AesSha2 ||
              info.authData['public_key'] != backupPubKey) {
            decryption.free();
            return;
          }
          final args = GenerateUploadKeysArgs(
            pubkey: backupPubKey,
            dbSessions: <DbInboundGroupSessionBundle>[],
            userId: userID,
          );
          // we need to calculate verified beforehand, as else we pass a closure to an isolate
          // with 500 keys they do, however, noticably block the UI, which is why we give brief async suspentions in here
          // so that the event loop can progress
          var i = 0;
          for (final dbSession in dbSessions) {
            final device =
                client.getUserDeviceKeysByCurve25519Key(dbSession.senderKey);
            args.dbSessions.add(
              DbInboundGroupSessionBundle(
                dbSession: dbSession,
                verified: device?.verified ?? false,
              ),
            );
            i++;
            if (i > 10) {
              await Future.delayed(Duration(milliseconds: 1));
              i = 0;
            }
          }
          final roomKeys =
              await client.nativeImplementations.generateUploadKeys(args);
          Logs().i('[Key Manager] Uploading ${dbSessions.length} room keys...');
          // upload the payload...
          await client.putRoomKeys(info.version, roomKeys);
          // and now finally mark all the keys as uploaded
          // no need to optimze this, as we only run it so seldomly and almost never with many keys at once
          for (final dbSession in dbSessions) {
            await database.markInboundGroupSessionAsUploaded(
              dbSession.roomId,
              dbSession.sessionId,
            );
          }
        } finally {
          decryption.free();
        }
      } catch (e, s) {
        Logs().e('[Key Manager] Error uploading room keys', e, s);
      }
    }

    _uploadingFuture = uploadInternal();
    try {
      await _uploadingFuture;
    } finally {
      _uploadingFuture = null;
    }
  }

  /// Handle an incoming to_device event that is related to key sharing
  Future<void> handleToDeviceEvent(ToDeviceEvent event) async {
    if (event.type == EventTypes.RoomKeyRequest) {
      if (event.content['request_id'] is! String) {
        return; // invalid event
      }
      if (event.content['action'] == 'request') {
        // we are *receiving* a request
        Logs().i(
          '[KeyManager] Received key sharing request from ${event.sender}:${event.content['requesting_device_id']}...',
        );
        if (!event.content.containsKey('body')) {
          Logs().w('[KeyManager] No body, doing nothing');
          return; // no body
        }
        final body = event.content.tryGetMap<String, Object?>('body');
        if (body == null) {
          Logs().w('[KeyManager] Wrong type for body, doing nothing');
          return; // wrong type for body
        }
        final roomId = body.tryGet<String>('room_id');
        if (roomId == null) {
          Logs().w(
            '[KeyManager] Wrong type for room_id or no room_id, doing nothing',
          );
          return; // wrong type for roomId or no roomId found
        }
        final device = client.userDeviceKeys[event.sender]
            ?.deviceKeys[event.content['requesting_device_id']];
        if (device == null) {
          Logs().w('[KeyManager] Device not found, doing nothing');
          return; // device not found
        }
        if (device.userId == client.userID &&
            device.deviceId == client.deviceID) {
          Logs().i('[KeyManager] Request is by ourself, ignoring');
          return; // ignore requests by ourself
        }
        final room = client.getRoomById(roomId);
        if (room == null) {
          Logs().i('[KeyManager] Unknown room, ignoring');
          return; // unknown room
        }
        final sessionId = body.tryGet<String>('session_id');
        if (sessionId == null) {
          Logs().w(
            '[KeyManager] Wrong type for session_id or no session_id, doing nothing',
          );
          return; // wrong type for session_id
        }
        // okay, let's see if we have this session at all
        final session = await loadInboundGroupSession(room.id, sessionId);
        if (session == null) {
          Logs().i('[KeyManager] Unknown session, ignoring');
          return; // we don't have this session anyways
        }
        if (event.content['request_id'] is! String) {
          Logs().w(
            '[KeyManager] Wrong type for request_id or no request_id, doing nothing',
          );
          return; // wrong type for request_id
        }
        final request = KeyManagerKeyShareRequest(
          requestId: event.content.tryGet<String>('request_id')!,
          devices: [device],
          room: room,
          sessionId: sessionId,
        );
        if (incomingShareRequests.containsKey(request.requestId)) {
          Logs().i('[KeyManager] Already processed this request, ignoring');
          return; // we don't want to process one and the same request multiple times
        }
        incomingShareRequests[request.requestId] = request;
        final roomKeyRequest =
            RoomKeyRequest.fromToDeviceEvent(event, this, request);
        if (device.userId == client.userID &&
            device.verified &&
            !device.blocked) {
          Logs().i('[KeyManager] All checks out, forwarding key...');
          // alright, we can forward the key
          await roomKeyRequest.forwardKey();
        } else if (device.encryptToDevice &&
            session.allowedAtIndex
                    .tryGet<Map<String, Object?>>(device.userId)
                    ?.tryGet(device.curve25519Key!) !=
                null) {
          // if we know the user may see the message, then we can just forward the key.
          // we do not need to check if the device is verified, just if it is not blocked,
          // as that is the logic we already initially try to send out the room keys.
          final index =
              session.allowedAtIndex[device.userId]![device.curve25519Key]!;
          Logs().i(
            '[KeyManager] Valid foreign request, forwarding key at index $index...',
          );
          await roomKeyRequest.forwardKey(index);
        } else {
          Logs()
              .i('[KeyManager] Asking client, if the key should be forwarded');
          client.onRoomKeyRequest
              .add(roomKeyRequest); // let the client handle this
        }
      } else if (event.content['action'] == 'request_cancellation') {
        // we got told to cancel an incoming request
        if (!incomingShareRequests.containsKey(event.content['request_id'])) {
          return; // we don't know this request anyways
        }
        // alright, let's just cancel this request
        final request = incomingShareRequests[event.content['request_id']]!;
        request.canceled = true;
        incomingShareRequests.remove(request.requestId);
      }
    } else if (event.type == EventTypes.ForwardedRoomKey) {
      // we *received* an incoming key request
      final encryptedContent = event.encryptedContent;
      if (encryptedContent == null) {
        Logs().w(
          'Ignoring an unencrypted forwarded key from a to device message',
          event.toJson(),
        );
        return;
      }
      final request = outgoingShareRequests.values.firstWhereOrNull(
        (r) =>
            r.room.id == event.content['room_id'] &&
            r.sessionId == event.content['session_id'],
      );
      if (request == null || request.canceled) {
        return; // no associated request found or it got canceled
      }
      final device = request.devices.firstWhereOrNull(
        (d) =>
            d.userId == event.sender &&
            d.curve25519Key == encryptedContent['sender_key'],
      );
      if (device == null) {
        return; // someone we didn't send our request to replied....better ignore this
      }
      // we add the sender key to the forwarded key chain
      if (event.content['forwarding_curve25519_key_chain'] is! List) {
        event.content['forwarding_curve25519_key_chain'] = <String>[];
      }
      (event.content['forwarding_curve25519_key_chain'] as List)
          .add(encryptedContent['sender_key']);
      if (event.content['sender_claimed_ed25519_key'] is! String) {
        Logs().w('sender_claimed_ed255519_key has wrong type');
        return; // wrong type
      }
      // TODO: verify that the keys work to decrypt a message
      // alright, all checks out, let's go ahead and store this session
      await setInboundGroupSession(
        request.room.id,
        request.sessionId,
        device.curve25519Key!,
        event.content,
        forwarded: true,
        senderClaimedKeys: {
          'ed25519': event.content['sender_claimed_ed25519_key'] as String,
        },
      );
      request.devices.removeWhere(
        (k) => k.userId == device.userId && k.deviceId == device.deviceId,
      );
      outgoingShareRequests.remove(request.requestId);
      // send cancel to all other devices
      if (request.devices.isEmpty) {
        return; // no need to send any cancellation
      }
      // Send with send-to-device messaging
      final sendToDeviceMessage = {
        'action': 'request_cancellation',
        'request_id': request.requestId,
        'requesting_device_id': client.deviceID,
      };
      final data = <String, Map<String, Map<String, dynamic>>>{};
      for (final device in request.devices) {
        final userData = data[device.userId] ??= {};
        userData[device.deviceId!] = sendToDeviceMessage;
      }
      await client.sendToDevice(
        EventTypes.RoomKeyRequest,
        client.generateUniqueTransactionId(),
        data,
      );
    } else if (event.type == EventTypes.RoomKey) {
      Logs().v(
        '[KeyManager] Received room key with session ${event.content['session_id']}',
      );
      final encryptedContent = event.encryptedContent;
      if (encryptedContent == null) {
        Logs().v('[KeyManager] not encrypted, ignoring...');
        return; // the event wasn't encrypted, this is a security risk;
      }
      final roomId = event.content.tryGet<String>('room_id');
      final sessionId = event.content.tryGet<String>('session_id');
      if (roomId == null || sessionId == null) {
        Logs().w(
          'Either room_id or session_id are not the expected type or missing',
        );
        return;
      }
      final sender_ed25519 = client.userDeviceKeys[event.sender]
          ?.deviceKeys[event.content['requesting_device_id']]?.ed25519Key;
      if (sender_ed25519 != null) {
        event.content['sender_claimed_ed25519_key'] = sender_ed25519;
      }
      Logs().v('[KeyManager] Keeping room key');
      await setInboundGroupSession(
        roomId,
        sessionId,
        encryptedContent['sender_key'],
        event.content,
        forwarded: false,
      );
    }
  }

  StreamSubscription<SyncUpdate>? _uploadKeysOnSync;

  void dispose() {
    // ignore: discarded_futures
    _uploadKeysOnSync?.cancel();
    for (final sess in _outboundGroupSessions.values) {
      sess.dispose();
    }
    for (final entries in _inboundGroupSessions.values) {
      for (final sess in entries.values) {
        sess.dispose();
      }
    }
  }
}

class KeyManagerKeyShareRequest {
  final String requestId;
  final List<DeviceKeys> devices;
  final Room room;
  final String sessionId;
  bool canceled;

  KeyManagerKeyShareRequest({
    required this.requestId,
    List<DeviceKeys>? devices,
    required this.room,
    required this.sessionId,
    this.canceled = false,
  }) : devices = devices ?? [];
}

class RoomKeyRequest extends ToDeviceEvent {
  KeyManager keyManager;
  KeyManagerKeyShareRequest request;

  RoomKeyRequest.fromToDeviceEvent(
    ToDeviceEvent toDeviceEvent,
    this.keyManager,
    this.request,
  ) : super(
          sender: toDeviceEvent.sender,
          content: toDeviceEvent.content,
          type: toDeviceEvent.type,
        );

  Room get room => request.room;

  DeviceKeys get requestingDevice => request.devices.first;

  Future<void> forwardKey([int? index]) async {
    if (request.canceled) {
      keyManager.incomingShareRequests.remove(request.requestId);
      return; // request is canceled, don't send anything
    }
    final room = this.room;
    final session =
        await keyManager.loadInboundGroupSession(room.id, request.sessionId);
    if (session?.inboundGroupSession == null) {
      Logs().v("[KeyManager] Not forwarding key we don't have");
      return;
    }

    final message = session!.content.copy();
    message['forwarding_curve25519_key_chain'] =
        List<String>.from(session.forwardingCurve25519KeyChain);

    if (session.senderKey.isNotEmpty) {
      message['sender_key'] = session.senderKey;
    }
    message['sender_claimed_ed25519_key'] =
        session.senderClaimedKeys['ed25519'] ??
            (session.forwardingCurve25519KeyChain.isEmpty
                ? keyManager.encryption.fingerprintKey
                : null);
    message['session_key'] = session.inboundGroupSession!.export_session(
      index ?? session.inboundGroupSession!.first_known_index(),
    );
    // send the actual reply of the key back to the requester
    await keyManager.client.sendToDeviceEncrypted(
      [requestingDevice],
      EventTypes.ForwardedRoomKey,
      message,
    );
    keyManager.incomingShareRequests.remove(request.requestId);
  }
}

/// you would likely want to use [NativeImplementations] and
/// [Client.nativeImplementations] instead
RoomKeys generateUploadKeysImplementation(GenerateUploadKeysArgs args) {
  final enc = olm.PkEncryption();
  try {
    enc.set_recipient_key(args.pubkey);
    // first we generate the payload to upload all the session keys in this chunk
    final roomKeys = RoomKeys(rooms: {});
    for (final dbSession in args.dbSessions) {
      final sess = SessionKey.fromDb(dbSession.dbSession, args.userId);
      if (!sess.isValid) {
        continue;
      }
      // create the room if it doesn't exist
      final roomKeyBackup =
          roomKeys.rooms[sess.roomId] ??= RoomKeyBackup(sessions: {});
      // generate the encrypted content
      final payload = <String, dynamic>{
        'algorithm': AlgorithmTypes.megolmV1AesSha2,
        'forwarding_curve25519_key_chain': sess.forwardingCurve25519KeyChain,
        'sender_key': sess.senderKey,
        'sender_claimed_keys': sess.senderClaimedKeys,
        'session_key': sess.inboundGroupSession!
            .export_session(sess.inboundGroupSession!.first_known_index()),
      };
      // encrypt the content
      final encrypted = enc.encrypt(json.encode(payload));
      // fetch the device, if available...
      //final device = args.client.getUserDeviceKeysByCurve25519Key(sess.senderKey);
      // aaaand finally add the session key to our payload
      roomKeyBackup.sessions[sess.sessionId] = KeyBackupData(
        firstMessageIndex: sess.inboundGroupSession!.first_known_index(),
        forwardedCount: sess.forwardingCurve25519KeyChain.length,
        isVerified: dbSession.verified, //device?.verified ?? false,
        sessionData: {
          'ephemeral': encrypted.ephemeral,
          'ciphertext': encrypted.ciphertext,
          'mac': encrypted.mac,
        },
      );
    }
    enc.free();
    return roomKeys;
  } catch (e, s) {
    Logs().e('[Key Manager] Error generating payload', e, s);
    enc.free();
    rethrow;
  }
}

class DbInboundGroupSessionBundle {
  DbInboundGroupSessionBundle({
    required this.dbSession,
    required this.verified,
  });

  factory DbInboundGroupSessionBundle.fromJson(Map<dynamic, dynamic> json) =>
      DbInboundGroupSessionBundle(
        dbSession:
            StoredInboundGroupSession.fromJson(Map.from(json['dbSession'])),
        verified: json['verified'],
      );

  Map<String, Object> toJson() => {
        'dbSession': dbSession.toJson(),
        'verified': verified,
      };
  StoredInboundGroupSession dbSession;
  bool verified;
}

class GenerateUploadKeysArgs {
  GenerateUploadKeysArgs({
    required this.pubkey,
    required this.dbSessions,
    required this.userId,
  });

  factory GenerateUploadKeysArgs.fromJson(Map<dynamic, dynamic> json) =>
      GenerateUploadKeysArgs(
        pubkey: json['pubkey'],
        dbSessions: (json['dbSessions'] as Iterable)
            .map((e) => DbInboundGroupSessionBundle.fromJson(e))
            .toList(),
        userId: json['userId'],
      );

  Map<String, Object> toJson() => {
        'pubkey': pubkey,
        'dbSessions': dbSessions.map((e) => e.toJson()).toList(),
        'userId': userId,
      };

  String pubkey;
  List<DbInboundGroupSessionBundle> dbSessions;
  String userId;
}
