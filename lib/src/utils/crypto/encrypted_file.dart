// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';
import 'dart:typed_data';

import 'package:vodozemac/vodozemac.dart';

import 'package:matrix/encryption/utils/base64_unpadded.dart';
import 'package:matrix/src/utils/crypto/crypto.dart';

class EncryptedFile {
  EncryptedFile({
    required this.data,
    required this.k,
    required this.iv,
    required this.sha256,
  });
  Uint8List data;
  String k;
  String iv;
  String sha256;
}

Future<EncryptedFile> encryptFile(Uint8List input) async {
  final key = secureRandomBytes(32);
  final iv = secureRandomBytes(16);
  final data = CryptoUtils.aesCtr(input: input, key: key, iv: iv);
  final hash = CryptoUtils.sha256(input: data);
  return EncryptedFile(
    data: data,
    k: base64Url.encode(key).replaceAll('=', ''),
    iv: base64.encode(iv).replaceAll('=', ''),
    sha256: base64.encode(hash).replaceAll('=', ''),
  );
}

/// you would likely want to use [NativeImplementations] and
/// [Client.nativeImplementations] instead
Future<Uint8List?> decryptFileImplementation(EncryptedFile input) async {
  if (base64.encode(CryptoUtils.sha256(input: input.data)) !=
      base64.normalize(input.sha256)) {
    return null;
  }

  final key = base64decodeUnpadded(base64.normalize(input.k));
  final iv = base64decodeUnpadded(base64.normalize(input.iv));
  return CryptoUtils.aesCtr(input: input.data, key: key, iv: iv);
}
