import 'dart:typed_data';

mixin DatabaseFileStorage {
  bool get supportsFileStoring => false;

  late final Uri? fileStorageLocation;
  late final Duration? deleteFilesAfterDuration;

  Future<void> storeFile(Uri mxcUri, Uint8List bytes, int time) async {
    return;
  }

  Future<Uint8List?> getFile(Uri mxcUri) async {
    return null;
  }

  Future<void> deleteOldFiles(int savedAt) async {
    return;
  }

  Future<bool> deleteFile(Uri mxcUri) async => false;
}
