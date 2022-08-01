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
import 'dart:typed_data';

import 'package:matrix/encryption/utils/base64_unpadded.dart';
import 'crypto.dart';

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
  final data = await aesCtr.encrypt(input, key, iv);
  final hash = await sha256(data);
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
  if (base64.encode(await sha256(input.data)) !=
      base64.normalize(input.sha256)) {
    return null;
  }

  final key = base64decodeUnpadded(base64.normalize(input.k));
  final iv = base64decodeUnpadded(base64.normalize(input.iv));
  return await aesCtr.encrypt(input.data, key, iv);
}
