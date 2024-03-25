import 'dart:typed_data';

class FileResponse {
  FileResponse({this.contentType, required this.data});
  String? contentType;
  Uint8List data;
}
