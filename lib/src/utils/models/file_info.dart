
import 'package:equatable/equatable.dart';

class FileInfo with EquatableMixin {
  final String fileName;
  final String filePath;
  final int fileSize;
  final Stream<List<int>>? readStream;

  FileInfo(this.fileName, this.filePath, this.fileSize, {this.readStream});

  factory FileInfo.empty() {
    return FileInfo('', '', 0);
  }

  @override
  List<Object?> get props => [fileName, filePath, fileSize, readStream];
}