// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:matrix/src/database/sqflite_box.dart'
    if (dart.library.js_interop) 'package:matrix/src/database/indexeddb_box.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  group('Box tests', () {
    late BoxCollection collection;
    const boxNames = <String>{'cats', 'dogs'};
    const data = {'name': 'Fluffy', 'age': 2};
    const data2 = {'name': 'Loki', 'age': 4};
    Database? db;
    const isWeb = bool.fromEnvironment('dart.library.js_interop');
    setUp(() async {
      if (!isWeb) {
        db = await databaseFactoryFfi.openDatabase(':memory:');
      }
      collection = await BoxCollection.open(
        'testbox',
        boxNames,
        sqfliteDatabase: db,
        sqfliteFactory: isWeb ? null : databaseFactoryFfi,
      );
    });

    test('Box.put and Box.get', () async {
      final box = collection.openBox<Map>('cats');
      await box.put('fluffy', data);
      expect(await box.get('fluffy'), data);
      await box.clear();
    });

    test('Box.getAll', () async {
      final box = collection.openBox<Map>('cats');
      await box.put('fluffy', data);
      await box.put('loki', data2);
      expect(await box.getAll(['fluffy', 'loki']), [data, data2]);
      await box.clear();
    });

    test('Box.getAllKeys', () async {
      final box = collection.openBox<Map>('cats');
      await box.put('fluffy', data);
      await box.put('loki', data2);
      expect(await box.getAllKeys(), ['fluffy', 'loki']);
      await box.clear();
    });

    test('Box.getAllValues', () async {
      final box = collection.openBox<Map>('cats');
      await box.put('fluffy', data);
      await box.put('loki', data2);
      expect(await box.getAllValues(), {'fluffy': data, 'loki': data2});
      await box.clear();
    });

    test(
      'Box.getAllValues with a key added after the keys were cached',
      () async {
        final box = collection.openBox<Map>('cats');
        await box.put('fluffy', data);

        // Populate the key cache, like any earlier read from the box does.
        expect(await box.getAllKeys(), ['fluffy']);

        // 'alpha' sorts before 'fluffy', so the order the keys were written in
        // differs from the order the box stores them in.
        await box.put('alpha', data2);

        expect(await box.getAllValues(), {'fluffy': data, 'alpha': data2});
        await box.clear();
      },
    );

    test('Box.getKeysWithPrefix', () async {
      final box = collection.openBox<Map>('cats');
      await box.put('!a:x|1', data);
      await box.put('!a:x|2', data);
      // Same prefix without the separator and a key sorting right after it.
      await box.put('!a:xy|3', data);
      await box.put('!a:x}', data);
      await box.put('!b:x|4', data2);
      expect((await box.getKeysWithPrefix('!a:x|'))..sort(), [
        '!a:x|1',
        '!a:x|2',
      ]);
      await box.clear();
    });

    test('Box.getKeysWithPrefix in transaction', () async {
      final box = collection.openBox<Map>('cats');
      await box.put('!a:x|1', data);
      await box.put('!a:x|2', data);
      await collection.transaction(() async {
        await box.put('!a:x|3', data);
        await box.delete('!a:x|1');
        expect((await box.getKeysWithPrefix('!a:x|'))..sort(), [
          '!a:x|2',
          '!a:x|3',
        ]);
      });
      expect((await box.getKeysWithPrefix('!a:x|'))..sort(), [
        '!a:x|2',
        '!a:x|3',
      ]);
      await box.clear();
    });

    test('Box.delete', () async {
      final box = collection.openBox<Map>('cats');
      await box.put('fluffy', data);
      await box.put('loki', data2);
      await box.delete('fluffy');
      expect(await box.get('fluffy'), null);
      await box.clear();
    });

    test('Box.delete in transaction', () async {
      final box = collection.openBox<Map>('cats');
      await box.put('fluffy', data);
      await box.put('loki', data2);
      await collection.transaction(() async {
        await box.delete('fluffy');
        expect(await box.get('fluffy'), null);
      });
      expect(await box.get('fluffy'), null);
      await box.clear();
    });

    test('nested transaction keeps the order of writes', () async {
      final box = collection.openBox<Map>('cats');
      await collection.transaction(() async {
        await box.put('fluffy', data);
        await collection.transaction(() async {
          await box.put('loki', data2);
        });
        await box.put('fluffy', data2);
      });
      box.clearQuickAccessCache();
      expect(await box.get('fluffy'), data2);
      expect(await box.get('loki'), data2);
      await box.clear();
    });

    test(
      'a failed transaction writes nothing and does not swallow later writes',
      () async {
        final box = collection.openBox<Map>('cats');
        await expectLater(
          collection.transaction(() async {
            await box.put('fluffy', data);
            throw Exception('boom');
          }),
          throwsException,
        );
        expect(await box.get('fluffy'), null);
        await box.put('loki', data2);
        box.clearQuickAccessCache();
        expect(await box.get('loki'), data2);
        expect(await box.get('fluffy'), null);
        await box.clear();
      },
    );

    test('a transaction failing at commit clears the caches', () async {
      final box = collection.openBox<Map>('cats');
      await collection.close();
      // Committing to a closed database throws, so only a stale cache could
      // still answer the read.
      await expectLater(
        collection.transaction(() => box.put('fluffy', data)),
        throwsA(anything),
      );
      await expectLater(box.get('fluffy'), throwsA(anything));
    });

    test('a transaction writes the last value of each key', () async {
      final box = collection.openBox<Map>('cats');
      await box.put('gone', data);
      await collection.transaction(() async {
        await box.put('fluffy', data);
        await box.put('fluffy', data2);
        await box.delete('gone');
        await box.put('loki', data);
        await box.delete('loki');
        await box.put('loki', data2);
      });
      box.clearQuickAccessCache();
      expect(await box.get('fluffy'), data2);
      expect(await box.get('loki'), data2);
      expect(await box.get('gone'), null);
      await box.clear();
    });

    test('reads in a transaction see its pending writes', () async {
      final box = collection.openBox<Map>('cats');
      await box.put('stored', data);
      await box.put('deleted', data);
      box.clearQuickAccessCache();
      await collection.transaction(() async {
        await box.put('new', data2);
        await box.delete('deleted');
        expect(await box.get('new'), data2);
        expect(await box.get('deleted'), null);
        expect(await box.getAll(['stored', 'new', 'deleted']), [
          data,
          data2,
          null,
        ]);
        expect((await box.getAllKeys())..sort(), ['new', 'stored']);
        expect(await box.getAllValues(), {'stored': data, 'new': data2});
      });
      await box.clear();
    });

    test('clear in a transaction keeps only later writes', () async {
      final box = collection.openBox<Map>('cats');
      await box.put('fluffy', data);
      await collection.transaction(() async {
        await box.clear();
        await box.put('loki', data2);
        expect(await box.get('fluffy'), null);
        expect(await box.getAllKeys(), ['loki']);
      });
      box.clearQuickAccessCache();
      expect(await box.get('fluffy'), null);
      expect(await box.get('loki'), data2);
      await box.clear();
    });

    test('writes during commit are kept in order', () async {
      final box = collection.openBox<Map>('cats');
      late Future<void> lateWrite;
      final transaction = collection.transaction(() async {
        await box.put('fluffy', data);
        // Fires outside the transaction's zone after the action returned,
        // i.e. while the transaction commits.
        lateWrite = Zone.root.run(() => Future(() => box.put('fluffy', data2)));
      });
      await transaction;
      await lateWrite;
      box.clearQuickAccessCache();
      expect(await box.get('fluffy'), data2);
      await box.clear();
    });

    test('getAll and deleteAll with 2000 keys', () async {
      final box = collection.openBox<Map>('cats');
      final keys = [for (var i = 0; i < 2000; i++) 'cat$i'];
      await collection.transaction(() async {
        for (final key in keys) {
          await box.put(key, data);
        }
      });
      box.clearQuickAccessCache();
      expect((await box.getAll(keys)).every((v) => v != null), isTrue);
      await box.deleteAll(keys);
      box.clearQuickAccessCache();
      expect((await box.getAll(keys)).every((v) => v == null), isTrue);
      await box.clear();
    });

    test('reads sent before the commit see its writes', () async {
      final box = collection.openBox<Map>('cats');
      late Future<void> olderReads;
      late Future<List<String>> keys;
      late Future<Map<String, Map>> values;
      await collection.transaction(() async {
        // Answered with the store state from before the writes.
        olderReads = Zone.root.run(
          () => Future.wait([
            box.get('!a|1'),
            box.getAll(['!a|2']),
          ]),
        );
        await box.put('!a|1', data);
        await box.put('!a|2', data2);
        // Outside the transaction's zone, answered while it commits.
        keys = Zone.root.run(() => box.getKeysWithPrefix('!a|'));
        values = Zone.root.run(box.getAllValues);
      });
      expect((await keys)..sort(), ['!a|1', '!a|2']);
      expect(await values, {'!a|1': data, '!a|2': data2});
      await olderReads;
      // The older answers must not shadow the writes in the cache.
      expect(await box.get('!a|1'), data);
      expect(await box.getAll(['!a|2']), [data2]);
      await box.clear();
    });

    test('a box with a cache size evicts the least recently used', () async {
      final box = collection.openBox<Map>('dogs', cacheSize: 2);
      await box.put('a', data);
      await box.put('b', data);
      await box.get('a'); // a is now more recent than b
      await box.put('c', data2);
      expect(box.cachedKeys, ['a', 'c']);
      expect(await box.get('b'), data); // evicted, read from the store
      await box.clear();
    });

    test('pending writes survive eviction', () async {
      final box = collection.openBox<Map>('dogs', cacheSize: 1);
      await collection.transaction(() async {
        await box.put('a', data);
        await box.put('b', data2);
        expect(await box.get('a'), data);
      });
      box.clearQuickAccessCache();
      expect(await box.get('a'), data);
      expect(await box.get('b'), data2);
      await box.clear();
    });

    test('Box.deleteAll', () async {
      final box = collection.openBox<Map>('cats');
      await box.put('fluffy', data);
      await box.put('loki', data2);
      await box.deleteAll(['fluffy', 'loki']);
      expect(await box.get('fluffy'), null);
      expect(await box.get('loki'), null);
      await box.clear();
    });

    test('Box.clear', () async {
      final box = collection.openBox<Map>('cats');
      await box.put('fluffy', data);
      await box.put('loki', data2);
      await box.clear();
      expect(await box.get('fluffy'), null);
      expect(await box.get('loki'), null);
    });

    test('Box.close', () async {
      await collection.close();
    });

    test('Collection.deleteDatabase', () async {
      await collection.deleteDatabase(
        db?.path ?? '',
        isWeb ? null : databaseFactoryFfi,
      );
    });
  });
}
