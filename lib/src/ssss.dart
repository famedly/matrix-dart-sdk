import 'dart:typed_data';
import 'dart:convert';

import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:base58check/base58.dart';
import 'package:password_hash/password_hash.dart';
import 'package:random_string/random_string.dart';

import 'client.dart';
import 'account_data.dart';
import 'utils/device_keys_list.dart';
import 'utils/to_device_event.dart';

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
const AES_BLOCKSIZE = 16;

class SSSS {
  final Client client;
  final pendingShareRequests = <String, _ShareRequest>{};
  SSSS(this.client);

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

    // workaround for https://github.com/leocavalcante/encrypt/issues/136
    var plain = Uint8List.fromList(utf8.encode(data));
    final bytesMissing = AES_BLOCKSIZE - (plain.lengthInBytes % AES_BLOCKSIZE);
    if (bytesMissing != AES_BLOCKSIZE) {
      // we want to be able to modify it
      final oldPlain = plain;
      plain = Uint8List(plain.lengthInBytes + bytesMissing);
      for (var i = 0; i < oldPlain.lengthInBytes; i++) {
        plain[i] = oldPlain[i];
      }
    }
    var ciphertext = AES(Key(keys.aesKey), mode: AESMode.ctr, padding: null)
        .encrypt(plain, iv: IV(iv))
        .bytes;
    if (bytesMissing != AES_BLOCKSIZE) {
      // chop off those extra bytes again
      ciphertext = ciphertext.sublist(0, plain.length - bytesMissing);
    }

    final hmac = Hmac(sha256, keys.hmacKey).convert(ciphertext);

    return _Encrypted(
        iv: base64.encode(iv),
        ciphertext: base64.encode(ciphertext),
        mac: base64.encode(hmac.bytes));
  }

  static String decryptAes(_Encrypted data, Uint8List key, String name) {
    final keys = deriveKeys(key, name);
    final hmac = base64
        .encode(Hmac(sha256, keys.hmacKey)
            .convert(base64.decode(data.ciphertext))
            .bytes)
        .replaceAll(RegExp(r'=+$'), '');
    if (hmac != data.mac.replaceAll(RegExp(r'=+$'), '')) {
      throw 'Bad MAC';
    }
    // workaround for https://github.com/leocavalcante/encrypt/issues/136
    var cipher = base64.decode(data.ciphertext);
    final bytesMissing = AES_BLOCKSIZE - (cipher.lengthInBytes % AES_BLOCKSIZE);
    if (bytesMissing != AES_BLOCKSIZE) {
      // we want to be able to modify it
      final oldCipher = cipher;
      cipher = Uint8List(cipher.lengthInBytes + bytesMissing);
      for (var i = 0; i < oldCipher.lengthInBytes; i++) {
        cipher[i] = oldCipher[i];
      }
    }
    final decipher = AES(Key(keys.aesKey), mode: AESMode.ctr, padding: null)
        .decrypt(Encrypted(cipher), iv: IV(base64.decode(data.iv)));
    if (bytesMissing != AES_BLOCKSIZE) {
      // chop off those extra bytes again
      return String.fromCharCodes(
          decipher.sublist(0, decipher.length - bytesMissing));
    }
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

  static Uint8List keyFromPassword(String password, _PasswordInfo info) {
    if (info.algorithm != 'm.pbkdf2') {
      throw 'Unknown algorithm';
    }
    final generator = PBKDF2(hashAlgorithm: sha512);
    return Uint8List.fromList(generator.generateKey(password, info.salt,
        info.iterations, info.bits != null ? info.bits / 8 : 32));
  }

  String get defaultKeyId {
    final keyData = client.accountData['m.secret_storage.default_key'];
    if (keyData == null || !(keyData.content['key'] is String)) {
      return null;
    }
    return keyData.content['key'];
  }

  AccountData getKey(String keyId) {
    return client.accountData['m.secret_storage.key.${keyId}'];
  }

  bool checkKey(Uint8List key, AccountData keyData) {
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
    if (keys.contains(ret.keyId)) {
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
      await client.database.storeSSSSCache(client.id, type, keyId, decrypted);
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
    await client.jsonRequest(
      type: HTTPType.PUT,
      action: '/client/r0/user/${client.userID}/account_data/${type}',
      data: content,
    );
    if (CACHE_TYPES.contains(type) && client.database != null) {
      // cache the thing
      await client.database.storeSSSSCache(client.id, type, keyId, secret);
    }
  }

  Future<void> maybeCacheAll(String keyId, Uint8List key) async {
    for (final type in CACHE_TYPES) {
      final secret = await getCached(type);
      if (secret == null) {
        await getStored(type, keyId, key);
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
    final requestId =
        randomString(512) + DateTime.now().millisecondsSinceEpoch.toString();
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
          !pendingShareRequests.containsKey(event.content['request_id'])) {
        print('[SSSS] Not by us or unknown request');
        return; // we have no idea what we just received
      }
      final request = pendingShareRequests[event.content['request_id']];
      // alright, as we received a known request id we know that it must have originated from a trusted source
      pendingShareRequests.remove(request.requestId);
      if (!(event.content['secret'] is String)) {
        print('[SSSS] Secret wasn\'t a string');
        return; // the secret wasn't a string....wut?
      }
      if (request.start.add(Duration(minutes: 15)).isBefore(DateTime.now())) {
        print('[SSSS] Request is too far in the past');
        return; // our request is more than 15min in the past...better not trust it anymore
      }
      print('[SSSS] Secret for type ${request.type} is ok, storing it');
      if (client.database != null) {
        final keyId = keyIdFromType(request.type);
        if (keyId != null) {
          await client.database.storeSSSSCache(
              client.id, request.type, keyId, event.content['secret']);
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

class _PasswordInfo {
  final String algorithm;
  final String salt;
  final int iterations;
  final int bits;

  _PasswordInfo({this.algorithm, this.salt, this.iterations, this.bits});
}

class OpenSSSS {
  final SSSS ssss;
  final String keyId;
  final AccountData keyData;
  OpenSSSS({this.ssss, this.keyId, this.keyData});
  Uint8List privateKey;

  bool get isUnlocked => privateKey != null;

  void unlock({String password, String recoveryKey}) {
    if (password != null) {
      privateKey = SSSS.keyFromPassword(
          password,
          _PasswordInfo(
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

  Future<void> maybeCacheAll() async {
    await ssss.maybeCacheAll(keyId, privateKey);
  }
}
