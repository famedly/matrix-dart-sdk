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

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:webcrypto/webcrypto.dart' as webcrypto;

Uint8List secureRandomBytes(int len) {
  final rng = Random.secure();
  final list = Uint8List(len);
  list.setAll(0, Iterable.generate(list.length, (i) => rng.nextInt(256)));
  return list;
}

FutureOr<Uint8List> aesCtr(
  Uint8List input,
  Uint8List key,
  Uint8List iv,
) async {
  final aesCtrKey = await webcrypto.AesCtrSecretKey.importRawKey(key);
  return await aesCtrKey.encryptBytes(input, iv, 64);
}

FutureOr<Uint8List> pbkdf2(
  Uint8List passphrase,
  Uint8List salt,
  int iterations,
  int bits, {
  webcrypto.Hash hash = webcrypto.Hash.sha256,
}) async {
  final key = await webcrypto.Pbkdf2SecretKey.importRawKey(passphrase);
  return await key.deriveBits(
    bits,
    hash,
    salt,
    iterations,
  );
}

Future<Uint8List> sha256(Uint8List data) =>
    webcrypto.Hash.sha256.digestBytes(data);

Future<Uint8List> sha512(Uint8List data) =>
    webcrypto.Hash.sha512.digestBytes(data);
