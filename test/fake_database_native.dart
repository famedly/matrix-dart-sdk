/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020 Famedly GmbH
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

import 'dart:io';
import 'dart:math';

import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/src/database/hive_database.dart';
import 'package:file/memory.dart';
import 'package:hive/hive.dart';
import 'package:moor/moor.dart';
import 'package:moor/ffi.dart' as moor;

Future<DatabaseApi> getDatabase(Client _) => getHiveDatabase(_);

Future<Database> getMoorDatabase(Client _) async {
  moorRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return Database(moor.VmDatabase.memory());
}

bool hiveInitialized = false;

Future<FamedlySdkHiveDatabase> getHiveDatabase(Client c) async {
  if (!hiveInitialized) {
    final fileSystem = MemoryFileSystem();
    final testHivePath =
        '${fileSystem.path}/build/.test_store/${Random().nextDouble()}';
    Directory(testHivePath).createSync(recursive: true);
    Hive.init(testHivePath);
    hiveInitialized = true;
  }
  final db = FamedlySdkHiveDatabase('unit_test.${c.hashCode}');
  await db.open();
  return db;
}
