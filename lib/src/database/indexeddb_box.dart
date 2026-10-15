// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:js_interop';

import 'package:meta/meta.dart';
import 'package:web/web.dart';

import '../../matrix_api_lite/utils/logs.dart';
import 'box_overlay.dart';
import 'zone_transaction_mixin.dart';

/// Key-Value store abstraction over IndexedDB so that the sdk database can use
/// a single interface for all platforms. API is inspired by Hive.
class BoxCollection with ZoneTransactionMixin, GroupCommit<Box> {
  final IDBDatabase _db;
  final Set<String> boxNames;
  final String name;

  BoxCollection(this._db, this.boxNames, this.name);

  static Future<BoxCollection> open(
    String name,
    Set<String> boxNames, {
    Object? sqfliteDatabase,
    Object? sqfliteFactory,
    IDBFactory? idbFactory,
    int version = 1,
  }) async {
    idbFactory ??= window.indexedDB;
    final dbOpenCompleter = Completer<BoxCollection>();
    final request = idbFactory.open(name, version);

    request.onerror = (Event event) {
      // An aborted upgrade also fails the open request after db.onerror.
      if (dbOpenCompleter.isCompleted) return;
      Logs().e('[IndexedDBBox] Error loading database - ${request.error}');
      dbOpenCompleter.completeError(
        'Error loading database - ${request.error}',
      );
    }.toJS;

    request.onupgradeneeded = (IDBVersionChangeEvent event) {
      final db = (event.target! as IDBOpenDBRequest).result as IDBDatabase;

      db.onerror = (Event event) {
        // This db stays the collection's, so later errors bubble here too.
        if (dbOpenCompleter.isCompleted) return;
        Logs().e('[IndexedDBBox] [onupgradeneeded] Error loading database');
        dbOpenCompleter.completeError(
          'Error loading database onupgradeneeded.',
        );
      }.toJS;

      for (final name in boxNames) {
        if (db.objectStoreNames.contains(name)) continue;
        db.createObjectStore(
          name,
          IDBObjectStoreParameters(autoIncrement: true),
        );
      }
    }.toJS;

    request.onsuccess = (Event event) {
      final db = request.result as IDBDatabase;
      dbOpenCompleter.complete(BoxCollection(db, boxNames, name));
    }.toJS;
    return dbOpenCompleter.future;
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
    final completer = Completer<void>();
    final txn = _db.transaction(
      [for (final box in boxes) box.name].jsify()!,
      'readwrite',
    );
    txn.onerror = (Event event) {
      Logs().e('[IndexedDBBox] [transaction] Error - ${txn.error}');
      if (completer.isCompleted) return;
      completer.completeError(
        'Transaction not completed due to an error - ${txn.error}'.toJS,
      );
    }.toJS;
    // An abort, e.g. on a full disk, does not always fire an error event.
    txn.onabort = (Event event) {
      if (completer.isCompleted) return;
      Logs().e('[IndexedDBBox] [transaction] Aborted - ${txn.error}');
      completer.completeError(
        'Transaction not completed due to an abort - ${txn.error}'.toJS,
      );
    }.toJS;
    txn.oncomplete = (Event event) {
      completer.complete();
    }.toJS;
    // The requests must be issued without awaiting in between, otherwise
    // IndexedDB commits the transaction early.
    try {
      for (final box in boxes) {
        box._startCommit(txn);
      }
    } catch (_) {
      // The requests sent before must not commit. The abort completes the
      // completer with an error.
      completer.future.ignore();
      txn.abort();
      rethrow;
    }
    await completer.future;
  }

  /// Clears all opened boxes.
  Future<void> clear() => transaction(() async {
    for (final box in _boxes.values) {
      await box.clear();
    }
  });

  // ignore: unnecessary_lambdas, interop members cannot be torn off
  Future<void> close() => closeAfterCommit(() => _db.close());

  Future<void> deleteDatabase(String name, [dynamic factory]) async {
    await close();
    final deleteDatabaseCompleter = Completer();
    final request = ((factory ?? window.indexedDB) as IDBFactory)
        .deleteDatabase(name);
    request.onerror = (Event event) {
      Logs().e('[IndexedDBBox] [deleteDatabase] Error - ${request.error}');
      deleteDatabaseCompleter.completeError(
        'Error deleting database - ${request.error}'.toJS,
      );
    }.toJS;
    request.onsuccess = (Event event) {
      Logs().i('[IndexedDBBox] [deleteDatabase] Database deleted.');
      deleteDatabaseCompleter.complete();
    }.toJS;
    return deleteDatabaseCompleter.future;
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

  Box(this.name, this.boxCollection, {this.cacheSize});

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

  /// Sends the pending writes as requests of [txn].
  void _startCommit(IDBTransaction txn) {
    final writes = overlay.startCommit();
    final store = txn.objectStore(name);
    if (overlay.committingClear) store.clear();
    final dropped = <String>[];
    for (final MapEntry(:key, :value) in writes.entries) {
      if (value == null) {
        store.delete(key.toJS);
        continue;
      }
      try {
        // Throws synchronously if the value cannot be cloned.
        store.put(value.jsify(), key.toJS);
      } catch (e, s) {
        // One value that cannot be stored must not block all others.
        Logs().e('[IndexedDBBox] Dropped a value of $name/$key', e, s);
        dropped.add(key);
      }
    }
    for (final key in dropped) {
      writes.remove(key);
      _quickAccessCache.remove(key);
      _quickAccessCachedKeys = null;
    }
  }

  Future<void> _write(String key, V? value) {
    overlay.pending[key] = value;
    _cache(key, value);
    return boxCollection.written(this);
  }

  Future<List<String>> getAllKeys() async {
    final cachedKeys = _quickAccessCachedKeys;
    if (cachedKeys != null) return cachedKeys.toList();
    final txn = boxCollection._db.transaction(name.toJS, 'readonly');
    final keys = overlay.keys(await _getAllKeysFromStore(txn));
    // put and delete keep this set in sync with the pending writes. A box
    // with a cache size keeps none, the set would grow without bound.
    if (cacheSize == null) _quickAccessCachedKeys = keys.toSet();
    return keys;
  }

  /// Reads the keys from the object store, bypassing [_quickAccessCachedKeys].
  ///
  /// [put] and [delete] keep the cached key set complete, but in their own
  /// mutation order rather than in the store's key order, while
  /// [IDBObjectStore.getAll] always returns the values in key order. So only
  /// freshly read keys may be zipped against those values.
  Future<List<String>> _getAllKeysFromStore(IDBTransaction txn) async {
    final store = txn.objectStore(name);
    final getAllKeysCompleter = Completer();
    final request = store.getAllKeys();
    request.onerror = (Event event) {
      Logs().e('[IndexedDBBox] [getAllKeys] Error - ${request.error}');
      getAllKeysCompleter.completeError(
        '[IndexedDBBox] [getAllKeys] Error - ${request.error}'.toJS,
      );
    }.toJS;
    request.onsuccess = (Event event) {
      getAllKeysCompleter.complete();
    }.toJS;
    await getAllKeysCompleter.future;
    return (request.result?.dartify() as List?)?.cast<String>() ?? [];
  }

  /// Returns all keys starting with [prefix], using the key order of the
  /// object store.
  Future<List<String>> getKeysWithPrefix(String prefix) async {
    final txn = boxCollection._db.transaction(name.toJS, 'readonly');
    final request = txn
        .objectStore(name)
        .getAllKeys(
          IDBKeyRange.bound(prefix.toJS, _prefixEnd(prefix).toJS, false, true),
        );
    final completer = Completer();
    request.onerror = (Event event) {
      Logs().e('[IndexedDBBox] [getKeysWithPrefix] Error - ${request.error}');
      completer.completeError(
        '[IndexedDBBox] [getKeysWithPrefix] Error - ${request.error}'.toJS,
      );
    }.toJS;
    request.onsuccess = (Event event) {
      completer.complete();
    }.toJS;
    await completer.future;
    return overlay.keys(
      (request.result?.dartify() as List?)?.cast<String>() ?? [],
      prefix,
    );
  }

  /// The smallest key after all keys starting with [prefix].
  static String _prefixEnd(String prefix) =>
      prefix.substring(0, prefix.length - 1) +
      String.fromCharCode(prefix.codeUnitAt(prefix.length - 1) + 1);

  Future<Map<String, V>> getAllValues() async {
    final txn = boxCollection._db.transaction(name.toJS, 'readonly');
    final store = txn.objectStore(name);
    final map = <String, V>{};

    /// NOTE: This is a workaround to get the keys as [IDBObjectStore.getAll()]
    /// only returns the values as a list.
    /// And using the [IDBObjectStore.openCursor()] method is not working as expected.
    final keys = await _getAllKeysFromStore(txn);

    final getAllValuesCompleter = Completer();
    final getAllValuesRequest = store.getAll();
    getAllValuesRequest.onerror = (Event event) {
      Logs().e(
        '[IndexedDBBox] [getAllValues] Error - ${getAllValuesRequest.error}',
      );
      getAllValuesCompleter.completeError(
        '[IndexedDBBox] [getAllValues] Error - ${getAllValuesRequest.error}'
            .toJS,
      );
    }.toJS;
    getAllValuesRequest.onsuccess = (Event event) {
      final values = getAllValuesRequest.result.dartify() as List;
      for (var i = 0; i < values.length; i++) {
        map[keys[i]] = _fromValue(values[i]) as V;
      }
      getAllValuesCompleter.complete();
    }.toJS;
    await getAllValuesCompleter.future;
    return overlay.values(map);
  }

  Future<V?> get(String key) async {
    final uncommitted = overlay.lookup(key);
    if (uncommitted != null) return uncommitted.value;
    if (_quickAccessCache.containsKey(key)) return _cacheHit(key);
    final txn = boxCollection._db.transaction(name.toJS, 'readonly');
    final store = txn.objectStore(name);
    final getObjectRequest = store.get(key.toJS);
    final getObjectCompleter = Completer();
    getObjectRequest.onerror = (Event event) {
      Logs().e('[IndexedDBBox] [get] Error - ${getObjectRequest.error}');
      getObjectCompleter.completeError(
        '[IndexedDBBox] [get] Error - ${getObjectRequest.error}'.toJS,
      );
    }.toJS;
    getObjectRequest.onsuccess = (Event event) {
      getObjectCompleter.complete();
    }.toJS;
    await getObjectCompleter.future;
    final value = _fromValue(getObjectRequest.result?.dartify());
    // A write sent meanwhile is newer than this answer.
    final newer = overlay.lookup(key);
    if (newer != null) return newer.value;
    _cache(key, value);
    return value;
  }

  Future<List<V?>> getAll(List<String> keys) async {
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
    if (missing.isEmpty) return [for (final key in keys) values[key]];
    final txn = boxCollection._db.transaction(name.toJS, 'readonly');
    final store = txn.objectStore(name);
    final found = await Future.wait(
      missing.map((key) async {
        final getObjectRequest = store.get(key.toJS);
        final getObjectCompleter = Completer();
        getObjectRequest.onerror = (Event event) {
          Logs().e(
            '[IndexedDBBox] [getAll] Error at key $key - ${getObjectRequest.error}',
          );
          getObjectCompleter.completeError(
            '[IndexedDBBox] [getAll] Error at key $key - ${getObjectRequest.error}'
                .toJS,
          );
        }.toJS;
        getObjectRequest.onsuccess = (Event event) {
          getObjectCompleter.complete();
        }.toJS;
        await getObjectCompleter.future;
        return _fromValue(getObjectRequest.result?.dartify());
      }),
    );
    for (var i = 0; i < missing.length; i++) {
      final key = missing[i];
      // A write sent meanwhile is newer than this answer.
      final newer = overlay.lookup(key);
      if (newer != null) {
        values[key] = newer.value;
        continue;
      }
      values[key] = found[i];
      // Misses are cached too, so that the next read needs no request.
      _cache(key, found[i]);
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
    // Cached as null so that a later read needs no request.
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

  V? _fromValue(Object? value) {
    if (value == null) return null;
    switch (V) {
      case const (List<dynamic>):
        return List.unmodifiable(value as List) as V;
      case const (Map<dynamic, dynamic>):
        return Map.unmodifiable(value as Map) as V;
      case const (int):
        // Workaround that [JSAny.dartify] on wasm could turn an int into double
        if (value is double) return value.round() as V;
        return value as V;
      case const (double):
      case const (bool):
      case const (String):
      default:
        return value as V;
    }
  }
}
