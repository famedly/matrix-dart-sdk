/// Workaround until [File] in dart:io and dart:html is unified

import 'dart:typed_data';

import 'package:image/image.dart';
import 'package:matrix_file_e2ee/matrix_file_e2ee.dart';

class MatrixFile {
  Uint8List bytes;
  String path;

  /// If this file is an Image, this will resize it to the
  /// given width and height. Otherwise returns false.
  /// At least width or height must be set!
  /// The bytes will be encoded as jpg.
  Future<bool> resize({
    int width,
    int height,
    int quality = 50,
  }) async {
    if (width == null && height == null) {
      throw ('At least width or height must be set!');
    }
    Image image;
    try {
      image = decodeImage(bytes);
    } catch (_) {
      return false;
    }
    var resizedImage = image;
    if (image.width > width) {
      resizedImage = copyResize(image, width: width);
    }
    if (image.height > height) {
      resizedImage = copyResize(image, height: height);
    }
    bytes = encodeJpg(resizedImage, quality: quality);
    return true;
  }

  /// Encrypts this file, changes the [bytes] and returns the
  /// encryption information as an [EncryptedFile].
  Future<EncryptedFile> encrypt() async {
    var encryptFile2 = encryptFile(bytes);
    final encryptedFile = await encryptFile2;
    bytes = encryptedFile.data;
    return encryptedFile;
  }

  MatrixFile({this.bytes, String path}) : path = path.toLowerCase();
  int get size => bytes.length;
}
