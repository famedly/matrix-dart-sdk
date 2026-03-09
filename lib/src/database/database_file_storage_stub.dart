import 'dart:typed_data';

mixin DatabaseFileStorage {
  bool get supportsFileStoring => false;

  late final Uri? fileStorageLocation;
  late final Duration? deleteFilesAfterDuration;

  final Map<Uri, Uint8List> _cache = {};

  Future<void> storeFile(Uri mxcUri, Uint8List bytes, int time) async {
    if (mxcUri.scheme != 'cache') return;
    _cache[mxcUri] = bytes;
  }

  Future<Uint8List?> getFile(Uri mxcUri) async {
    return _cache[mxcUri];
  }

  Future<void> deleteOldFiles(int savedAt) async {
    return; // Not supported. Cache is cleared on every app restart anyway.
  }

  Future<bool> deleteFile(Uri mxcUri) async {
    return _cache.remove(mxcUri) != null;
  }
}
