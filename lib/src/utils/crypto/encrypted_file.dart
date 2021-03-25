import 'dart:typed_data';
import 'dart:convert';

import 'crypto.dart';

class EncryptedFile {
  EncryptedFile({
    this.data,
    this.k,
    this.iv,
    this.sha256,
  });
  Uint8List data;
  String k;
  String iv;
  String sha256;
}

Future<EncryptedFile> encryptFile(Uint8List input) async {
  final key = secureRandomBytes(32);
  final iv = secureRandomBytes(16);
  final data = await aesCtr.encrypt(input, key, iv);
  final hash = await sha256(data);
  return EncryptedFile(
    data: data,
    k: base64Url.encode(key).replaceAll('=', ''),
    iv: base64.encode(iv).replaceAll('=', ''),
    sha256: base64.encode(hash).replaceAll('=', ''),
  );
}

Future<Uint8List> decryptFile(EncryptedFile input) async {
  if (base64.encode(await sha256(input.data)) != base64.normalize(input.sha256)) {
    return null;
  }

  final key = base64.decode(base64.normalize(input.k));
  final iv = base64.decode(base64.normalize(input.iv));
  return await aesCtr.encrypt(input.data, key, iv);
}
