/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020, 2021 Famedly GmbH
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
import 'dart:core';
import 'dart:typed_data';

import 'package:base58check/base58.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';

import 'package:matrix/encryption/encryption.dart';
import 'package:matrix/encryption/utils/base64_unpadded.dart';
import 'package:matrix/encryption/utils/ssss_cache.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:matrix/src/utils/crypto/crypto.dart' as uc;

const cacheTypes = <String>{
  EventTypes.CrossSigningSelfSigning,
  EventTypes.CrossSigningUserSigning,
  EventTypes.MegolmBackup,
};

const zeroStr =
    '\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00';
const base58Alphabet =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
const base58 = Base58Codec(base58Alphabet);
const olmRecoveryKeyPrefix = [0x8B, 0x01];
const ssssKeyLength = 32;
const pbkdf2DefaultIterations = 500000;
const pbkdf2SaltLength = 64;

/// SSSS: **S**ecure **S**ecret **S**torage and **S**haring
/// Read more about SSSS at:
/// https://matrix.org/docs/guides/implementing-more-advanced-e-2-ee-features-such-as-cross-signing#3-implementing-ssss
class SSSS {
  final Encryption encryption;

  Client get client => encryption.client;
  final pendingShareRequests = <String, _ShareRequest>{};
  final _validators = <String, FutureOr<bool> Function(String)>{};
  final _cacheCallbacks = <String, FutureOr<void> Function(String)>{};
  final Map<String, SSSSCache> _cache = <String, SSSSCache>{};

  /// Will be called when a new secret has been stored in the database
  final CachedStreamController<String> onSecretStored =
      CachedStreamController();

  SSSS(this.encryption);

  // for testing
  Future<void> clearCache() async {
    await client.database?.clearSSSSCache();
    _cache.clear();
  }

  static DerivedKeys deriveKeys(Uint8List key, String name) {
    final zerosalt = Uint8List(8);
    final prk = Hmac(sha256, zerosalt).convert(key);
    final b = Uint8List(1);
    b[0] = 1;
    final aesKey = Hmac(sha256, prk.bytes).convert(utf8.encode(name) + b);
    b[0] = 2;
    final hmacKey =
        Hmac(sha256, prk.bytes).convert(aesKey.bytes + utf8.encode(name) + b);
    return DerivedKeys(
      aesKey: Uint8List.fromList(aesKey.bytes),
      hmacKey: Uint8List.fromList(hmacKey.bytes),
    );
  }

  static Future<EncryptedContent> encryptAes(
    String data,
    Uint8List key,
    String name, [
    String? ivStr,
  ]) async {
    Uint8List iv;
    if (ivStr != null) {
      iv = base64decodeUnpadded(ivStr);
    } else {
      iv = Uint8List.fromList(uc.secureRandomBytes(16));
    }
    // we need to clear bit 63 of the IV
    iv[8] &= 0x7f;

    final keys = deriveKeys(key, name);

    final plain = Uint8List.fromList(utf8.encode(data));
    final ciphertext = await uc.aesCtr.encrypt(plain, keys.aesKey, iv);

    final hmac = Hmac(sha256, keys.hmacKey).convert(ciphertext);

    return EncryptedContent(
      iv: base64.encode(iv),
      ciphertext: base64.encode(ciphertext),
      mac: base64.encode(hmac.bytes),
    );
  }

  static Future<String> decryptAes(
    EncryptedContent data,
    Uint8List key,
    String name,
  ) async {
    final keys = deriveKeys(key, name);
    final cipher = base64decodeUnpadded(data.ciphertext);
    final hmac = base64
        .encode(Hmac(sha256, keys.hmacKey).convert(cipher).bytes)
        .replaceAll(RegExp(r'=+$'), '');
    if (hmac != data.mac.replaceAll(RegExp(r'=+$'), '')) {
      throw Exception('Bad MAC');
    }
    final decipher = await uc.aesCtr
        .encrypt(cipher, keys.aesKey, base64decodeUnpadded(data.iv));
    return String.fromCharCodes(decipher);
  }

  static Uint8List decodeRecoveryKey(String recoveryKey) {
    final result = base58.decode(recoveryKey.replaceAll(RegExp(r'\s'), ''));

    final parity = result.fold<int>(0, (a, b) => a ^ b);
    if (parity != 0) {
      throw InvalidPassphraseException('Incorrect parity');
    }

    for (var i = 0; i < olmRecoveryKeyPrefix.length; i++) {
      if (result[i] != olmRecoveryKeyPrefix[i]) {
        throw InvalidPassphraseException('Incorrect prefix');
      }
    }

    if (result.length != olmRecoveryKeyPrefix.length + ssssKeyLength + 1) {
      throw InvalidPassphraseException('Incorrect length');
    }

    return Uint8List.fromList(
      result.sublist(
        olmRecoveryKeyPrefix.length,
        olmRecoveryKeyPrefix.length + ssssKeyLength,
      ),
    );
  }

  static String encodeRecoveryKey(Uint8List recoveryKey) {
    final keyToEncode = <int>[...olmRecoveryKeyPrefix, ...recoveryKey];
    final parity = keyToEncode.fold<int>(0, (a, b) => a ^ b);
    keyToEncode.add(parity);
    // base58-encode and add a space every four chars
    return base58
        .encode(keyToEncode)
        .replaceAllMapped(RegExp(r'.{4}'), (s) => '${s.group(0)} ')
        .trim();
  }

  static Future<Uint8List> keyFromPassphrase(
    String passphrase,
    PassphraseInfo info,
  ) async {
    if (info.algorithm != AlgorithmTypes.pbkdf2) {
      throw InvalidPassphraseException('Unknown algorithm');
    }
    if (info.iterations == null) {
      throw InvalidPassphraseException('Passphrase info without iterations');
    }
    if (info.salt == null) {
      throw InvalidPassphraseException('Passphrase info without salt');
    }
    return await uc.pbkdf2(
      Uint8List.fromList(utf8.encode(passphrase)),
      Uint8List.fromList(utf8.encode(info.salt!)),
      uc.sha512,
      info.iterations!,
      info.bits ?? 256,
    );
  }

  void setValidator(String type, FutureOr<bool> Function(String) validator) {
    _validators[type] = validator;
  }

  void setCacheCallback(String type, FutureOr<void> Function(String) callback) {
    _cacheCallbacks[type] = callback;
  }

  String? get defaultKeyId => client
      .accountData[EventTypes.SecretStorageDefaultKey]
      ?.parsedSecretStorageDefaultKeyContent
      .key;

  Future<void> setDefaultKeyId(String keyId) async {
    await client.setAccountData(
      client.userID!,
      EventTypes.SecretStorageDefaultKey,
      SecretStorageDefaultKeyContent(key: keyId).toJson(),
    );
  }

  SecretStorageKeyContent? getKey(String keyId) {
    return client.accountData[EventTypes.secretStorageKey(keyId)]
        ?.parsedSecretStorageKeyContent;
  }

  bool isKeyValid(String keyId) =>
      getKey(keyId)?.algorithm == AlgorithmTypes.secretStorageV1AesHmcSha2;

  /// Creates a new secret storage key, optional encrypts it with [passphrase]
  /// and stores it in the user's `accountData`.
  Future<OpenSSSS> createKey([String? passphrase]) async {
    Uint8List privateKey;
    final content = SecretStorageKeyContent();
    if (passphrase != null) {
      // we need to derive the key off of the passphrase
      content.passphrase = PassphraseInfo(
        iterations: pbkdf2DefaultIterations,
        salt: base64.encode(uc.secureRandomBytes(pbkdf2SaltLength)),
        algorithm: AlgorithmTypes.pbkdf2,
        bits: ssssKeyLength * 8,
      );
      privateKey = await Future.value(
        client.nativeImplementations.keyFromPassphrase(
          KeyFromPassphraseArgs(
            passphrase: passphrase,
            info: content.passphrase!,
          ),
        ),
      ).timeout(Duration(seconds: 10));
    } else {
      // we need to just generate a new key from scratch
      privateKey = Uint8List.fromList(uc.secureRandomBytes(ssssKeyLength));
    }
    // now that we have the private key, let's create the iv and mac
    final encrypted = await encryptAes(zeroStr, privateKey, '');
    content.iv = encrypted.iv;
    content.mac = encrypted.mac;
    content.algorithm = AlgorithmTypes.secretStorageV1AesHmcSha2;

    const keyidByteLength = 24;

    // make sure we generate a unique key id
    final keyId = () sync* {
      for (;;) {
        yield base64.encode(uc.secureRandomBytes(keyidByteLength));
      }
    }()
        .firstWhere((keyId) => getKey(keyId) == null);

    final accountDataTypeKeyId = EventTypes.secretStorageKey(keyId);
    // noooow we set the account data

    await client.setAccountData(
      client.userID!,
      accountDataTypeKeyId,
      content.toJson(),
    );

    while (!client.accountData.containsKey(accountDataTypeKeyId)) {
      Logs().v('Waiting accountData to have $accountDataTypeKeyId');
      await client.oneShotSync();
    }

    final key = open(keyId);
    await key.setPrivateKey(privateKey);
    return key;
  }

  Future<bool> checkKey(Uint8List key, SecretStorageKeyContent info) async {
    if (info.algorithm == AlgorithmTypes.secretStorageV1AesHmcSha2) {
      if ((info.mac is String) && (info.iv is String)) {
        final encrypted = await encryptAes(zeroStr, key, '', info.iv);
        return info.mac!.replaceAll(RegExp(r'=+$'), '') ==
            encrypted.mac.replaceAll(RegExp(r'=+$'), '');
      } else {
        // no real information about the key, assume it is valid
        return true;
      }
    } else {
      throw InvalidPassphraseException('Unknown Algorithm');
    }
  }

  bool isSecret(String type) =>
      client.accountData[type]?.content['encrypted'] is Map;

  Future<String?> getCached(String type) async {
    if (client.database == null) {
      return null;
    }
    // check if it is still valid
    final keys = keyIdsFromType(type);
    if (keys == null) {
      return null;
    }
    bool isValid(SSSSCache dbEntry) =>
        keys.contains(dbEntry.keyId) &&
        dbEntry.ciphertext != null &&
        dbEntry.keyId != null &&
        client.accountData[type]?.content
                .tryGetMap<String, Object?>('encrypted')
                ?.tryGetMap<String, Object?>(dbEntry.keyId!)
                ?.tryGet<String>('ciphertext') ==
            dbEntry.ciphertext;

    final fromCache = _cache[type];
    if (fromCache != null && isValid(fromCache)) {
      return fromCache.content;
    }
    final ret = await client.database?.getSSSSCache(type);
    if (ret == null) {
      return null;
    }
    if (isValid(ret)) {
      _cache[type] = ret;
      return ret.content;
    }
    return null;
  }

  Future<String> getStored(String type, String keyId, Uint8List key) async {
    final secretInfo = client.accountData[type];
    if (secretInfo == null) {
      throw Exception('Not found');
    }
    final encryptedContent =
        secretInfo.content.tryGetMap<String, Object?>('encrypted');
    if (encryptedContent == null) {
      throw Exception('Content is not encrypted');
    }
    final enc = encryptedContent.tryGetMap<String, Object?>(keyId);
    if (enc == null) {
      throw Exception('Wrong / unknown key: $type, $keyId');
    }
    final ciphertext = enc.tryGet<String>('ciphertext');
    final iv = enc.tryGet<String>('iv');
    final mac = enc.tryGet<String>('mac');
    if (ciphertext == null || iv == null || mac == null) {
      throw Exception('Wrong types for encrypted content or missing keys.');
    }
    final encryptInfo = EncryptedContent(
      iv: iv,
      ciphertext: ciphertext,
      mac: mac,
    );
    final decrypted = await decryptAes(encryptInfo, key, type);
    final db = client.database;
    if (cacheTypes.contains(type) && db != null) {
      // cache the thing
      await db.storeSSSSCache(type, keyId, ciphertext, decrypted);
      onSecretStored.add(keyId);
      if (_cacheCallbacks.containsKey(type) && await getCached(type) == null) {
        _cacheCallbacks[type]!(decrypted);
      }
    }
    return decrypted;
  }

  Future<void> store(
    String type,
    String secret,
    String keyId,
    Uint8List key, {
    bool add = false,
  }) async {
    final encrypted = await encryptAes(secret, key, type);
    Map<String, dynamic>? content;
    if (add && client.accountData[type] != null) {
      content = client.accountData[type]!.content.copy();
      if (content['encrypted'] is! Map) {
        content['encrypted'] = <String, dynamic>{};
      }
    }
    content ??= <String, dynamic>{
      'encrypted': <String, dynamic>{},
    };
    content['encrypted'][keyId] = <String, dynamic>{
      'iv': encrypted.iv,
      'ciphertext': encrypted.ciphertext,
      'mac': encrypted.mac,
    };
    // store the thing in your account data
    await client.setAccountData(client.userID!, type, content);
    final db = client.database;
    if (cacheTypes.contains(type) && db != null) {
      // cache the thing
      await db.storeSSSSCache(type, keyId, encrypted.ciphertext, secret);
      onSecretStored.add(keyId);
      if (_cacheCallbacks.containsKey(type) && await getCached(type) == null) {
        _cacheCallbacks[type]!(secret);
      }
    }
  }

  Future<void> validateAndStripOtherKeys(
    String type,
    String secret,
    String keyId,
    Uint8List key,
  ) async {
    if (await getStored(type, keyId, key) != secret) {
      throw Exception('Secrets do not match up!');
    }
    // now remove all other keys
    final content = client.accountData[type]?.content.copy();
    if (content == null) {
      throw InvalidPassphraseException('Key has no content!');
    }
    final encryptedContent = content.tryGetMap<String, Object?>('encrypted');
    if (encryptedContent == null) {
      throw Exception('Wrong type for encrypted content!');
    }

    final otherKeys =
        Set<String>.from(encryptedContent.keys.where((k) => k != keyId));
    encryptedContent.removeWhere((k, v) => otherKeys.contains(k));
    // yes, we are paranoid...
    if (await getStored(type, keyId, key) != secret) {
      throw Exception('Secrets do not match up!');
    }
    // store the thing in your account data
    await client.setAccountData(client.userID!, type, content);
    if (cacheTypes.contains(type)) {
      // cache the thing
      final ciphertext = encryptedContent
          .tryGetMap<String, Object?>(keyId)
          ?.tryGet<String>('ciphertext');
      if (ciphertext == null) {
        throw Exception('Wrong type for ciphertext!');
      }
      await client.database?.storeSSSSCache(type, keyId, ciphertext, secret);
      onSecretStored.add(keyId);
    }
  }

  Future<void> maybeCacheAll(String keyId, Uint8List key) async {
    for (final type in cacheTypes) {
      final secret = await getCached(type);
      if (secret == null) {
        try {
          await getStored(type, keyId, key);
        } catch (_) {
          // the entry wasn't stored, just ignore it
        }
      }
    }
  }

  Future<void> maybeRequestAll([List<DeviceKeys>? devices]) async {
    for (final type in cacheTypes) {
      if (keyIdsFromType(type) != null) {
        final secret = await getCached(type);
        if (secret == null) {
          await request(type, devices);
        }
      }
    }
  }

  Future<void> request(String type, [List<DeviceKeys>? devices]) async {
    // only send to own, verified devices
    Logs().i('[SSSS] Requesting type $type...');
    if (devices == null || devices.isEmpty) {
      if (!client.userDeviceKeys.containsKey(client.userID)) {
        Logs().w('[SSSS] User does not have any devices');
        return;
      }
      devices =
          client.userDeviceKeys[client.userID]!.deviceKeys.values.toList();
    }
    devices.removeWhere(
      (DeviceKeys d) =>
          d.userId != client.userID ||
          !d.verified ||
          d.blocked ||
          d.deviceId == client.deviceID,
    );
    if (devices.isEmpty) {
      Logs().w('[SSSS] No devices');
      return;
    }
    final requestId = client.generateUniqueTransactionId();
    final request = _ShareRequest(
      requestId: requestId,
      type: type,
      devices: devices,
    );
    pendingShareRequests[requestId] = request;
    await client.sendToDeviceEncrypted(devices, EventTypes.SecretRequest, {
      'action': 'request',
      'requesting_device_id': client.deviceID,
      'request_id': requestId,
      'name': type,
    });
  }

  DateTime? _lastCacheRequest;
  bool _isPeriodicallyRequestingMissingCache = false;

  Future<void> periodicallyRequestMissingCache() async {
    if (_isPeriodicallyRequestingMissingCache ||
        (_lastCacheRequest != null &&
            DateTime.now()
                .subtract(Duration(minutes: 15))
                .isBefore(_lastCacheRequest!)) ||
        client.isUnknownSession) {
      // we are already requesting right now or we attempted to within the last 15 min
      return;
    }
    _lastCacheRequest = DateTime.now();
    _isPeriodicallyRequestingMissingCache = true;
    try {
      await maybeRequestAll();
    } finally {
      _isPeriodicallyRequestingMissingCache = false;
    }
  }

  Future<void> handleToDeviceEvent(ToDeviceEvent event) async {
    if (event.type == EventTypes.SecretRequest) {
      // got a request to share a secret
      Logs().i('[SSSS] Received sharing request...');
      if (event.sender != client.userID ||
          !client.userDeviceKeys.containsKey(client.userID)) {
        Logs().i('[SSSS] Not sent by us');
        return; // we aren't asking for it ourselves, so ignore
      }
      if (event.content['action'] != 'request') {
        Logs().i('[SSSS] it is actually a cancelation');
        return; // not actually requesting, so ignore
      }
      final device = client.userDeviceKeys[client.userID]!
          .deviceKeys[event.content['requesting_device_id']];
      if (device == null || !device.verified || device.blocked) {
        Logs().i('[SSSS] Unknown / unverified devices, ignoring');
        return; // nope....unknown or untrusted device
      }
      // alright, all seems fine...let's check if we actually have the secret they are asking for
      final type = event.content.tryGet<String>('name');
      if (type == null) {
        Logs().i('[SSSS] Wrong data type for type param, ignoring');
        return;
      }
      final secret = await getCached(type);
      if (secret == null) {
        Logs()
            .i('[SSSS] We don\'t have the secret for $type ourself, ignoring');
        return; // seems like we don't have this, either
      }
      // okay, all checks out...time to share this secret!
      Logs().i('[SSSS] Replying with secret for $type');
      await client.sendToDeviceEncrypted(
          [device],
          EventTypes.SecretSend,
          {
            'request_id': event.content['request_id'],
            'secret': secret,
          });
    } else if (event.type == EventTypes.SecretSend) {
      // receiving a secret we asked for
      Logs().i('[SSSS] Received shared secret...');
      final encryptedContent = event.encryptedContent;
      if (event.sender != client.userID ||
          !pendingShareRequests.containsKey(event.content['request_id']) ||
          encryptedContent == null) {
        Logs().i('[SSSS] Not by us or unknown request');
        return; // we have no idea what we just received
      }
      final request = pendingShareRequests[event.content['request_id']]!;
      // alright, as we received a known request id, let's check if the sender is valid
      final device = request.devices.firstWhereOrNull(
        (d) =>
            d.userId == event.sender &&
            d.curve25519Key == encryptedContent['sender_key'],
      );
      if (device == null) {
        Logs().i('[SSSS] Someone else replied?');
        return; // someone replied whom we didn't send the share request to
      }
      final secret = event.content.tryGet<String>('secret');
      if (secret == null) {
        Logs().i('[SSSS] Secret wasn\'t a string');
        return; // the secret wasn't a string....wut?
      }
      // let's validate if the secret is, well, valid
      if (_validators.containsKey(request.type) &&
          !(await _validators[request.type]!(secret))) {
        Logs().i('[SSSS] The received secret was invalid');
        return; // didn't pass the validator
      }
      pendingShareRequests.remove(request.requestId);
      if (request.start.add(Duration(minutes: 15)).isBefore(DateTime.now())) {
        Logs().i('[SSSS] Request is too far in the past');
        return; // our request is more than 15min in the past...better not trust it anymore
      }
      Logs().i('[SSSS] Secret for type ${request.type} is ok, storing it');
      final db = client.database;
      if (db != null) {
        final keyId = keyIdFromType(request.type);
        if (keyId != null) {
          final ciphertext = (client.accountData[request.type]!.content
                  .tryGetMap<String, Object?>('encrypted'))
              ?.tryGetMap<String, Object?>(keyId)
              ?.tryGet<String>('ciphertext');
          if (ciphertext == null) {
            Logs().i('[SSSS] Ciphertext is empty or not a String');
            return;
          }
          await db.storeSSSSCache(request.type, keyId, ciphertext, secret);
          if (_cacheCallbacks.containsKey(request.type)) {
            _cacheCallbacks[request.type]!(secret);
          }
          onSecretStored.add(keyId);
        }
      }
    }
  }

  Set<String>? keyIdsFromType(String type) {
    final data = client.accountData[type];
    if (data == null) {
      return null;
    }
    final contentEncrypted =
        data.content.tryGetMap<String, Object?>('encrypted');
    if (contentEncrypted != null) {
      return contentEncrypted.keys.toSet();
    }
    return null;
  }

  String? keyIdFromType(String type) {
    final keys = keyIdsFromType(type);
    if (keys == null || keys.isEmpty) {
      return null;
    }
    if (keys.contains(defaultKeyId)) {
      return defaultKeyId;
    }
    return keys.first;
  }

  OpenSSSS open([String? identifier]) {
    identifier ??= defaultKeyId;
    if (identifier == null) {
      throw Exception('Dont know what to open');
    }
    final keyToOpen = keyIdFromType(identifier) ?? identifier;
    final key = getKey(keyToOpen);
    if (key == null) {
      throw Exception('Unknown key to open');
    }
    return OpenSSSS(ssss: this, keyId: keyToOpen, keyData: key);
  }
}

class _ShareRequest {
  final String requestId;
  final String type;
  final List<DeviceKeys> devices;
  final DateTime start;

  _ShareRequest({
    required this.requestId,
    required this.type,
    required this.devices,
  }) : start = DateTime.now();
}

class EncryptedContent {
  final String iv;
  final String ciphertext;
  final String mac;

  EncryptedContent({
    required this.iv,
    required this.ciphertext,
    required this.mac,
  });
}

class DerivedKeys {
  final Uint8List aesKey;
  final Uint8List hmacKey;

  DerivedKeys({required this.aesKey, required this.hmacKey});
}

class OpenSSSS {
  final SSSS ssss;
  final String keyId;
  final SecretStorageKeyContent keyData;

  OpenSSSS({required this.ssss, required this.keyId, required this.keyData});

  Uint8List? privateKey;

  bool get isUnlocked => privateKey != null;

  bool get hasPassphrase => keyData.passphrase != null;

  String? get recoveryKey =>
      isUnlocked ? SSSS.encodeRecoveryKey(privateKey!) : null;

  Future<void> unlock({
    String? passphrase,
    String? recoveryKey,
    String? keyOrPassphrase,
    bool postUnlock = true,
  }) async {
    if (keyOrPassphrase != null) {
      try {
        await unlock(recoveryKey: keyOrPassphrase, postUnlock: postUnlock);
      } catch (_) {
        if (hasPassphrase) {
          await unlock(passphrase: keyOrPassphrase, postUnlock: postUnlock);
        } else {
          rethrow;
        }
      }
      return;
    } else if (passphrase != null) {
      if (!hasPassphrase) {
        throw InvalidPassphraseException(
          'Tried to unlock with passphrase while key does not have a passphrase',
        );
      }
      privateKey = await Future.value(
        ssss.client.nativeImplementations.keyFromPassphrase(
          KeyFromPassphraseArgs(
            passphrase: passphrase,
            info: keyData.passphrase!,
          ),
        ),
      ).timeout(Duration(seconds: 10));
    } else if (recoveryKey != null) {
      privateKey = SSSS.decodeRecoveryKey(recoveryKey);
    } else {
      throw InvalidPassphraseException('Nothing specified');
    }
    // verify the validity of the key
    if (!await ssss.checkKey(privateKey!, keyData)) {
      privateKey = null;
      throw InvalidPassphraseException('Inalid key');
    }
    if (postUnlock) {
      try {
        await _postUnlock();
      } catch (e, s) {
        Logs().e('Error during post unlock', e, s);
      }
    }
  }

  Future<void> setPrivateKey(Uint8List key) async {
    if (!await ssss.checkKey(key, keyData)) {
      throw Exception('Invalid key');
    }
    privateKey = key;
  }

  Future<String> getStored(String type) async {
    final privateKey = this.privateKey;
    if (privateKey == null) {
      throw Exception('SSSS not unlocked');
    }
    return await ssss.getStored(type, keyId, privateKey);
  }

  Future<void> store(String type, String secret, {bool add = false}) async {
    final privateKey = this.privateKey;
    if (privateKey == null) {
      throw Exception('SSSS not unlocked');
    }
    await ssss.store(type, secret, keyId, privateKey, add: add);
    while (!ssss.client.accountData.containsKey(type) ||
        !(ssss.client.accountData[type]!.content
            .tryGetMap<String, Object?>('encrypted')!
            .containsKey(keyId)) ||
        await getStored(type) != secret) {
      Logs().d('Wait for secret of $type to match in accountdata');
      await ssss.client.oneShotSync();
    }
  }

  Future<void> validateAndStripOtherKeys(String type, String secret) async {
    final privateKey = this.privateKey;
    if (privateKey == null) {
      throw Exception('SSSS not unlocked');
    }
    await ssss.validateAndStripOtherKeys(type, secret, keyId, privateKey);
  }

  Future<void> maybeCacheAll() async {
    final privateKey = this.privateKey;
    if (privateKey == null) {
      throw Exception('SSSS not unlocked');
    }
    await ssss.maybeCacheAll(keyId, privateKey);
  }

  Future<void> _postUnlock() async {
    // first try to cache all secrets that aren't cached yet
    await maybeCacheAll();
    // now try to self-sign
    if (ssss.encryption.crossSigning.enabled &&
        ssss.client.userDeviceKeys[ssss.client.userID]?.masterKey != null &&
        (ssss
                .keyIdsFromType(EventTypes.CrossSigningMasterKey)
                ?.contains(keyId) ??
            false) &&
        (ssss.client.isUnknownSession ||
            ssss.client.userDeviceKeys[ssss.client.userID]!.masterKey
                    ?.directVerified !=
                true)) {
      try {
        await ssss.encryption.crossSigning.selfSign(openSsss: this);
      } catch (e, s) {
        Logs().e('[SSSS] Failed to self-sign', e, s);
      }
    }
  }
}

class KeyFromPassphraseArgs {
  final String passphrase;
  final PassphraseInfo info;

  KeyFromPassphraseArgs({required this.passphrase, required this.info});
}

/// you would likely want to use [NativeImplementations] and
/// [Client.nativeImplementations] instead
Future<Uint8List> generateKeyFromPassphrase(KeyFromPassphraseArgs args) async {
  return await SSSS.keyFromPassphrase(args.passphrase, args.info);
}

class InvalidPassphraseException implements Exception {
  String cause;
  InvalidPassphraseException(this.cause);
}
