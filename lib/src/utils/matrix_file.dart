/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020, 2021 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

/// Workaround until [File] in dart:io and dart:html is unified

import 'dart:async';
import 'dart:typed_data';

import 'package:blurhash_dart/blurhash_dart.dart';
import 'package:image/image.dart';
import 'package:mime/mime.dart';

import '../../matrix.dart';

class MatrixFile {
  final Uint8List bytes;
  final String name;
  final String mimeType;

  /// Encrypts this file and returns the
  /// encryption information as an [EncryptedFile].
  Future<EncryptedFile> encrypt() async {
    return await encryptFile(bytes);
  }

  MatrixFile({required this.bytes, required String name, String? mimeType})
      : mimeType = mimeType ??
            lookupMimeType(name, headerBytes: bytes) ??
            'application/octet-stream',
        name = name.split('/').last.toLowerCase();

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
  MatrixImageFile({
    required Uint8List bytes,
    required String name,
    String? mimeType,
    this.width,
    this.height,
    this.blurhash,
  }) : super(bytes: bytes, name: name, mimeType: mimeType);

  /// Creates a new image file and calculates the width, height and blurhash.
  static Future<MatrixImageFile> create(
      {required Uint8List bytes,
      required String name,
      String? mimeType,
      Future<T> Function<T, U>(FutureOr<T> Function(U arg) function, U arg)?
          compute}) async {
    final metaData = compute != null
        ? await compute(_calcMetadata, bytes)
        : _calcMetadata(bytes);

    return MatrixImageFile(
      bytes: metaData?.bytes ?? bytes,
      name: name,
      mimeType: mimeType,
      width: metaData?.width,
      height: metaData?.height,
      blurhash: metaData?.blurhash,
    );
  }

  /// builds a [MatrixImageFile] and shrinks it in order to reduce traffic
  ///
  /// in case shrinking does not work (e.g. for unsupported MIME types), the
  /// initial image is simply preserved
  static Future<MatrixImageFile> shrink(
      {required Uint8List bytes,
      required String name,
      int maxDimension = 1600,
      String? mimeType,
      Future<MatrixImageFileResizedResponse?> Function(
              MatrixImageFileResizeArguments)?
          customImageResizer,
      Future<T> Function<T, U>(FutureOr<T> Function(U arg) function, U arg)?
          compute}) async {
    final arguments = MatrixImageFileResizeArguments(
      bytes: bytes,
      maxDimension: maxDimension,
      fileName: name,
      calcBlurhash: true,
    );
    final resizedData = customImageResizer != null
        ? await customImageResizer(arguments)
        : compute != null
            ? await compute(_resize, arguments)
            : _resize(arguments);

    if (resizedData == null) {
      return MatrixImageFile(bytes: bytes, name: name, mimeType: mimeType);
    }

    final thumbnailFile = MatrixImageFile(
      bytes: resizedData.bytes,
      name: name,
      mimeType: mimeType,
      width: resizedData.width,
      height: resizedData.height,
      blurhash: resizedData.blurhash,
    );
    return thumbnailFile;
  }

  /// returns the width of the image
  final int? width;

  /// returns the height of the image
  final int? height;

  /// generates the blur hash for the image
  final String? blurhash;

  @override
  String get msgType => 'm.image';
  @override
  Map<String, dynamic> get info => ({
        ...super.info,
        if (width != null) 'w': width,
        if (height != null) 'h': height,
        if (blurhash != null) 'xyz.amorgan.blurhash': blurhash,
      });

  /// computes a thumbnail for the image
  Future<MatrixImageFile?> generateThumbnail(
      {int dimension = Client.defaultThumbnailSize,
      Future<MatrixImageFileResizedResponse?> Function(
              MatrixImageFileResizeArguments)?
          customImageResizer,
      Future<T> Function<T, U>(FutureOr<T> Function(U arg) function, U arg)?
          compute}) async {
    final thumbnailFile = await shrink(
      bytes: bytes,
      name: name,
      mimeType: mimeType,
      compute: compute,
      maxDimension: dimension,
      customImageResizer: customImageResizer,
    );
    // the thumbnail should rather return null than the unshrinked image
    if ((thumbnailFile.width ?? 0) > dimension ||
        (thumbnailFile.height ?? 0) > dimension) {
      return null;
    }
    return thumbnailFile;
  }

  static MatrixImageFileResizedResponse? _calcMetadata(Uint8List bytes) {
    final image = decodeImage(bytes);
    if (image == null) return null;

    return MatrixImageFileResizedResponse(
      bytes: bytes,
      width: image.width,
      height: image.height,
      blurhash: BlurHash.encode(
        image,
        numCompX: 4,
        numCompY: 3,
      ).hash,
    );
  }

  static MatrixImageFileResizedResponse? _resize(
      MatrixImageFileResizeArguments arguments) {
    final image = decodeImage(arguments.bytes);

    final resized = copyResize(image!,
        height: image.height > image.width ? arguments.maxDimension : null,
        width: image.width >= image.height ? arguments.maxDimension : null);

    final encoded = encodeNamedImage(resized, arguments.fileName);
    if (encoded == null) return null;
    final bytes = Uint8List.fromList(encoded);
    return MatrixImageFileResizedResponse(
      bytes: bytes,
      width: resized.width,
      height: resized.height,
      blurhash: arguments.calcBlurhash
          ? BlurHash.encode(
              resized,
              numCompX: 4,
              numCompY: 3,
            ).hash
          : null,
    );
  }
}

class MatrixImageFileResizedResponse {
  final Uint8List bytes;
  final int width;
  final int height;
  final String? blurhash;

  const MatrixImageFileResizedResponse({
    required this.bytes,
    required this.width,
    required this.height,
    this.blurhash,
  });
}

class MatrixImageFileResizeArguments {
  final Uint8List bytes;
  final int maxDimension;
  final String fileName;
  final bool calcBlurhash;

  const MatrixImageFileResizeArguments({
    required this.bytes,
    required this.maxDimension,
    required this.fileName,
    required this.calcBlurhash,
  });
}

class MatrixVideoFile extends MatrixFile {
  final int? width;
  final int? height;
  final int? duration;

  MatrixVideoFile(
      {required Uint8List bytes,
      required String name,
      String? mimeType,
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
  final int? duration;

  MatrixAudioFile(
      {required Uint8List bytes,
      required String name,
      String? mimeType,
      this.duration})
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
