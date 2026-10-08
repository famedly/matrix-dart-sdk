// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:sqflite_common/sqflite.dart';

import 'zone_transaction_mixin.dart';

/// Key-Value store abstraction over Sqflite so that the sdk database can use
/// a single interface for all platforms. API is inspired by Hive.
class BoxCollection with ZoneTransactionMixin {
  final Database _db;
  final Set<String> boxNames;
  final String name;

  BoxCollection(this._db, this.boxNames, this.name);

  static Future<BoxCollection> open(
    String name,
    Set<String> boxNames, {
    Object? sqfliteDatabase,
    DatabaseFactory? sqfliteFactory,
    dynamic idbFactory,
    int version = 1,
  }) async {
    if (sqfliteDatabase is! Database) {
      throw ('You must provide a Database `sqfliteDatabase` for use on native.');
    }
    final batch = sqfliteDatabase.batch();
    for (final name in boxNames) {
      batch.execute(
        'CREATE TABLE IF NOT EXISTS $name (k TEXT PRIMARY KEY NOT NULL, v TEXT)',
      );
      batch.execute(
        'DROP INDEX IF EXISTS k_index',
      ); // Previously we have created a redundant index. We can safely remove it.
    }
    await batch.commit(noResult: true);
    return BoxCollection(sqfliteDatabase, boxNames, name);
  }

  final _boxes = <Box>{};

  Box<V> openBox<V>(String name, {int? cacheSize}) {
    if (!boxNames.contains(name)) {
      throw ('Box with name $name is not in the known box names of this collection.');
    }
    final box = Box<V>(name, this, cacheSize: cacheSize);
    _boxes.add(box);
    return box;
  }

  /// Boxes with writes of the running transaction, null outside of one.
  Set<Box>? _dirtyBoxes;

  Future<void> transaction(
    Future<void> Function() action, {
    List<String>? boxNames,
    bool readOnly = false,
  }) => zoneTransaction(() async {
    // A nested transaction joins the outer one, so all writes stay in order.
    if (_dirtyBoxes != null) return action();
    final dirtyBoxes = _dirtyBoxes = {};
    try {
      await action();
      // Writes from other zones may arrive while we commit. They get the next
      // batch, so that no write is overtaken by an older one.
      while (dirtyBoxes.isNotEmpty) {
        final batch = _db.batch();
        for (final box in dirtyBoxes) {
          box._flushPending(batch);
        }
        dirtyBoxes.clear();
        await batch.commit(noResult: true);
      }
    } catch (_) {
      // Nothing of a failed transaction may stay visible.
      for (final box in _boxes) {
        box.clearQuickAccessCache();
      }
      rethrow;
    } finally {
      _dirtyBoxes = null;
      // Dropped only now: a read sent before a commit merges the pending
      // writes after the store answered, which is before the commit ends.
      for (final box in _boxes) {
        box._pending.clear();
        box._pendingClear = false;
      }
    }
  });

  Future<void> clear() => transaction(() async {
    for (final name in boxNames) {
      await _db.delete(name);
    }
  });

  Future<void> close() => zoneTransaction(_db.close);

  @Deprecated('use collection.deleteDatabase now')
  static Future<void> delete(String path, [dynamic factory]) =>
      (factory ?? databaseFactory).deleteDatabase(path);

  Future<void> deleteDatabase(String path, [dynamic factory]) async {
    await close();
    await (factory ?? databaseFactory).deleteDatabase(path);
  }
}

class Box<V> {
  final String name;
  final BoxCollection boxCollection;

  /// Maximum number of cached values, null for no limit.
  final int? cacheSize;

  final Map<String, V?> _quickAccessCache = {};

  /// _quickAccessCachedKeys is only used to make sure that if you fetch all keys from a
  /// box, you do not need to have an expensive read operation twice. There is
  /// no other usage for this at the moment. So the cache is never partial.
  /// Once the keys are cached, they need to be updated when changed in put and
  /// delete* so that the cache does not become outdated.
  Set<String>? _quickAccessCachedKeys;

  /// Uncommitted writes of the running transaction, null marks a deletion.
  final Map<String, V?> _pending = {};

  /// Whether the running transaction cleared this box before [_pending].
  bool _pendingClear = false;

  static const Set<Type> allowedValueTypes = {
    List<dynamic>,
    Map<dynamic, dynamic>,
    String,
    int,
    double,
    bool,
  };

  Box(this.name, this.boxCollection, {this.cacheSize}) {
    if (!allowedValueTypes.any((type) => V == type)) {
      throw Exception(
        'Illegal value type for Box: "$V". Must be one of $allowedValueTypes',
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
        'Wrong database type! Expected String but got one of type ${value.runtimeType}',
      );
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

  void _cache(String key, V? value) {
    // Re-inserting moves the key to the end, the most recently used.
    _quickAccessCache.remove(key);
    _quickAccessCache[key] = value;
    final cacheSize = this.cacheSize;
    if (cacheSize != null && _quickAccessCache.length > cacheSize) {
      _quickAccessCache.remove(_quickAccessCache.keys.first);
    }
  }

  /// Reads a cached value, marking it as the most recently used.
  V? _cacheHit(String key) {
    if (cacheSize == null) return _quickAccessCache[key];
    final value = _quickAccessCache.remove(key);
    _quickAccessCache[key] = value;
    return value;
  }

  @visibleForTesting
  List<String> get cachedKeys => _quickAccessCache.keys.toList();

  void _addPending(String key, V? value) {
    _pending[key] = value;
    boxCollection._dirtyBoxes!.add(this);
  }

  void _flushPending(Batch batch) {
    if (_pendingClear) batch.delete(name);
    for (final MapEntry(:key, :value) in _pending.entries) {
      if (value == null) {
        batch.delete(name, where: 'k = ?', whereArgs: [key]);
      } else {
        batch.insert(name, {
          'k': key,
          'v': _toString(value),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  }

  Future<List<String>> getAllKeys([Transaction? txn]) async {
    final cachedKeys = _quickAccessCachedKeys;
    if (cachedKeys != null) return cachedKeys.toList();
    final executor = txn ?? boxCollection._db;
    final result = await executor.query(name, columns: ['k']);
    final keys = _withPending(result.map((row) => row['k'] as String));
    // put and delete keep this set in sync with the pending writes. A box
    // with a cache size keeps none, the set would grow without bound.
    if (cacheSize == null) _quickAccessCachedKeys = keys.toSet();
    return keys;
  }

  /// Returns all keys starting with [prefix], using the primary key index.
  Future<List<String>> getKeysWithPrefix(
    String prefix, [
    Transaction? txn,
  ]) async {
    final executor = txn ?? boxCollection._db;
    final result = await executor.query(
      name,
      columns: ['k'],
      where: 'k >= ? AND k < ?',
      whereArgs: [prefix, _prefixEnd(prefix)],
    );
    return _withPending(result.map((row) => row['k'] as String), prefix);
  }

  /// The smallest key after all keys starting with [prefix].
  static String _prefixEnd(String prefix) =>
      prefix.substring(0, prefix.length - 1) +
      String.fromCharCode(prefix.codeUnitAt(prefix.length - 1) + 1);

  /// Applies the pending writes to keys read from the store.
  List<String> _withPending(Iterable<String> storeKeys, [String prefix = '']) =>
      {
        if (!_pendingClear)
          ...storeKeys.where((key) => !_pending.containsKey(key)),
        for (final MapEntry(:key, :value) in _pending.entries)
          if (value != null && key.startsWith(prefix)) key,
      }.toList();

  Future<Map<String, V>> getAllValues([Transaction? txn]) async {
    final executor = txn ?? boxCollection._db;
    final values = <String, V>{};
    if (!_pendingClear) {
      for (final row in await executor.query(name)) {
        values[row['k'] as String] = _fromString(row['v']) as V;
      }
    }
    for (final MapEntry(:key, :value) in _pending.entries) {
      if (value == null) {
        values.remove(key);
      } else {
        values[key] = value;
      }
    }
    return values;
  }

  Future<V?> get(String key, [Transaction? txn]) async {
    if (_pending.containsKey(key)) return _pending[key];
    if (_pendingClear) return null;
    if (_quickAccessCache.containsKey(key)) return _cacheHit(key);
    final executor = txn ?? boxCollection._db;
    final result = await executor.query(
      name,
      columns: ['v'],
      where: 'k = ?',
      whereArgs: [key],
    );
    final value = result.isEmpty ? null : _fromString(result.single['v']);
    // A write sent meanwhile is newer than this answer.
    if (!_pendingClear && !_pending.containsKey(key)) {
      _cache(key, value);
    }
    return value;
  }

  Future<List<V?>> getAll(List<String> keys, [Transaction? txn]) async {
    final values = <String, V?>{};
    final missing = <String>[];
    for (final key in keys) {
      if (_pending.containsKey(key)) {
        values[key] = _pending[key];
      } else if (_pendingClear) {
        values[key] = null;
      } else if (_quickAccessCache.containsKey(key)) {
        values[key] = _cacheHit(key);
      } else {
        missing.add(key);
      }
    }
    final executor = txn ?? boxCollection._db;
    // Older SQLite builds allow only 999 variables per statement.
    for (var i = 0; i < missing.length; i += 800) {
      final chunk = missing.sublist(i, min(i + 800, missing.length));
      final result = await executor.query(
        name,
        where: 'k IN (${chunk.map((_) => '?').join(',')})',
        whereArgs: chunk,
      );
      final found = {
        for (final row in result) row['k'] as String: _fromString(row['v']),
      };
      for (final key in chunk) {
        values[key] = found[key];
        // Misses are cached too, so that the next read needs no query. A
        // write sent meanwhile is newer than this answer.
        if (!_pendingClear && !_pending.containsKey(key)) {
          _cache(key, found[key]);
        }
      }
    }
    return [for (final key in keys) values[key]];
  }

  Future<void> put(String key, V val) async {
    if (boxCollection._dirtyBoxes != null) {
      _addPending(key, val);
    } else {
      await boxCollection._db.insert(name, {
        'k': key,
        'v': _toString(val),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    _cache(key, val);
    _quickAccessCachedKeys?.add(key);
  }

  Future<void> delete(String key) async {
    if (boxCollection._dirtyBoxes != null) {
      _addPending(key, null);
    } else {
      await boxCollection._db.delete(name, where: 'k = ?', whereArgs: [key]);
    }
    // Set to null instead of remove() so that a later read needs no query.
    _cache(key, null);
    _quickAccessCachedKeys?.remove(key);
  }

  Future<void> deleteAll(List<String> keys) async {
    if (boxCollection._dirtyBoxes != null) {
      for (final key in keys) {
        _addPending(key, null);
      }
    } else {
      // Older SQLite builds allow only 999 variables per statement.
      for (var i = 0; i < keys.length; i += 500) {
        final chunk = keys.sublist(i, min(i + 500, keys.length));
        await boxCollection._db.delete(
          name,
          where: 'k IN (${chunk.map((_) => '?').join(',')})',
          whereArgs: chunk,
        );
      }
    }
    for (final key in keys) {
      _cache(key, null);
    }
    _quickAccessCachedKeys?.removeAll(keys);
  }

  void clearQuickAccessCache() {
    _quickAccessCache.clear();
    _quickAccessCachedKeys = null;
  }

  Future<void> clear() async {
    if (boxCollection._dirtyBoxes != null) {
      _pending.clear();
      _pendingClear = true;
      boxCollection._dirtyBoxes!.add(this);
      _quickAccessCache.clear();
      if (cacheSize == null) _quickAccessCachedKeys = {};
    } else {
      await boxCollection._db.delete(name);
      clearQuickAccessCache();
    }
  }
}
