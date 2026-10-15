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

    test('transactions from other zones run one after another', () async {
      final box = collection.openBox<int>('dogs');
      await box.put('count', 0);
      Future<void> increment() => Zone.root.run(
        () => collection.transaction(() async {
          final count = await box.get('count');
          await Future.delayed(const Duration(milliseconds: 5));
          await box.put('count', count! + 1);
        }),
      );
      await Future.wait([increment(), increment(), increment()]);
      expect(await box.get('count'), 3);
      await box.clear();
    });

    test(
      'reads see the uncommitted writes, the last one of a key wins',
      () async {
        final box = collection.openBox<Map>('cats');
        await box.put('!a|stored', data);
        await box.put('!a|deleted', data);
        box.clearQuickAccessCache();
        await collection.transaction(() async {
          await box.put('!a|new', data);
          await box.put('!a|new', data2);
          await box.delete('!a|deleted');
          expect(await box.get('!a|new'), data2);
          expect(await box.getAll(['!a|stored', '!a|deleted']), [data, null]);
          expect((await box.getAllKeys())..sort(), ['!a|new', '!a|stored']);
          expect((await box.getKeysWithPrefix('!a|'))..sort(), [
            '!a|new',
            '!a|stored',
          ]);
          expect(await box.getAllValues(), {
            '!a|stored': data,
            '!a|new': data2,
          });
        });
        box.clearQuickAccessCache();
        expect(await box.getAllValues(), {'!a|stored': data, '!a|new': data2});
        await box.clear();
      },
    );

    test('clear keeps only later writes, also for reads sent before', () async {
      // A box with a cache size keeps no key set, so the reads use the store.
      final box = collection.openBox<Map>('dogs', cacheSize: 10);
      await box.put('fluffy', data);
      late Future<Map<String, Map>> olderValues;
      await collection.transaction(() async {
        // Sent before the clear, answered after it.
        olderValues = Zone.root.run(box.getAllValues);
        await box.clear();
        await box.put('loki', data2);
        expect(await box.getAll(['fluffy', 'loki']), [null, data2]);
        expect(await box.getAllKeys(), ['loki']);
        expect(await box.getKeysWithPrefix('fl'), isEmpty);
      });
      expect(await olderValues, {'loki': data2});
      box.clearQuickAccessCache();
      expect(await box.getAllValues(), {'loki': data2});
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

    test(
      'writes from other zones around a transaction keep their order',
      () async {
        final box = collection.openBox<Map>('cats');
        for (var hops = 0; hops < 8; hops++) {
          late Future<void> write;
          await collection.transaction(() async {
            await box.put('cat$hops', data);
            // Lands a few microtasks later, so one of them hits the end of the
            // transaction or its commit.
            write = Zone.root.run(() async {
              for (var i = 0; i < hops; i++) {
                await null;
              }
              await box.put('cat$hops', data2);
            });
          });
          await write;
        }
        box.clearQuickAccessCache();
        for (var hops = 0; hops < 8; hops++) {
          expect(await box.get('cat$hops'), data2);
        }
        await box.clear();
      },
    );

    test(
      'awaited writes and transactions are committed when they complete',
      () async {
        final box = collection.openBox<Map>('cats');
        await box.put('fluffy', data);
        expect(await db!.query('cats'), hasLength(1));
        await collection.transaction(() => box.put('loki', data2));
        expect(await db!.query('cats'), hasLength(2));
        await Future.wait([for (var i = 0; i < 100; i++) box.put('$i', data)]);
        expect(await db!.query('cats'), hasLength(102));
        await box.clear();
      },
      skip: isWeb ? 'needs direct access to the store' : false,
    );

    test(
      'a commit from outside does not store half of a transaction',
      () async {
        final box = collection.openBox<Map>('cats');
        final gate = Completer<void>();
        // The first commit runs, the second waits while the transaction runs.
        final outside = Future.wait([
          box.put('a', data),
          Future(() => box.put('b', data)),
        ]);
        final transaction = collection.transaction(() async {
          await box.put('own1', data);
          await gate.future;
          await box.put('own2', data);
        });
        await Future.delayed(const Duration(milliseconds: 50));
        final stored = [for (final row in await db!.query('cats')) row['k']];
        expect(stored, isNot(contains('own1')));
        gate.complete();
        await transaction;
        await outside;
        expect([
          for (final row in await db!.query('cats')) row['k'],
        ], containsAll(['a', 'b', 'own1', 'own2']));
        await box.clear();
      },
      skip: isWeb ? 'needs direct access to the store' : false,
    );

    test('a throwing transaction still commits its writes', () async {
      final box = collection.openBox<Map>('cats');
      await expectLater(
        collection.transaction(() async {
          await box.put('fluffy', data);
          throw Exception('boom');
        }),
        throwsException,
      );
      box.clearQuickAccessCache();
      expect(await box.get('fluffy'), data);
      await box.clear();
    });

    test('a value that cannot be stored does not block the others', () async {
      final box = collection.openBox<Map>('cats');
      final dogs = collection.openBox<Map>('dogs');
      await collection.transaction(() async {
        await dogs.put('rex', data);
        await box.put('fluffy', data);
        // Neither JSON nor IndexedDB can encode it, the web's WeakMap inside
        // fails the structured clone. A plain Object() would be cloned.
        await box.put('broken', {'expando': Expando()});
      });
      box.clearQuickAccessCache();
      dogs.clearQuickAccessCache();
      expect(await dogs.get('rex'), data);
      expect(await box.get('fluffy'), data);
      expect(await box.get('broken'), null);
      await box.clear();
      await dogs.clear();
    });

    test(
      'a failed commit keeps the writes readable and commits them later',
      () async {
        final box = collection.openBox<Map>('cats');
        await db!.execute('DROP TABLE cats');
        await expectLater(box.put('fluffy', data), throwsA(anything));
        box.clearQuickAccessCache();
        expect(await box.get('fluffy'), data);
        await db!.execute(
          'CREATE TABLE cats (k TEXT PRIMARY KEY NOT NULL, v TEXT)',
        );
        await box.put('loki', data2);
        expect(await db!.query('cats'), hasLength(2));
      },
      skip: isWeb ? 'needs direct access to the store' : false,
    );

    test(
      'close() closes the store even if the last commit fails',
      () async {
        final box = collection.openBox<Map>('cats');
        await db!.execute('DROP TABLE cats');
        await expectLater(box.put('fluffy', data), throwsA(anything));
        await collection.close();
        expect(db!.isOpen, isFalse);
      },
      skip: isWeb ? 'needs direct access to the store' : false,
    );

    test('getAll with more keys than a statement takes variables', () async {
      final box = collection.openBox<Map>('cats');
      final keys = [for (var i = 0; i < 2000; i++) 'cat$i'];
      await collection.transaction(() async {
        for (final key in keys) {
          await box.put(key, data);
        }
      });
      box.clearQuickAccessCache();
      expect((await box.getAll(keys)).every((v) => v != null), isTrue);
      await box.clear();
    });

    test('a box with a cache size keeps the most recently used', () async {
      final box = collection.openBox<Map>('dogs', cacheSize: 10);
      await box.put('hot', data);
      for (var i = 0; i < 100; i++) {
        await box.put('$i', data2);
        await box.get('hot');
        expect(box.cachedKeys.length, lessThanOrEqualTo(11));
      }
      expect(box.cachedKeys, [for (var i = 90; i < 100; i++) '$i', 'hot']);
      expect(await box.get('0'), data2); // evicted, read from the store
      await box.clear();
    });

    test('uncommitted writes survive eviction', () async {
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
