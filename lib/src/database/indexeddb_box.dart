// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:js_interop';

import 'package:meta/meta.dart';
import 'package:web/web.dart';

import '../../matrix_api_lite/utils/logs.dart';
import 'zone_transaction_mixin.dart';

/// Key-Value store abstraction over IndexedDB so that the sdk database can use
/// a single interface for all platforms. API is inspired by Hive.
class BoxCollection with ZoneTransactionMixin {
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
      Logs().e('[IndexedDBBox] Error loading database - ${request.error}');
      dbOpenCompleter.completeError(
        'Error loading database - ${request.error}',
      );
    }.toJS;

    request.onupgradeneeded = (IDBVersionChangeEvent event) {
      final db = (event.target! as IDBOpenDBRequest).result as IDBDatabase;

      db.onerror = (Event event) {
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

  /// Writes from other zones while a transaction is open, also while it
  /// commits, join it, so that its older writes of the same key cannot
  /// overtake them. If it fails, they are still written.
  Future<void> transaction(
    Future<void> Function() action, {
    List<String>? boxNames,
    bool readOnly = false,
  }) => zoneTransaction(() async {
    // A nested transaction joins the outer one, so all writes stay in order.
    if (_dirtyBoxes != null) return action();
    final dirtyBoxes = _dirtyBoxes = {};
    Future<void> commitBatch() async {
      final boxes = dirtyBoxes.toList();
      dirtyBoxes.clear();
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
          box._flushPending(txn);
        }
      } catch (_) {
        // E.g. a value that cannot be cloned: the requests sent before it
        // must not commit. The abort completes the completer with an error.
        completer.future.ignore();
        txn.abort();
        rethrow;
      }
      await completer.future;
    }

    // Writes from other zones may arrive while we commit. They get the next
    // transaction, so that no write is overtaken by an older one. The loop
    // stays here: the last check must run in the same microtask as the finally.
    try {
      await action();
      while (dirtyBoxes.isNotEmpty) {
        await commitBatch();
      }
    } catch (_) {
      // Nothing of a failed transaction may stay visible, but the writes from
      // other zones that joined it are still written.
      dirtyBoxes.clear();
      for (final box in _boxes) {
        box.clearQuickAccessCache();
        box._pending
          ..clear()
          ..addAll(box._foreignPending);
        box._pendingClear = box._foreignClear;
        if (box._pending.isNotEmpty || box._pendingClear) dirtyBoxes.add(box);
      }
      try {
        while (dirtyBoxes.isNotEmpty) {
          await commitBatch();
        }
      } catch (e, s) {
        for (final box in _boxes) {
          box.clearQuickAccessCache();
        }
        Logs().e(
          '[IndexedDBBox] Lost writes from other zones of a failed transaction',
          e,
          s,
        );
      }
      rethrow;
    } finally {
      _dirtyBoxes = null;
      // Dropped only now: a read sent before a commit merges the pending
      // writes after the store answered, which is before the commit ends.
      for (final box in _boxes) {
        box._pending.clear();
        box._pendingClear = false;
        box._foreignPending.clear();
        box._foreignClear = false;
      }
    }
  });

  Future<void> clear() async {
    final transactionCompleter = Completer();
    final txn = _db.transaction(boxNames.toList().jsify()!, 'readwrite');
    for (final name in boxNames) {
      final objStoreClearCompleter = Completer();
      final request = txn.objectStore(name).clear();
      request.onerror = (Event event) {
        Logs().e(
          '[IndexedDBBox] [clear] Object store clear error - ${request.error}',
        );
        objStoreClearCompleter.completeError(
          'Object store clear not completed due to an error - ${request.error}'
              .toJS,
        );
      }.toJS;
      request.onsuccess = (Event event) {
        objStoreClearCompleter.complete();
      }.toJS;
      unawaited(objStoreClearCompleter.future);
    }
    txn.onerror = (Event event) {
      Logs().e('[IndexedDBBox] [clear] Error - ${txn.error}');
      transactionCompleter.completeError(
        'DB clear transaction not completed due to an error - ${txn.error}'
            .toJS,
      );
    }.toJS;
    txn.oncomplete = (Event event) {
      transactionCompleter.complete();
    }.toJS;
    return transactionCompleter.future;
  }

  Future<void> close() => zoneTransaction(() async => _db.close());

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

  /// Writes from other zones during the running transaction, kept if it
  /// fails. Null marks a deletion.
  final Map<String, V?> _foreignPending = {};

  /// Whether another zone cleared this box during the running transaction.
  bool _foreignClear = false;

  Box(this.name, this.boxCollection, {this.cacheSize});

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
    if (!boxCollection.inTransactionZone) _foreignPending[key] = value;
    boxCollection._dirtyBoxes!.add(this);
  }

  void _flushPending(IDBTransaction txn) {
    final store = txn.objectStore(name);
    if (_pendingClear) store.clear();
    for (final MapEntry(:key, :value) in _pending.entries) {
      if (value == null) {
        store.delete(key.toJS);
      } else {
        store.put(value.jsify(), key.toJS);
      }
    }
  }

  Future<List<String>> getAllKeys([IDBTransaction? txn]) async {
    final cachedKeys = _quickAccessCachedKeys;
    if (cachedKeys != null) return cachedKeys.toList();
    txn ??= boxCollection._db.transaction(name.toJS, 'readonly');
    final keys = _withPending(await _getAllKeysFromStore(txn));
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
  Future<List<String>> getKeysWithPrefix(
    String prefix, [
    IDBTransaction? txn,
  ]) async {
    txn ??= boxCollection._db.transaction(name.toJS, 'readonly');
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
    return _withPending(
      (request.result?.dartify() as List?)?.cast<String>() ?? [],
      prefix,
    );
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

  Future<Map<String, V>> getAllValues([IDBTransaction? txn]) async {
    txn ??= boxCollection._db.transaction(name.toJS, 'readonly');
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
    if (_pendingClear) map.clear();
    for (final MapEntry(:key, :value) in _pending.entries) {
      if (value == null) {
        map.remove(key);
      } else {
        map[key] = value;
      }
    }
    return map;
  }

  Future<V?> get(String key, [IDBTransaction? txn]) async {
    if (_pending.containsKey(key)) return _pending[key];
    if (_pendingClear) return null;
    if (_quickAccessCache.containsKey(key)) return _cacheHit(key);
    txn ??= boxCollection._db.transaction(name.toJS, 'readonly');
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
    if (!_pendingClear && !_pending.containsKey(key)) {
      _cache(key, value);
    }
    return value;
  }

  Future<List<V?>> getAll(List<String> keys, [IDBTransaction? txn]) async {
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
    if (missing.isEmpty) return [for (final key in keys) values[key]];
    txn ??= boxCollection._db.transaction(name.toJS, 'readonly');
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
      values[key] = found[i];
      // Misses are cached too, so that the next read needs no request. A
      // write sent meanwhile is newer than this answer.
      if (!_pendingClear && !_pending.containsKey(key)) {
        _cache(key, found[i]);
      }
    }
    return [for (final key in keys) values[key]];
  }

  Future<void> put(String key, V val) async {
    if (boxCollection._dirtyBoxes != null) {
      _addPending(key, val);
      _cache(key, val);
      _quickAccessCachedKeys?.add(key);
      return;
    }

    final txn = boxCollection._db.transaction(name.toJS, 'readwrite');
    final store = txn.objectStore(name);
    final putRequest = store.put(val.jsify(), key.toJS);
    final putCompleter = Completer();
    putRequest.onerror = (Event event) {
      Logs().e('[IndexedDBBox] [put] Error - ${putRequest.error}');
      putCompleter.completeError(
        '[IndexedDBBox] [put] Error - ${putRequest.error}'.toJS,
      );
    }.toJS;
    putRequest.onsuccess = (Event event) {
      putCompleter.complete();
    }.toJS;
    await putCompleter.future;
    // A transaction's write sent meanwhile is newer than this one.
    if (_pendingClear || _pending.containsKey(key)) return;
    _cache(key, val);
    _quickAccessCachedKeys?.add(key);
    return;
  }

  Future<void> delete(String key) async {
    if (boxCollection._dirtyBoxes != null) {
      _addPending(key, null);
      _cache(key, null);
      _quickAccessCachedKeys?.remove(key);
      return;
    }

    final txn = boxCollection._db.transaction(name.toJS, 'readwrite');
    final store = txn.objectStore(name);
    final deleteRequest = store.delete(key.toJS);
    final deleteCompleter = Completer();
    deleteRequest.onerror = (Event event) {
      Logs().e('[IndexedDBBox] [delete] Error - ${deleteRequest.error}');
      deleteCompleter.completeError(
        '[IndexedDBBox] [delete] Error - ${deleteRequest.error}'.toJS,
      );
    }.toJS;
    deleteRequest.onsuccess = (Event event) {
      deleteCompleter.complete();
    }.toJS;
    await deleteCompleter.future;
    // A transaction's write sent meanwhile is newer than this one.
    if (_pendingClear || _pending.containsKey(key)) return;
    // Set to null instead of remove() so that a later read needs no request.
    _cache(key, null);
    _quickAccessCachedKeys?.remove(key);
    return;
  }

  Future<void> deleteAll(List<String> keys) async {
    if (boxCollection._dirtyBoxes != null) {
      for (final key in keys) {
        _addPending(key, null);
        _cache(key, null);
      }
      _quickAccessCachedKeys?.removeAll(keys);
      return;
    }

    final txn = boxCollection._db.transaction(name.toJS, 'readwrite');
    final store = txn.objectStore(name);
    for (final key in keys) {
      final deleteRequest = store.delete(key.toJS);
      final deleteCompleter = Completer();
      deleteRequest.onerror = (Event event) {
        Logs().e(
          '[IndexedDBBox] [deleteAll] Error at key $key - ${deleteRequest.error}',
        );
        deleteCompleter.completeError(
          '[IndexedDBBox] [deleteAll] Error at key $key - ${deleteRequest.error}'
              .toJS,
        );
      }.toJS;
      deleteRequest.onsuccess = (Event event) {
        deleteCompleter.complete();
      }.toJS;
      await deleteCompleter.future;
      // A transaction's write sent meanwhile is newer than this one.
      if (_pendingClear || _pending.containsKey(key)) continue;
      _cache(key, null);
      _quickAccessCachedKeys?.remove(key);
    }
    return;
  }

  void clearQuickAccessCache() {
    _quickAccessCache.clear();
    _quickAccessCachedKeys = null;
  }

  Future<void> clear() async {
    if (boxCollection._dirtyBoxes != null) {
      _pending.clear();
      _pendingClear = true;
      if (!boxCollection.inTransactionZone) {
        _foreignPending.clear();
        _foreignClear = true;
      }
      boxCollection._dirtyBoxes!.add(this);
      _quickAccessCache.clear();
      if (cacheSize == null) _quickAccessCachedKeys = {};
    } else {
      final txn = boxCollection._db.transaction(name.toJS, 'readwrite');
      final store = txn.objectStore(name);
      final clearRequest = store.clear();
      final clearCompleter = Completer();
      clearRequest.onerror = (Event event) {
        Logs().e('[IndexedDBBox] [clear] Error - ${clearRequest.error}');
        clearCompleter.completeError(
          '[IndexedDBBox] [clear] Error - ${clearRequest.error}'.toJS,
        );
      }.toJS;
      clearRequest.onsuccess = (Event event) {
        clearCompleter.complete();
      }.toJS;
      await clearCompleter.future;
      clearQuickAccessCache();
    }
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
