/// Workaround until [File] in dart:io and dart:html is unified

import 'dart:typed_data';

import 'package:matrix_file_e2ee/matrix_file_e2ee.dart';

class MatrixFile {
  Uint8List bytes;
  String path;

  /// Encrypts this file, changes the [bytes] and returns the
  /// encryption information as an [EncryptedFile].
  Future<EncryptedFile> encrypt() async {
    var encryptFile2 = encryptFile(bytes);
    final encryptedFile = await encryptFile2;
    bytes = encryptedFile.data;
    return encryptedFile;
  }

  MatrixFile({this.bytes, String path}) : path = path.toLowerCase();
  int get size => bytes.length;
}
