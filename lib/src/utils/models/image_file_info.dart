import 'package:matrix/matrix.dart';

class ImageFileInfo extends FileInfo {
  ImageFileInfo(
    super.fileName, 
    super.filePath,
    super.fileSize, {
      super.readStream,
      super.progressCallback,
      this.width,
      this.height,
    }
  );
  
  final int? width;

  final int? height;

  @override
  Map<String, dynamic> get metadata => ({
        'mimetype': mimeType,
        'size': fileSize,
        'w': width,
        'h': height,
      });

  @override
  List<Object?> get props => [width, height, ...super.props];
}