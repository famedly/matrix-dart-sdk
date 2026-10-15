// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:sqflite_common/sqflite.dart';

import '../../matrix_api_lite/utils/logs.dart';
import 'box_overlay.dart';
import 'zone_transaction_mixin.dart';

/// Key-Value store abstraction over Sqflite so that the sdk database can use
/// a single interface for all platforms. API is inspired by Hive.
class BoxCollection with ZoneTransactionMixin, GroupCommit<Box> {
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

  final _boxes = <String, Box>{};

  Box<V> openBox<V>(String name, {int? cacheSize}) {
    if (!boxNames.contains(name)) {
      throw ('Box with name $name is not in the known box names of this collection.');
    }
    // One instance per name, so that all readers see the same uncommitted
    // writes.
    return (_boxes[name] ??= Box<V>(name, this, cacheSize: cacheSize))
        as Box<V>;
  }

  @override
  Future<void> commitBoxes(List<Box> boxes) async {
    final writes = [for (final box in boxes) (box, box._startCommit())];
    final (box, ops) = writes.first;
    if (writes.length == 1 && !box.overlay.committingClear && ops.length == 1) {
      // A single statement is atomic anyway and saves the batch's BEGIN and
      // COMMIT round trips.
      final (key, value) = ops.single;
      value == null
          ? await _db.delete(box.name, where: 'k = ?', whereArgs: [key])
          : await _db.insert(box.name, {
              'k': key,
              'v': value,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
      return;
    }
    final batch = _db.batch();
    for (final (box, ops) in writes) {
      if (box.overlay.committingClear) batch.delete(box.name);
      for (final (key, value) in ops) {
        value == null
            ? batch.delete(box.name, where: 'k = ?', whereArgs: [key])
            : batch.insert(box.name, {
                'k': key,
                'v': value,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    await batch.commit(noResult: true);
  }

  /// Clears all opened boxes.
  Future<void> clear() => transaction(() async {
    for (final box in _boxes.values) {
      await box.clear();
    }
  });

  Future<void> close() => closeAfterCommit(_db.close);

  @Deprecated('use collection.deleteDatabase now')
  static Future<void> delete(String path, [dynamic factory]) =>
      (factory ?? databaseFactory).deleteDatabase(path);

  Future<void> deleteDatabase(String path, [dynamic factory]) async {
    await close();
    await (factory ?? databaseFactory).deleteDatabase(path);
  }
}

class Box<V> implements OverlayBox {
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

  @override
  final Overlay<V> overlay = Overlay<V>();

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
    if (cacheSize != null &&
        _quickAccessCache.length > cacheSize + cacheSize ~/ 10) {
      // Dropping in batches keeps eviction O(1) amortized; keys.first has to
      // skip the deleted slots at the front of the map.
      _quickAccessCache.keys
          .take(_quickAccessCache.length - cacheSize)
          .toList()
          .forEach(_quickAccessCache.remove);
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

  /// Starts the commit of the pending writes and returns them as keys with
  /// encoded values, null for a deletion. A clear goes first.
  List<(String, String?)> _startCommit() {
    final writes = overlay.startCommit();
    final ops = <(String, String?)>[];
    final dropped = <String>[];
    for (final MapEntry(:key, :value) in writes.entries) {
      try {
        ops.add((key, _toString(value)));
      } catch (e, s) {
        // One value that cannot be stored must not block all others.
        Logs().e('[SqfliteBox] Dropped a value of $name/$key', e, s);
        dropped.add(key);
      }
    }
    for (final key in dropped) {
      writes.remove(key);
      _quickAccessCache.remove(key);
      _quickAccessCachedKeys = null;
    }
    return ops;
  }

  Future<void> _write(String key, V? value) {
    overlay.pending[key] = value;
    _cache(key, value);
    return boxCollection.written(this);
  }

  Future<List<String>> getAllKeys([Transaction? txn]) async {
    final cachedKeys = _quickAccessCachedKeys;
    if (cachedKeys != null) return cachedKeys.toList();
    final executor = txn ?? boxCollection._db;
    final result = await executor.query(name, columns: ['k']);
    final keys = overlay.keys(result.map((row) => row['k'] as String));
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
    return overlay.keys(result.map((row) => row['k'] as String), prefix);
  }

  /// The smallest key after all keys starting with [prefix].
  static String _prefixEnd(String prefix) =>
      prefix.substring(0, prefix.length - 1) +
      String.fromCharCode(prefix.codeUnitAt(prefix.length - 1) + 1);

  Future<Map<String, V>> getAllValues([Transaction? txn]) async {
    final executor = txn ?? boxCollection._db;
    final values = <String, V>{};
    for (final row in await executor.query(name)) {
      values[row['k'] as String] = _fromString(row['v']) as V;
    }
    return overlay.values(values);
  }

  Future<V?> get(String key, [Transaction? txn]) async {
    final uncommitted = overlay.lookup(key);
    if (uncommitted != null) return uncommitted.value;
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
    final newer = overlay.lookup(key);
    if (newer != null) return newer.value;
    _cache(key, value);
    return value;
  }

  Future<List<V?>> getAll(List<String> keys, [Transaction? txn]) async {
    final values = <String, V?>{};
    final missing = <String>[];
    for (final key in keys) {
      final uncommitted = overlay.lookup(key);
      if (uncommitted != null) {
        values[key] = uncommitted.value;
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
        // A write sent meanwhile is newer than this answer.
        final newer = overlay.lookup(key);
        if (newer != null) {
          values[key] = newer.value;
          continue;
        }
        values[key] = found[key];
        // Misses are cached too, so that the next read needs no query.
        _cache(key, found[key]);
      }
    }
    return [for (final key in keys) values[key]];
  }

  /// Completes when the write is committed, or at once in a transaction,
  /// which commits it when it ends.
  Future<void> put(String key, V val) {
    _quickAccessCachedKeys?.add(key);
    return _write(key, val);
  }

  Future<void> delete(String key) {
    _quickAccessCachedKeys?.remove(key);
    // Cached as null so that a later read needs no query.
    return _write(key, null);
  }

  Future<void> deleteAll(List<String> keys) {
    _quickAccessCachedKeys?.removeAll(keys);
    for (final key in keys) {
      overlay.pending[key] = null;
      _cache(key, null);
    }
    return boxCollection.written(this);
  }

  void clearQuickAccessCache() {
    _quickAccessCache.clear();
    _quickAccessCachedKeys = null;
  }

  Future<void> clear() {
    overlay.clear();
    _quickAccessCache.clear();
    _quickAccessCachedKeys = cacheSize == null ? {} : null;
    return boxCollection.written(this);
  }
}
