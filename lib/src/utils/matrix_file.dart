/// Workaround until [File] in dart:io and dart:html is unified

import 'dart:typed_data';

import 'package:matrix_file_e2ee/matrix_file_e2ee.dart';

class MatrixFile {
  Uint8List bytes;
  String path;

  Future<EncryptedFile> encrypt() async {
    print("[Matrix] Encrypt file with a size of ${bytes.length} bytes");
    final EncryptedFile encryptedFile = await encryptFile(bytes);
    print("[Matrix] File encryption successfull");
    this.bytes = encryptedFile.data;
    return encryptedFile;
  }

  MatrixFile({this.bytes, String path}) : this.path = path.toLowerCase();
  int get size => bytes.length;
}
