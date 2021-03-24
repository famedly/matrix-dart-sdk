import 'dart:ffi';
import 'dart:io';

final libcrypto = Platform.isIOS
    ? DynamicLibrary.process()
    : DynamicLibrary.open(Platform.isAndroid
        ? 'libcrypto.so'
        : Platform.isWindows
            ? 'libcrypto.dll'
            : Platform.isMacOS ? 'libcrypto.1.1.dylib' : 'libcrypto.so.1.1');

final PKCS5_PBKDF2_HMAC = libcrypto.lookupFunction<
  IntPtr Function(Pointer<Uint8> pass, IntPtr passlen, Pointer<Uint8> salt, IntPtr saltlen, IntPtr iter, Pointer<NativeType> digest, IntPtr keylen, Pointer<Uint8> out),
  int Function(Pointer<Uint8> pass, int passlen, Pointer<Uint8> salt, int saltlen, int iter, Pointer<NativeType> digest, int keylen, Pointer<Uint8> out)
>('PKCS5_PBKDF2_HMAC');

final EVP_sha1 = libcrypto.lookupFunction<
  Pointer<NativeType> Function(),
  Pointer<NativeType> Function()
>('EVP_sha1');

final EVP_sha256 = libcrypto.lookupFunction<
  Pointer<NativeType> Function(),
  Pointer<NativeType> Function()
>('EVP_sha256');

final EVP_sha512 = libcrypto.lookupFunction<
  Pointer<NativeType> Function(),
  Pointer<NativeType> Function()
>('EVP_sha512');

final EVP_aes_128_ctr = libcrypto.lookupFunction<
  Pointer<NativeType> Function(),
  Pointer<NativeType> Function()
>('EVP_aes_128_ctr');

final EVP_aes_256_ctr = libcrypto.lookupFunction<
  Pointer<NativeType> Function(),
  Pointer<NativeType> Function()
>('EVP_aes_256_ctr');

final EVP_CIPHER_CTX_new = libcrypto.lookupFunction<
  Pointer<NativeType> Function(),
  Pointer<NativeType> Function()
>('EVP_CIPHER_CTX_new');

final EVP_EncryptInit_ex = libcrypto.lookupFunction<
  Pointer<NativeType> Function(Pointer<NativeType> ctx, Pointer<NativeType> alg, Pointer<NativeType> some, Pointer<Uint8> key, Pointer<Uint8> iv),
  Pointer<NativeType> Function(Pointer<NativeType> ctx, Pointer<NativeType> alg, Pointer<NativeType> some, Pointer<Uint8> key, Pointer<Uint8> iv)
>('EVP_EncryptInit_ex');

final EVP_EncryptUpdate = libcrypto.lookupFunction<
  Pointer<NativeType> Function(Pointer<NativeType> ctx, Pointer<Uint8> output, Pointer<IntPtr> outputLen, Pointer<Uint8> input, IntPtr inputLen),
  Pointer<NativeType> Function(Pointer<NativeType> ctx, Pointer<Uint8> output, Pointer<IntPtr> outputLen, Pointer<Uint8> input, int inputLen)
>('EVP_EncryptUpdate');

final EVP_EncryptFinal_ex = libcrypto.lookupFunction<
  Pointer<NativeType> Function(Pointer<NativeType> ctx, Pointer<Uint8> data, Pointer<IntPtr> len),
  Pointer<NativeType> Function(Pointer<NativeType> ctx, Pointer<Uint8> data, Pointer<IntPtr> len)
>('EVP_EncryptFinal_ex');

final EVP_CIPHER_CTX_free = libcrypto.lookupFunction<
  Pointer<NativeType> Function(Pointer<NativeType> ctx),
  Pointer<NativeType> Function(Pointer<NativeType> ctx)
>('EVP_CIPHER_CTX_free');
