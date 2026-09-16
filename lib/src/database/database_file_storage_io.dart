// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart';

import '../../matrix.dart';

// ignore: unused-code
mixin DatabaseFileStorage {
  bool get supportsFileStoring => fileStorageLocation != null;

  late final Uri? fileStorageLocation;
  late final Duration? deleteFilesAfterDuration;

  /// Map an MXC URI to a local File path
  File _getFileFromMxc(Uri mxcUri) {
    // Replace all special characters with underscores to avoid PathNotFoundException on Windows.
    final host = mxcUri.host.replaceAll('.', '_');
    final path = mxcUri.pathSegments.join('_');
    final query = mxcUri.queryParameters.entries
        .map((entry) => '${entry.key}${entry.value}')
        .join('_');
    final fileName = '${host}_${path}_$query';
    return File(join(Directory.fromUri(fileStorageLocation!).path, fileName));
  }

  Future<void> storeFile(Uri mxcUri, Uint8List bytes, int time) async {
    final fileStorageLocation = this.fileStorageLocation;
    if (!supportsFileStoring || fileStorageLocation == null) return;

    final file = _getFileFromMxc(mxcUri);

    if (await file.exists()) return;
    await file.writeAsBytes(bytes);
  }

  Future<Uint8List?> getFile(Uri mxcUri) async {
    final fileStorageLocation = this.fileStorageLocation;
    if (!supportsFileStoring || fileStorageLocation == null) return null;

    final file = _getFileFromMxc(mxcUri);

    if (await file.exists()) return await file.readAsBytes();
    return null;
  }

  Future<bool> deleteFile(Uri mxcUri) async {
    final fileStorageLocation = this.fileStorageLocation;
    if (!supportsFileStoring || fileStorageLocation == null) return false;

    final file = _getFileFromMxc(mxcUri);

    if (await file.exists() == false) return false;

    try {
      await file.delete();
    } on PathNotFoundException {
      return false;
    }
    return true;
  }

  Future<void> deleteOldFiles(int savedAt) async {
    final dirUri = fileStorageLocation;
    final deleteFilesAfterDuration = this.deleteFilesAfterDuration;
    if (!supportsFileStoring ||
        dirUri == null ||
        deleteFilesAfterDuration == null) {
      return;
    }
    final dir = Directory.fromUri(dirUri);
    final entities = await dir.list().toList();
    for (final file in entities) {
      if (file is! File) continue;
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file) continue;
      if (DateTime.now().difference(stat.modified) > deleteFilesAfterDuration) {
        Logs().v('Delete old file', file.path);
        try {
          await file.delete();
        } on PathNotFoundException {
          // File may have been removed after listing, e.g. by sendFileEvent cleanup.
        }
      }
    }
  }
}
