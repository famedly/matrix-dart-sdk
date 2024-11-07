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

import 'dart:ffi';
import 'dart:io';

final libcrypto = () {
  if (Platform.isIOS) {
    return DynamicLibrary.process();
  } else if (Platform.isAndroid) {
    return DynamicLibrary.open('libcrypto.so');
  } else if (Platform.isWindows) {
    return DynamicLibrary.open('libcrypto.dll');
  } else if (Platform.isMacOS) {
    try {
      return DynamicLibrary.open('libcrypto.3.dylib');
    } catch (_) {
      return DynamicLibrary.open('libcrypto.1.1.dylib');
    }
  } else {
    try {
      return DynamicLibrary.open('libcrypto.so.3');
    } catch (_) {
      return DynamicLibrary.open('libcrypto.so.1.1');
    }
  }
}();

final PKCS5_PBKDF2_HMAC = libcrypto.lookupFunction<
    IntPtr Function(
      Pointer<Uint8> pass,
      IntPtr passlen,
      Pointer<Uint8> salt,
      IntPtr saltlen,
      IntPtr iter,
      Pointer<NativeType> digest,
      IntPtr keylen,
      Pointer<Uint8> out,
    ),
    int Function(
      Pointer<Uint8> pass,
      int passlen,
      Pointer<Uint8> salt,
      int saltlen,
      int iter,
      Pointer<NativeType> digest,
      int keylen,
      Pointer<Uint8> out,
    )>('PKCS5_PBKDF2_HMAC');

final EVP_sha1 = libcrypto.lookupFunction<Pointer<NativeType> Function(),
    Pointer<NativeType> Function()>('EVP_sha1');

final EVP_sha256 = libcrypto.lookupFunction<Pointer<NativeType> Function(),
    Pointer<NativeType> Function()>('EVP_sha256');

final EVP_sha512 = libcrypto.lookupFunction<Pointer<NativeType> Function(),
    Pointer<NativeType> Function()>('EVP_sha512');

final EVP_aes_128_ctr = libcrypto.lookupFunction<Pointer<NativeType> Function(),
    Pointer<NativeType> Function()>('EVP_aes_128_ctr');

final EVP_aes_256_ctr = libcrypto.lookupFunction<Pointer<NativeType> Function(),
    Pointer<NativeType> Function()>('EVP_aes_256_ctr');

final EVP_CIPHER_CTX_new = libcrypto.lookupFunction<
    Pointer<NativeType> Function(),
    Pointer<NativeType> Function()>('EVP_CIPHER_CTX_new');

final EVP_EncryptInit_ex = libcrypto.lookupFunction<
    Pointer<NativeType> Function(
      Pointer<NativeType> ctx,
      Pointer<NativeType> alg,
      Pointer<NativeType> some,
      Pointer<Uint8> key,
      Pointer<Uint8> iv,
    ),
    Pointer<NativeType> Function(
      Pointer<NativeType> ctx,
      Pointer<NativeType> alg,
      Pointer<NativeType> some,
      Pointer<Uint8> key,
      Pointer<Uint8> iv,
    )>('EVP_EncryptInit_ex');

final EVP_EncryptUpdate = libcrypto.lookupFunction<
    Pointer<NativeType> Function(
      Pointer<NativeType> ctx,
      Pointer<Uint8> output,
      Pointer<IntPtr> outputLen,
      Pointer<Uint8> input,
      IntPtr inputLen,
    ),
    Pointer<NativeType> Function(
      Pointer<NativeType> ctx,
      Pointer<Uint8> output,
      Pointer<IntPtr> outputLen,
      Pointer<Uint8> input,
      int inputLen,
    )>('EVP_EncryptUpdate');

final EVP_EncryptFinal_ex = libcrypto.lookupFunction<
    Pointer<NativeType> Function(
      Pointer<NativeType> ctx,
      Pointer<Uint8> data,
      Pointer<IntPtr> len,
    ),
    Pointer<NativeType> Function(
      Pointer<NativeType> ctx,
      Pointer<Uint8> data,
      Pointer<IntPtr> len,
    )>('EVP_EncryptFinal_ex');

final EVP_CIPHER_CTX_free = libcrypto.lookupFunction<
    Pointer<NativeType> Function(Pointer<NativeType> ctx),
    Pointer<NativeType> Function(
      Pointer<NativeType> ctx,
    )>('EVP_CIPHER_CTX_free');

final EVP_Digest = libcrypto.lookupFunction<
    IntPtr Function(
      Pointer<Uint8> data,
      IntPtr len,
      Pointer<Uint8> hash,
      Pointer<IntPtr> hsize,
      Pointer<NativeType> alg,
      Pointer<NativeType> engine,
    ),
    int Function(
      Pointer<Uint8> data,
      int len,
      Pointer<Uint8> hash,
      Pointer<IntPtr> hsize,
      Pointer<NativeType> alg,
      Pointer<NativeType> engine,
    )>('EVP_Digest');

final EVP_MD_size = () {
  // EVP_MD_size was renamed to EVP_MD_get_size in Openssl3.0.
  // There is an alias macro, but those don't exist in libraries.
  // Try loading the new name first, then fall back to the old one if not found.
  try {
    return libcrypto.lookupFunction<IntPtr Function(Pointer<NativeType> ctx),
        int Function(Pointer<NativeType> ctx)>('EVP_MD_get_size');
  } catch (e) {
    return libcrypto.lookupFunction<IntPtr Function(Pointer<NativeType> ctx),
        int Function(Pointer<NativeType> ctx)>('EVP_MD_size');
  }
}();
