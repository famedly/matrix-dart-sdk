import 'dart:typed_data';

import 'package:matrix/matrix.dart';

class VideoFileInfo extends FileInfo {

  final Uint8List imagePlaceholderBytes;

  final Duration? duration;

  final int? width;
  
  final int? height;

  VideoFileInfo(
    super.fileName,
    super.filePath,
    super.fileSize, {
      required this.imagePlaceholderBytes,
      this.width,
      this.height,
      this.duration,
    }
  );
  
  @override
  List<Object?> get props => [
    width, height, duration, imagePlaceholderBytes, ...super.props,
  ];
}