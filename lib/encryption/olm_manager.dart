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

import 'dart:convert';

import 'package:canonical_json/canonical_json.dart';
import 'package:famedlysdk/famedlysdk.dart';
import 'package:olm/olm.dart' as olm;
import 'package:pedantic/pedantic.dart';

import '../encryption/utils/json_signature_check_extension.dart';
import 'encryption.dart';
import 'utils/olm_session.dart';
import '../src/utils/run_in_root.dart';

class OlmManager {
  final Encryption encryption;
  Client get client => encryption.client;
  olm.Account _olmAccount;

  /// Returns the base64 encoded keys to store them in a store.
  /// This String should **never** leave the device!
  String get pickledOlmAccount =>
      enabled ? _olmAccount.pickle(client.userID) : null;
  String get fingerprintKey =>
      enabled ? json.decode(_olmAccount.identity_keys())['ed25519'] : null;
  String get identityKey =>
      enabled ? json.decode(_olmAccount.identity_keys())['curve25519'] : null;

  bool get enabled => _olmAccount != null;

  OlmManager(this.encryption);

  /// A map from Curve25519 identity keys to existing olm sessions.
  Map<String, List<OlmSession>> get olmSessions => _olmSessions;
  final Map<String, List<OlmSession>> _olmSessions = {};

  Future<void> init(String olmAccount) async {
    if (olmAccount == null) {
      try {
        await olm.init();
        _olmAccount = olm.Account();
        _olmAccount.create();
        if (await uploadKeys(uploadDeviceKeys: true, updateDatabase: false) ==
            false) {
          throw ('Upload key failed');
        }
      } catch (_) {
        _olmAccount?.free();
        _olmAccount = null;
        rethrow;
      }
    } else {
      try {
        await olm.init();
        _olmAccount = olm.Account();
        _olmAccount.unpickle(client.userID, olmAccount);
      } catch (_) {
        _olmAccount?.free();
        _olmAccount = null;
        rethrow;
      }
    }
  }

  /// Adds a signature to this json from this olm account and returns the signed
  /// json.
  Map<String, dynamic> signJson(Map<String, dynamic> payload) {
    if (!enabled) throw ('Encryption is disabled');
    final Map<String, dynamic> unsigned = payload['unsigned'];
    final Map<String, dynamic> signatures = payload['signatures'];
    payload.remove('unsigned');
    payload.remove('signatures');
    final canonical = canonicalJson.encode(payload);
    final signature = _olmAccount.sign(String.fromCharCodes(canonical));
    if (signatures != null) {
      payload['signatures'] = signatures;
    } else {
      payload['signatures'] = <String, dynamic>{};
    }
    if (!payload['signatures'].containsKey(client.userID)) {
      payload['signatures'][client.userID] = <String, dynamic>{};
    }
    payload['signatures'][client.userID]['ed25519:${client.deviceID}'] =
        signature;
    if (unsigned != null) {
      payload['unsigned'] = unsigned;
    }
    return payload;
  }

  String signString(String s) {
    return _olmAccount.sign(s);
  }

  /// Checks the signature of a signed json object.
  @deprecated
  bool checkJsonSignature(String key, Map<String, dynamic> signedJson,
      String userId, String deviceId) {
    if (!enabled) throw ('Encryption is disabled');
    final Map<String, dynamic> signatures = signedJson['signatures'];
    if (signatures == null || !signatures.containsKey(userId)) return false;
    signedJson.remove('unsigned');
    signedJson.remove('signatures');
    if (!signatures[userId].containsKey('ed25519:$deviceId')) return false;
    final String signature = signatures[userId]['ed25519:$deviceId'];
    final canonical = canonicalJson.encode(signedJson);
    final message = String.fromCharCodes(canonical);
    var isValid = false;
    final olmutil = olm.Utility();
    try {
      olmutil.ed25519_verify(key, message, signature);
      isValid = true;
    } catch (e, s) {
      isValid = false;
      Logs().w('[LibOlm] Signature check failed', e, s);
    } finally {
      olmutil.free();
    }
    return isValid;
  }

  bool _uploadKeysLock = false;

  /// Generates new one time keys, signs everything and upload it to the server.
  Future<bool> uploadKeys(
      {bool uploadDeviceKeys = false,
      int oldKeyCount = 0,
      bool updateDatabase = true}) async {
    if (!enabled) {
      return true;
    }

    if (_uploadKeysLock) {
      return false;
    }
    _uploadKeysLock = true;

    try {
      // check if we have OTKs that still need uploading. If we do, we don't try to generate new ones,
      // instead we try to upload the old ones first
      final oldOTKsNeedingUpload =
          json.decode(_olmAccount.one_time_keys())['curve25519'].entries.length;
      // generate one-time keys
      // we generate 2/3rds of max, so that other keys people may still have can
      // still be used
      final oneTimeKeysCount =
          (_olmAccount.max_number_of_one_time_keys() * 2 / 3).floor() -
              oldKeyCount -
              oldOTKsNeedingUpload;
      if (oneTimeKeysCount > 0) {
        _olmAccount.generate_one_time_keys(oneTimeKeysCount);
      }
      final Map<String, dynamic> oneTimeKeys =
          json.decode(_olmAccount.one_time_keys());

      // now sign all the one-time keys
      final signedOneTimeKeys = <String, dynamic>{};
      for (final entry in oneTimeKeys['curve25519'].entries) {
        final key = entry.key;
        final value = entry.value;
        signedOneTimeKeys['signed_curve25519:$key'] = <String, dynamic>{};
        signedOneTimeKeys['signed_curve25519:$key'] = signJson({
          'key': value,
        });
      }

      // and now generate the payload to upload
      final keysContent = <String, dynamic>{
        if (uploadDeviceKeys)
          'device_keys': {
            'user_id': client.userID,
            'device_id': client.deviceID,
            'algorithms': [
              AlgorithmTypes.olmV1Curve25519AesSha2,
              AlgorithmTypes.megolmV1AesSha2
            ],
            'keys': <String, dynamic>{},
          },
      };
      if (uploadDeviceKeys) {
        final Map<String, dynamic> keys =
            json.decode(_olmAccount.identity_keys());
        for (final entry in keys.entries) {
          final algorithm = entry.key;
          final value = entry.value;
          keysContent['device_keys']['keys']['$algorithm:${client.deviceID}'] =
              value;
        }
        keysContent['device_keys'] =
            signJson(keysContent['device_keys'] as Map<String, dynamic>);
      }

      // we save the generated OTKs into the database.
      // in case the app gets killed during upload or the upload fails due to bad network
      // we can still re-try later
      if (updateDatabase) {
        await client.database?.updateClientKeys(pickledOlmAccount, client.id);
      }
      final response = await client.uploadDeviceKeys(
        deviceKeys: uploadDeviceKeys
            ? MatrixDeviceKeys.fromJson(keysContent['device_keys'])
            : null,
        oneTimeKeys: signedOneTimeKeys,
      );
      // mark the OTKs as published and save that to datbase
      _olmAccount.mark_keys_as_published();
      if (updateDatabase) {
        await client.database?.updateClientKeys(pickledOlmAccount, client.id);
      }
      return response['signed_curve25519'] == oneTimeKeysCount;
    } finally {
      _uploadKeysLock = false;
    }
  }

  void handleDeviceOneTimeKeysCount(Map<String, int> countJson) {
    if (!enabled) {
      return;
    }
    // Check if there are at least half of max_number_of_one_time_keys left on the server
    // and generate and upload more if not.
    if (countJson.containsKey('signed_curve25519') &&
        countJson['signed_curve25519'] <
            (_olmAccount.max_number_of_one_time_keys() / 2)) {
      uploadKeys(oldKeyCount: countJson['signed_curve25519']);
    }
  }

  void storeOlmSession(OlmSession session) {
    if (client.database == null) {
      return;
    }
    _olmSessions[session.identityKey] ??= <OlmSession>[];
    final ix = _olmSessions[session.identityKey]
        .indexWhere((s) => s.sessionId == session.sessionId);
    if (ix == -1) {
      // add a new session
      _olmSessions[session.identityKey].add(session);
    } else {
      // update an existing session
      _olmSessions[session.identityKey][ix] = session;
    }
    client.database.storeOlmSession(
        client.id,
        session.identityKey,
        session.sessionId,
        session.pickledSession,
        session.lastReceived.millisecondsSinceEpoch);
  }

  ToDeviceEvent _decryptToDeviceEvent(ToDeviceEvent event) {
    if (event.type != EventTypes.Encrypted) {
      return event;
    }
    final content = event.parsedRoomEncryptedContent;
    if (content.algorithm != AlgorithmTypes.olmV1Curve25519AesSha2) {
      throw DecryptException(DecryptException.unknownAlgorithm);
    }
    if (!content.ciphertextOlm.containsKey(identityKey)) {
      throw DecryptException(DecryptException.isntSentForThisDevice);
    }
    String plaintext;
    final senderKey = content.senderKey;
    final body = content.ciphertextOlm[identityKey].body;
    final type = content.ciphertextOlm[identityKey].type;
    if (type != 0 && type != 1) {
      throw DecryptException(DecryptException.unknownMessageType);
    }
    final device = client.userDeviceKeys[event.sender]?.deviceKeys?.values
        ?.firstWhere((d) => d.curve25519Key == senderKey, orElse: () => null);
    final existingSessions = olmSessions[senderKey];
    final updateSessionUsage = ([OlmSession session]) => runInRoot(() {
          if (session != null) {
            session.lastReceived = DateTime.now();
            storeOlmSession(session);
          }
          if (device != null) {
            device.lastActive = DateTime.now();
            client.database?.setLastActiveUserDeviceKey(
                device.lastActive.millisecondsSinceEpoch,
                client.id,
                device.userId,
                device.deviceId);
          }
        });
    if (existingSessions != null) {
      for (var session in existingSessions) {
        if (type == 0 && session.session.matches_inbound(body) == true) {
          try {
            plaintext = session.session.decrypt(type, body);
          } catch (e) {
            throw DecryptException(
                DecryptException.decryptionFailed, e.toString());
          }
          updateSessionUsage(session);
          break;
        } else if (type == 1) {
          try {
            plaintext = session.session.decrypt(type, body);
            updateSessionUsage(session);
            break;
          } catch (_) {
            plaintext = null;
          }
        }
      }
    }
    if (plaintext == null && type != 0) {
      throw DecryptException(DecryptException.unableToDecryptWithAnyOlmSession);
    }

    if (plaintext == null) {
      var newSession = olm.Session();
      try {
        newSession.create_inbound_from(_olmAccount, senderKey, body);
        _olmAccount.remove_one_time_keys(newSession);
        client.database?.updateClientKeys(pickledOlmAccount, client.id);
        plaintext = newSession.decrypt(type, body);
        runInRoot(() => storeOlmSession(OlmSession(
              key: client.userID,
              identityKey: senderKey,
              sessionId: newSession.session_id(),
              session: newSession,
              lastReceived: DateTime.now(),
            )));
        updateSessionUsage();
      } catch (e) {
        newSession?.free();
        throw DecryptException(DecryptException.decryptionFailed, e.toString());
      }
    }
    final Map<String, dynamic> plainContent = json.decode(plaintext);
    if (plainContent.containsKey('sender') &&
        plainContent['sender'] != event.sender) {
      throw DecryptException(DecryptException.senderDoesntMatch);
    }
    if (plainContent.containsKey('recipient') &&
        plainContent['recipient'] != client.userID) {
      throw DecryptException(DecryptException.recipientDoesntMatch);
    }
    if (plainContent['recipient_keys'] is Map &&
        plainContent['recipient_keys']['ed25519'] is String &&
        plainContent['recipient_keys']['ed25519'] != fingerprintKey) {
      throw DecryptException(DecryptException.ownFingerprintDoesntMatch);
    }
    return ToDeviceEvent(
      content: plainContent['content'],
      encryptedContent: event.content,
      type: plainContent['type'],
      sender: event.sender,
    );
  }

  Future<List<OlmSession>> getOlmSessionsFromDatabase(String senderKey) async {
    if (client.database == null) {
      return [];
    }
    final rows =
        await client.database.dbGetOlmSessions(client.id, senderKey).get();
    final res = <OlmSession>[];
    for (final row in rows) {
      final sess = OlmSession.fromDb(row, client.userID);
      if (sess.isValid) {
        res.add(sess);
      }
    }
    return res;
  }

  Future<void> getOlmSessionsForDevicesFromDatabase(
      List<String> senderKeys) async {
    if (client.database == null) {
      return;
    }
    final rows = await client.database
        .dbGetOlmSessionsForDevices(client.id, senderKeys)
        .get();
    final res = <String, List<OlmSession>>{};
    for (final row in rows) {
      res[row.identityKey] ??= <OlmSession>[];
      final sess = OlmSession.fromDb(row, client.userID);
      if (sess.isValid) {
        res[row.identityKey].add(sess);
      }
    }
    for (final entry in res.entries) {
      _olmSessions[entry.key] = entry.value;
    }
  }

  Future<List<OlmSession>> getOlmSessions(String senderKey,
      {bool getFromDb = true}) async {
    var sess = olmSessions[senderKey];
    if ((getFromDb ?? true) && (sess == null || sess.isEmpty)) {
      final sessions = await getOlmSessionsFromDatabase(senderKey);
      if (sessions.isEmpty) {
        return [];
      }
      sess = _olmSessions[senderKey] = sessions;
    }
    if (sess == null) {
      return [];
    }
    sess.sort((a, b) => a.lastReceived == b.lastReceived
        ? a.sessionId.compareTo(b.sessionId)
        : b.lastReceived.compareTo(a.lastReceived));
    return sess;
  }

  final Map<String, DateTime> _restoredOlmSessionsTime = {};

  Future<void> restoreOlmSession(String userId, String senderKey) async {
    if (!client.userDeviceKeys.containsKey(userId)) {
      return;
    }
    final device = client.userDeviceKeys[userId].deviceKeys.values
        .firstWhere((d) => d.curve25519Key == senderKey, orElse: () => null);
    if (device == null) {
      return;
    }
    // per device only one olm session per hour should be restored
    final mapKey = '$userId;$senderKey';
    if (_restoredOlmSessionsTime.containsKey(mapKey) &&
        DateTime.now()
            .subtract(Duration(hours: 1))
            .isBefore(_restoredOlmSessionsTime[mapKey])) {
      return;
    }
    _restoredOlmSessionsTime[mapKey] = DateTime.now();
    await startOutgoingOlmSessions([device]);
    await client.sendToDeviceEncrypted([device], 'm.dummy', {});
  }

  Future<ToDeviceEvent> decryptToDeviceEvent(ToDeviceEvent event) async {
    if (event.type != EventTypes.Encrypted) {
      return event;
    }
    final senderKey = event.parsedRoomEncryptedContent.senderKey;
    final loadFromDb = () async {
      final sessions = await getOlmSessions(senderKey);
      return sessions.isNotEmpty;
    };
    if (!_olmSessions.containsKey(senderKey)) {
      await loadFromDb();
    }
    try {
      event = _decryptToDeviceEvent(event);
      if (event.type != EventTypes.Encrypted || !(await loadFromDb())) {
        return event;
      }
      // retry to decrypt!
      return _decryptToDeviceEvent(event);
    } catch (_) {
      // okay, the thing errored while decrypting. It is safe to assume that the olm session is corrupt and we should generate a new one
      if (client.enableE2eeRecovery) {
        unawaited(
            runInRoot(() => restoreOlmSession(event.senderId, senderKey)));
      }
      rethrow;
    }
  }

  Future<void> startOutgoingOlmSessions(List<DeviceKeys> deviceKeys) async {
    Logs().v(
        '[OlmManager] Starting session with ${deviceKeys.length} devices...');
    var requestingKeysFrom = <String, Map<String, String>>{};
    for (var device in deviceKeys) {
      if (requestingKeysFrom[device.userId] == null) {
        requestingKeysFrom[device.userId] = {};
      }
      requestingKeysFrom[device.userId][device.deviceId] = 'signed_curve25519';
    }

    final response =
        await client.requestOneTimeKeys(requestingKeysFrom, timeout: 10000);

    for (var userKeysEntry in response.oneTimeKeys.entries) {
      final userId = userKeysEntry.key;
      for (var deviceKeysEntry in userKeysEntry.value.entries) {
        final deviceId = deviceKeysEntry.key;
        final fingerprintKey =
            client.userDeviceKeys[userId].deviceKeys[deviceId].ed25519Key;
        final identityKey =
            client.userDeviceKeys[userId].deviceKeys[deviceId].curve25519Key;
        for (Map<String, dynamic> deviceKey in deviceKeysEntry.value.values) {
          if (!deviceKey.checkJsonSignature(fingerprintKey, userId, deviceId)) {
            continue;
          }
          Logs().v('[OlmManager] Starting session with ${userId}:${deviceId}');
          var session = olm.Session();
          try {
            session.create_outbound(_olmAccount, identityKey, deviceKey['key']);
            await storeOlmSession(OlmSession(
              key: client.userID,
              identityKey: identityKey,
              sessionId: session.session_id(),
              session: session,
              lastReceived:
                  DateTime.now(), // we want to use a newly created session
            ));
          } catch (e, s) {
            session.free();
            Logs()
                .e('[LibOlm] Could not create new outbound olm session', e, s);
          }
        }
      }
    }
  }

  Future<Map<String, dynamic>> encryptToDeviceMessagePayload(
      DeviceKeys device, String type, Map<String, dynamic> payload,
      {bool getFromDb}) async {
    final sess =
        await getOlmSessions(device.curve25519Key, getFromDb: getFromDb);
    if (sess.isEmpty) {
      throw ('No olm session found for ${device.userId}:${device.deviceId}');
    }
    final fullPayload = {
      'type': type,
      'content': payload,
      'sender': client.userID,
      'keys': {'ed25519': fingerprintKey},
      'recipient': device.userId,
      'recipient_keys': {'ed25519': device.ed25519Key},
    };
    final encryptResult = sess.first.session.encrypt(json.encode(fullPayload));
    storeOlmSession(sess.first);
    final encryptedBody = <String, dynamic>{
      'algorithm': AlgorithmTypes.olmV1Curve25519AesSha2,
      'sender_key': identityKey,
      'ciphertext': <String, dynamic>{},
    };
    encryptedBody['ciphertext'][device.curve25519Key] = {
      'type': encryptResult.type,
      'body': encryptResult.body,
    };
    return encryptedBody;
  }

  Future<Map<String, dynamic>> encryptToDeviceMessage(
      List<DeviceKeys> deviceKeys,
      String type,
      Map<String, dynamic> payload) async {
    var data = <String, Map<String, Map<String, dynamic>>>{};
    // first check if any of our sessions we want to encrypt for are in the database
    if (client.database != null) {
      await getOlmSessionsForDevicesFromDatabase(
          deviceKeys.map((d) => d.curve25519Key).toList());
    }
    final deviceKeysWithoutSession = List<DeviceKeys>.from(deviceKeys);
    deviceKeysWithoutSession.removeWhere((DeviceKeys deviceKeys) =>
        olmSessions.containsKey(deviceKeys.curve25519Key) &&
        olmSessions[deviceKeys.curve25519Key].isNotEmpty);
    if (deviceKeysWithoutSession.isNotEmpty) {
      await startOutgoingOlmSessions(deviceKeysWithoutSession);
    }
    for (final device in deviceKeys) {
      if (!data.containsKey(device.userId)) {
        data[device.userId] = {};
      }
      try {
        data[device.userId][device.deviceId] =
            await encryptToDeviceMessagePayload(device, type, payload,
                getFromDb: false);
      } catch (e, s) {
        Logs().w('[LibOlm] Error encrypting to-device event', e, s);
        continue;
      }
    }
    return data;
  }

  void dispose() {
    for (final sessions in olmSessions.values) {
      for (final sess in sessions) {
        sess.dispose();
      }
    }
    _olmAccount?.free();
    _olmAccount = null;
  }
}
