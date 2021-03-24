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

abstract class Cipher {
  Cipher._();
  Pointer<NativeType> getAlg(int keysize);
  Uint8List encrypt(Uint8List input, Uint8List key, Uint8List iv) {
    final alg = getAlg(key.length * 8);
    final mem = malloc.call<Uint8>(sizeOf<IntPtr>() + key.length + iv.length + input.length);
    final lenMem = mem.cast<IntPtr>();
    final keyMem = mem.elementAt(sizeOf<IntPtr>());
    final ivMem = keyMem.elementAt(key.length);
    final dataMem = ivMem.elementAt(iv.length);
    try {
      keyMem.asTypedList(key.length).setAll(0, key);
      ivMem.asTypedList(iv.length).setAll(0, iv);
      dataMem.asTypedList(input.length).setAll(0, input);
      final ctx = EVP_CIPHER_CTX_new();
      EVP_EncryptInit_ex(ctx, alg, nullptr, keyMem, ivMem);
      EVP_EncryptUpdate(ctx, dataMem, lenMem, dataMem, input.length);
      EVP_EncryptFinal_ex(ctx, dataMem.elementAt(lenMem.value), lenMem);
      EVP_CIPHER_CTX_free(ctx);
      return Uint8List.fromList(dataMem.asTypedList(input.length));
    } finally {
      malloc.free(mem);
    }
  }
}

final Cipher aesCtr = _AesCtr();

class _AesCtr extends Cipher {
  _AesCtr() : super._();

  @override
  Pointer<NativeType> getAlg(int keysize) {
    switch (keysize) {
      case 128: return EVP_aes_128_ctr();
      case 256: return EVP_aes_256_ctr();
      default: throw ArgumentError('invalid key size');
    }
  }
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
