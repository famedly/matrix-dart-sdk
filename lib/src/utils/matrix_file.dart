/// Workaround until [File] in dart:io and dart:html is unified

import 'dart:typed_data';

class MatrixFile {
  Uint8List bytes;
  String path;

  MatrixFile({this.bytes, String path}) : this.path = path.toLowerCase();
  int get size => bytes.length;
}
