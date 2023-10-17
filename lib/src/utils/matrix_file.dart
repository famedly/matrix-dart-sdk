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
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:blurhash_dart/blurhash_dart.dart';
import 'package:image/image.dart';
import 'package:mime/mime.dart';

import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/compute_callback.dart';

class MatrixFile {
  final Uint8List? bytes;
  final String name;
  final String mimeType;
  final String? filePath;

  /// Encrypts this file and returns the
  /// encryption information as an [EncryptedFile].
  Future<EncryptedFile?> encrypt() async {
    if (bytes != null) {
      return await encryptFile(bytes!);
    }
    return null;
  }

  MatrixFile({this.bytes, required String name, String? mimeType, this.filePath})
      : mimeType = mimeType ??
            lookupMimeType(name, headerBytes: bytes) ??
            'application/octet-stream',
        name = name.split('/').last;

  /// derivatives the MIME type from the [bytes] and correspondingly creates a
  /// [MatrixFile], [MatrixImageFile], [MatrixAudioFile] or a [MatrixVideoFile]
  factory MatrixFile.fromMimeType(
      { Uint8List? bytes, required String name, String? mimeType, String? filePath}) {
    final msgType = msgTypeFromMime(mimeType ??
        lookupMimeType(name, headerBytes: bytes) ??
        'application/octet-stream');
    if (msgType == MessageTypes.Image) {
      return MatrixImageFile(name: name, mimeType: mimeType, filePath: filePath, bytes: bytes);
    }
    if (msgType == MessageTypes.Video) {
      return MatrixVideoFile(bytes: bytes, name: name, mimeType: mimeType, filePath: filePath);
    }
    if (msgType == MessageTypes.Audio && bytes != null) {
      return MatrixAudioFile(bytes: bytes, name: name, mimeType: mimeType, filePath: filePath);
    }
    return MatrixFile(bytes: bytes, name: name, mimeType: mimeType, filePath: filePath);
  }

  factory MatrixFile.fromFileInfo(
      {required FileInfo fileInfo}) {
    final msgType = msgTypeFromMime(fileInfo.mimeType);
    if (msgType == MessageTypes.Image) {
      return MatrixImageFile(
        name: fileInfo.fileName,
        mimeType: fileInfo.mimeType,
        filePath: fileInfo.filePath,
        bytes: null,
        width: (fileInfo.metadata['w'] as double?)?.toInt(),
        height: (fileInfo.metadata['h'] as double?)?.toInt(),
      );
    }
    if (msgType == MessageTypes.Video) {
      return MatrixVideoFile(
        bytes: fileInfo is VideoFileInfo 
          ? fileInfo.imagePlaceholderBytes
          : null,
        name: fileInfo.fileName,
        mimeType: fileInfo.mimeType,
        filePath: fileInfo.filePath,
        width: (fileInfo.metadata['w'] as double?)?.toInt(),
        height: (fileInfo.metadata['h'] as double?)?.toInt(),
        duration: fileInfo.metadata['duration'], 
      );
    }
    if (msgType == MessageTypes.Audio) {
      return MatrixAudioFile(
        bytes: Uint8List.fromList([]),
        name: fileInfo.fileName,
        mimeType: fileInfo.mimeType,
        filePath: fileInfo.filePath,
        duration: fileInfo.metadata['duration'],
      );
    }
    return MatrixFile(
      bytes: null,
      name: fileInfo.fileName,
      mimeType: fileInfo.mimeType,
      filePath: fileInfo.filePath,
    );
  }

  int get size => bytes?.length ?? 0;

  String get msgType {
    return msgTypeFromMime(mimeType);
  }

  Map<String, dynamic> get info => ({
        'mimetype': mimeType,
        'size': size,
      });

  static String msgTypeFromMime(String mimeType) {
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
}

class MatrixImageFile extends MatrixFile {
  MatrixImageFile({
    Uint8List? bytes,
    required String name,
    super.filePath,
    String? mimeType,
    int? width,
    int? height,
    this.blurhash,
  })  : _width = width,
        _height = height,
        super(bytes: bytes, name: name, mimeType: mimeType);

  /// Creates a new image file and calculates the width, height and blurhash.
  static Future<MatrixImageFile> create({
    required Uint8List bytes,
    required String name,
    String? mimeType,
    String? filePath,
    @Deprecated('Use [nativeImplementations] instead') ComputeRunner? compute,
    NativeImplementations nativeImplementations = NativeImplementations.dummy,
  }) async {
    if (compute != null) {
      nativeImplementations =
          NativeImplementationsIsolate.fromRunInBackground(compute);
    }
    final metaData = await nativeImplementations.calcImageMetadata(bytes);

    return MatrixImageFile(
      bytes: metaData?.bytes ?? bytes,
      name: name,
      filePath: filePath,
      mimeType: mimeType,
      width: metaData?.width,
      height: metaData?.height,
      blurhash: metaData?.blurhash,
    );
  }

  /// Builds a [MatrixImageFile] and shrinks it in order to reduce traffic.
  /// If shrinking does not work (e.g. for unsupported MIME types), the
  /// initial image is preserved without shrinking it.
  static Future<MatrixImageFile> shrink({
    required Uint8List bytes,
    required String name,
    int maxDimension = 1600,
    String? mimeType,
    Future<MatrixImageFileResizedResponse?> Function(
            MatrixImageFileResizeArguments)?
        customImageResizer,
    @Deprecated('Use [nativeImplementations] instead') ComputeRunner? compute,
    NativeImplementations nativeImplementations = NativeImplementations.dummy,
  }) async {
    if (compute != null) {
      nativeImplementations =
          NativeImplementationsIsolate.fromRunInBackground(compute);
    }
    final image = MatrixImageFile(name: name, mimeType: mimeType, bytes: bytes);

    return await image.generateThumbnail(
            dimension: maxDimension,
            customImageResizer: customImageResizer,
            nativeImplementations: nativeImplementations) ??
        image;
  }

  int? _width;

  /// returns the width of the image
  int? get width => _width;

  int? _height;

  /// returns the height of the image
  int? get height => _height;

  /// If the image size is null, allow us to update it's value.
  void setImageSizeIfNull({required int? width, required int? height}) {
    _width ??= width;
    _height ??= height;
  }

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

  /// Computes a thumbnail for the image.
  /// Also sets height and width on the original image if they were unset.
  Future<MatrixImageFile?> generateThumbnail({
    int dimension = Client.defaultThumbnailSize,
    Future<MatrixImageFileResizedResponse?> Function(
            MatrixImageFileResizeArguments)?
        customImageResizer,
    @Deprecated('Use [nativeImplementations] instead') ComputeRunner? compute,
    NativeImplementations nativeImplementations = NativeImplementations.dummy,
  }) async {
    if (compute != null) {
      nativeImplementations =
          NativeImplementationsIsolate.fromRunInBackground(compute);
    }
    if (bytes != null) {
      final arguments = MatrixImageFileResizeArguments(
        bytes: bytes!,
        maxDimension: dimension,
        fileName: name,
        calcBlurhash: true,
      );

      final resizedData = customImageResizer != null
        ? await customImageResizer(arguments)
        : await nativeImplementations.shrinkImage(arguments);

      if (resizedData == null) {
        return null;
      }

      // we should take the opportunity to update the image dimension
      setImageSizeIfNull(
          width: resizedData.originalWidth, height: resizedData.originalHeight);

      // the thumbnail should rather return null than the enshrined image
      if (resizedData.width > dimension || resizedData.height > dimension) {
        return null;
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
  }

  /// you would likely want to use [NativeImplementations] and
  /// [Client.nativeImplementations] instead
  static MatrixImageFileResizedResponse? calcMetadataImplementation(
      Uint8List bytes) {
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

  /// you would likely want to use [NativeImplementations] and
  /// [Client.nativeImplementations] instead
  static MatrixImageFileResizedResponse? resizeImplementation(
      MatrixImageFileResizeArguments arguments) {
    final image = decodeImage(arguments.bytes);

    final resized = copyResize(image!,
        height: image.height > image.width ? arguments.maxDimension : null,
        width: image.width >= image.height ? arguments.maxDimension : null);

    final encoded = encodeNamedImage(arguments.fileName, resized);
    if (encoded == null) return null;
    final bytes = Uint8List.fromList(encoded);
    return MatrixImageFileResizedResponse(
      bytes: bytes,
      width: resized.width,
      height: resized.height,
      originalHeight: image.height,
      originalWidth: image.width,
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

  final int? originalHeight;
  final int? originalWidth;

  const MatrixImageFileResizedResponse({
    required this.bytes,
    required this.width,
    required this.height,
    this.originalHeight,
    this.originalWidth,
    this.blurhash,
  });

  factory MatrixImageFileResizedResponse.fromJson(
    Map<String, dynamic> json,
  ) =>
      MatrixImageFileResizedResponse(
        bytes: Uint8List.fromList(
            (json['bytes'] as Iterable<dynamic>).whereType<int>().toList()),
        width: json['width'],
        height: json['height'],
        originalHeight: json['originalHeight'],
        originalWidth: json['originalWidth'],
        blurhash: json['blurhash'],
      );

  Map<String, dynamic> toJson() => {
        'bytes': bytes,
        'width': width,
        'height': height,
        if (blurhash != null) 'blurhash': blurhash,
        if (originalHeight != null) 'originalHeight': originalHeight,
        if (originalWidth != null) 'originalWidth': originalWidth,
      };
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

  factory MatrixImageFileResizeArguments.fromJson(Map<String, dynamic> json) =>
      MatrixImageFileResizeArguments(
        bytes: json['bytes'],
        maxDimension: json['maxDimension'],
        fileName: json['fileName'],
        calcBlurhash: json['calcBlurhash'],
      );

  Map<String, Object> toJson() => {
        'bytes': bytes,
        'maxDimension': maxDimension,
        'fileName': fileName,
        'calcBlurhash': calcBlurhash,
      };
}

class MatrixVideoFile extends MatrixFile {
  final int? width;
  final int? height;
  final int? duration;

  MatrixVideoFile(
      {Uint8List? bytes,
      required String name,
      String? mimeType,
      super.filePath,
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
      super.filePath,
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
    return MatrixFile.fromMimeType(bytes: data, name: 'crypt');
  }
}
