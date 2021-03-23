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

final EVP_sha512 = libcrypto.lookupFunction<
  Pointer<NativeType> Function(),
  Pointer<NativeType> Function()
>('EVP_sha512');
