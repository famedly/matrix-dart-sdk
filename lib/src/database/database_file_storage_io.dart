import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:matrix/matrix.dart';
import 'package:path/path.dart';

mixin DatabaseFileStorage {
  bool get supportsFileStoring => fileStorageLocation != null;

  late final Uri? fileStorageLocation;
  late final Duration? deleteFilesAfterDuration;

  /// Map an MXC URI to a local File path
  File _getFileFromMxc(Uri mxcUri) {
    // Encode MXC to a filesystem-safe file name
    final fileName = base64Url.encode(
      utf8.encode(
        mxcUri.toString(),
      ),
    );
    // Resolve storage directory from configured URI
    final dirPath = Directory.fromUri(fileStorageLocation!).path;
    // Join directory and file name to form full path
    final filePath = join(dirPath, fileName);
    // Return File handle pointing to the computed path
    return File(filePath);
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

    await file.delete();
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
      if (DateTime.now().difference(stat.modified) > deleteFilesAfterDuration) {
        Logs().v('Delete old file', file.path);
        await file.delete();
      }
    }
  }
}
