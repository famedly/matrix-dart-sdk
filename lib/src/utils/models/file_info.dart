
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:matrix/matrix.dart';
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
  

  FileInfo fromMatrixFile(MatrixFile file) {
    if (file.msgType == MessageTypes.Image) {
      return ImageFileInfo(
        fileName,
        filePath,
        fileSize,
        width: file.info['w'],
        height: file.info['h'],
      );
    } else if (file.msgType == MessageTypes.Video) {
      return VideoFileInfo(
        fileName,
        filePath,
        fileSize,
        imagePlaceholderBytes: file.bytes ?? Uint8List(0),
        width: file.info['w'],
        height: file.info['h'],
        duration: file.info['duration'],
      );
    }
    return FileInfo(fileName, filePath, fileSize, readStream: readStream);
  }

  @override
  List<Object?> get props => [fileName, filePath, fileSize, readStream];
}