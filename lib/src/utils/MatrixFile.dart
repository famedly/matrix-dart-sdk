class MatrixFile {
  List<int> bytes;
  String path;

  MatrixFile({this.bytes, this.path});
  int get size => bytes.length;
}
