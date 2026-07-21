// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:io';

import 'package:matrix/matrix.dart';
import 'package:sqflite_common/sqlite_api.dart';

// ignore: unused-code
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

  /// checks whether the database exists and is encrypted
  ///
  /// In case it is not encrypted, the file is being migrated
  /// to SQLCipher and encrypted using the given cipher and checks
  /// whether that operation was successful
  Future<void> ensureDatabaseFileEncrypted() async {
    final file = File(path);

    // in case the file does not exist there is no need to migrate
    if (!await file.exists()) {
      return;
    }

    // no work to do in case the DB is already encrypted
    if (!await _isPlainText(file)) {
      return;
    }

    Logs().d(
      'Warning: Found unencrypted sqlite database. Encrypting using SQLCipher.',
    );

    // hell, it's unencrypted. This should not happen. Time to encrypt it.
    final plainDb = await factory.openDatabase(path);

    final encryptedPath = '$path.encrypted';

    await plainDb.execute(
      "ATTACH DATABASE '$encryptedPath' AS encrypted KEY '$cipher';",
    );
    await plainDb.execute("SELECT sqlcipher_export('encrypted');");
    // ignore: prefer_single_quotes
    await plainDb.execute("DETACH DATABASE encrypted;");
    await plainDb.close();

    Logs().d('Migrated data to temporary database. Checking integrity.');

    final encryptedFile = File(encryptedPath);
    // we should now have a second file - which is encrypted
    assert(await encryptedFile.exists());
    assert(!await _isPlainText(encryptedFile));

    Logs().d('New file encrypted. Deleting plain text database.');

    // deleting the plain file and replacing it with the new one
    await file.delete();
    await encryptedFile.copy(path);
    // delete the temporary encrypted file
    await encryptedFile.delete();

    Logs().d('Migration done.');
  }

  /// safely applies the PRAGMA key to a [Database]
  ///
  /// To be directly used as [OpenDatabaseOptions.onConfigure].
  ///
  /// * ensures PRAGMA is supported by the given [database]
  /// * applies [cipher] as PRAGMA key
  /// * checks whether this operation was successful
  Future<void> applyPragmaKey(Database database) async {
    final cipherVersion = await database.rawQuery('PRAGMA cipher_version;');
    if (cipherVersion.isEmpty) {
      // Make sure that we're actually using SQLCipher, since the pragma
      // used to encrypt databases just fails silently with regular
      // sqlite3
      // (meaning that we'd accidentally use plaintext databases).
      throw StateError(
        'SQLCipher library is not available, '
        'please check your dependencies!',
      );
    } else {
      final version = cipherVersion.singleOrNull?['cipher_version'];
      Logs().d(
        'PRAGMA supported by bundled SQLite. Encryption supported. SQLCipher version: $version.',
      );
    }

    final result = await database.rawQuery("PRAGMA KEY='$cipher';");
    assert(result.single['ok'] == 'ok');
  }

  /// checks whether a File has a plain text SQLite header
  Future<bool> _isPlainText(File file) async {
    final raf = await file.open();
    final bytes = await raf.read(15);
    await raf.close();

    const header = [
      83,
      81,
      76,
      105,
      116,
      101,
      32,
      102,
      111,
      114,
      109,
      97,
      116,
      32,
      51,
    ];

    return _listEquals(bytes, header);
  }

  /// Taken from `package:flutter/foundation.dart`;
  ///
  /// Compares two lists for element-by-element equality.
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) {
      return b == null;
    }
    if (b == null || a.length != b.length) {
      return false;
    }
    if (identical(a, b)) {
      return true;
    }
    for (var index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }
}
