/// Workaround until [File] in dart:io and dart:html is unified
class MatrixFile {
  List<int> bytes;
  String path;

  MatrixFile({this.bytes, String path}) : this.path = path.toLowerCase();
  int get size => bytes.length;
}
