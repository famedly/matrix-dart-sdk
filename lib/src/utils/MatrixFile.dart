class MatrixFile {
  List<int> bytes;
  String path;

  MatrixFile({this.bytes, this.path});

  Future<List<int>> readAsBytes() async => bytes;
}
