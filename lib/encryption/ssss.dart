/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020 Famedly GmbH
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

import 'dart:typed_data';
import 'dart:convert';

import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:base58check/base58.dart';
import 'package:password_hash/password_hash.dart';
import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/matrix_api.dart';

import 'encryption.dart';

const CACHE_TYPES = <String>[
  'm.cross_signing.self_signing',
  'm.cross_signing.user_signing',
  'm.megolm_backup.v1'
];
const ZERO_STR =
    '\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00';
const BASE58_ALPHABET =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
const base58 = Base58Codec(BASE58_ALPHABET);
const OLM_RECOVERY_KEY_PREFIX = [0x8B, 0x01];
const OLM_PRIVATE_KEY_LENGTH = 32; // TODO: fetch from dart-olm

class SSSS {
  final Encryption encryption;
  Client get client => encryption.client;
  final pendingShareRequests = <String, _ShareRequest>{};
  final _validators = <String, Future<bool> Function(String)>{};
  SSSS(this.encryption);

  static _DerivedKeys deriveKeys(Uint8List key, String name) {
    final zerosalt = Uint8List(8);
    final prk = Hmac(sha256, zerosalt).convert(key);
    final b = Uint8List(1);
    b[0] = 1;
    final aesKey = Hmac(sha256, prk.bytes).convert(utf8.encode(name) + b);
    b[0] = 2;
    final hmacKey =
        Hmac(sha256, prk.bytes).convert(aesKey.bytes + utf8.encode(name) + b);
    return _DerivedKeys(aesKey: aesKey.bytes, hmacKey: hmacKey.bytes);
  }

  static _Encrypted encryptAes(String data, Uint8List key, String name,
      [String ivStr]) {
    Uint8List iv;
    if (ivStr != null) {
      iv = base64.decode(ivStr);
    } else {
      iv = Uint8List.fromList(SecureRandom(16).bytes);
    }
    // we need to clear bit 63 of the IV
    iv[8] &= 0x7f;

    final keys = deriveKeys(key, name);

    final plain = Uint8List.fromList(utf8.encode(data));
    final ciphertext = AES(Key(keys.aesKey), mode: AESMode.ctr, padding: null)
        .encrypt(plain, iv: IV(iv))
        .bytes;

    final hmac = Hmac(sha256, keys.hmacKey).convert(ciphertext);

    return _Encrypted(
        iv: base64.encode(iv),
        ciphertext: base64.encode(ciphertext),
        mac: base64.encode(hmac.bytes));
  }

  static String decryptAes(_Encrypted data, Uint8List key, String name) {
    final keys = deriveKeys(key, name);
    final cipher = base64.decode(data.ciphertext);
    final hmac = base64
        .encode(Hmac(sha256, keys.hmacKey).convert(cipher).bytes)
        .replaceAll(RegExp(r'=+$'), '');
    if (hmac != data.mac.replaceAll(RegExp(r'=+$'), '')) {
      throw 'Bad MAC';
    }
    final decipher = AES(Key(keys.aesKey), mode: AESMode.ctr, padding: null)
        .decrypt(Encrypted(cipher), iv: IV(base64.decode(data.iv)));
    return String.fromCharCodes(decipher);
  }

  static Uint8List decodeRecoveryKey(String recoveryKey) {
    final result = base58.decode(recoveryKey.replaceAll(' ', ''));

    var parity = 0;
    for (final b in result) {
      parity ^= b;
    }
    if (parity != 0) {
      throw 'Incorrect parity';
    }

    for (var i = 0; i < OLM_RECOVERY_KEY_PREFIX.length; i++) {
      if (result[i] != OLM_RECOVERY_KEY_PREFIX[i]) {
        throw 'Incorrect prefix';
      }
    }

    if (result.length !=
        OLM_RECOVERY_KEY_PREFIX.length + OLM_PRIVATE_KEY_LENGTH + 1) {
      throw 'Incorrect length';
    }

    return Uint8List.fromList(result.sublist(OLM_RECOVERY_KEY_PREFIX.length,
        OLM_RECOVERY_KEY_PREFIX.length + OLM_PRIVATE_KEY_LENGTH));
  }

  static Uint8List keyFromPassphrase(String passphrase, _PassphraseInfo info) {
    if (info.algorithm != 'm.pbkdf2') {
      throw 'Unknown algorithm';
    }
    final generator = PBKDF2(hashAlgorithm: sha512);
    return Uint8List.fromList(generator.generateKey(passphrase, info.salt,
        info.iterations, info.bits != null ? info.bits / 8 : 32));
  }

  void setValidator(String type, Future<bool> Function(String) validator) {
    _validators[type] = validator;
  }

  String get defaultKeyId {
    final keyData = client.accountData['m.secret_storage.default_key'];
    if (keyData == null || !(keyData.content['key'] is String)) {
      return null;
    }
    return keyData.content['key'];
  }

  BasicEvent getKey(String keyId) {
    return client.accountData['m.secret_storage.key.${keyId}'];
  }

  bool checkKey(Uint8List key, BasicEvent keyData) {
    final info = keyData.content;
    if (info['algorithm'] == 'm.secret_storage.v1.aes-hmac-sha2') {
      if ((info['mac'] is String) && (info['iv'] is String)) {
        final encrypted = encryptAes(ZERO_STR, key, '', info['iv']);
        return info['mac'].replaceAll(RegExp(r'=+$'), '') ==
            encrypted.mac.replaceAll(RegExp(r'=+$'), '');
      } else {
        // no real information about the key, assume it is valid
        return true;
      }
    } else {
      throw 'Unknown Algorithm';
    }
  }

  Future<String> getCached(String type) async {
    if (client.database == null) {
      return null;
    }
    final ret = await client.database.getSSSSCache(client.id, type);
    if (ret == null) {
      return null;
    }
    // check if it is still valid
    final keys = keyIdsFromType(type);
    if (keys.contains(ret.keyId) &&
        client.accountData[type].content['encrypted'][ret.keyId]
                ['ciphertext'] ==
            ret.ciphertext) {
      return ret.content;
    }
    return null;
  }

  Future<String> getStored(String type, String keyId, Uint8List key) async {
    final secretInfo = client.accountData[type];
    if (secretInfo == null) {
      throw 'Not found';
    }
    if (!(secretInfo.content['encrypted'] is Map)) {
      throw 'Content is not encrypted';
    }
    if (!(secretInfo.content['encrypted'][keyId] is Map)) {
      throw 'Wrong / unknown key';
    }
    final enc = secretInfo.content['encrypted'][keyId];
    final encryptInfo = _Encrypted(
        iv: enc['iv'], ciphertext: enc['ciphertext'], mac: enc['mac']);
    final decrypted = decryptAes(encryptInfo, key, type);
    if (CACHE_TYPES.contains(type) && client.database != null) {
      // cache the thing
      await client.database
          .storeSSSSCache(client.id, type, keyId, enc['ciphertext'], decrypted);
    }
    return decrypted;
  }

  Future<void> store(
      String type, String secret, String keyId, Uint8List key) async {
    final encrypted = encryptAes(secret, key, type);
    final content = <String, dynamic>{
      'encrypted': <String, dynamic>{},
    };
    content['encrypted'][keyId] = <String, dynamic>{
      'iv': encrypted.iv,
      'ciphertext': encrypted.ciphertext,
      'mac': encrypted.mac,
    };
    // store the thing in your account data
    await client.api.setAccountData(client.userID, type, content);
    if (CACHE_TYPES.contains(type) && client.database != null) {
      // cache the thing
      await client.database
          .storeSSSSCache(client.id, type, keyId, encrypted.ciphertext, secret);
    }
  }

  Future<void> maybeCacheAll(String keyId, Uint8List key) async {
    for (final type in CACHE_TYPES) {
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

  Future<void> maybeRequestAll(List<DeviceKeys> devices) async {
    for (final type in CACHE_TYPES) {
      final secret = await getCached(type);
      if (secret == null) {
        await request(type, devices);
      }
    }
  }

  Future<void> request(String type, List<DeviceKeys> devices) async {
    // only send to own, verified devices
    print('[SSSS] Requesting type ${type}...');
    devices.removeWhere((DeviceKeys d) =>
        d.userId != client.userID ||
        !d.verified ||
        d.blocked ||
        d.deviceId == client.deviceID);
    if (devices.isEmpty) {
      print('[SSSS] Warn: No devices');
      return;
    }
    final requestId = client.generateUniqueTransactionId();
    final request = _ShareRequest(
      requestId: requestId,
      type: type,
      devices: devices,
    );
    pendingShareRequests[requestId] = request;
    await client.sendToDevice(devices, 'm.secret.request', {
      'action': 'request',
      'requesting_device_id': client.deviceID,
      'request_id': requestId,
      'name': type,
    });
  }

  Future<void> handleToDeviceEvent(ToDeviceEvent event) async {
    if (event.type == 'm.secret.request') {
      // got a request to share a secret
      print('[SSSS] Received sharing request...');
      if (event.sender != client.userID ||
          !client.userDeviceKeys.containsKey(client.userID)) {
        print('[SSSS] Not sent by us');
        return; // we aren't asking for it ourselves, so ignore
      }
      if (event.content['action'] != 'request') {
        print('[SSSS] it is actually a cancelation');
        return; // not actually requesting, so ignore
      }
      final device = client.userDeviceKeys[client.userID]
          .deviceKeys[event.content['requesting_device_id']];
      if (device == null || !device.verified || device.blocked) {
        print('[SSSS] Unknown / unverified devices, ignoring');
        return; // nope....unknown or untrusted device
      }
      // alright, all seems fine...let's check if we actually have the secret they are asking for
      final type = event.content['name'];
      final secret = await getCached(type);
      if (secret == null) {
        print('[SSSS] We don\'t have the secret for ${type} ourself, ignoring');
        return; // seems like we don't have this, either
      }
      // okay, all checks out...time to share this secret!
      print('[SSSS] Replying with secret for ${type}');
      await client.sendToDevice(
          [device],
          'm.secret.send',
          {
            'request_id': event.content['request_id'],
            'secret': secret,
          });
    } else if (event.type == 'm.secret.send') {
      // receiving a secret we asked for
      print('[SSSS] Received shared secret...');
      if (event.sender != client.userID ||
          !pendingShareRequests.containsKey(event.content['request_id']) ||
          event.encryptedContent == null) {
        print('[SSSS] Not by us or unknown request');
        return; // we have no idea what we just received
      }
      final request = pendingShareRequests[event.content['request_id']];
      // alright, as we received a known request id, let's check if the sender is valid
      final device = request.devices.firstWhere(
          (d) =>
              d.userId == event.sender &&
              d.curve25519Key == event.encryptedContent['sender_key'],
          orElse: () => null);
      if (device == null) {
        print('[SSSS] Someone else replied?');
        return; // someone replied whom we didn't send the share request to
      }
      final secret = event.content['secret'];
      if (!(event.content['secret'] is String)) {
        print('[SSSS] Secret wasn\'t a string');
        return; // the secret wasn't a string....wut?
      }
      // let's validate if the secret is, well, valid
      if (_validators.containsKey(request.type) &&
          !(await _validators[request.type](secret))) {
        print('[SSSS] The received secret was invalid');
        return; // didn't pass the validator
      }
      pendingShareRequests.remove(request.requestId);
      if (request.start.add(Duration(minutes: 15)).isBefore(DateTime.now())) {
        print('[SSSS] Request is too far in the past');
        return; // our request is more than 15min in the past...better not trust it anymore
      }
      print('[SSSS] Secret for type ${request.type} is ok, storing it');
      if (client.database != null) {
        final keyId = keyIdFromType(request.type);
        if (keyId != null) {
          final ciphertext = client.accountData[request.type]
              .content['encrypted'][keyId]['ciphertext'];
          await client.database.storeSSSSCache(
              client.id, request.type, keyId, ciphertext, secret);
        }
      }
    }
  }

  Set<String> keyIdsFromType(String type) {
    final data = client.accountData[type];
    if (data == null) {
      return null;
    }
    if (data.content['encrypted'] is Map) {
      final Set keys = <String>{};
      for (final key in data.content['encrypted'].keys) {
        keys.add(key);
      }
      return keys;
    }
    return null;
  }

  String keyIdFromType(String type) {
    final keys = keyIdsFromType(type);
    if (keys == null || keys.isEmpty) {
      return null;
    }
    if (keys.contains(defaultKeyId)) {
      return defaultKeyId;
    }
    return keys.first;
  }

  OpenSSSS open([String identifier]) {
    identifier ??= defaultKeyId;
    if (identifier == null) {
      throw 'Dont know what to open';
    }
    final keyToOpen = keyIdFromType(identifier) ?? identifier;
    if (keyToOpen == null) {
      throw 'No key found to open';
    }
    final key = getKey(keyToOpen);
    if (key == null) {
      throw 'Unknown key to open';
    }
    return OpenSSSS(ssss: this, keyId: keyToOpen, keyData: key);
  }
}

class _ShareRequest {
  final String requestId;
  final String type;
  final List<DeviceKeys> devices;
  final DateTime start;

  _ShareRequest({this.requestId, this.type, this.devices})
      : start = DateTime.now();
}

class _Encrypted {
  final String iv;
  final String ciphertext;
  final String mac;

  _Encrypted({this.iv, this.ciphertext, this.mac});
}

class _DerivedKeys {
  final Uint8List aesKey;
  final Uint8List hmacKey;

  _DerivedKeys({this.aesKey, this.hmacKey});
}

class _PassphraseInfo {
  final String algorithm;
  final String salt;
  final int iterations;
  final int bits;

  _PassphraseInfo({this.algorithm, this.salt, this.iterations, this.bits});
}

class OpenSSSS {
  final SSSS ssss;
  final String keyId;
  final BasicEvent keyData;
  OpenSSSS({this.ssss, this.keyId, this.keyData});
  Uint8List privateKey;

  bool get isUnlocked => privateKey != null;

  void unlock({String passphrase, String recoveryKey}) {
    if (passphrase != null) {
      privateKey = SSSS.keyFromPassphrase(
          passphrase,
          _PassphraseInfo(
              algorithm: keyData.content['passphrase']['algorithm'],
              salt: keyData.content['passphrase']['salt'],
              iterations: keyData.content['passphrase']['iterations'],
              bits: keyData.content['passphrase']['bits']));
    } else if (recoveryKey != null) {
      privateKey = SSSS.decodeRecoveryKey(recoveryKey);
    } else {
      throw 'Nothing specified';
    }
    // verify the validity of the key
    if (!ssss.checkKey(privateKey, keyData)) {
      privateKey = null;
      throw 'Inalid key';
    }
  }

  Future<String> getStored(String type) async {
    return await ssss.getStored(type, keyId, privateKey);
  }

  Future<void> store(String type, String secret) async {
    await ssss.store(type, secret, keyId, privateKey);
  }

  Future<void> maybeCacheAll() async {
    await ssss.maybeCacheAll(keyId, privateKey);
  }
}
