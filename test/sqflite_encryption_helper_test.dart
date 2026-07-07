// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

@TestOn('vm')
library;

import 'dart:io';

import 'package:matrix/matrix.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  group('SQfLiteEncryptionHelper', () {
    late Directory tempDir;
    late String dbPath;
    late SQfLiteEncryptionHelper helper;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('encryption_helper');
      dbPath = '${tempDir.path}/test.sqlite';
      helper = SQfLiteEncryptionHelper(
        factory: databaseFactoryFfi,
        path: dbPath,
        cipher: 'secret',
      );
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('ffiInit is a no-op', () {
      // ignore: deprecated_member_use_from_same_package
      expect(SQfLiteEncryptionHelper.ffiInit, returnsNormally);
    });

    test(
      'ensureDatabaseFileEncrypted does nothing without a database file',
      () async {
        await helper.ensureDatabaseFileEncrypted();
        expect(await File(dbPath).exists(), false);
      },
    );

    test(
      'ensureDatabaseFileEncrypted skips already encrypted databases',
      () async {
        // an encrypted database does not start with the plain text SQLite header
        final bytes = List<int>.generate(32, (i) => 255 - i);
        await File(dbPath).writeAsBytes(bytes);

        await helper.ensureDatabaseFileEncrypted();

        expect(await File(dbPath).readAsBytes(), bytes);
      },
    );

    test(
      'ensureDatabaseFileEncrypted fails loudly when SQLCipher is not available',
      () async {
        // create a plain text SQLite database
        final db = await databaseFactoryFfi.openDatabase(dbPath);
        await db.execute('CREATE TABLE cats (name TEXT)');
        await db.close();

        // the bundled sqlite3 is not SQLCipher, so the migration must not
        // silently do the wrong thing
        await expectLater(
          helper.ensureDatabaseFileEncrypted(),
          throwsStateError,
        );

        // the plain database file is left untouched
        expect(await File(dbPath).exists(), true);
      },
    );

    test(
      'applyPragmaKey fails loudly when SQLCipher is not available',
      () async {
        final db = await databaseFactoryFfi.openDatabase(dbPath);

        await expectLater(helper.applyPragmaKey(db), throwsStateError);

        await db.close();
      },
    );
  });
}
