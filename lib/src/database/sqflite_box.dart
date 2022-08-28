import 'dart:async';
import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

/// Key-Value store abstraction over Sqflite so that the sdk database can use
/// a single interface for all platforms. API is inspired by Hive.
class BoxCollection {
  final Database _db;
  final Set<String> boxNames;

  BoxCollection(this._db, this.boxNames);

  static Future<BoxCollection> open(
    String name,
    Set<String> boxNames, {
    Object? sqfliteDatabase,
    dynamic idbFactory,
  }) async {
    if (sqfliteDatabase is! Database) {
      throw ('You must provide a Database `sqfliteDatabase` for FluffyBox on native.');
    }
    final batch = sqfliteDatabase.batch();
    for (final name in boxNames) {
      batch.execute(
        'CREATE TABLE IF NOT EXISTS $name (k TEXT PRIMARY KEY NOT NULL, v TEXT)',
      );
      batch.execute('CREATE INDEX IF NOT EXISTS k_index ON $name (k)');
    }
    await batch.commit(noResult: true);
    return BoxCollection(sqfliteDatabase, boxNames);
  }

  Box<V> openBox<V>(String name) {
    if (!boxNames.contains(name)) {
      throw ('Box with name $name is not in the known box names of this collection.');
    }
    return Box<V>(name, this);
  }

  Batch? _activeBatch;

  Completer<void>? _transactionLock;
  final _transactionZones = <Zone>{};

  Future<void> transaction(
    Future<void> Function() action, {
    List<String>? boxNames,
    bool readOnly = false,
  }) async {
    // we want transactions to lock, however NOT if transactoins are run inside of each other.
    // to be able to do this, we use dart zones (https://dart.dev/articles/archive/zones).
    // _transactionZones holds a set of all zones which are currently running a transaction.
    // _transactionLock holds the lock.

    // first we try to determine if we are inside of a transaction currently
    var isInTransaction = false;
    Zone? zone = Zone.current;
    // for that we keep on iterating to the parent zone until there is either no zone anymore
    // or we have found a zone inside of _transactionZones.
    while (zone != null) {
      if (_transactionZones.contains(zone)) {
        isInTransaction = true;
        break;
      }
      zone = zone.parent;
    }
    // if we are inside a transaction....just run the action
    if (isInTransaction) {
      return await action();
    }
    // if we are *not* in a transaction, time to wait for the lock!
    while (_transactionLock != null) {
      await _transactionLock!.future;
    }
    // claim the lock
    final lock = Completer<void>();
    _transactionLock = lock;
    try {
      // run the action inside of a new zone
      return await runZoned(() async {
        try {
          // don't forget to add the new zone to _transactionZones!
          _transactionZones.add(Zone.current);

          final batch = _db.batch();
          _activeBatch = batch;
          await action();
          _activeBatch = null;
          await batch.commit(noResult: true);
          return;
        } finally {
          // aaaand remove the zone from _transactionZones again
          _transactionZones.remove(Zone.current);
        }
      });
    } finally {
      // aaaand finally release the lock
      _transactionLock = null;
      lock.complete();
    }
  }

  Future<void> clear() => transaction(
        () async {
          for (final name in boxNames) {
            await _db.delete(name);
          }
        },
      );

  Future<void> close() => _db.close();
}

class Box<V> {
  final String name;
  final BoxCollection boxCollection;
  final Map<String, V?> _cache = {};

  /// _cachedKeys is only used to make sure that if you fetch all keys from a
  /// box, you do not need to have an expensive read operation twice. There is
  /// no other usage for this at the moment. So the cache is never partial.
  /// Once the keys are cached, they need to be updated when changed in put and
  /// delete* so that the cache does not become outdated.
  Set<String>? _cachedKeys;
  bool get _keysCached => _cachedKeys != null;

  static const Set<Type> allowedValueTypes = {
    List<dynamic>,
    Map<dynamic, dynamic>,
    String,
    int,
    double,
    bool,
  };

  Box(this.name, this.boxCollection) {
    if (!allowedValueTypes.any((type) => V == type)) {
      throw Exception(
        'Illegal value type for Box: "${V.toString()}". Must be one of $allowedValueTypes',
      );
    }
  }

  String? _toString(V? value) {
    if (value == null) return null;
    switch (V) {
      case const (List<dynamic>):
      case const (Map<dynamic, dynamic>):
        return jsonEncode(value);
      case const (String):
      case const (int):
      case const (double):
      case const (bool):
      default:
        return value.toString();
    }
  }

  V? _fromString(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw Exception(
          'Wrong database type! Expected String but got one of type ${value.runtimeType}');
    }
    switch (V) {
      case const (int):
        return int.parse(value) as V;
      case const (double):
        return double.parse(value) as V;
      case const (bool):
        return (value == 'true') as V;
      case const (List<dynamic>):
        return List.unmodifiable(jsonDecode(value)) as V;
      case const (Map<dynamic, dynamic>):
        return Map.unmodifiable(jsonDecode(value)) as V;
      case const (String):
      default:
        return value as V;
    }
  }

  Future<List<String>> getAllKeys([Transaction? txn]) async {
    if (_keysCached) return _cachedKeys!.toList();

    final executor = txn ?? boxCollection._db;

    final result = await executor.query(name, columns: ['k']);
    final keys = result.map((row) => row['k'] as String).toList();

    _cachedKeys = keys.toSet();
    return keys;
  }

  Future<Map<String, V>> getAllValues([Transaction? txn]) async {
    final executor = txn ?? boxCollection._db;

    final result = await executor.query(name);
    return Map.fromEntries(
      result.map(
        (row) => MapEntry(
          row['k'] as String,
          _fromString(row['v']) as V,
        ),
      ),
    );
  }

  Future<V?> get(String key, [Transaction? txn]) async {
    if (_cache.containsKey(key)) return _cache[key];

    final executor = txn ?? boxCollection._db;

    final result = await executor.query(
      name,
      columns: ['v'],
      where: 'k = ?',
      whereArgs: [key],
    );

    final value = result.isEmpty ? null : _fromString(result.single['v']);
    _cache[key] = value;
    return value;
  }

  Future<List<V?>> getAll(List<String> keys, [Transaction? txn]) async {
    if (!keys.any((key) => !_cache.containsKey(key))) {
      return keys.map((key) => _cache[key]).toList();
    }

    // The SQL operation might fail with more than 1000 keys. We define some
    // buffer here and half the amount of keys recursively for this situation.
    const getAllMax = 800;
    if (keys.length > getAllMax) {
      final half = keys.length ~/ 2;
      return [
        ...(await getAll(keys.sublist(0, half))),
        ...(await getAll(keys.sublist(half))),
      ];
    }

    final executor = txn ?? boxCollection._db;

    final list = <V?>[];

    final result = await executor.query(
      name,
      where: 'k IN (${keys.map((_) => '?').join(',')})',
      whereArgs: keys,
    );
    final resultMap = Map<String, V?>.fromEntries(
      result.map((row) => MapEntry(row['k'] as String, _fromString(row['v']))),
    );

    // We want to make sure that they values are returnd in the exact same
    // order than the given keys. That's why we do this instead of just return
    // `resultMap.values`.
    list.addAll(keys.map((key) => resultMap[key]));

    _cache.addAll(resultMap);

    return list;
  }

  Future<void> put(String key, V val) async {
    final txn = boxCollection._activeBatch;

    final params = {
      'k': key,
      'v': _toString(val),
    };
    if (txn == null) {
      await boxCollection._db.insert(
        name,
        params,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      txn.insert(
        name,
        params,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    _cache[key] = val;
    _cachedKeys?.add(key);
    return;
  }

  Future<void> delete(String key, [Batch? txn]) async {
    txn ??= boxCollection._activeBatch;

    if (txn == null) {
      await boxCollection._db.delete(name, where: 'k = ?', whereArgs: [key]);
    } else {
      txn.delete(name, where: 'k = ?', whereArgs: [key]);
    }

    _cache.remove(key);
    _cachedKeys?.remove(key);
    return;
  }

  Future<void> deleteAll(List<String> keys, [Batch? txn]) async {
    txn ??= boxCollection._activeBatch;

    final placeholder = keys.map((_) => '?').join(',');
    if (txn == null) {
      await boxCollection._db.delete(
        name,
        where: 'k IN ($placeholder)',
        whereArgs: keys,
      );
    } else {
      txn.delete(
        name,
        where: 'k IN ($placeholder)',
        whereArgs: keys,
      );
    }

    for (final key in keys) {
      _cache.remove(key);
      _cachedKeys?.removeAll(keys);
    }
    return;
  }

  Future<void> clear([Batch? txn]) async {
    txn ??= boxCollection._activeBatch;

    if (txn == null) {
      await boxCollection._db.delete(name);
    } else {
      txn.delete(name);
    }

    _cache.clear();
    _cachedKeys = null;
    return;
  }
}
