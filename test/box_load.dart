// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

// ignore_for_file: avoid_print

// Load test, not part of the suite: dart test -j 1 test/box_load.dart

library;

import 'package:matrix/src/database/sqflite_box.dart'
    if (dart.library.js_interop) 'package:matrix/src/database/indexeddb_box.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

const isWeb = bool.fromEnvironment('dart.library.js_interop');
const boxNames = {'a', 'b', 'c', 'd', 'e'};

Future<String> dbPath(String name) async => isWeb
    ? 'load_$name'
    : '${await databaseFactoryFfi.getDatabasesPath()}/$name.db';

/// A file-backed store, so that commits pay the real disk cost.
Future<BoxCollection> openCollection(String name) async {
  Database? db;
  if (!isWeb) {
    final path = await dbPath(name);
    await databaseFactoryFfi.deleteDatabase(path);
    db = await databaseFactoryFfi.openDatabase(path);
  }
  return BoxCollection.open(
    'load_$name',
    boxNames,
    sqfliteDatabase: db,
    sqfliteFactory: isWeb ? null : databaseFactoryFfi,
  );
}

Future<void> measure(String name, Future<void> Function() run) async {
  final sw = Stopwatch()..start();
  await run();
  print('LOAD $name ${sw.elapsedMilliseconds} ms');
}

Map<String, Object?> value(int i) => {
  'type': 'm.room.message',
  'event_id': '\$event$i',
  'content': {'body': 'Message number $i with some text', 'msgtype': 'm.text'},
  'origin_server_ts': 1700000000000 + i,
};

void main() {
  test('L1 concurrent writes outside a transaction', () async {
    final collection = await openCollection('l1');
    final box = collection.openBox<Map>('a');
    await measure(
      'L1 2000 concurrent writes',
      () => Future.wait([
        for (var i = 0; i < 2000; i++) box.put('k$i', value(i)),
      ]),
    );
    box.clearQuickAccessCache();
    expect(await box.get('k1999'), value(1999));
    await collection.deleteDatabase(
      await dbPath('l1'),
      isWeb ? null : databaseFactoryFfi,
    );
  });

  test('L2 sequential writes outside a transaction', () async {
    final collection = await openCollection('l2');
    final box = collection.openBox<Map>('a');
    await measure('L2 2000 sequential writes', () async {
      for (var i = 0; i < 2000; i++) {
        await box.put('k$i', value(i));
      }
    });
    box.clearQuickAccessCache();
    expect(await box.get('k1999'), value(1999));
    await collection.deleteDatabase(
      await dbPath('l2'),
      isWeb ? null : databaseFactoryFfi,
    );
  });

  test('L3 sync-like transaction', () async {
    final collection = await openCollection('l3');
    final boxes = [for (final name in boxNames) collection.openBox<Map>(name)];
    await measure('L3 20000 writes + 5000 reads in a transaction', () async {
      await collection.transaction(() async {
        for (var i = 0; i < 20000; i++) {
          // Every third write overwrites an earlier key.
          final key = i % 3 == 0 ? 'k${i ~/ 2}' : 'k$i';
          await boxes[i % boxes.length].put(key, value(i));
          if (i % 4 == 0) await boxes[(i + 1) % boxes.length].get('k${i ~/ 4}');
        }
      });
    });
    for (final box in boxes) {
      box.clearQuickAccessCache();
    }
    expect(await boxes[19999 % boxes.length].get('k19999'), value(19999));
    await collection.deleteDatabase(
      await dbPath('l3'),
      isWeb ? null : databaseFactoryFfi,
    );
  });
}
