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
  Map<String, dynamic> get metadata => ({
        'mimetype': mimeType,
        'size': fileSize,
        'w': width?.toDouble(),
        'h': height?.toDouble(),
      });

  @override
  List<Object?> get props => [width, height, ...super.props];
}