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

import 'package:canonical_json/canonical_json.dart';
import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/matrix_api.dart';
import 'package:olm/olm.dart' as olm;
import './encryption.dart';

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
  Map<String, List<olm.Session>> get olmSessions => _olmSessions;
  final Map<String, List<olm.Session>> _olmSessions = {};

  Future<void> init(String olmAccount) async {
    if (olmAccount == null) {
      try {
        await olm.init();
        _olmAccount = olm.Account();
        _olmAccount.create();
        if (await uploadKeys(uploadDeviceKeys: true) == false) {
          throw ('Upload key failed');
        }
      } catch (_) {
        _olmAccount?.free();
        _olmAccount = null;
      }
    } else {
      try {
        await olm.init();
        _olmAccount = olm.Account();
        _olmAccount.unpickle(client.userID, olmAccount);
      } catch (_) {
        _olmAccount?.free();
        _olmAccount = null;
      }
    }
  }

  /// Adds a signature to this json from this olm account.
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

  /// Checks the signature of a signed json object.
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
    } catch (e) {
      isValid = false;
      print('[LibOlm] Signature check failed: ' + e.toString());
    } finally {
      olmutil.free();
    }
    return isValid;
  }

  /// Generates new one time keys, signs everything and upload it to the server.
  Future<bool> uploadKeys(
      {bool uploadDeviceKeys = false, int oldKeyCount = 0}) async {
    if (!enabled) {
      return true;
    }

    // generate one-time keys
    // we generate 2/3rds of max, so that other keys people may still have can
    // still be used
    final oneTimeKeysCount =
        (_olmAccount.max_number_of_one_time_keys() * 2 / 3).floor() -
            oldKeyCount;
    _olmAccount.generate_one_time_keys(oneTimeKeysCount);
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
            'm.olm.v1.curve25519-aes-sha2',
            'm.megolm.v1.aes-sha2'
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

    final response = await client.api.uploadDeviceKeys(
      deviceKeys: uploadDeviceKeys
          ? MatrixDeviceKeys.fromJson(keysContent['device_keys'])
          : null,
      oneTimeKeys: signedOneTimeKeys,
    );
    _olmAccount.mark_keys_as_published();
    await client.database?.updateClientKeys(pickledOlmAccount, client.id);
    return response['signed_curve25519'] == oneTimeKeysCount;
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

  void storeOlmSession(String curve25519IdentityKey, olm.Session session) {
    if (client.database == null) {
      return;
    }
    if (!_olmSessions.containsKey(curve25519IdentityKey)) {
      _olmSessions[curve25519IdentityKey] = [];
    }
    final ix = _olmSessions[curve25519IdentityKey]
        .indexWhere((s) => s.session_id() == session.session_id());
    if (ix == -1) {
      // add a new session
      _olmSessions[curve25519IdentityKey].add(session);
    } else {
      // update an existing session
      _olmSessions[curve25519IdentityKey][ix] = session;
    }
    final pickle = session.pickle(client.userID);
    client.database.storeOlmSession(
        client.id, curve25519IdentityKey, session.session_id(), pickle);
  }

  ToDeviceEvent _decryptToDeviceEvent(ToDeviceEvent event) {
    if (event.type != EventTypes.Encrypted) {
      return event;
    }
    if (event.content['algorithm'] != 'm.olm.v1.curve25519-aes-sha2') {
      throw ('Unknown algorithm: ${event.content}');
    }
    if (!event.content['ciphertext'].containsKey(identityKey)) {
      throw ("The message isn't sent for this device");
    }
    String plaintext;
    final String senderKey = event.content['sender_key'];
    final String body = event.content['ciphertext'][identityKey]['body'];
    final int type = event.content['ciphertext'][identityKey]['type'];
    if (type != 0 && type != 1) {
      throw ('Unknown message type');
    }
    var existingSessions = olmSessions[senderKey];
    if (existingSessions != null) {
      for (var session in existingSessions) {
        if (type == 0 && session.matches_inbound(body) == true) {
          plaintext = session.decrypt(type, body);
          storeOlmSession(senderKey, session);
          break;
        } else if (type == 1) {
          try {
            plaintext = session.decrypt(type, body);
            storeOlmSession(senderKey, session);
            break;
          } catch (_) {
            plaintext = null;
          }
        }
      }
    }
    if (plaintext == null && type != 0) {
      return event;
    }

    if (plaintext == null) {
      var newSession = olm.Session();
      try {
        newSession.create_inbound_from(_olmAccount, senderKey, body);
        _olmAccount.remove_one_time_keys(newSession);
        client.database?.updateClientKeys(pickledOlmAccount, client.id);
        plaintext = newSession.decrypt(type, body);
        storeOlmSession(senderKey, newSession);
      } catch (_) {
        newSession?.free();
        rethrow;
      }
    }
    final Map<String, dynamic> plainContent = json.decode(plaintext);
    if (plainContent.containsKey('sender') &&
        plainContent['sender'] != event.sender) {
      throw ("Message was decrypted but sender doesn't match");
    }
    if (plainContent.containsKey('recipient') &&
        plainContent['recipient'] != client.userID) {
      throw ("Message was decrypted but recipient doesn't match");
    }
    if (plainContent['recipient_keys'] is Map &&
        plainContent['recipient_keys']['ed25519'] is String &&
        plainContent['recipient_keys']['ed25519'] != fingerprintKey) {
      throw ("Message was decrypted but own fingerprint Key doesn't match");
    }
    return ToDeviceEvent(
      content: plainContent['content'],
      encryptedContent: event.content,
      type: plainContent['type'],
      sender: event.sender,
    );
  }

  Future<ToDeviceEvent> decryptToDeviceEvent(ToDeviceEvent event) async {
    if (event.type != EventTypes.Encrypted) {
      return event;
    }
    final senderKey = event.content['sender_key'];
    final loadFromDb = () async {
      if (client.database == null) {
        return false;
      }
      final sessions = await client.database
          .getSingleOlmSessions(client.id, senderKey, client.userID);
      if (sessions.isEmpty) {
        return false; // okay, can't do anything
      }
      _olmSessions[senderKey] = sessions;
      return true;
    };
    if (!_olmSessions.containsKey(senderKey)) {
      await loadFromDb();
    }
    event = _decryptToDeviceEvent(event);
    if (event.type != EventTypes.Encrypted || !(await loadFromDb())) {
      return event;
    }
    // retry to decrypt!
    return _decryptToDeviceEvent(event);
  }

  Future<void> startOutgoingOlmSessions(List<DeviceKeys> deviceKeys) async {
    var requestingKeysFrom = <String, Map<String, String>>{};
    for (var device in deviceKeys) {
      if (requestingKeysFrom[device.userId] == null) {
        requestingKeysFrom[device.userId] = {};
      }
      requestingKeysFrom[device.userId][device.deviceId] = 'signed_curve25519';
    }

    final response =
        await client.api.requestOneTimeKeys(requestingKeysFrom, timeout: 10000);

    for (var userKeysEntry in response.oneTimeKeys.entries) {
      final userId = userKeysEntry.key;
      for (var deviceKeysEntry in userKeysEntry.value.entries) {
        final deviceId = deviceKeysEntry.key;
        final fingerprintKey =
            client.userDeviceKeys[userId].deviceKeys[deviceId].ed25519Key;
        final identityKey =
            client.userDeviceKeys[userId].deviceKeys[deviceId].curve25519Key;
        for (Map<String, dynamic> deviceKey in deviceKeysEntry.value.values) {
          if (!checkJsonSignature(
              fingerprintKey, deviceKey, userId, deviceId)) {
            continue;
          }
          try {
            var session = olm.Session();
            session.create_outbound(_olmAccount, identityKey, deviceKey['key']);
            await storeOlmSession(identityKey, session);
          } catch (e) {
            print('[LibOlm] Could not create new outbound olm session: ' +
                e.toString());
          }
        }
      }
    }
  }

  Future<Map<String, dynamic>> encryptToDeviceMessagePayload(
      DeviceKeys device, String type, Map<String, dynamic> payload) async {
    var sess = olmSessions[device.curve25519Key];
    if (sess == null || sess.isEmpty) {
      final sessions = await client.database
          .getSingleOlmSessions(client.id, device.curve25519Key, client.userID);
      if (sessions.isEmpty) {
        throw ('No olm session found');
      }
      sess = _olmSessions[device.curve25519Key] = sessions;
    }
    sess.sort((a, b) => a.session_id().compareTo(b.session_id()));
    final fullPayload = {
      'type': type,
      'content': payload,
      'sender': client.userID,
      'keys': {'ed25519': fingerprintKey},
      'recipient': device.userId,
      'recipient_keys': {'ed25519': device.ed25519Key},
    };
    final encryptResult = sess.first.encrypt(json.encode(fullPayload));
    storeOlmSession(device.curve25519Key, sess.first);
    final encryptedBody = <String, dynamic>{
      'algorithm': 'm.olm.v1.curve25519-aes-sha2',
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
      for (final device in deviceKeys) {
        if (!olmSessions.containsKey(device.curve25519Key)) {
          final sessions = await client.database.getSingleOlmSessions(
              client.id, device.curve25519Key, client.userID);
          if (sessions.isNotEmpty) {
            _olmSessions[device.curve25519Key] = sessions;
          }
        }
      }
    }
    final deviceKeysWithoutSession = List<DeviceKeys>.from(deviceKeys);
    deviceKeysWithoutSession.removeWhere((DeviceKeys deviceKeys) =>
        olmSessions.containsKey(deviceKeys.curve25519Key));
    if (deviceKeysWithoutSession.isNotEmpty) {
      await startOutgoingOlmSessions(deviceKeysWithoutSession);
    }
    for (final device in deviceKeys) {
      if (!data.containsKey(device.userId)) {
        data[device.userId] = {};
      }
      try {
        data[device.userId][device.deviceId] =
            await encryptToDeviceMessagePayload(device, type, payload);
      } catch (e) {
        print('[LibOlm] Error encrypting to-device event: ' + e.toString());
        continue;
      }
    }
    return data;
  }

  void dispose() {
    for (final sessions in olmSessions.values) {
      for (final sess in sessions) {
        sess.free();
      }
    }
    _olmAccount?.free();
    _olmAccount = null;
  }
}
