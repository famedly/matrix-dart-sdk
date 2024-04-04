// This is a stub implementation of all filesystem related calls done
// by the matrix SDK database. This fake implementation ensures we can compile
// using dart2js.

import 'dart:typed_data';

class File extends FileSystemEntry {
  const File(super.path);

  Future<Uint8List> readAsBytes() async => Uint8List(0);

  Future<void> writeAsBytes(Uint8List data) async => Future.value();
}

class Directory extends FileSystemEntry {
  const Directory(super.path);

  Stream<FileSystemEntry> list() async* {
    return;
  }
}

abstract class FileSystemEntry {
  final String path;

  const FileSystemEntry(this.path);

  Future<void> delete() => Future.value();

  Future<FileStat> stat() async => FileStat();

  Future<bool> exists() async => false;
}

class FileStat {
  final modified = DateTime.fromMillisecondsSinceEpoch(0);
}
