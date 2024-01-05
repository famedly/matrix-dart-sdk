import 'package:sqflite_common/sqlite_api.dart';

/// A helper utility for SQfLite related encryption operations
///
/// * helps loading the required dynamic libraries - even on cursed systems
/// * migrates unencrypted SQLite databases to SQLCipher
/// * applies the PRAGMA key to a database and ensure it is properly loading
class SQfLiteEncryptionHelper {
  /// the factory to use for all SQfLite operations
  final DatabaseFactory factory;

  /// the path of the database
  final String path;

  /// the (supposed) PRAGMA key of the database
  final String cipher;

  const SQfLiteEncryptionHelper({
    required this.factory,
    required this.path,
    required this.cipher,
  });

  /// Loads the correct [DynamicLibrary] required for SQLCipher
  ///
  /// To be used with `package:sqlite3/open.dart`:
  /// ```dart
  /// void main() {
  ///   final factory = createDatabaseFactoryFfi(
  ///     ffiInit: SQfLiteEncryptionHelper.ffiInit,
  ///   );
  /// }
  /// ```
  static void ffiInit() => throw UnimplementedError();

  /// checks whether the database exists and is encrypted
  ///
  /// In case it is not encrypted, the file is being migrated
  /// to SQLCipher and encrypted using the given cipher and checks
  /// whether that operation was successful
  Future<void> ensureDatabaseFileEncrypted() async =>
      throw UnimplementedError();

  /// safely applies the PRAGMA key to a [Database]
  ///
  /// To be directly used as [OpenDatabaseOptions.onConfigure].
  ///
  /// * ensures PRAGMA is supported by the given [database]
  /// * applies [cipher] as PRAGMA key
  /// * checks whether this operation was successful
  Future<void> applyPragmaKey(Database database) async =>
      throw UnimplementedError();
}
