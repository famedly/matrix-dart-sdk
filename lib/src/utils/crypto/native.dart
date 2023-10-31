import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:matrix/encryption/utils/base64_unpadded.dart';
import 'package:matrix/src/utils/crypto/base64.dart';

import 'package:matrix/src/utils/crypto/ffi.dart';
import 'package:matrix/src/utils/models/encrypted_file_info.dart';
import 'package:matrix/src/utils/models/encrypted_file_key.dart';

abstract class Hash {
  Hash._(this.ptr);
  Pointer<NativeType> ptr;

  FutureOr<Uint8List> call(Uint8List data) {
    final outSize = EVP_MD_size(ptr);
    final mem = malloc.call<Uint8>(outSize + data.length);
    final dataMem = mem.elementAt(outSize);
    try {
      dataMem.asTypedList(data.length).setAll(0, data);
      EVP_Digest(dataMem, data.length, mem, nullptr, ptr, nullptr);
      return Uint8List.fromList(mem.asTypedList(outSize));
    } finally {
      malloc.free(mem);
    }
  }
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

  static const String keyType = 'oct';
  static const String algorithmName = 'A256CTR';
  static const String messageDigestAlgorithm = 'sha256';
  static const String version = 'v2';
  static const int maxHashSize = 32;
  static const int memorySizeForHashSizePointer = 1;

  Cipher._();
  Pointer<NativeType> getAlg(int keysize);
  FutureOr<Uint8List> encrypt(Uint8List input, Uint8List key, Uint8List iv) {
    final alg = getAlg(key.length * 8);
    final mem = malloc
        .call<Uint8>(sizeOf<IntPtr>() + key.length + iv.length + input.length);
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

  Future<EncryptedFileInfo> encryptStream({
    required Stream<List<int>> inputStream,
    required File outputFile,
    required Uint8List key, 
    required Uint8List initialVector,
  }) async {
    final algorithm = getAlg(key.length * 8);

    final memSize = sizeOf<IntPtr>() + key.length + initialVector.length + maxHashSize + memorySizeForHashSizePointer;
    final memNeeded = malloc.call<Uint8>(memSize);

    final intPointer = memNeeded.cast<IntPtr>();
    final keyPointer = memNeeded.elementAt(sizeOf<IntPtr>());
    final initialVectorPointer = keyPointer.elementAt(key.length);
    final hashValuePointer = initialVectorPointer.elementAt(initialVector.length);
    final hashSizePointer = hashValuePointer.elementAt(maxHashSize);
    
    IOSink? outIoSink;
    final cipherContext = EVP_CIPHER_CTX_new();
    final mdHashContext = EVP_MD_CTX_new();
    final digestName = _getDigestName();
    try {
      outIoSink = outputFile.openWrite();
      keyPointer.asTypedList(key.length).setAll(0, key);
      initialVectorPointer.asTypedList(initialVector.length).setAll(0, initialVector);
      
      if (EVP_EncryptInit_ex(cipherContext, algorithm, nullptr, keyPointer, initialVectorPointer) == 0) {
        throw Exception('encryptStream::EVP_EncryptInit_ex Failed');
      }
      if (EVP_DigestInit_ex(mdHashContext, digestName, nullptr) == 0) {
        throw Exception('encryptStream::EVP_DigestInit_ex Failed');
      }
      
      await _encryptAndHashData(
        inputStream: inputStream,
        cipherContext: cipherContext,
        mDHashContext: mdHashContext,
        outIoSink: outIoSink,
        intPointer: intPointer,
      );
      
      final hashBase64Encoded = _getHashBase64Encoded(hashSizePointer, mdHashContext, hashValuePointer);

      return EncryptedFileInfo(
        key: _createEncryptedFileKey(algorithmName, key),
        version: version,
        initialVector: base64.encode(initialVector),
        hashes: {
          messageDigestAlgorithm: hashBase64Encoded,  
        }
      );
    } catch (e) {
      throw Exception(e);
    } finally {
      malloc.free(memNeeded);
      _freeContexts(mdHashContext, cipherContext);
      await outIoSink?.close();
    }
  }

  Pointer<NativeType> _getDigestName() {
    final digestAlgo = messageDigestAlgorithm.toNativeUtf8();
    final digestName = EVP_get_digestbyname(digestAlgo);
    if (digestName == nullptr) {
      throw Exception('getDigestName():: EVP_get_digestbyname failed');
    }
    calloc.free(digestAlgo);
    return digestName;
  }

  Future<void> _encryptAndHashData({
    required Stream<List<int>> inputStream,
    required Pointer<NativeType> cipherContext,
    required Pointer<IntPtr> intPointer,
    required IOSink? outIoSink,
    required Pointer<NativeType> mDHashContext,
  }) async {
    await inputStream.forEach((bytes) {
      final memData = malloc.call<Uint8>(bytes.length);
      final dataPointer = memData.elementAt(0);
      dataPointer.asTypedList(bytes.length).setAll(0, bytes);

      if (EVP_EncryptUpdate(cipherContext, dataPointer, intPointer, dataPointer, bytes.length) == 0) {
        malloc.free(memData);
        throw Exception('encryptStream::EVP_EncryptUpdate Failed');
      }

      outIoSink!.add(Uint8List.fromList(dataPointer.asTypedList(bytes.length)));
      if (EVP_DigestUpdate(mDHashContext, dataPointer, bytes.length) == 0) {
        malloc.free(memData);
        throw Exception('encryptStream::EVP_DigestUpdate Failed');
      }
      malloc.free(memData);
    });
  }

  String _getHashBase64Encoded(Pointer<Uint8> hashSize, Pointer<NativeType> mdHashContext, Pointer<Uint8> hashValue) {
    final maxHashLengthSize = EVP_MD_size(EVP_sha256());
    hashSize.asTypedList(1).setAll(0, [maxHashLengthSize]);
    if (EVP_DigestFinal_ex(mdHashContext, hashValue, hashSize) == 0) {
      throw Exception('encryptStream::EVP_DigestFinal_ex Failed');
    }
    
    final hashValueBytes = Uint8List.fromList(hashValue.asTypedList(maxHashLengthSize));
    return base64.encode(hashValueBytes).toUnpaddedBase64();
  }

  EncryptedFileKey _createEncryptedFileKey(String algorithmName, Uint8List keyBytes) {
    return EncryptedFileKey(
      algorithrm: algorithmName,
      key: base64Url.encode(keyBytes).toBase64Url(),
      extractable: true,
      keyOperations: [KeyOperation.encrypt, KeyOperation.decrypt],
      keyType: keyType,
    );
  }

  void _freeContexts(Pointer<NativeType> mdHashContext, Pointer<NativeType> cipherContext) {
    EVP_MD_CTX_free(mdHashContext);
    EVP_CIPHER_CTX_free(cipherContext);
  }

  Future<bool> decryptStream({
    required Stream<List<int>> inputStream,
    required File outputFile,
    required EncryptedFileInfo encryptedFileInfo,
  }) async {
    final keyDecoded = _base64decodeUnpadded(encryptedFileInfo.key.key);
    final initialVectorDecoded = _base64decodeUnpadded(encryptedFileInfo.initialVector);
    final algorithm = getAlg(keyDecoded.length * 8);

    final memSize = sizeOf<IntPtr>() + keyDecoded.length + initialVectorDecoded.length + maxHashSize + memorySizeForHashSizePointer;
    final memNeeded = malloc.call<Uint8>(memSize);
    
    final intPointer = memNeeded.cast<IntPtr>();
    final keyPointer = memNeeded.elementAt(sizeOf<IntPtr>());
    final initialVectorPointer = keyPointer.elementAt(keyDecoded.length);
    final hashValuePointer = initialVectorPointer.elementAt(initialVectorDecoded.length);
    final hashSizePointer = hashValuePointer.elementAt(maxHashSize);

    IOSink? outIoSink;
    final cipherContext = EVP_CIPHER_CTX_new();
    final mDHashContext = EVP_MD_CTX_new();
    final digestName = _getDigestName();
    try {
      outIoSink = outputFile.openWrite();
      keyPointer.asTypedList(keyDecoded.length).setAll(0, keyDecoded);
      initialVectorPointer.asTypedList(initialVectorDecoded.length).setAll(0, initialVectorDecoded);
      
      if (EVP_EncryptInit_ex(cipherContext, algorithm, nullptr, keyPointer, initialVectorPointer) == 0) {
        throw Exception('decryptStream::EVP_EncryptInit_ex failed');
      }

      if (EVP_DigestInit_ex(mDHashContext, digestName, nullptr) == 0) {
        throw Exception('decryptStream::EVP_DigestInit_ex failed');
      }

      await _decryptAndHashData(
        inputStream: inputStream,
        cipherContext: cipherContext,
        mDHashContext: mDHashContext,
        outIoSink: outIoSink,
        intPointer: intPointer,
      );

      final hashBase64Encoded = _getHashBase64Encoded(hashSizePointer, mDHashContext, hashValuePointer);

      return hashBase64Encoded == encryptedFileInfo.hashes[messageDigestAlgorithm];
    } catch (e) {
      throw Exception(e);
    } finally {
      malloc.free(memNeeded);
      _freeContexts(mDHashContext, cipherContext);
      await outIoSink?.close();
    }
  }

  Future<void> _decryptAndHashData({
    required Stream<List<int>> inputStream,
    required Pointer<NativeType> cipherContext,
    required Pointer<IntPtr> intPointer,
    required IOSink? outIoSink,
    required Pointer<NativeType> mDHashContext,
  }) async {
    await inputStream.forEach((bytes) {
      final memData = malloc.call<Uint8>(sizeOf<IntPtr>() + bytes.length);
      final dataPointer = memData.elementAt(sizeOf<IntPtr>());
      dataPointer.asTypedList(bytes.length).setAll(0, bytes);
      if (EVP_DigestUpdate(mDHashContext, dataPointer, bytes.length) == 0) {
        malloc.free(memData);
        throw Exception('decryptAndHashData::EVP_DigestUpdate failed');
      }
      if (EVP_EncryptUpdate(cipherContext, dataPointer, intPointer, dataPointer, bytes.length) == 0) {
        malloc.free(memData);
        throw Exception('decryptAndHashData::EVP_EncryptUpdate failed');
      }
      outIoSink!.add(Uint8List.fromList(dataPointer.asTypedList(bytes.length)));
      malloc.free(memData);
    });
  }

  Uint8List _base64decodeUnpadded(String value) {
    return base64decodeUnpadded(base64.normalize(value));
  }
}

final Cipher aesCtr = _AesCtr();

class _AesCtr extends Cipher {
  _AesCtr() : super._();

  @override
  Pointer<NativeType> getAlg(int keysize) {
    switch (keysize) {
      case 128:
        return EVP_aes_128_ctr();
      case 256:
        return EVP_aes_256_ctr();
      default:
        throw ArgumentError('invalid key size');
    }
  }
}

FutureOr<Uint8List> pbkdf2(
    Uint8List passphrase, Uint8List salt, Hash hash, int iterations, int bits) {
  final outLen = bits ~/ 8;
  final mem = malloc.call<Uint8>(passphrase.length + salt.length + outLen);
  final saltMem = mem.elementAt(passphrase.length);
  final outMem = saltMem.elementAt(salt.length);
  try {
    mem.asTypedList(passphrase.length).setAll(0, passphrase);
    saltMem.asTypedList(salt.length).setAll(0, salt);
    PKCS5_PBKDF2_HMAC(mem, passphrase.length, saltMem, salt.length, iterations,
        hash.ptr, outLen, outMem);
    return Uint8List.fromList(outMem.asTypedList(outLen));
  } finally {
    malloc.free(mem);
  }
}