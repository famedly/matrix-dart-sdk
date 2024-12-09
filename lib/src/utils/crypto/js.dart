// Copyright (c) 2020 Famedly GmbH
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:typed_data';

import 'package:matrix/src/utils/crypto/subtle.dart' as subtle;
import 'package:matrix/src/utils/crypto/subtle.dart';

abstract class Hash {
  Hash._(this.name);
  String name;

  Future<Uint8List> call(Uint8List input) async =>
      Uint8List.view(await digest(name, input));
}

final Hash sha1 = _Sha1();
final Hash sha256 = _Sha256();
final Hash sha512 = _Sha512();

class _Sha1 extends Hash {
  _Sha1() : super._('SHA-1');
}

class _Sha256 extends Hash {
  _Sha256() : super._('SHA-256');
}

class _Sha512 extends Hash {
  _Sha512() : super._('SHA-512');
}

abstract class Cipher {
  Cipher._(this.name);
  String name;
  Object params(Uint8List iv);
  Future<Uint8List> encrypt(
    Uint8List input,
    Uint8List key,
    Uint8List iv,
  ) async {
    final subtleKey = await importKey('raw', key, name, false, ['encrypt']);
    return (await subtle.encrypt(params(iv), subtleKey, input)).asUint8List();
  }
}

final Cipher aesCtr = _AesCtr();

class _AesCtr extends Cipher {
  _AesCtr() : super._('AES-CTR');

  @override
  Object params(Uint8List iv) =>
      AesCtrParams(name: name, counter: iv, length: 64);
}

Future<Uint8List> pbkdf2(
  Uint8List passphrase,
  Uint8List salt,
  Hash hash,
  int iterations,
  int bits,
) async {
  final raw =
      await importKey('raw', passphrase, 'PBKDF2', false, ['deriveBits']);
  final res = await deriveBits(
    Pbkdf2Params(
      name: 'PBKDF2',
      hash: hash.name,
      salt: salt,
      iterations: iterations,
    ),
    raw,
    bits,
  );
  return Uint8List.view(res);
}
