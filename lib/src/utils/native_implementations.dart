// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:matrix/encryption.dart';
import 'package:matrix/encryption/utils/base64_unpadded.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/compute_callback.dart';
import 'package:vodozemac/vodozemac.dart';

/// provides native implementations for demanding arithmetic operations
/// in order to prevent the UI from blocking
///
/// possible implementations might be:
/// - native code
/// - another Dart isolate
/// - a web worker
/// - a dummy implementations
///
/// Rules for extension (important for [noSuchMethod] implementations)
/// - always only accept exactly *one* positioned argument
/// - catch the corresponding case in [NativeImplementations.noSuchMethod]
/// - always write a dummy implementations
abstract class NativeImplementations {
  const NativeImplementations();

  /// a dummy implementation executing all calls in the same thread causing
  /// the UI to likely freeze
  static const dummy = NativeImplementationsDummy();

  FutureOr<RoomKeys> generateUploadKeys(
    GenerateUploadKeysArgs args, {
    bool retryInDummy = true,
  });

  FutureOr<Uint8List> keyFromPassphrase(
    KeyFromPassphraseArgs args, {
    bool retryInDummy = true,
  });

  FutureOr<Uint8List?> decryptFile(
    EncryptedFile file, {
    bool retryInDummy = true,
  });

  FutureOr<MatrixImageFileResizedResponse?> shrinkImage(
    MatrixImageFileResizeArguments args, {
    bool retryInDummy = false,
  });

  FutureOr<MatrixImageFileResizedResponse?> calcImageMetadata(
    Uint8List bytes, {
    bool retryInDummy = false,
  });

  FutureOr<bool> checkSecretStorageKey(CheckSecretStorageKeyArgs args);

  /// this implementation will catch any non-implemented method
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final dynamic argument = invocation.positionalArguments.single;
    final memberName = invocation.memberName.toString().split('"')[1];

    Logs().d(
      'Missing implementations of Client.nativeImplementations.$memberName. '
      'You should consider implementing it. '
      'Fallback from NativeImplementations.dummy used.',
    );
    switch (memberName) {
      // we need to pass the futures right through or we will run into type errors later!
      case 'generateUploadKeys':
        // ignore: discarded_futures
        return dummy.generateUploadKeys(argument);
      case 'keyFromPassphrase':
        // ignore: discarded_futures
        return dummy.keyFromPassphrase(argument);
      case 'decryptFile':
        // ignore: discarded_futures
        return dummy.decryptFile(argument);
      case 'shrinkImage':
        return dummy.shrinkImage(argument);
      case 'calcImageMetadata':
        return dummy.calcImageMetadata(argument);
      case 'checkSecretStorageKey':
        return dummy.checkSecretStorageKey(argument);
      default:
        return super.noSuchMethod(invocation);
    }
  }
}

class CheckSecretStorageKeyArgs {
  final Uint8List key;
  final String iv;
  final String mac;

  const CheckSecretStorageKeyArgs({
    required this.key,
    required this.iv,
    required this.mac,
  });
}

class NativeImplementationsDummy extends NativeImplementations {
  const NativeImplementationsDummy();

  @override
  Future<Uint8List?> decryptFile(
    EncryptedFile file, {
    bool retryInDummy = true,
  }) {
    return decryptFileImplementation(file);
  }

  @override
  Future<RoomKeys> generateUploadKeys(
    GenerateUploadKeysArgs args, {
    bool retryInDummy = true,
  }) async {
    return generateUploadKeysImplementation(args);
  }

  @override
  Future<Uint8List> keyFromPassphrase(
    KeyFromPassphraseArgs args, {
    bool retryInDummy = true,
  }) {
    return generateKeyFromPassphrase(args);
  }

  @override
  MatrixImageFileResizedResponse? shrinkImage(
    MatrixImageFileResizeArguments args, {
    bool retryInDummy = false,
  }) {
    return MatrixImageFile.resizeImplementation(args);
  }

  @override
  MatrixImageFileResizedResponse? calcImageMetadata(
    Uint8List bytes, {
    bool retryInDummy = false,
  }) {
    return MatrixImageFile.calcMetadataImplementation(bytes);
  }

  @override
  FutureOr<bool> checkSecretStorageKey(CheckSecretStorageKeyArgs args) {
    final iv = base64decodeUnpadded(args.iv);
    iv[8] &= 0x7f;

    final zerosalt = Uint8List(8);
    final prk = CryptoUtils.hmac(key: zerosalt, input: args.key);
    final b = Uint8List(1);

    b[0] = 1;
    final aesKey = CryptoUtils.hmac(key: prk, input: utf8.encode('') + b);

    b[0] = 2;
    final hmacKey = CryptoUtils.hmac(
      key: prk,
      input: aesKey + utf8.encode('') + b,
    );

    const zeroStr =
        '\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
        '\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00';

    final plain = Uint8List.fromList(utf8.encode(zeroStr));
    final ciphertext = CryptoUtils.aesCtr(
      input: plain,
      key: Uint8List.fromList(aesKey),
      iv: iv,
    );
    final computedMac = CryptoUtils.hmac(
      key: Uint8List.fromList(hmacKey),
      input: ciphertext,
    );

    final expected = args.mac.replaceAll(RegExp(r'=+$'), '');
    final actual = base64.encode(computedMac).replaceAll(RegExp(r'=+$'), '');
    return expected == actual;
  }
}

/// a [NativeImplementations] based on Flutter's `compute` function
///
/// this implementations simply wraps the given [compute] function around
/// the implementation of [NativeImplementations.dummy]
class NativeImplementationsIsolate extends NativeImplementations {
  /// pass by Flutter's compute function here
  final ComputeCallback compute;
  final Future<void> Function()? vodozemacInit;

  NativeImplementationsIsolate(
    this.compute, {

    /// To generate upload keys, vodozemac needs to be initialized in the isolate.
    this.vodozemacInit,
  });

  Future<T> runInBackground<T, U>(
    FutureOr<T> Function(U arg) function,
    U arg,
  ) async {
    final compute = this.compute;
    return await compute(function, arg);
  }

  @override
  Future<Uint8List?> decryptFile(
    EncryptedFile file, {
    bool retryInDummy = true,
  }) {
    return runInBackground<Uint8List?, EncryptedFile>((
      EncryptedFile args,
    ) async {
      await vodozemacInit?.call();
      return NativeImplementations.dummy.decryptFile(args);
    }, file);
  }

  @override
  Future<RoomKeys> generateUploadKeys(
    GenerateUploadKeysArgs args, {
    bool retryInDummy = true,
  }) async {
    return runInBackground<RoomKeys, GenerateUploadKeysArgs>((
      GenerateUploadKeysArgs args,
    ) async {
      await vodozemacInit?.call();
      return NativeImplementations.dummy.generateUploadKeys(args);
    }, args);
  }

  @override
  Future<Uint8List> keyFromPassphrase(
    KeyFromPassphraseArgs args, {
    bool retryInDummy = true,
  }) {
    return runInBackground<Uint8List, KeyFromPassphraseArgs>((
      KeyFromPassphraseArgs args,
    ) async {
      await vodozemacInit?.call();
      return NativeImplementations.dummy.keyFromPassphrase(args);
    }, args);
  }

  @override
  Future<MatrixImageFileResizedResponse?> shrinkImage(
    MatrixImageFileResizeArguments args, {
    bool retryInDummy = false,
  }) {
    return runInBackground<
      MatrixImageFileResizedResponse?,
      MatrixImageFileResizeArguments
    >(NativeImplementations.dummy.shrinkImage, args);
  }

  @override
  FutureOr<MatrixImageFileResizedResponse?> calcImageMetadata(
    Uint8List bytes, {
    bool retryInDummy = false,
  }) {
    return runInBackground<MatrixImageFileResizedResponse?, Uint8List>(
      NativeImplementations.dummy.calcImageMetadata,
      bytes,
    );
  }

  @override
  Future<bool> checkSecretStorageKey(CheckSecretStorageKeyArgs args) {
    return runInBackground<bool, CheckSecretStorageKeyArgs>((
      CheckSecretStorageKeyArgs args,
    ) async {
      await vodozemacInit?.call();
      return NativeImplementations.dummy.checkSecretStorageKey(args);
    }, args);
  }
}
