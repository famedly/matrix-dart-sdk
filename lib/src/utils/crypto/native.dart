import 'dart:typed_data';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'ffi.dart';

abstract class Hash {
  Hash._(this.ptr);
  Pointer<NativeType> ptr;
}

final Hash sha1 = _Sha1();
final Hash sha256 = _Sha256();
final Hash sha512 = _Sha512();

class _Sha1 extends Hash {
  _Sha1() : super._(EVP_sha1());
}

class _Sha256 extends Hash {
  _Sha256() : super._(EVP_sha256());
}

class _Sha512 extends Hash {
  _Sha512() : super._(EVP_sha512());
}

Uint8List pbkdf2(Uint8List passphrase, Uint8List salt, Hash hash, int iterations, int bits) {
  final outLen = bits ~/ 8;
  final mem = malloc.call<Uint8>(passphrase.length + salt.length + outLen);
  final saltMem = mem.elementAt(passphrase.length);
  final outMem = saltMem.elementAt(salt.length);
  try {
    mem.asTypedList(passphrase.length).setAll(0, passphrase);
    saltMem.asTypedList(salt.length).setAll(0, salt);
    PKCS5_PBKDF2_HMAC(mem, passphrase.length, saltMem, salt.length, iterations, hash.ptr, outLen, outMem);
    return Uint8List.fromList(outMem.asTypedList(outLen));
  } finally {
    malloc.free(mem);
  }
}
