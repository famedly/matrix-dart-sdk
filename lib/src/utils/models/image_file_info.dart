import 'package:matrix/matrix.dart';

class ImageFileInfo extends FileInfo {
  ImageFileInfo(
    super.fileName, 
    super.filePath, 
    super.fileSize, {
      this.width,
      this.height,
    }
  );
  
  final int? width;

  final int? height;

  @override
  List<Object?> get props => [width, height, ...super.props];
}