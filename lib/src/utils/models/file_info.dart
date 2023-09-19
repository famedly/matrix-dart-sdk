
import 'package:equatable/equatable.dart';
import 'package:mime/mime.dart';

class FileInfo with EquatableMixin {
  final String fileName;
  final String filePath;
  final int fileSize;
  final Stream<List<int>>? readStream;

  FileInfo(this.fileName, this.filePath, this.fileSize, {this.readStream});

  factory FileInfo.empty() {
    return FileInfo('', '', 0);
  }

  String get mimeType =>
      lookupMimeType(filePath) ?? 
      lookupMimeType(fileName) ??
      'application/octet-stream';

  Map<String, dynamic> get metadata => ({
        'mimetype': mimeType,
        'size': fileSize,
      });

  @override
  List<Object?> get props => [fileName, filePath, fileSize, readStream];
}