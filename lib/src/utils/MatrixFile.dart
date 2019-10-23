class MatrixFile {
  List<int> bytes;
  String path;

  MatrixFile({this.bytes, String path}) : this.path = path.toLowerCase();
  int get size => bytes.length;
}
