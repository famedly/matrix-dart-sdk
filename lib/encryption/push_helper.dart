/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2021 Famedly GmbH
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
import 'dart:typed_data';

import 'package:olm/olm.dart' as olm;
import 'package:cryptography/cryptography.dart';

import '../matrix.dart';
import 'encryption.dart';

class PushHelper {
  final Encryption encryption;
  Client get client => encryption.client;
  Uint8List? privateKey;
  String? publicKey;

  PushHelper(this.encryption);

  /// base64 decode both padded and unpadded base64
  Uint8List _b64decode(String s) {
    // dart wants padded base64: https://github.com/dart-lang/sdk/issues/39510
    final needEquals = (4 - (s.length % 4)) % 4;
    return base64.decode(s + ('=' * needEquals));
  }

  /// Decrypt a given [ciphertext] and [ephemeral] key, validating the [mac]
  Future<String> _pkDecrypt(
      {required String ciphertext,
      required String mac,
      required String ephemeral}) async {
    final _privateKey = privateKey;
    if (_privateKey == null) {
      throw Exception('No private key to decrypt with');
    }

    // first we do ECDH (x25519) with the ephemeral key, the resulting secret lands in `secretKey`
    final x25519 = Cryptography.instance.x25519();
    final secretKey = await x25519.sharedSecretKey(
      keyPair: await x25519.newKeyPairFromSeed(_privateKey),
      remotePublicKey:
          SimplePublicKey(_b64decode(ephemeral), type: KeyPairType.x25519),
    );

    // next we do HKDF to get the aesKey, macKey and aesIv
    final zerosalt = List.filled(32, 0);
    final hmac = Hmac.sha256();
    final prk = (await hmac.calculateMac(await secretKey.extractBytes(),
            secretKey: SecretKey(zerosalt)))
        .bytes;
    final aesKey =
        (await hmac.calculateMac([1], secretKey: SecretKey(prk))).bytes;
    final macKey =
        (await hmac.calculateMac([...aesKey, 2], secretKey: SecretKey(prk)))
            .bytes;
    final aesIv =
        (await hmac.calculateMac([...macKey, 3], secretKey: SecretKey(prk)))
            .bytes
            .sublist(0, 16);

    // now we calculate and compare the macs
    final resMac = (await hmac.calculateMac(_b64decode(ciphertext),
            secretKey: SecretKey(macKey)))
        .bytes
        .sublist(0, 8);
    if (base64.encode(resMac).replaceAll('=', '') != mac.replaceAll('=', '')) {
      throw Exception('Bad mac');
    }

    // finally decrypt the actual ciphertext
    final aes = AesCbc.with256bits(macAlgorithm: MacAlgorithm.empty);
    final decrypted = await aes.decrypt(
        SecretBox(_b64decode(ciphertext), nonce: aesIv, mac: Mac.empty),
        secretKey: SecretKey(aesKey));
    return utf8.decode(decrypted);
  }

  /// Process a push payload, decrypting it based on its algorithm
  Future<Map<String, dynamic>> processPushPayload(
      Map<String, dynamic> data) async {
    var algorithm = data.tryGet<String>('algorithm');
    if (algorithm == null) {
      List<Map<String, dynamic>>? devices;
      if (data['devices'] is String) {
        devices = json.decode(data['devices']).cast<Map<String, dynamic>>();
      } else {
        devices = data.tryGetList<Map<String, dynamic>>('devices');
      }
      if (devices != null && devices.isNotEmpty) {
        algorithm = devices.first
            .tryGetMap<String, dynamic>('data')
            ?.tryGet<String>('algorithm');
      }
    }
    Logs().v('[Push] Using algorithm: $algorithm');
    switch (algorithm) {
      case 'com.famedly.curve25519-aes-sha2':
        final ciphertext = data.tryGet<String>('ciphertext');
        final mac = data.tryGet<String>('mac');
        final ephemeral = data.tryGet<String>('ephemeral');
        if (ciphertext == null || mac == null || ephemeral == null) {
          throw Exception('Invalid encrypted push payload');
        }
        return json.decode(await _pkDecrypt(
          ciphertext: ciphertext,
          mac: mac,
          ephemeral: ephemeral,
        ));
      default:
        return data;
    }
  }

  /// Initialize the push helper with a [pushPrivateKey], generating a new keypair
  /// if none passed or empty
  Future<void> init([String? pushPrivateKey]) async {
    if (pushPrivateKey != null && pushPrivateKey.isNotEmpty) {
      try {
        final _privateKey = base64.decode(pushPrivateKey);
        final keyObj = olm.PkDecryption();
        try {
          publicKey = keyObj.init_with_private_key(_privateKey);
          privateKey = _privateKey;
        } finally {
          keyObj.free();
        }
      } catch (e, s) {
        client.onEncryptionError.add(
          SdkError(
            exception: e is Exception ? e : Exception(e),
            stackTrace: s,
          ),
        );
        privateKey = null;
        publicKey = null;
      }
    } else {
      privateKey = null;
      publicKey = null;
    }
    await _maybeGenerateNewKeypair();
  }

  /// Transmutes a pusher to add the public key and algorithm. Additionally generates a
  /// new keypair, if needed
  Future<Pusher> getPusher(Pusher pusher) async {
    await _maybeGenerateNewKeypair();
    if (privateKey == null) {
      throw Exception('No private key found');
    }
    final newPusher = Pusher.fromJson(pusher.toJson());
    newPusher.data = PusherData.fromJson(<String, dynamic>{
      ...newPusher.data.toJson(),
      'public_key': publicKey,
      'algorithm': 'com.famedly.curve25519-aes-sha2',
    });
    return newPusher;
  }

  /// Force generation of a new keypair
  Future<void> generateNewKeypair() async {
    try {
      final keyObj = olm.PkDecryption();
      try {
        publicKey = keyObj.generate_key();
        privateKey = keyObj.get_private_key();
      } finally {
        keyObj.free();
      }
      await client.database?.storePushPrivateKey(base64.encode(privateKey!));
    } catch (e, s) {
      client.onEncryptionError.add(
        SdkError(
          exception: e is Exception ? e : Exception(e),
          stackTrace: s,
        ),
      );
      rethrow;
    }
  }

  /// Generate a new keypair only if there is none
  Future<void> _maybeGenerateNewKeypair() async {
    if (privateKey != null) {
      return;
    }
    await generateNewKeypair();
  }
}
