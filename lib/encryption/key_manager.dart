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

import 'package:olm/olm.dart' as olm;
import 'package:pedantic/pedantic.dart';

import './encryption.dart';
import './utils/outbound_group_session.dart';
import './utils/session_key.dart';
import '../famedlysdk.dart';
import '../matrix_api.dart';
import '../src/database/database.dart';
import '../src/utils/logs.dart';
import '../src/utils/run_in_background.dart';
import '../src/utils/run_in_root.dart';

const MEGOLM_KEY = 'm.megolm_backup.v1';

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
    encryption.ssss.setValidator(MEGOLM_KEY, (String secret) async {
      final keyObj = olm.PkDecryption();
      try {
        final info = await getRoomKeysBackupInfo(false);
        if (info.algorithm != RoomKeysAlgorithmType.v1Curve25519AesSha2) {
          return false;
        }
        if (keyObj.init_with_private_key(base64.decode(secret)) ==
            info.authData['public_key']) {
          _requestedSessionIds.clear();
          return true;
        }
        return false;
      } catch (_) {
        return false;
      } finally {
        keyObj.free();
      }
    });
  }

  bool get enabled => client.accountData[MEGOLM_KEY] != null;

  /// clear all cached inbound group sessions. useful for testing
  void clearInboundGroupSessions() {
    _inboundGroupSessions.clear();
  }

  void setInboundGroupSession(String roomId, String sessionId, String senderKey,
      Map<String, dynamic> content,
      {bool forwarded = false,
      Map<String, String> senderClaimedKeys,
      bool uploaded = false}) {
    senderClaimedKeys ??= <String, String>{};
    if (!senderClaimedKeys.containsKey('ed25519')) {
      final device = client.getUserDeviceKeysByCurve25519Key(senderKey);
      if (device != null) {
        senderClaimedKeys['ed25519'] = device.ed25519Key;
      }
    }
    final oldSession =
        getInboundGroupSession(roomId, sessionId, senderKey, otherRooms: false);
    if (content['algorithm'] != 'm.megolm.v1.aes-sha2') {
      return;
    }
    olm.InboundGroupSession inboundGroupSession;
    try {
      inboundGroupSession = olm.InboundGroupSession();
      if (forwarded) {
        inboundGroupSession.import_session(content['session_key']);
      } else {
        inboundGroupSession.create(content['session_key']);
      }
    } catch (e, s) {
      inboundGroupSession.free();
      Logs.error(
          '[LibOlm] Could not create new InboundGroupSession: ' + e.toString(),
          s);
      return;
    }
    final newSession = SessionKey(
      content: content,
      inboundGroupSession: inboundGroupSession,
      indexes: {},
      roomId: roomId,
      sessionId: sessionId,
      key: client.userID,
      senderKey: senderKey,
      senderClaimedKeys: senderClaimedKeys,
    );
    final oldFirstIndex =
        oldSession?.inboundGroupSession?.first_known_index() ?? 0;
    final newFirstIndex = newSession.inboundGroupSession.first_known_index();
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
    if (!_inboundGroupSessions.containsKey(roomId)) {
      _inboundGroupSessions[roomId] = <String, SessionKey>{};
    }
    _inboundGroupSessions[roomId][sessionId] = newSession;
    client.database
        ?.storeInboundGroupSession(
      client.id,
      roomId,
      sessionId,
      inboundGroupSession.pickle(client.userID),
      json.encode(content),
      json.encode({}),
      senderKey,
      json.encode(senderClaimedKeys),
    )
        ?.then((_) {
      if (uploaded) {
        client.database
            .markInboundGroupSessionAsUploaded(client.id, roomId, sessionId);
      }
    });
    // TODO: somehow try to decrypt last message again
    final room = client.getRoomById(roomId);
    if (room != null) {
      room.onSessionKeyReceived.add(sessionId);
    }
  }

  SessionKey getInboundGroupSession(
      String roomId, String sessionId, String senderKey,
      {bool otherRooms = true}) {
    if (_inboundGroupSessions.containsKey(roomId) &&
        _inboundGroupSessions[roomId].containsKey(sessionId)) {
      final sess = _inboundGroupSessions[roomId][sessionId];
      if (sess.senderKey != senderKey && sess.senderKey.isNotEmpty) {
        return null;
      }
      return sess;
    }
    if (!otherRooms) {
      return null;
    }
    // search if this session id is *somehow* found in another room
    for (final val in _inboundGroupSessions.values) {
      if (val.containsKey(sessionId)) {
        final sess = val[sessionId];
        if (sess.senderKey != senderKey && sess.senderKey.isNotEmpty) {
          return null;
        }
        return sess;
      }
    }
    return null;
  }

  /// Loads an inbound group session
  Future<SessionKey> loadInboundGroupSession(
      String roomId, String sessionId, String senderKey) async {
    if (roomId == null || sessionId == null || senderKey == null) {
      return null;
    }
    if (_inboundGroupSessions.containsKey(roomId) &&
        _inboundGroupSessions[roomId].containsKey(sessionId)) {
      final sess = _inboundGroupSessions[roomId][sessionId];
      if (sess.senderKey != senderKey && sess.senderKey.isNotEmpty) {
        return null; // sender keys do not match....better not do anything
      }
      return sess; // nothing to do
    }
    final session = await client.database
        ?.getDbInboundGroupSession(client.id, roomId, sessionId);
    if (session == null) {
      final room = client.getRoomById(roomId);
      final requestIdent = '$roomId|$sessionId|$senderKey';
      if (client.enableE2eeRecovery &&
          room != null &&
          !_requestedSessionIds.contains(requestIdent) &&
          !client.isUnknownSession) {
        // do e2ee recovery
        _requestedSessionIds.add(requestIdent);
        unawaited(runInRoot(() =>
            request(room, sessionId, senderKey, askOnlyOwnDevices: true)));
      }
      return null;
    }
    if (!_inboundGroupSessions.containsKey(roomId)) {
      _inboundGroupSessions[roomId] = <String, SessionKey>{};
    }
    final sess = SessionKey.fromDb(session, client.userID);
    if (!sess.isValid ||
        (sess.senderKey.isNotEmpty && sess.senderKey != senderKey)) {
      return null;
    }
    _inboundGroupSessions[roomId][sessionId] = sess;
    return sess;
  }

  /// clear all cached inbound group sessions. useful for testing
  void clearOutboundGroupSessions() {
    _outboundGroupSessions.clear();
  }

  /// Clears the existing outboundGroupSession but first checks if the participating
  /// devices have been changed. Returns false if the session has not been cleared because
  /// it wasn't necessary.
  Future<bool> clearOutboundGroupSession(String roomId,
      {bool wipe = false}) async {
    final room = client.getRoomById(roomId);
    final sess = getOutboundGroupSession(roomId);
    if (room == null || sess == null) {
      return true;
    }
    if (!wipe) {
      // first check if the devices in the room changed
      final deviceKeys = await room.getUserDeviceKeys();
      deviceKeys.removeWhere((k) => k.blocked);
      final deviceKeyIds = deviceKeys.map((k) => k.deviceId).toList();
      deviceKeyIds.sort();
      if (deviceKeyIds.toString() != sess.devices.toString()) {
        wipe = true;
      }
      // next check if it needs to be rotated
      final encryptionContent = room.getState(EventTypes.Encryption)?.content;
      final maxMessages = encryptionContent != null &&
              encryptionContent['rotation_period_msgs'] is int
          ? encryptionContent['rotation_period_msgs']
          : 100;
      final maxAge = encryptionContent != null &&
              encryptionContent['rotation_period_ms'] is int
          ? encryptionContent['rotation_period_ms']
          : 604800000; // default of one week
      if (sess.sentMessages >= maxMessages ||
          sess.creationTime
              .add(Duration(milliseconds: maxAge))
              .isBefore(DateTime.now())) {
        wipe = true;
      }
      if (!wipe) {
        return false;
      }
    }
    sess.dispose();
    _outboundGroupSessions.remove(roomId);
    await client.database?.removeOutboundGroupSession(client.id, roomId);
    return true;
  }

  Future<void> storeOutboundGroupSession(
      String roomId, OutboundGroupSession sess) async {
    if (sess == null) {
      return;
    }
    await client.database?.storeOutboundGroupSession(
        client.id,
        roomId,
        sess.outboundGroupSession.pickle(client.userID),
        json.encode(sess.devices),
        sess.creationTime.millisecondsSinceEpoch,
        sess.sentMessages);
  }

  Future<OutboundGroupSession> createOutboundGroupSession(String roomId) async {
    await clearOutboundGroupSession(roomId, wipe: true);
    final room = client.getRoomById(roomId);
    if (room == null) {
      return null;
    }
    final deviceKeys = await room.getUserDeviceKeys();
    deviceKeys.removeWhere((k) => k.blocked);
    final deviceKeyIds = deviceKeys.map((k) => k.deviceId).toList();
    deviceKeyIds.sort();
    final outboundGroupSession = olm.OutboundGroupSession();
    try {
      outboundGroupSession.create();
    } catch (e, s) {
      outboundGroupSession.free();
      Logs.error(
          '[LibOlm] Unable to create new outboundGroupSession: ' + e.toString(),
          s);
      return null;
    }
    final rawSession = <String, dynamic>{
      'algorithm': 'm.megolm.v1.aes-sha2',
      'room_id': room.id,
      'session_id': outboundGroupSession.session_id(),
      'session_key': outboundGroupSession.session_key(),
    };
    setInboundGroupSession(
        roomId, rawSession['session_id'], encryption.identityKey, rawSession);
    final sess = OutboundGroupSession(
      devices: deviceKeyIds,
      creationTime: DateTime.now(),
      outboundGroupSession: outboundGroupSession,
      sentMessages: 0,
      key: client.userID,
    );
    try {
      await client.sendToDeviceEncrypted(deviceKeys, 'm.room_key', rawSession);
      await storeOutboundGroupSession(roomId, sess);
      _outboundGroupSessions[roomId] = sess;
    } catch (e, s) {
      Logs.error(
          '[LibOlm] Unable to send the session key to the participating devices: ' +
              e.toString(),
          s);
      sess.dispose();
      return null;
    }
    return sess;
  }

  OutboundGroupSession getOutboundGroupSession(String roomId) {
    return _outboundGroupSessions[roomId];
  }

  Future<void> loadOutboundGroupSession(String roomId) async {
    if (_loadedOutboundGroupSessions.contains(roomId) ||
        _outboundGroupSessions.containsKey(roomId) ||
        client.database == null) {
      return; // nothing to do
    }
    _loadedOutboundGroupSessions.add(roomId);
    final session =
        await client.database.getDbOutboundGroupSession(client.id, roomId);
    if (session == null) {
      return;
    }
    final sess = OutboundGroupSession.fromDb(session, client.userID);
    if (!sess.isValid) {
      return;
    }
    _outboundGroupSessions[roomId] = sess;
  }

  Future<bool> isCached() async {
    if (!enabled) {
      return false;
    }
    return (await encryption.ssss.getCached(MEGOLM_KEY)) != null;
  }

  RoomKeysVersionResponse _roomKeysVersionCache;
  DateTime _roomKeysVersionCacheDate;
  Future<RoomKeysVersionResponse> getRoomKeysBackupInfo(
      [bool useCache = true]) async {
    if (_roomKeysVersionCache != null &&
        _roomKeysVersionCacheDate != null &&
        useCache &&
        DateTime.now()
            .subtract(Duration(minutes: 5))
            .isBefore(_roomKeysVersionCacheDate)) {
      return _roomKeysVersionCache;
    }
    _roomKeysVersionCache = await client.getRoomKeysBackup();
    _roomKeysVersionCacheDate = DateTime.now();
    return _roomKeysVersionCache;
  }

  Future<void> loadFromResponse(RoomKeys keys) async {
    if (!(await isCached())) {
      return;
    }
    final privateKey =
        base64.decode(await encryption.ssss.getCached(MEGOLM_KEY));
    final decryption = olm.PkDecryption();
    final info = await getRoomKeysBackupInfo();
    String backupPubKey;
    try {
      backupPubKey = decryption.init_with_private_key(privateKey);

      if (backupPubKey == null ||
          info.algorithm != RoomKeysAlgorithmType.v1Curve25519AesSha2 ||
          info.authData['public_key'] != backupPubKey) {
        return;
      }
      for (final roomEntry in keys.rooms.entries) {
        final roomId = roomEntry.key;
        for (final sessionEntry in roomEntry.value.sessions.entries) {
          final sessionId = sessionEntry.key;
          final session = sessionEntry.value;
          final firstMessageIndex = session.firstMessageIndex;
          final forwardedCount = session.forwardedCount;
          final isVerified = session.isVerified;
          final sessionData = session.sessionData;
          if (firstMessageIndex == null ||
              forwardedCount == null ||
              isVerified == null ||
              !(sessionData is Map)) {
            continue;
          }
          Map<String, dynamic> decrypted;
          try {
            decrypted = json.decode(decryption.decrypt(sessionData['ephemeral'],
                sessionData['mac'], sessionData['ciphertext']));
          } catch (e, s) {
            Logs.error(
                '[LibOlm] Error decrypting room key: ' + e.toString(), s);
          }
          if (decrypted != null) {
            decrypted['session_id'] = sessionId;
            decrypted['room_id'] = roomId;
            setInboundGroupSession(
                roomId, sessionId, decrypted['sender_key'], decrypted,
                forwarded: true,
                senderClaimedKeys: decrypted['sender_claimed_keys'] != null
                    ? Map<String, String>.from(decrypted['sender_claimed_keys'])
                    : null,
                uploaded: true);
          }
        }
      }
    } finally {
      decryption.free();
    }
  }

  Future<void> loadSingleKey(String roomId, String sessionId) async {
    final info = await getRoomKeysBackupInfo();
    final ret =
        await client.getRoomKeysSingleKey(roomId, sessionId, info.version);
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
    String senderKey, {
    bool tryOnlineBackup = true,
    bool askOnlyOwnDevices = false,
  }) async {
    if (tryOnlineBackup && await isCached()) {
      // let's first check our online key backup store thingy...
      var hadPreviously =
          getInboundGroupSession(room.id, sessionId, senderKey) != null;
      try {
        await loadSingleKey(room.id, sessionId);
      } catch (err, stacktrace) {
        if (err is MatrixException && err.errcode == 'M_NOT_FOUND') {
          Logs.info(
              '[KeyManager] Key not in online key backup, requesting it from other devices...');
        } else {
          Logs.error(
              '[KeyManager] Failed to access online key backup: ' +
                  err.toString(),
              stacktrace);
        }
      }
      if (!hadPreviously &&
          getInboundGroupSession(room.id, sessionId, senderKey) != null) {
        return; // we managed to load the session from online backup, no need to care about it now
      }
    }
    try {
      // while we just send the to-device event to '*', we still need to save the
      // devices themself to know where to send the cancel to after receiving a reply
      final devices = await room.getUserDeviceKeys();
      if (askOnlyOwnDevices) {
        devices.removeWhere((d) => d.userId != client.userID);
      }
      final requestId = client.generateUniqueTransactionId();
      final request = KeyManagerKeyShareRequest(
        requestId: requestId,
        devices: devices,
        room: room,
        sessionId: sessionId,
        senderKey: senderKey,
      );
      final userList = await room.requestParticipants();
      await client.sendToDevicesOfUserIds(
        userList.map<String>((u) => u.id).toSet(),
        'm.room_key_request',
        {
          'action': 'request',
          'body': {
            'algorithm': 'm.megolm.v1.aes-sha2',
            'room_id': room.id,
            'sender_key': senderKey,
            'session_id': sessionId,
          },
          'request_id': requestId,
          'requesting_device_id': client.deviceID,
        },
      );
      outgoingShareRequests[request.requestId] = request;
    } catch (e, s) {
      Logs.error(
          '[Key Manager] Sending key verification request failed: ' +
              e.toString(),
          s);
    }
  }

  bool _isUploadingKeys = false;
  Future<void> backgroundTasks() async {
    if (_isUploadingKeys || client.database == null) {
      return;
    }
    _isUploadingKeys = true;
    try {
      if (!(await isCached())) {
        return; // we can't backup anyways
      }
      final dbSessions =
          await client.database.getInboundGroupSessionsToUpload().get();
      if (dbSessions.isEmpty) {
        return; // nothing to do
      }
      final privateKey =
          base64.decode(await encryption.ssss.getCached(MEGOLM_KEY));
      // decryption is needed to calculate the public key and thus see if the claimed information is in fact valid
      final decryption = olm.PkDecryption();
      final info = await getRoomKeysBackupInfo(false);
      String backupPubKey;
      try {
        backupPubKey = decryption.init_with_private_key(privateKey);

        if (backupPubKey == null ||
            info.algorithm != RoomKeysAlgorithmType.v1Curve25519AesSha2 ||
            info.authData['public_key'] != backupPubKey) {
          return;
        }
        final args = _GenerateUploadKeysArgs(
          pubkey: backupPubKey,
          dbSessions: <_DbInboundGroupSessionBundle>[],
          userId: client.userID,
        );
        // we need to calculate verified beforehand, as else we pass a closure to an isolate
        // with 500 keys they do, however, noticably block the UI, which is why we give brief async suspentions in here
        // so that the event loop can progress
        var i = 0;
        for (final dbSession in dbSessions) {
          final device =
              client.getUserDeviceKeysByCurve25519Key(dbSession.senderKey);
          args.dbSessions.add(_DbInboundGroupSessionBundle(
            dbSession: dbSession,
            verified: device?.verified ?? false,
          ));
          i++;
          if (i > 10) {
            await Future.delayed(Duration(milliseconds: 1));
            i = 0;
          }
        }
        final roomKeys =
            await runInBackground<RoomKeys, _GenerateUploadKeysArgs>(
                _generateUploadKeys, args);
        Logs.info('[Key Manager] Uploading ${dbSessions.length} room keys...');
        // upload the payload...
        await client.storeRoomKeys(info.version, roomKeys);
        // and now finally mark all the keys as uploaded
        // no need to optimze this, as we only run it so seldomly and almost never with many keys at once
        for (final dbSession in dbSessions) {
          await client.database.markInboundGroupSessionAsUploaded(
              client.id, dbSession.roomId, dbSession.sessionId);
        }
      } finally {
        decryption.free();
      }
    } catch (e, s) {
      Logs.error('[Key Manager] Error uploading room keys: ' + e.toString(), s);
    } finally {
      _isUploadingKeys = false;
    }
  }

  /// Handle an incoming to_device event that is related to key sharing
  Future<void> handleToDeviceEvent(ToDeviceEvent event) async {
    if (event.type == 'm.room_key_request') {
      if (!(event.content['request_id'] is String)) {
        return; // invalid event
      }
      if (event.content['action'] == 'request') {
        // we are *receiving* a request
        Logs.info('[KeyManager] Received key sharing request...');
        if (!event.content.containsKey('body')) {
          Logs.info('[KeyManager] No body, doing nothing');
          return; // no body
        }
        if (!client.userDeviceKeys.containsKey(event.sender) ||
            !client.userDeviceKeys[event.sender].deviceKeys
                .containsKey(event.content['requesting_device_id'])) {
          Logs.info('[KeyManager] Device not found, doing nothing');
          return; // device not found
        }
        final device = client.userDeviceKeys[event.sender]
            .deviceKeys[event.content['requesting_device_id']];
        if (device.userId == client.userID &&
            device.deviceId == client.deviceID) {
          Logs.info('[KeyManager] Request is by ourself, ignoring');
          return; // ignore requests by ourself
        }
        final room = client.getRoomById(event.content['body']['room_id']);
        if (room == null) {
          Logs.info('[KeyManager] Unknown room, ignoring');
          return; // unknown room
        }
        final sessionId = event.content['body']['session_id'];
        final senderKey = event.content['body']['sender_key'];
        // okay, let's see if we have this session at all
        if ((await loadInboundGroupSession(room.id, sessionId, senderKey)) ==
            null) {
          Logs.info('[KeyManager] Unknown session, ignoring');
          return; // we don't have this session anyways
        }
        final request = KeyManagerKeyShareRequest(
          requestId: event.content['request_id'],
          devices: [device],
          room: room,
          sessionId: sessionId,
          senderKey: senderKey,
        );
        if (incomingShareRequests.containsKey(request.requestId)) {
          Logs.info('[KeyManager] Already processed this request, ignoring');
          return; // we don't want to process one and the same request multiple times
        }
        incomingShareRequests[request.requestId] = request;
        final roomKeyRequest =
            RoomKeyRequest.fromToDeviceEvent(event, this, request);
        if (device.userId == client.userID &&
            device.verified &&
            !device.blocked) {
          Logs.info('[KeyManager] All checks out, forwarding key...');
          // alright, we can forward the key
          await roomKeyRequest.forwardKey();
        } else {
          Logs.info(
              '[KeyManager] Asking client, if the key should be forwarded');
          client.onRoomKeyRequest
              .add(roomKeyRequest); // let the client handle this
        }
      } else if (event.content['action'] == 'request_cancellation') {
        // we got told to cancel an incoming request
        if (!incomingShareRequests.containsKey(event.content['request_id'])) {
          return; // we don't know this request anyways
        }
        // alright, let's just cancel this request
        final request = incomingShareRequests[event.content['request_id']];
        request.canceled = true;
        incomingShareRequests.remove(request.requestId);
      }
    } else if (event.type == 'm.forwarded_room_key') {
      // we *received* an incoming key request
      if (event.encryptedContent == null) {
        return; // event wasn't encrypted, this is a security risk
      }
      final request = outgoingShareRequests.values.firstWhere(
          (r) =>
              r.room.id == event.content['room_id'] &&
              r.sessionId == event.content['session_id'] &&
              r.senderKey == event.content['sender_key'],
          orElse: () => null);
      if (request == null || request.canceled) {
        return; // no associated request found or it got canceled
      }
      final device = request.devices.firstWhere(
          (d) =>
              d.userId == event.sender &&
              d.curve25519Key == event.encryptedContent['sender_key'],
          orElse: () => null);
      if (device == null) {
        return; // someone we didn't send our request to replied....better ignore this
      }
      // we add the sender key to the forwarded key chain
      if (!(event.content['forwarding_curve25519_key_chain'] is List)) {
        event.content['forwarding_curve25519_key_chain'] = <String>[];
      }
      event.content['forwarding_curve25519_key_chain']
          .add(event.encryptedContent['sender_key']);
      // TODO: verify that the keys work to decrypt a message
      // alright, all checks out, let's go ahead and store this session
      setInboundGroupSession(
          request.room.id, request.sessionId, request.senderKey, event.content,
          forwarded: true,
          senderClaimedKeys: {
            'ed25519': event.content['sender_claimed_ed25519_key'],
          });
      request.devices.removeWhere(
          (k) => k.userId == device.userId && k.deviceId == device.deviceId);
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
      var data = <String, Map<String, Map<String, dynamic>>>{};
      for (final device in request.devices) {
        if (!data.containsKey(device.userId)) {
          data[device.userId] = {};
        }
        data[device.userId][device.deviceId] = sendToDeviceMessage;
      }
      await client.sendToDevice(
        'm.room_key_request',
        client.generateUniqueTransactionId(),
        data,
      );
    } else if (event.type == 'm.room_key') {
      if (event.encryptedContent == null) {
        return; // the event wasn't encrypted, this is a security risk;
      }
      final String roomId = event.content['room_id'];
      final String sessionId = event.content['session_id'];
      if (client.userDeviceKeys.containsKey(event.sender) &&
          client.userDeviceKeys[event.sender].deviceKeys
              .containsKey(event.content['requesting_device_id'])) {
        event.content['sender_claimed_ed25519_key'] = client
            .userDeviceKeys[event.sender]
            .deviceKeys[event.content['requesting_device_id']]
            .ed25519Key;
      }
      setInboundGroupSession(roomId, sessionId,
          event.encryptedContent['sender_key'], event.content,
          forwarded: false);
    }
  }

  void dispose() {
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
  final String senderKey;
  bool canceled;

  KeyManagerKeyShareRequest(
      {this.requestId,
      this.devices,
      this.room,
      this.sessionId,
      this.senderKey,
      this.canceled = false});
}

class RoomKeyRequest extends ToDeviceEvent {
  KeyManager keyManager;
  KeyManagerKeyShareRequest request;
  RoomKeyRequest.fromToDeviceEvent(ToDeviceEvent toDeviceEvent,
      KeyManager keyManager, KeyManagerKeyShareRequest request) {
    this.keyManager = keyManager;
    this.request = request;
    sender = toDeviceEvent.sender;
    content = toDeviceEvent.content;
    type = toDeviceEvent.type;
  }

  Room get room => request.room;

  DeviceKeys get requestingDevice => request.devices.first;

  Future<void> forwardKey() async {
    if (request.canceled) {
      keyManager.incomingShareRequests.remove(request.requestId);
      return; // request is canceled, don't send anything
    }
    var room = this.room;
    final session = await keyManager.loadInboundGroupSession(
        room.id, request.sessionId, request.senderKey);
    var message = session.content;
    message['forwarding_curve25519_key_chain'] =
        List<String>.from(session.forwardingCurve25519KeyChain);

    message['sender_key'] =
        (session.senderKey != null && session.senderKey.isNotEmpty)
            ? session.senderKey
            : request.senderKey;
    message['sender_claimed_ed25519_key'] =
        session.senderClaimedKeys['ed25519'] ??
            (session.forwardingCurve25519KeyChain.isEmpty
                ? keyManager.encryption.fingerprintKey
                : null);
    message['session_key'] = session.inboundGroupSession
        .export_session(session.inboundGroupSession.first_known_index());
    // send the actual reply of the key back to the requester
    await keyManager.client.sendToDeviceEncrypted(
      [requestingDevice],
      'm.forwarded_room_key',
      message,
    );
    keyManager.incomingShareRequests.remove(request.requestId);
  }
}

RoomKeys _generateUploadKeys(_GenerateUploadKeysArgs args) {
  final enc = olm.PkEncryption();
  try {
    enc.set_recipient_key(args.pubkey);
    // first we generate the payload to upload all the session keys in this chunk
    final roomKeys = RoomKeys();
    for (final dbSession in args.dbSessions) {
      final sess = SessionKey.fromDb(dbSession.dbSession, args.userId);
      if (!sess.isValid) {
        continue;
      }
      // create the room if it doesn't exist
      if (!roomKeys.rooms.containsKey(sess.roomId)) {
        roomKeys.rooms[sess.roomId] = RoomKeysRoom();
      }
      // generate the encrypted content
      final payload = <String, dynamic>{
        'algorithm': 'm.megolm.v1.aes-sha2',
        'forwarding_curve25519_key_chain': sess.forwardingCurve25519KeyChain,
        'sender_key': sess.senderKey,
        'sender_clencaimed_keys': sess.senderClaimedKeys,
        'session_key': sess.inboundGroupSession
            .export_session(sess.inboundGroupSession.first_known_index()),
      };
      // encrypt the content
      final encrypted = enc.encrypt(json.encode(payload));
      // fetch the device, if available...
      //final device = args.client.getUserDeviceKeysByCurve25519Key(sess.senderKey);
      // aaaand finally add the session key to our payload
      roomKeys.rooms[sess.roomId].sessions[sess.sessionId] = RoomKeysSingleKey(
        firstMessageIndex: sess.inboundGroupSession.first_known_index(),
        forwardedCount: sess.forwardingCurve25519KeyChain.length,
        isVerified: dbSession.verified, //device?.verified ?? false,
        sessionData: {
          'ephemeral': encrypted.ephemeral,
          'ciphertext': encrypted.ciphertext,
          'mac': encrypted.mac,
        },
      );
    }
    return roomKeys;
  } catch (e, s) {
    Logs.error('[Key Manager] Error generating payload ' + e.toString(), s);
    rethrow;
  } finally {
    enc.free();
  }
}

class _DbInboundGroupSessionBundle {
  _DbInboundGroupSessionBundle({this.dbSession, this.verified});

  DbInboundGroupSession dbSession;
  bool verified;
}

class _GenerateUploadKeysArgs {
  _GenerateUploadKeysArgs({this.pubkey, this.dbSessions, this.userId});

  String pubkey;
  List<_DbInboundGroupSessionBundle> dbSessions;
  String userId;
}
