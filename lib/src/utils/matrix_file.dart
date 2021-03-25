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

import 'dart:typed_data';

import 'crypto/encrypted_file.dart';
import 'package:mime/mime.dart';

import '../../famedlysdk.dart';

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
    mimeType ??=
        lookupMimeType(name, headerBytes: bytes) ?? 'application/octet-stream';
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
