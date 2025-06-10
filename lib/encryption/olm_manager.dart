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

import 'package:async/async.dart';
import 'package:canonical_json/canonical_json.dart';
import 'package:collection/collection.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:matrix/encryption/encryption.dart';
import 'package:matrix/encryption/utils/json_signature_check_extension.dart';
import 'package:matrix/encryption/utils/olm_session.dart';
import 'package:matrix/encryption/utils/pickle_key.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/msc_extensions/msc_3814_dehydrated_devices/api.dart';
import 'package:matrix/src/utils/run_benchmarked.dart';
import 'package:matrix/src/utils/run_in_root.dart';

class OlmManager {
  final Encryption encryption;
  Client get client => encryption.client;
  vod.Account? _olmAccount;
  String? ourDeviceId;

  /// Returns the base64 encoded keys to store them in a store.
  /// This String should **never** leave the device!
  String? get pickledOlmAccount {
    return enabled
        ? _olmAccount!.toPickleEncrypted(client.userID!.toPickleKey())
        : null;
  }

  String? get fingerprintKey =>
      enabled ? _olmAccount!.identityKeys.ed25519.toBase64() : null;
  String? get identityKey =>
      enabled ? _olmAccount!.identityKeys.curve25519.toBase64() : null;

  String? pickleOlmAccountWithKey(String key) =>
      enabled ? _olmAccount!.toPickleEncrypted(key.toPickleKey()) : null;

  bool get enabled => _olmAccount != null;

  OlmManager(this.encryption);

  /// A map from Curve25519 identity keys to existing olm sessions.
  Map<String, List<OlmSession>> get olmSessions => _olmSessions;
  final Map<String, List<OlmSession>> _olmSessions = {};

  // NOTE(Nico): On initial login we pass null to create a new account
  Future<void> init({
    String? olmAccount,
    required String? deviceId,
    String? pickleKey,
    String? dehydratedDeviceAlgorithm,
  }) async {
    ourDeviceId = deviceId;
    if (olmAccount == null) {
      _olmAccount = vod.Account();
      if (!await uploadKeys(
        uploadDeviceKeys: true,
        updateDatabase: false,
        dehydratedDeviceAlgorithm: dehydratedDeviceAlgorithm,
        dehydratedDevicePickleKey:
            dehydratedDeviceAlgorithm != null ? pickleKey : null,
      )) {
        throw ('Upload key failed');
      }
    } else {
      try {
        _olmAccount = vod.Account.fromPickleEncrypted(
          pickle: olmAccount,
          pickleKey: (pickleKey ?? client.userID!).toPickleKey(),
        );
      } catch (e) {
        Logs().d(
          'Unable to unpickle account in vodozemac format. Trying Olm format...',
          e,
        );
        _olmAccount = vod.Account.fromOlmPickleEncrypted(
          pickle: olmAccount,
          pickleKey: utf8.encode(pickleKey ?? client.userID!),
        );
      }
    }
  }

  /// Adds a signature to this json from this olm account and returns the signed
  /// json.
  Map<String, dynamic> signJson(Map<String, dynamic> payload) {
    if (!enabled) throw ('Encryption is disabled');
    final Map<String, dynamic>? unsigned = payload['unsigned'];
    final Map<String, dynamic>? signatures = payload['signatures'];
    payload.remove('unsigned');
    payload.remove('signatures');
    final canonical = canonicalJson.encode(payload);
    final signature = _olmAccount!.sign(String.fromCharCodes(canonical));
    if (signatures != null) {
      payload['signatures'] = signatures;
    } else {
      payload['signatures'] = <String, dynamic>{};
    }
    if (!payload['signatures'].containsKey(client.userID)) {
      payload['signatures'][client.userID] = <String, dynamic>{};
    }
    payload['signatures'][client.userID]['ed25519:$ourDeviceId'] =
        signature.toBase64();
    if (unsigned != null) {
      payload['unsigned'] = unsigned;
    }
    return payload;
  }

  String signString(String s) {
    return _olmAccount!.sign(s).toBase64();
  }

  bool _uploadKeysLock = false;
  CancelableOperation<Map<String, int>>? currentUpload;

  int? get maxNumberOfOneTimeKeys => _olmAccount?.maxNumberOfOneTimeKeys;

  /// Generates new one time keys, signs everything and upload it to the server.
  /// If `retry` is > 0, the request will be retried with new OTKs on upload failure.
  Future<bool> uploadKeys({
    bool uploadDeviceKeys = false,
    int? oldKeyCount = 0,
    bool updateDatabase = true,
    bool? unusedFallbackKey = false,
    String? dehydratedDeviceAlgorithm,
    String? dehydratedDevicePickleKey,
    int retry = 1,
  }) async {
    final olmAccount = _olmAccount;
    if (olmAccount == null) {
      return true;
    }

    if (_uploadKeysLock) {
      return false;
    }
    _uploadKeysLock = true;

    final signedOneTimeKeys = <String, Map<String, Object?>>{};
    try {
      int? uploadedOneTimeKeysCount;
      if (oldKeyCount != null) {
        // check if we have OTKs that still need uploading. If we do, we don't try to generate new ones,
        // instead we try to upload the old ones first
        final oldOTKsNeedingUpload = olmAccount.oneTimeKeys.length;

        // generate one-time keys
        // we generate 2/3rds of max, so that other keys people may still have can
        // still be used
        final oneTimeKeysCount =
            (olmAccount.maxNumberOfOneTimeKeys * 2 / 3).floor() -
                oldKeyCount -
                oldOTKsNeedingUpload;
        if (oneTimeKeysCount > 0) {
          olmAccount.generateOneTimeKeys(oneTimeKeysCount);
        }
        uploadedOneTimeKeysCount = oneTimeKeysCount + oldOTKsNeedingUpload;
      }

      if (unusedFallbackKey == false) {
        // we don't have an unused fallback key uploaded....so let's change that!
        olmAccount.generateFallbackKey();
      }

      // we save the generated OTKs into the database.
      // in case the app gets killed during upload or the upload fails due to bad network
      // we can still re-try later
      if (updateDatabase) {
        await encryption.olmDatabase?.updateClientKeys(pickledOlmAccount!);
      }

      // and now generate the payload to upload
      var deviceKeys = <String, dynamic>{
        'user_id': client.userID,
        'device_id': ourDeviceId,
        'algorithms': [
          AlgorithmTypes.olmV1Curve25519AesSha2,
          AlgorithmTypes.megolmV1AesSha2,
        ],
        'keys': <String, dynamic>{},
      };

      if (uploadDeviceKeys) {
        final keys = olmAccount.identityKeys;
        deviceKeys['keys']['curve25519:$ourDeviceId'] =
            keys.curve25519.toBase64();
        deviceKeys['keys']['ed25519:$ourDeviceId'] = keys.ed25519.toBase64();
        deviceKeys = signJson(deviceKeys);
      }

      // now sign all the one-time keys
      for (final entry in olmAccount.oneTimeKeys.entries) {
        final key = entry.key;
        final value = entry.value.toBase64();
        signedOneTimeKeys['signed_curve25519:$key'] = signJson({
          'key': value,
        });
      }

      final signedFallbackKeys = <String, dynamic>{};
      final fallbackKey = olmAccount.fallbackKey;
      // now sign all the fallback keys
      for (final entry in fallbackKey.entries) {
        final key = entry.key;
        final value = entry.value.toBase64();
        signedFallbackKeys['signed_curve25519:$key'] = signJson({
          'key': value,
          'fallback': true,
        });
      }

      if (signedFallbackKeys.isEmpty &&
          signedOneTimeKeys.isEmpty &&
          !uploadDeviceKeys) {
        _uploadKeysLock = false;
        return true;
      }

      // Workaround: Make sure we stop if we got logged out in the meantime.
      if (!client.isLogged()) return true;

      if (ourDeviceId != client.deviceID) {
        if (dehydratedDeviceAlgorithm == null ||
            dehydratedDevicePickleKey == null) {
          throw Exception(
            'You need to provide both the pickle key and the algorithm to use dehydrated devices!',
          );
        }

        await client.uploadDehydratedDevice(
          deviceId: ourDeviceId!,
          initialDeviceDisplayName: client.dehydratedDeviceDisplayName,
          deviceKeys:
              uploadDeviceKeys ? MatrixDeviceKeys.fromJson(deviceKeys) : null,
          oneTimeKeys: signedOneTimeKeys,
          fallbackKeys: signedFallbackKeys,
          deviceData: {
            'algorithm': dehydratedDeviceAlgorithm,
            'device': encryption.olmManager
                .pickleOlmAccountWithKey(dehydratedDevicePickleKey),
          },
        );
        return true;
      }
      final currentUpload = this.currentUpload = CancelableOperation.fromFuture(
        client.uploadKeys(
          deviceKeys:
              uploadDeviceKeys ? MatrixDeviceKeys.fromJson(deviceKeys) : null,
          oneTimeKeys: signedOneTimeKeys,
          fallbackKeys: signedFallbackKeys,
        ),
      );
      final response = await currentUpload.valueOrCancellation();
      if (response == null) {
        _uploadKeysLock = false;
        return false;
      }

      // mark the OTKs as published and save that to datbase
      olmAccount.markKeysAsPublished();
      if (updateDatabase) {
        await encryption.olmDatabase?.updateClientKeys(pickledOlmAccount!);
      }
      return (uploadedOneTimeKeysCount != null &&
              response['signed_curve25519'] == uploadedOneTimeKeysCount) ||
          uploadedOneTimeKeysCount == null;
    } on MatrixException catch (exception) {
      _uploadKeysLock = false;

      // we failed to upload the keys. If we only tried to upload one time keys, try to recover by removing them and generating new ones.
      if (!uploadDeviceKeys &&
          unusedFallbackKey != false &&
          retry > 0 &&
          dehydratedDeviceAlgorithm != null &&
          signedOneTimeKeys.isNotEmpty &&
          exception.error == MatrixError.M_UNKNOWN) {
        Logs().w('Rotating otks because upload failed', exception);
        for (final otk in signedOneTimeKeys.values) {
          final key = otk.tryGet<String>('key');
          if (key != null) {
            olmAccount.removeOneTimeKey(key);
          }
        }

        await uploadKeys(
          uploadDeviceKeys: uploadDeviceKeys,
          oldKeyCount: oldKeyCount,
          updateDatabase: updateDatabase,
          unusedFallbackKey: unusedFallbackKey,
          retry: retry - 1,
        );
      }
    } finally {
      _uploadKeysLock = false;
    }

    return false;
  }

  final _otkUpdateDedup = AsyncCache<void>.ephemeral();

  Future<void> handleDeviceOneTimeKeysCount(
    Map<String, int>? countJson,
    List<String>? unusedFallbackKeyTypes,
  ) async {
    if (!enabled) {
      return;
    }

    await _otkUpdateDedup.fetch(
      () => runBenchmarked('handleOtkUpdate', () async {
        // Check if there are at least half of max_number_of_one_time_keys left on the server
        // and generate and upload more if not.

        // If the server did not send us a count, assume it is 0
        final keyCount = countJson?.tryGet<int>('signed_curve25519') ?? 0;

        // If the server does not support fallback keys, it will not tell us about them.
        // If the server supports them but has no key, upload a new one.
        var unusedFallbackKey = true;
        if (unusedFallbackKeyTypes?.contains('signed_curve25519') == false) {
          unusedFallbackKey = false;
        }

        // fixup accidental too many uploads. We delete only one of them so that the server has time to update the counts and because we will get rate limited anyway.
        if (keyCount > _olmAccount!.maxNumberOfOneTimeKeys) {
          final requestingKeysFrom = {
            client.userID!: {ourDeviceId!: 'signed_curve25519'},
          };
          await client.claimKeys(requestingKeysFrom, timeout: 10000);
        }

        // Only upload keys if they are less than half of the max or we have no unused fallback key
        if (keyCount < (_olmAccount!.maxNumberOfOneTimeKeys / 2) ||
            !unusedFallbackKey) {
          await uploadKeys(
            oldKeyCount: keyCount < (_olmAccount!.maxNumberOfOneTimeKeys / 2)
                ? keyCount
                : null,
            unusedFallbackKey: unusedFallbackKey,
          );
        }
      }),
    );
  }

  Future<void> storeOlmSession(OlmSession session) async {
    if (session.sessionId == null || session.pickledSession == null) {
      return;
    }

    _olmSessions[session.identityKey] ??= <OlmSession>[];
    final ix = _olmSessions[session.identityKey]!
        .indexWhere((s) => s.sessionId == session.sessionId);
    if (ix == -1) {
      // add a new session
      _olmSessions[session.identityKey]!.add(session);
    } else {
      // update an existing session
      _olmSessions[session.identityKey]![ix] = session;
    }
    await encryption.olmDatabase?.storeOlmSession(
      session.identityKey,
      session.sessionId!,
      session.pickledSession!,
      session.lastReceived?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<ToDeviceEvent> _decryptToDeviceEvent(ToDeviceEvent event) async {
    if (event.type != EventTypes.Encrypted) {
      return event;
    }
    final content = event.parsedRoomEncryptedContent;
    if (content.algorithm != AlgorithmTypes.olmV1Curve25519AesSha2) {
      throw DecryptException(DecryptException.unknownAlgorithm);
    }
    if (content.ciphertextOlm == null ||
        !content.ciphertextOlm!.containsKey(identityKey)) {
      throw DecryptException(DecryptException.isntSentForThisDevice);
    }
    String? plaintext;
    final senderKey = content.senderKey;
    final body = content.ciphertextOlm![identityKey]!.body;
    final type = content.ciphertextOlm![identityKey]!.type;
    if (type != 0 && type != 1) {
      throw DecryptException(DecryptException.unknownMessageType);
    }
    final device = client.userDeviceKeys[event.sender]?.deviceKeys.values
        .firstWhereOrNull((d) => d.curve25519Key == senderKey);
    final existingSessions = olmSessions[senderKey];
    Future<void> updateSessionUsage([OlmSession? session]) async {
      try {
        if (session != null) {
          session.lastReceived = DateTime.now();
          await storeOlmSession(session);
        }
        if (device != null) {
          device.lastActive = DateTime.now();
          await encryption.olmDatabase?.setLastActiveUserDeviceKey(
            device.lastActive.millisecondsSinceEpoch,
            device.userId,
            device.deviceId!,
          );
        }
      } catch (e, s) {
        Logs().e('Error while updating olm session timestamp', e, s);
      }
    }

    if (existingSessions != null) {
      for (final session in existingSessions) {
        if (session.session == null) {
          continue;
        }

        try {
          plaintext = session.session!.decrypt(
            messageType: type,
            ciphertext: body,
          );
          await updateSessionUsage(session);
          break;
        } catch (_) {
          plaintext = null;
        }
      }
    }
    if (plaintext == null && type != 0) {
      throw DecryptException(DecryptException.unableToDecryptWithAnyOlmSession);
    }

    if (plaintext == null) {
      try {
        final result = _olmAccount!.createInboundSession(
          theirIdentityKey: vod.Curve25519PublicKey.fromBase64(senderKey),
          preKeyMessageBase64: body,
        );
        plaintext = result.plaintext;
        final newSession = result.session;

        await encryption.olmDatabase?.updateClientKeys(pickledOlmAccount!);

        await storeOlmSession(
          OlmSession(
            key: client.userID!,
            identityKey: senderKey,
            sessionId: newSession.sessionId,
            session: newSession,
            lastReceived: DateTime.now(),
          ),
        );
        await updateSessionUsage();
      } catch (e) {
        throw DecryptException(DecryptException.decryptionFailed, e.toString());
      }
    }
    final Map<String, dynamic> plainContent = json.decode(plaintext);
    if (plainContent['sender'] != event.sender) {
      throw DecryptException(DecryptException.senderDoesntMatch);
    }
    if (plainContent['recipient'] != client.userID) {
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
    final olmSessions =
        await encryption.olmDatabase?.getOlmSessions(senderKey, client.userID!);
    return olmSessions?.where((sess) => sess.isValid).toList() ?? [];
  }

  Future<void> getOlmSessionsForDevicesFromDatabase(
    List<String> senderKeys,
  ) async {
    final rows = await encryption.olmDatabase?.getOlmSessionsForDevices(
      senderKeys,
      client.userID!,
    );
    final res = <String, List<OlmSession>>{};
    for (final sess in rows ?? []) {
      res[sess.identityKey] ??= <OlmSession>[];
      if (sess.isValid) {
        res[sess.identityKey]!.add(sess);
      }
    }
    for (final entry in res.entries) {
      _olmSessions[entry.key] = entry.value;
    }
  }

  Future<List<OlmSession>> getOlmSessions(
    String senderKey, {
    bool getFromDb = true,
  }) async {
    var sess = olmSessions[senderKey];
    if ((getFromDb) && (sess == null || sess.isEmpty)) {
      final sessions = await getOlmSessionsFromDatabase(senderKey);
      if (sessions.isEmpty) {
        return [];
      }
      sess = _olmSessions[senderKey] = sessions;
    }
    if (sess == null) {
      return [];
    }
    sess.sort(
      (a, b) => a.lastReceived == b.lastReceived
          ? (a.sessionId ?? '').compareTo(b.sessionId ?? '')
          : (b.lastReceived ?? DateTime(0))
              .compareTo(a.lastReceived ?? DateTime(0)),
    );
    return sess;
  }

  final Map<String, DateTime> _restoredOlmSessionsTime = {};

  Future<void> restoreOlmSession(String userId, String senderKey) async {
    if (!client.userDeviceKeys.containsKey(userId)) {
      return;
    }
    final device = client.userDeviceKeys[userId]!.deviceKeys.values
        .firstWhereOrNull((d) => d.curve25519Key == senderKey);
    if (device == null) {
      return;
    }
    // per device only one olm session per hour should be restored
    final mapKey = '$userId;$senderKey';
    if (_restoredOlmSessionsTime.containsKey(mapKey) &&
        DateTime.now()
            .subtract(Duration(hours: 1))
            .isBefore(_restoredOlmSessionsTime[mapKey]!)) {
      Logs().w(
        '[OlmManager] Skipping restore session, one was restored in the past hour',
      );
      return;
    }
    _restoredOlmSessionsTime[mapKey] = DateTime.now();
    await startOutgoingOlmSessions([device]);
    await client.sendToDeviceEncrypted([device], EventTypes.Dummy, {});
  }

  Future<ToDeviceEvent> decryptToDeviceEvent(ToDeviceEvent event) async {
    if (event.type != EventTypes.Encrypted) {
      return event;
    }
    final senderKey = event.parsedRoomEncryptedContent.senderKey;
    Future<bool> loadFromDb() async {
      final sessions = await getOlmSessions(senderKey);
      return sessions.isNotEmpty;
    }

    if (!_olmSessions.containsKey(senderKey)) {
      await loadFromDb();
    }
    try {
      event = await _decryptToDeviceEvent(event);
      if (event.type != EventTypes.Encrypted || !(await loadFromDb())) {
        return event;
      }
      // retry to decrypt!
      return _decryptToDeviceEvent(event);
    } catch (_) {
      // okay, the thing errored while decrypting. It is safe to assume that the olm session is corrupt and we should generate a new one
      runInRoot(() => restoreOlmSession(event.senderId, senderKey));

      rethrow;
    }
  }

  Future<void> startOutgoingOlmSessions(List<DeviceKeys> deviceKeys) async {
    Logs().v(
      '[OlmManager] Starting session with ${deviceKeys.length} devices...',
    );
    final requestingKeysFrom = <String, Map<String, String>>{};
    for (final device in deviceKeys) {
      if (requestingKeysFrom[device.userId] == null) {
        requestingKeysFrom[device.userId] = {};
      }
      requestingKeysFrom[device.userId]![device.deviceId!] =
          'signed_curve25519';
    }

    final response = await client.claimKeys(requestingKeysFrom, timeout: 10000);

    for (final userKeysEntry in response.oneTimeKeys.entries) {
      final userId = userKeysEntry.key;
      for (final deviceKeysEntry in userKeysEntry.value.entries) {
        final deviceId = deviceKeysEntry.key;
        final fingerprintKey =
            client.userDeviceKeys[userId]!.deviceKeys[deviceId]!.ed25519Key;
        final identityKey =
            client.userDeviceKeys[userId]!.deviceKeys[deviceId]!.curve25519Key;
        for (final deviceKey in deviceKeysEntry.value.values) {
          if (fingerprintKey == null ||
              identityKey == null ||
              deviceKey is! Map<String, Object?> ||
              !deviceKey.checkJsonSignature(fingerprintKey, userId, deviceId) ||
              deviceKey['key'] is! String) {
            Logs().w(
              'Skipping invalid device key from $userId:$deviceId',
              deviceKey,
            );
            continue;
          }
          Logs().v('[OlmManager] Starting session with $userId:$deviceId');
          try {
            final session = _olmAccount!.createOutboundSession(
              identityKey: vod.Curve25519PublicKey.fromBase64(identityKey),
              oneTimeKey: vod.Curve25519PublicKey.fromBase64(
                deviceKey.tryGet<String>('key')!,
              ),
            );

            await storeOlmSession(
              OlmSession(
                key: client.userID!,
                identityKey: identityKey,
                sessionId: session.sessionId,
                session: session,
                lastReceived:
                    DateTime.now(), // we want to use a newly created session
              ),
            );
          } catch (e, s) {
            Logs().e(
              '[Vodozemac] Could not create new outbound olm session',
              e,
              s,
            );
          }
        }
      }
    }
  }

  /// Encryptes a ToDeviceMessage for the given device with an existing
  /// olm session.
  /// Throws `NoOlmSessionFoundException` if there is no olm session with this
  /// device and none could be created.
  Future<Map<String, dynamic>> encryptToDeviceMessagePayload(
    DeviceKeys device,
    String type,
    Map<String, dynamic> payload, {
    bool getFromDb = true,
  }) async {
    final sess =
        await getOlmSessions(device.curve25519Key!, getFromDb: getFromDb);
    if (sess.isEmpty) {
      throw NoOlmSessionFoundException(device);
    }
    final fullPayload = {
      'type': type,
      'content': payload,
      'sender': client.userID,
      'keys': {'ed25519': fingerprintKey},
      'recipient': device.userId,
      'recipient_keys': {'ed25519': device.ed25519Key},
    };
    final encryptResult = sess.first.session!.encrypt(json.encode(fullPayload));
    await storeOlmSession(sess.first);
    if (encryption.olmDatabase != null) {
      try {
        await encryption.olmDatabase?.setLastSentMessageUserDeviceKey(
          json.encode({
            'type': type,
            'content': payload,
          }),
          device.userId,
          device.deviceId!,
        );
      } catch (e, s) {
        // we can ignore this error, since it would just make us use a different olm session possibly
        Logs().w('Error while updating olm usage timestamp', e, s);
      }
    }
    final encryptedBody = <String, dynamic>{
      'algorithm': AlgorithmTypes.olmV1Curve25519AesSha2,
      'sender_key': identityKey,
      'ciphertext': <String, dynamic>{},
    };
    encryptedBody['ciphertext'][device.curve25519Key] = {
      'type': encryptResult.messageType,
      'body': encryptResult.ciphertext,
    };
    return encryptedBody;
  }

  Future<Map<String, Map<String, Map<String, dynamic>>>> encryptToDeviceMessage(
    List<DeviceKeys> deviceKeys,
    String type,
    Map<String, dynamic> payload,
  ) async {
    final data = <String, Map<String, Map<String, dynamic>>>{};
    // first check if any of our sessions we want to encrypt for are in the database
    if (encryption.olmDatabase != null) {
      await getOlmSessionsForDevicesFromDatabase(
        deviceKeys.map((d) => d.curve25519Key!).toList(),
      );
    }
    final deviceKeysWithoutSession = List<DeviceKeys>.from(deviceKeys);
    deviceKeysWithoutSession.removeWhere(
      (DeviceKeys deviceKeys) =>
          olmSessions[deviceKeys.curve25519Key]?.isNotEmpty ?? false,
    );
    if (deviceKeysWithoutSession.isNotEmpty) {
      await startOutgoingOlmSessions(deviceKeysWithoutSession);
    }
    for (final device in deviceKeys) {
      final userData = data[device.userId] ??= {};
      try {
        userData[device.deviceId!] = await encryptToDeviceMessagePayload(
          device,
          type,
          payload,
          getFromDb: false,
        );
      } on NoOlmSessionFoundException catch (e) {
        Logs().d('[Vodozemac] Error encrypting to-device event', e);
        continue;
      } catch (e, s) {
        Logs().wtf('[Vodozemac] Error encrypting to-device event', e, s);
        continue;
      }
    }
    return data;
  }

  Future<void> handleToDeviceEvent(ToDeviceEvent event) async {
    if (event.type == EventTypes.Dummy) {
      // We received an encrypted m.dummy. This means that the other end was not able to
      // decrypt our last message. So, we re-send it.
      final encryptedContent = event.encryptedContent;
      if (encryptedContent == null || encryption.olmDatabase == null) {
        return;
      }
      final device = client.getUserDeviceKeysByCurve25519Key(
        encryptedContent.tryGet<String>('sender_key') ?? '',
      );
      if (device == null) {
        return; // device not found
      }
      Logs().v(
        '[OlmManager] Device ${device.userId}:${device.deviceId} generated a new olm session, replaying last sent message...',
      );
      final lastSentMessageRes = await encryption.olmDatabase
          ?.getLastSentMessageUserDeviceKey(device.userId, device.deviceId!);
      if (lastSentMessageRes == null ||
          lastSentMessageRes.isEmpty ||
          lastSentMessageRes.first.isEmpty) {
        return;
      }
      final lastSentMessage = json.decode(lastSentMessageRes.first);
      // We do *not* want to re-play m.dummy events, as they hold no value except of saying
      // what olm session is the most recent one. In fact, if we *do* replay them, then
      // we can easily land in an infinite ping-pong trap!
      if (lastSentMessage['type'] != EventTypes.Dummy) {
        // okay, time to send the message!
        await client.sendToDeviceEncrypted(
          [device],
          lastSentMessage['type'],
          lastSentMessage['content'],
        );
      }
    }
  }

  Future<void> dispose() async {
    await currentUpload?.cancel();
  }
}

class NoOlmSessionFoundException implements Exception {
  final DeviceKeys device;

  NoOlmSessionFoundException(this.device);

  @override
  String toString() =>
      'No olm session found for ${device.userId}:${device.deviceId}';
}
