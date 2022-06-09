import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:hive/hive.dart';

import 'crypto.dart';

/// extends the [HiveAesCipher] by using OpenSSL as AES implementation
class HiveAesLibCryptoCipher extends HiveAesCipher {
  late final Uint8List _key;
  HiveAesLibCryptoCipher(List<int> key)
      : assert(key.length == 32 && key.every((it) => it > 0 || it <= 255),
            'The encryption key has to be a 32 byte (256 bit) array.'),
        _key = Uint8List.fromList(key),
        super(key);

  @override
  Future<int> decrypt(Uint8List inp, int inpOff, int inpLength, Uint8List out,
      int outOff) async {
    /// preparing the [SecretBox] with the range from the [inpOff] in the [inp]
    final secretBox = SecretBox.fromConcatenation(inp.view(inpOff, inpLength),
        nonceLength: 16, macLength: 0);

    /// decrypting
    final result = await AesCtr.with256bits(macAlgorithm: MacAlgorithm.empty)
        .decrypt(secretBox, secretKey: SecretKey(_key));

    /// save the clear text in the [out]
    out.setRange(outOff, outOff + result.length, result);

    /// return the clear text length as new offset
    return result.length;
  }

  @override
  Future<int> encrypt(Uint8List inp, int inpOff, int inpLength, Uint8List out,
      int outOff) async {
    final algo = aesCtr;

    /// generating new nonce / iv
    final random = Random.secure();
    final iv =
        Uint8List.fromList(List.generate(16, (index) => random.nextInt(255)));

    /// encrypt the next [inpLength] bytes of the [inp] starting from [inpOff]
    ///
    /// concentrating the encrypted text, nonce / iv and mac
    final concentration = Uint8List.fromList(
        [...iv, ...await algo.encrypt(inp.view(inpOff, inpLength), _key, iv)]);

    /// save the encrypted bytes in the [out]
    final outOffset = outOff + concentration.length;
    if (outOffset > out.length) {
      final previousOut = Uint8List.fromList(out);
      out = Uint8List(outOffset)..setRange(0, previousOut.length, previousOut);
    }
    out.setRange(outOff, outOffset, concentration);

    /// return the supposed step-off
    return concentration.length;
  }
}

/// Not part of public API
extension Uint8ListX on Uint8List {
  /// Not part of public API
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  Uint8List view(int offset, int bytes) {
    return Uint8List.view(buffer, offsetInBytes + offset, bytes);
  }
}
