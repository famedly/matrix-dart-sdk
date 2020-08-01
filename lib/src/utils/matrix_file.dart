/// Workaround until [File] in dart:io and dart:html is unified

import 'dart:typed_data';
import 'package:famedlysdk/matrix_api/model/message_types.dart';
import 'package:matrix_file_e2ee/matrix_file_e2ee.dart';
import 'package:mime/mime.dart';

class MatrixFile {
  Uint8List bytes;
  String name;
  String mimeType;

  /// Encrypts this file and returns the
  /// encryption information as an [EncryptedFile].
  Future<EncryptedFile> encrypt() async {
    return await encryptFile(bytes);
  }

  MatrixFile({this.bytes, this.name, this.mimeType}) {
    mimeType ??= lookupMimeType(name, headerBytes: bytes);
    name = name.split('/').last.toLowerCase();
  }

  int get size => bytes.length;

  String get msgType {
    if (mimeType.toLowerCase().startsWith('image/')) {
      return MessageTypes.Image;
    }
    if (mimeType.toLowerCase().startsWith('video/')) {
      return MessageTypes.Video;
    }
    if (mimeType.toLowerCase().startsWith('audio/')) {
      return MessageTypes.Audio;
    }
    return MessageTypes.File;
  }

  Map<String, dynamic> get info => ({
        'mimetype': mimeType,
        'size': size,
      });
}

class MatrixImageFile extends MatrixFile {
  int width;
  int height;
  String blurhash;

  MatrixImageFile(
      {Uint8List bytes,
      String name,
      String mimeType,
      this.width,
      this.height,
      this.blurhash})
      : super(bytes: bytes, name: name, mimeType: mimeType);
  @override
  String get msgType => 'm.image';
  @override
  Map<String, dynamic> get info => ({
        ...super.info,
        if (width != null) 'w': width,
        if (height != null) 'h': height,
        if (blurhash != null) 'xyz.amorgan.blurhash': blurhash,
      });
}

class MatrixVideoFile extends MatrixFile {
  int width;
  int height;
  int duration;

  MatrixVideoFile(
      {Uint8List bytes,
      String name,
      String mimeType,
      this.width,
      this.height,
      this.duration})
      : super(bytes: bytes, name: name, mimeType: mimeType);
  @override
  String get msgType => 'm.video';
  @override
  Map<String, dynamic> get info => ({
        ...super.info,
        if (width != null) 'w': width,
        if (height != null) 'h': height,
        if (duration != null) 'duration': duration,
      });
}

class MatrixAudioFile extends MatrixFile {
  int duration;

  MatrixAudioFile(
      {Uint8List bytes, String name, String mimeType, this.duration})
      : super(bytes: bytes, name: name, mimeType: mimeType);
  @override
  String get msgType => 'm.audio';
  @override
  Map<String, dynamic> get info => ({
        ...super.info,
        if (duration != null) 'duration': duration,
      });
}

extension ToMatrixFile on EncryptedFile {
  MatrixFile toMatrixFile() {
    return MatrixFile(
        bytes: data, name: 'crypt', mimeType: 'application/octet-stream');
  }
}
