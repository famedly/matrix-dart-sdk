import 'dart:typed_data';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'ffi.dart';

Uint8List pbkdf2(Uint8List passphrase, Uint8List salt, int iterations, int bits) {
  final outLen = bits ~/ 8;
  final mem = malloc.call<Uint8>(passphrase.length + salt.length + outLen);
  final saltMem = mem.elementAt(passphrase.length);
  final outMem = saltMem.elementAt(salt.length);
  try {
    mem.asTypedList(passphrase.length).setAll(0, passphrase);
    saltMem.asTypedList(salt.length).setAll(0, salt);
    PKCS5_PBKDF2_HMAC(mem, passphrase.length, saltMem, salt.length, iterations, EVP_sha512(), outLen, outMem);
    return Uint8List.fromList(outMem.asTypedList(outLen));
  } finally {
    malloc.free(mem);
  }
}
