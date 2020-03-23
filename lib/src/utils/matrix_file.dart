/// Workaround until [File] in dart:io and dart:html is unified

import 'dart:typed_data';

import 'package:matrix_file_e2ee/matrix_file_e2ee.dart';

class MatrixFile {
  Uint8List bytes;
  String path;

  /// Encrypts this file, changes the [bytes] and returns the
  /// encryption information as an [EncryptedFile].
  Future<EncryptedFile> encrypt() async {
    final EncryptedFile encryptedFile = await encryptFile(bytes);
    this.bytes = encryptedFile.data;
    return encryptedFile;
  }

  MatrixFile({this.bytes, String path}) : this.path = path.toLowerCase();
  int get size => bytes.length;
}
