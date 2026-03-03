import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

import 'package:matrix/matrix_api_lite/utils/logs.dart';
import 'package:matrix/src/database/zone_transaction_mixin.dart';

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
      Logs().e(
        '[IndexedDBBox] Error loading database - ${request.error?.toString()}',
      );
      dbOpenCompleter.completeError(
        'Error loading database - ${request.error?.toString()}',
      );
    }.toJS;

    request.onupgradeneeded = (IDBVersionChangeEvent event) {
      final db = (event.target! as IDBOpenDBRequest).result as IDBDatabase;

      db.onerror = (Event event) {
        Logs().e('[IndexedDBBox] [onupgradeneeded] Error loading database');
        dbOpenCompleter
            .completeError('Error loading database onupgradeneeded.');
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

  Box<V> openBox<V>(String name) {
    if (!boxNames.contains(name)) {
      throw ('Box with name $name is not in the known box names of this collection.');
    }
    return Box<V>(name, this);
  }

  List<Future<void> Function(IDBTransaction txn)>? _txnCache;

  Future<void> transaction(
    Future<void> Function() action, {
    List<String>? boxNames,
    bool readOnly = false,
  }) =>
      zoneTransaction(() async {
        final txnCache = _txnCache = [];
        await action();
        final cache =
            List<Future<void> Function(IDBTransaction txn)>.from(txnCache);
        _txnCache = null;
        if (cache.isEmpty) return;

        final transactionCompleter = Completer<void>();
        final txn = _db.transaction(
          boxNames?.jsify() ?? _db.objectStoreNames,
          readOnly ? 'readonly' : 'readwrite',
        );
        for (final fun in cache) {
          // The IDB methods return a Future in Dart but must not be awaited in
          // order to have an actual transaction. They must only be performed and
          // then the transaction object must call `txn.completed;` which then
          // returns the actual future.
          // https://developer.mozilla.org/en-US/docs/Web/API/IDBTransaction
          unawaited(fun(txn));
        }

        txn.onerror = (Event event) {
          Logs().e(
            '[IndexedDBBox] [transaction] Error - ${txn.error?.toString()}',
          );
          transactionCompleter.completeError(
            'Transaction not completed due to an error - ${txn.error?.toString()}'
                .toJS,
          );
        }.toJS;

        txn.oncomplete = (Event event) {
          transactionCompleter.complete();
        }.toJS;
        return transactionCompleter.future;
      });

  Future<void> clear() async {
    final transactionCompleter = Completer();
    final txn = _db.transaction(boxNames.toList().jsify()!, 'readwrite');
    for (final name in boxNames) {
      final objStoreClearCompleter = Completer();
      final request = txn.objectStore(name).clear();
      request.onerror = (Event event) {
        Logs().e(
          '[IndexedDBBox] [clear] Object store clear error - ${request.error?.toString()}',
        );
        objStoreClearCompleter.completeError(
          'Object store clear not completed due to an error - ${request.error?.toString()}'
              .toJS,
        );
      }.toJS;
      request.onsuccess = (Event event) {
        objStoreClearCompleter.complete();
      }.toJS;
      unawaited(objStoreClearCompleter.future);
    }
    txn.onerror = (Event event) {
      Logs().e('[IndexedDBBox] [clear] Error - ${txn.error?.toString()}');
      transactionCompleter.completeError(
        'DB clear transaction not completed due to an error - ${txn.error?.toString()}'
            .toJS,
      );
    }.toJS;
    txn.oncomplete = (Event event) {
      transactionCompleter.complete();
    }.toJS;
    return transactionCompleter.future;
  }

  Future<void> close() async {
    assert(_txnCache == null, 'Database closed while in transaction!');
    // Note, zoneTransaction and txnCache are different kinds of transactions.
    return zoneTransaction(() async => _db.close());
  }

  Future<void> deleteDatabase(String name, [dynamic factory]) async {
    await close();
    final deleteDatabaseCompleter = Completer();
    final request =
        ((factory ?? window.indexedDB) as IDBFactory).deleteDatabase(name);
    request.onerror = (Event event) {
      Logs().e(
        '[IndexedDBBox] [deleteDatabase] Error - ${request.error?.toString()}',
      );
      deleteDatabaseCompleter.completeError(
        'Error deleting database - ${request.error?.toString()}'.toJS,
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
  final Map<String, V?> _quickAccessCache = {};

  /// _quickAccessCachedKeys is only used to make sure that if you fetch all keys from a
  /// box, you do not need to have an expensive read operation twice. There is
  /// no other usage for this at the moment. So the cache is never partial.
  /// Once the keys are cached, they need to be updated when changed in put and
  /// delete* so that the cache does not become outdated.
  Set<String>? _quickAccessCachedKeys;

  Box(this.name, this.boxCollection);

  Future<List<String>> getAllKeys([IDBTransaction? txn]) async {
    if (_quickAccessCachedKeys != null) return _quickAccessCachedKeys!.toList();
    txn ??= boxCollection._db.transaction(name.toJS, 'readonly');
    final store = txn.objectStore(name);
    final getAllKeysCompleter = Completer();
    final request = store.getAllKeys();
    request.onerror = (Event event) {
      Logs().e(
        '[IndexedDBBox] [getAllKeys] Error - ${request.error?.toString()}',
      );
      getAllKeysCompleter.completeError(
        '[IndexedDBBox] [getAllKeys] Error - ${request.error?.toString()}'.toJS,
      );
    }.toJS;
    request.onsuccess = (Event event) {
      getAllKeysCompleter.complete();
    }.toJS;
    await getAllKeysCompleter.future;
    final keys = (request.result?.dartify() as List?)?.cast<String>() ?? [];
    _quickAccessCachedKeys = keys.toSet();
    return keys;
  }

  Future<Map<String, V>> getAllValues([IDBTransaction? txn]) async {
    txn ??= boxCollection._db.transaction(name.toJS, 'readonly');
    final store = txn.objectStore(name);
    final map = <String, V>{};

    /// NOTE: This is a workaround to get the keys as [IDBObjectStore.getAll()]
    /// only returns the values as a list.
    /// And using the [IDBObjectStore.openCursor()] method is not working as expected.
    final keys = await getAllKeys(txn);

    final getAllValuesCompleter = Completer();
    final getAllValuesRequest = store.getAll();
    getAllValuesRequest.onerror = (Event event) {
      Logs().e(
        '[IndexedDBBox] [getAllValues] Error - ${getAllValuesRequest.error?.toString()}',
      );
      getAllValuesCompleter.completeError(
        '[IndexedDBBox] [getAllValues] Error - ${getAllValuesRequest.error?.toString()}'
            .toJS,
      );
    }.toJS;
    getAllValuesRequest.onsuccess = (Event event) {
      final values = getAllValuesRequest.result.dartify() as List;
      for (int i = 0; i < values.length; i++) {
        map[keys[i]] = _fromValue(values[i]) as V;
      }
      getAllValuesCompleter.complete();
    }.toJS;
    await getAllValuesCompleter.future;
    return map;
  }

  Future<V?> get(String key, [IDBTransaction? txn]) async {
    if (_quickAccessCache.containsKey(key)) return _quickAccessCache[key];
    txn ??= boxCollection._db.transaction(name.toJS, 'readonly');
    final store = txn.objectStore(name);
    final getObjectRequest = store.get(key.toJS);
    final getObjectCompleter = Completer();
    getObjectRequest.onerror = (Event event) {
      Logs().e(
        '[IndexedDBBox] [get] Error - ${getObjectRequest.error?.toString()}',
      );
      getObjectCompleter.completeError(
        '[IndexedDBBox] [get] Error - ${getObjectRequest.error?.toString()}'
            .toJS,
      );
    }.toJS;
    getObjectRequest.onsuccess = (Event event) {
      getObjectCompleter.complete();
    }.toJS;
    await getObjectCompleter.future;
    _quickAccessCache[key] = _fromValue(getObjectRequest.result?.dartify());
    return _quickAccessCache[key];
  }

  Future<List<V?>> getAll(List<String> keys, [IDBTransaction? txn]) async {
    if (keys.every((key) => _quickAccessCache.containsKey(key))) {
      return keys.map((key) => _quickAccessCache[key]).toList();
    }
    txn ??= boxCollection._db.transaction(name.toJS, 'readonly');
    final store = txn.objectStore(name);
    final list = await Future.wait(
      keys.map((key) async {
        final getObjectRequest = store.get(key.toJS);
        final getObjectCompleter = Completer();
        getObjectRequest.onerror = (Event event) {
          Logs().e(
            '[IndexedDBBox] [getAll] Error at key $key - ${getObjectRequest.error?.toString()}',
          );
          getObjectCompleter.completeError(
            '[IndexedDBBox] [getAll] Error at key $key - ${getObjectRequest.error?.toString()}'
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
    for (var i = 0; i < keys.length; i++) {
      _quickAccessCache[keys[i]] = list[i];
    }
    return list;
  }

  Future<void> put(String key, V val, [IDBTransaction? txn]) async {
    if (boxCollection._txnCache != null) {
      boxCollection._txnCache!.add((txn) => put(key, val, txn));
      _quickAccessCache[key] = val;
      _quickAccessCachedKeys?.add(key);
      return;
    }

    txn ??= boxCollection._db.transaction(name.toJS, 'readwrite');
    final store = txn.objectStore(name);
    final putRequest = store.put(val.jsify(), key.toJS);
    final putCompleter = Completer();
    putRequest.onerror = (Event event) {
      Logs().e(
        '[IndexedDBBox] [put] Error - ${putRequest.error?.toString()}',
      );
      putCompleter.completeError(
        '[IndexedDBBox] [put] Error - ${putRequest.error?.toString()}'.toJS,
      );
    }.toJS;
    putRequest.onsuccess = (Event event) {
      putCompleter.complete();
    }.toJS;
    await putCompleter.future;
    _quickAccessCache[key] = val;
    _quickAccessCachedKeys?.add(key);
    return;
  }

  Future<void> delete(String key, [IDBTransaction? txn]) async {
    if (boxCollection._txnCache != null) {
      boxCollection._txnCache!.add((txn) => delete(key, txn));
      _quickAccessCache[key] = null;
      _quickAccessCachedKeys?.remove(key);
      return;
    }

    txn ??= boxCollection._db.transaction(name.toJS, 'readwrite');
    final store = txn.objectStore(name);
    final deleteRequest = store.delete(key.toJS);
    final deleteCompleter = Completer();
    deleteRequest.onerror = (Event event) {
      Logs().e(
        '[IndexedDBBox] [delete] Error - ${deleteRequest.error?.toString()}',
      );
      deleteCompleter.completeError(
        '[IndexedDBBox] [delete] Error - ${deleteRequest.error?.toString()}'
            .toJS,
      );
    }.toJS;
    deleteRequest.onsuccess = (Event event) {
      deleteCompleter.complete();
    }.toJS;
    await deleteCompleter.future;

    // Set to null instead remove() so that inside of transactions null is
    // returned.
    _quickAccessCache[key] = null;
    _quickAccessCachedKeys?.remove(key);
    return;
  }

  Future<void> deleteAll(List<String> keys, [IDBTransaction? txn]) async {
    if (boxCollection._txnCache != null) {
      boxCollection._txnCache!.add((txn) => deleteAll(keys, txn));
      for (final key in keys) {
        _quickAccessCache[key] = null;
      }
      _quickAccessCachedKeys?.removeAll(keys);
      return;
    }

    txn ??= boxCollection._db.transaction(name.toJS, 'readwrite');
    final store = txn.objectStore(name);
    for (final key in keys) {
      final deleteRequest = store.delete(key.toJS);
      final deleteCompleter = Completer();
      deleteRequest.onerror = (Event event) {
        Logs().e(
          '[IndexedDBBox] [deleteAll] Error at key $key - ${deleteRequest.error?.toString()}',
        );
        deleteCompleter.completeError(
          '[IndexedDBBox] [deleteAll] Error at key $key - ${deleteRequest.error?.toString()}'
              .toJS,
        );
      }.toJS;
      deleteRequest.onsuccess = (Event event) {
        deleteCompleter.complete();
      }.toJS;
      await deleteCompleter.future;
      _quickAccessCache[key] = null;
      _quickAccessCachedKeys?.remove(key);
    }
    return;
  }

  void clearQuickAccessCache() {
    _quickAccessCache.clear();
    _quickAccessCachedKeys = null;
  }

  Future<void> clear([IDBTransaction? txn]) async {
    if (boxCollection._txnCache != null) {
      boxCollection._txnCache!.add((txn) => clear(txn));
    } else {
      txn ??= boxCollection._db.transaction(name.toJS, 'readwrite');
      final store = txn.objectStore(name);
      final clearRequest = store.clear();
      final clearCompleter = Completer();
      clearRequest.onerror = (Event event) {
        Logs().e(
          '[IndexedDBBox] [clear] Error - ${clearRequest.error?.toString()}',
        );
        clearCompleter.completeError(
          '[IndexedDBBox] [clear] Error - ${clearRequest.error?.toString()}'
              .toJS,
        );
      }.toJS;
      clearRequest.onsuccess = (Event event) {
        clearCompleter.complete();
      }.toJS;
      await clearCompleter.future;
    }
    clearQuickAccessCache();
  }

  V? _fromValue(Object? value) {
    if (value == null) return null;
    switch (V) {
      case const (List<dynamic>):
        return List.unmodifiable(value as List) as V;
      case const (Map<dynamic, dynamic>):
        return Map.unmodifiable(value as Map) as V;
      case const (int):
      case const (double):
      case const (bool):
      case const (String):
      default:
        return value as V;
    }
  }
}
