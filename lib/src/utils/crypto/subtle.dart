// Copyright (c) 2020 Famedly GmbH
// SPDX-License-Identifier: AGPL-3.0-or-later

@JS()
library subtle;

import 'package:js/js.dart';
import 'dart:async';
import 'dart:js_util';
import 'dart:typed_data';

@JS()
class CryptoKey {}

@JS()
@anonymous
class Pbkdf2Params {
  external factory Pbkdf2Params({String name, String hash, Uint8List salt, int iterations});
  String name;
  String hash;
  Uint8List salt;
  int iterations;
}

@JS()
@anonymous
class AesCtrParams {
  external factory AesCtrParams({String name, Uint8List counter, int length});
  String name;
  Uint8List counter;
  int length;
}

@JS('crypto.subtle.encrypt')
external dynamic _encrypt(dynamic algorithm, CryptoKey key, Uint8List data);

Future<ByteBuffer> encrypt(dynamic algorithm, CryptoKey key, Uint8List data) {
  return promiseToFuture(_encrypt(algorithm, key, data));
}

@JS('crypto.subtle.decrypt')
external dynamic _decrypt(dynamic algorithm, CryptoKey key, Uint8List data);

Future<ByteBuffer> decrypt(dynamic algorithm, CryptoKey key, Uint8List data) {
  return promiseToFuture(_decrypt(algorithm, key, data));
}

@JS('crypto.subtle.importKey')
external dynamic _importKey(String format, dynamic keyData, dynamic algorithm,
    bool extractable, List<String> keyUsages);

Future<CryptoKey> importKey(String format, dynamic keyData, dynamic algorithm,
    bool extractable, List<String> keyUsages) {
  return promiseToFuture(
      _importKey(format, keyData, algorithm, extractable, keyUsages));
}

@JS('crypto.subtle.exportKey')
external dynamic _exportKey(String algorithm, CryptoKey key);

Future<dynamic> exportKey(String algorithm, CryptoKey key) {
  return promiseToFuture(_exportKey(algorithm, key));
}

@JS('crypto.subtle.deriveKey')
external dynamic _deriveKey(dynamic algorithm, CryptoKey baseKey, dynamic derivedKeyAlgorithm, bool extractable, List<String> keyUsages);

Future<ByteBuffer> deriveKey(dynamic algorithm, CryptoKey baseKey, dynamic derivedKeyAlgorithm, bool extractable, List<String> keyUsages) {
  return promiseToFuture(_deriveKey(algorithm, baseKey, derivedKeyAlgorithm, extractable, keyUsages));
}

@JS('crypto.subtle.deriveBits')
external dynamic _deriveBits(dynamic algorithm, CryptoKey baseKey, int length);

Future<ByteBuffer> deriveBits(dynamic algorithm, CryptoKey baseKey, int length) {
  return promiseToFuture(_deriveBits(algorithm, baseKey, length));
}

@JS('crypto.subtle.digest')
external dynamic _digest(String algorithm, Uint8List data);

Future<ByteBuffer> digest(String algorithm, Uint8List data) {
  return promiseToFuture(_digest(algorithm, data));
}
