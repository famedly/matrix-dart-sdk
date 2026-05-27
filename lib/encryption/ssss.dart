// SPDX-FileCopyrightText: 2019-Present, 2020, 2021 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:typed_data';

import 'package:base58check/base58.dart';
import 'package:collection/collection.dart';
import 'package:vodozemac/vodozemac.dart';

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
    await client.database.clearSSSSCache();
    _cache.clear();
  }

  static DerivedKeys deriveKeys(Uint8List key, String name) {
    final zerosalt = Uint8List(8);
    final prk = CryptoUtils.hmac(key: zerosalt, input: key);
    final b = Uint8List(1);
    b[0] = 1;
    final aesKey = CryptoUtils.hmac(key: prk, input: utf8.encode(name) + b);
    b[0] = 2;
    final hmacKey = CryptoUtils.hmac(
      key: prk,
      input: aesKey + utf8.encode(name) + b,
    );
    return DerivedKeys(
      aesKey: Uint8List.fromList(aesKey),
      hmacKey: Uint8List.fromList(hmacKey),
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
    final ciphertext =
        CryptoUtils.aesCtr(input: plain, key: keys.aesKey, iv: iv);

    final hmac = CryptoUtils.hmac(key: keys.hmacKey, input: ciphertext);

    return EncryptedContent(
      iv: base64.encode(iv),
      ciphertext: base64.encode(ciphertext),
      mac: base64.encode(hmac),
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
        .encode(CryptoUtils.hmac(key: keys.hmacKey, input: cipher))
        .replaceAll(RegExp(r'=+$'), '');
    if (hmac != data.mac.replaceAll(RegExp(r'=+$'), '')) {
      throw Exception('Bad MAC');
    }
    final decipher = CryptoUtils.aesCtr(
      input: cipher,
      key: keys.aesKey,
      iv: base64decodeUnpadded(data.iv),
    );
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

  /// Whether [input] looks like an Olm/SSSS recovery key (not a passphrase).
  static bool looksLikeRecoveryKey(String input) {
    final cleaned = input.replaceAll(RegExp(r'\s+'), '');
    return cleaned.length == 48 && cleaned.startsWith('Es');
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
    return CryptoUtils.pbkdf2(
      passphrase: Uint8List.fromList(utf8.encode(passphrase)),
      salt: Uint8List.fromList(utf8.encode(info.salt!)),
      iterations: info.iterations!,
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
    await _setAccountDataAndWaitForSync(
      EventTypes.SecretStorageDefaultKey,
      SecretStorageDefaultKeyContent(key: keyId).toJson(),
    );
  }

  /// PUTs account data, then waits until [/sync] has applied the same payload so
  /// [Client.accountData] and the DB stay aligned (both are updated in
  /// [Client]'s sync handler). [MatrixApi.setAccountData] alone does not touch
  /// local state; mirroring the PUT locally would race concurrent sync updates.
  Future<void> _setAccountDataAndWaitForSync(
    String type,
    Map<String, Object?> content,
  ) async {
    final expected = content.copy();
    await client.setAccountData(client.userID!, type, content);
    await _waitForAccountDataFromSync(type, expected);
  }

  Future<void> _waitForAccountDataFromSync(
    String type,
    Map<String, Object?> expectedContent,
  ) async {
    bool matchesExpected() {
      final ev = client.accountData[type];
      if (ev == null) return false;
      return const DeepCollectionEquality().equals(ev.content, expectedContent);
    }

    if (matchesExpected()) return;

    final completer = Completer<void>();
    final subscription = client.onAccountData.stream.listen((event) {
      if (event.type == type && matchesExpected()) {
        if (!completer.isCompleted) completer.complete();
      }
    });
    try {
      if (matchesExpected()) return;
      await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw TimeoutException(
          'Timed out waiting for account data "$type" from sync after '
          'setAccountData.',
        ),
      );
    } finally {
      await subscription.cancel();
    }
  }

  SecretStorageKeyContent? getKey(String keyId) {
    return client.accountData[EventTypes.secretStorageKey(keyId)]
        ?.parsedSecretStorageKeyContent;
  }

  bool isKeyValid(String keyId) =>
      getKey(keyId)?.algorithm == AlgorithmTypes.secretStorageV1AesHmcSha2;

  /// Creates a new secret storage key, optional encrypts it with [passphrase]
  /// and stores it in the user's `accountData`.
  Future<OpenSSSS> createKey([String? passphrase, String? name]) async {
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
    content.name = name;

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

    await _setAccountDataAndWaitForSync(accountDataTypeKeyId, content.toJson());

    final key = open(keyId);
    await key.setPrivateKey(privateKey);
    return key;
  }

  Future<bool> checkKey(Uint8List key, SecretStorageKeyContent info) async {
    if (info.algorithm == AlgorithmTypes.secretStorageV1AesHmcSha2) {
      if ((info.mac is String) && (info.iv is String)) {
        return client.nativeImplementations.checkSecretStorageKey(
          CheckSecretStorageKeyArgs(
            key: key,
            iv: info.iv!,
            mac: info.mac!,
          ),
        );
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
    final ret = await client.database.getSSSSCache(type);
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
    if (cacheTypes.contains(type)) {
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
    await _setAccountDataAndWaitForSync(
      type,
      Map<String, Object?>.from(content),
    );
    final db = client.database;
    if (cacheTypes.contains(type)) {
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
    Uint8List key, {
    bool isDefaultKey = true,
  }) async {
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

    final defaultKeyId = this.defaultKeyId;
    final otherKeys = Set<String>.from(
      encryptedContent.keys.where(
        (k) => isDefaultKey || defaultKeyId == null
            ? k != keyId
            : k != keyId && k != defaultKeyId,
      ),
    );
    encryptedContent.removeWhere((k, v) => otherKeys.contains(k));
    content['encrypted'] = encryptedContent;
    // Yes, we are paranoid...
    if (await getStored(type, keyId, key) != secret) {
      throw Exception('Secrets do not match up!');
    }
    await _setAccountDataAndWaitForSync(type, content);
    if (cacheTypes.contains(type)) {
      final ciphertext = encryptedContent
          .tryGetMap<String, Object?>(keyId)
          ?.tryGet<String>('ciphertext');
      if (ciphertext == null) {
        throw Exception('Wrong type for ciphertext!');
      }
      await client.database.storeSSSSCache(type, keyId, ciphertext, secret);
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

  /// Resolves the key id for a secret-storage key definition by its [name]
  /// field on `m.secret_storage.key.<key_id>` account data.
  ///
  /// If several keys share the same [name] (e.g. an orphaned definition left
  /// on the server after rotation), returns the id that appears most often in
  /// encrypted secret account data from [analyzeEncryptedSecrets]. Ties use
  /// lexicographic key order. Returns null when no key with that [name]
  /// exists.
  String? keyIdForNamedSecretStorageKey(String name) {
    if (name.isEmpty) return null;
    const prefix = 'm.secret_storage.key.';
    final candidates = <String>[];
    for (final entry in client.accountData.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      final keyName = entry.value.content['name'];
      if (keyName == name) {
        candidates.add(entry.key.substring(prefix.length));
      }
    }
    if (candidates.isEmpty) return null;

    if (candidates.length == 1) {
      return candidates.first;
    }

    final usage = <String, int>{for (final id in candidates) id: 0};
    for (final keyIds in analyzeEncryptedSecrets().values) {
      for (final kid in keyIds) {
        if (usage.containsKey(kid)) {
          usage[kid] = usage[kid]! + 1;
        }
      }
    }
    final ranked = usage.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });
    if (ranked.first.value > 0) {
      return ranked.first.key;
    }
    return null;
  }

  Future<void> removeUnusedNamedSecretStorageKeys(String name) async {
    if (name.isEmpty) return;
    const prefix = 'm.secret_storage.key.';
    final usedKeyIds =
        analyzeEncryptedSecrets().values.expand((s) => s).toSet();
    final entries = client.accountData.entries.toList(growable: false);
    for (final entry in entries) {
      if (!entry.key.startsWith(prefix)) continue;
      final keyId = entry.key.substring(prefix.length);
      if (entry.value.content['name'] != name) continue;
      if (usedKeyIds.contains(keyId)) continue;
      await _setAccountDataAndWaitForSync(
        EventTypes.secretStorageKey(keyId),
        {},
      );
    }
  }

  /// Returns secret event types mapped to valid SSSS key ids.
  ///
  /// Only account data entries with a valid `encrypted` map shape are included.
  Map<String, Set<String>> analyzeEncryptedSecrets() {
    final secrets = <String, Set<String>>{};
    for (final entry in client.accountData.entries) {
      final type = entry.key;
      final event = entry.value;
      final encryptedContent = event.content.tryGetMap<String, Object?>(
        'encrypted',
      );
      if (encryptedContent == null) continue;

      final validKeys = <String>{};
      for (final keyEntry in encryptedContent.entries) {
        final key = keyEntry.key;
        final value = keyEntry.value;
        if (!_isUsableEncryptedKeyEntry(key, value)) continue;
        validKeys.add(key);
      }
      if (validKeys.isNotEmpty) {
        secrets[type] = validKeys;
      }
    }
    return secrets;
  }

  /// Returns whether [type] has malformed encrypted entries, or entries
  /// encrypted with invalid key ids.
  bool hasInvalidEncryptedEntries(String type) {
    final encryptedContent = client.accountData[type]?.content
        .tryGetMap<String, Object?>('encrypted');
    if (encryptedContent == null) return false;

    for (final keyEntry in encryptedContent.entries) {
      final key = keyEntry.key;
      final value = keyEntry.value;
      if (value is! Map) return true;
      if (!_isUsableEncryptedKeyEntry(key, value)) return true;
    }
    return false;
  }

  bool _isUsableEncryptedKeyEntry(String key, Object? value) {
    if (value is! Map) return false;
    if (value['iv'] is! String ||
        value['ciphertext'] is! String ||
        value['mac'] is! String) {
      return false;
    }
    return isKeyValid(key);
  }

  /// Ordered key ids to try for migration:
  /// preferred key first, then all other candidates once.
  List<String> orderedCandidateKeyIds(
    Map<String, Set<String>> secretsByType,
    String preferredKeyId,
  ) {
    final ordered = <String>[preferredKeyId];
    for (final keyIds in secretsByType.values) {
      for (final keyId in keyIds) {
        if (keyId != preferredKeyId && !ordered.contains(keyId)) {
          ordered.add(keyId);
        }
      }
    }
    return ordered;
  }

  /// Migrates available secrets from old keys to [destinationKey].
  ///
  /// Returns the set of secret types that were successfully migrated.
  Future<Set<String>> migrateSecretsToKey({
    required OpenSSSS primaryUnlockedKey,
    required OpenSSSS destinationKey,
    String? unlockCredential,
    Map<String, OpenSSSS>? candidateOldKeys,
    bool stripKeys = false,
    bool stripAsDefaultKey = true,
  }) async {
    final remainingSecrets = analyzeEncryptedSecrets();
    final keyIds =
        orderedCandidateKeyIds(remainingSecrets, primaryUnlockedKey.keyId);
    if (keyIds.isEmpty) return {};

    final migratedSecretTypes = <String>{};
    Set<String> candidateSecretsForKey(String keyId) {
      return remainingSecrets.entries
          .where((entry) => entry.value.contains(keyId))
          .map((entry) => entry.key)
          .toSet();
    }

    for (final keyId in keyIds) {
      final key = keyId == primaryUnlockedKey.keyId
          ? primaryUnlockedKey
          : candidateOldKeys?[keyId] ??
              await _tryOpenAndUnlockKey(
                keyId,
                unlockCredential: unlockCredential,
              );
      if (key == null || !key.isUnlocked) continue;

      for (final secretType in candidateSecretsForKey(keyId)) {
        try {
          final secret = await key.getStored(secretType);
          await destinationKey.store(secretType, secret, add: true);
          migratedSecretTypes.add(secretType);
          remainingSecrets.remove(secretType);
        } catch (e, s) {
          Logs().v(
            'Could not migrate $secretType using SSSS key $keyId',
            e,
            s,
          );
        }
      }
      if (remainingSecrets.isEmpty) break;
    }
    if (stripKeys) {
      await _validateAndStripMigratedSecrets(
        destinationKey: destinationKey,
        migratedSecretTypes: migratedSecretTypes,
        isDefaultKey: stripAsDefaultKey,
      );
    }
    return migratedSecretTypes;
  }

  /// Validates migrated secrets for [destinationKey] and strips all other keys
  /// from each migrated secret type.
  Future<void> _validateAndStripMigratedSecrets({
    required OpenSSSS destinationKey,
    required Iterable<String> migratedSecretTypes,
    bool isDefaultKey = true,
  }) async {
    for (final type in migratedSecretTypes) {
      final secret = await destinationKey.getStored(type);
      await destinationKey.validateAndStripOtherKeys(
        type,
        secret,
        isDefaultKey: isDefaultKey,
      );
    }
    await destinationKey.maybeCacheAll();
  }

  Future<OpenSSSS?> _tryOpenAndUnlockKey(
    String keyId, {
    String? unlockCredential,
  }) async {
    try {
      final key = open(keyId);
      if (unlockCredential == null || key.isUnlocked) return key;
      try {
        await key.unlock(keyOrPassphrase: unlockCredential);
      } catch (e, s) {
        Logs().v(
          'Could not unlock SSSS key $keyId with provided credential',
          e,
          s,
        );
      }
      return key;
    } catch (e, s) {
      Logs().v('Skipping unavailable SSSS key $keyId during migration', e, s);
      return null;
    }
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
      if (SSSS.looksLikeRecoveryKey(keyOrPassphrase)) {
        try {
          await unlock(recoveryKey: keyOrPassphrase, postUnlock: postUnlock);
          return;
        } catch (e) {
          if (!hasPassphrase) {
            rethrow;
          }
        }
      }
      if (hasPassphrase) {
        await unlock(passphrase: keyOrPassphrase, postUnlock: postUnlock);
      } else {
        throw InvalidPassphraseException(
          'Tried to unlock with passphrase while key does not have a passphrase',
        );
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
      ).timeout(Duration(minutes: 2));
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
        (ssss.client.accountData[type]!.content
                .tryGetMap<String, Object?>('encrypted')
                ?.containsKey(keyId) !=
            true) ||
        await getStored(type) != secret) {
      Logs().d('Wait for secret of $type to match in accountdata');
      await ssss.client.oneShotSync();
    }
  }

  Future<void> validateAndStripOtherKeys(
    String type,
    String secret, {
    bool isDefaultKey = true,
  }) async {
    final privateKey = this.privateKey;
    if (privateKey == null) {
      throw Exception('SSSS not unlocked');
    }
    await ssss.validateAndStripOtherKeys(
      type,
      secret,
      keyId,
      privateKey,
      isDefaultKey: isDefaultKey,
    );
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
