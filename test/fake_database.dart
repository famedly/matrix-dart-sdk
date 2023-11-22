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

import 'package:file/local.dart';
import 'package:hive/hive.dart';

import 'package:matrix/matrix.dart';

Future<DatabaseApi> getDatabase(Client? _) => getHiveCollectionsDatabase(_);

bool hiveInitialized = false;

Future<HiveCollectionsDatabase> getHiveCollectionsDatabase(Client? c) async {
  final testHivePath = await LocalFileSystem()
      .systemTempDirectory
      .createTemp('dart-sdk-tests-database');
  if (!hiveInitialized) {
    Hive.init(testHivePath.path);
  }
  final db = HiveCollectionsDatabase(
    'unit_test.${c?.hashCode}',
    testHivePath.path,
  );
  await db.open();
  return db;
}

// ignore: deprecated_member_use_from_same_package
Future<FamedlySdkHiveDatabase> getHiveDatabase(Client? c) async {
  if (!hiveInitialized) {
    final testHivePath = await LocalFileSystem()
        .systemTempDirectory
        .createTemp('dart-sdk-tests-database');
    Hive.init(testHivePath.path);
    hiveInitialized = true;
  }
  // ignore: deprecated_member_use_from_same_package
  final db = FamedlySdkHiveDatabase('unit_test.${c?.hashCode}');
  await db.open();
  return db;
}
