import 'dart:async';
import 'dart:html';
import 'dart:indexed_db';

/// Key-Value store abstraction over IndexedDB so that the sdk database can use
/// a single interface for all platforms. API is inspired by Hive.
class BoxCollection {
  final Database _db;
  final Set<String> boxNames;

  BoxCollection(this._db, this.boxNames);

  static Future<BoxCollection> open(
    String name,
    Set<String> boxNames, {
    Object? sqfliteDatabase,
    IdbFactory? idbFactory,
  }) async {
    idbFactory ??= window.indexedDB!;
    final db = await idbFactory.open(name, version: 1,
        onUpgradeNeeded: (VersionChangeEvent event) {
      final db = event.target.result;
      for (final name in boxNames) {
        db.createObjectStore(name, autoIncrement: true);
      }
    });
    return BoxCollection(db, boxNames);
  }

  Box<V> openBox<V>(String name) {
    if (!boxNames.contains(name)) {
      throw ('Box with name $name is not in the known box names of this collection.');
    }
    return Box<V>(name, this);
  }

  List<Future<void> Function(Transaction txn)>? _txnCache;

  Future<void> transaction(
    Future<void> Function() action, {
    List<String>? boxNames,
    bool readOnly = false,
  }) async {
    boxNames ??= _db.objectStoreNames!.toList();
    _txnCache = [];
    await action();
    final cache = List<Future<void> Function(Transaction txn)>.from(_txnCache!);
    _txnCache = null;
    if (cache.isEmpty) return;
    final txn = _db.transaction(boxNames, readOnly ? 'readonly' : 'readwrite');
    for (final fun in cache) {
      // The IDB methods return a Future in Dart but must not be awaited in
      // order to have an actual transaction. They must only be performed and
      // then the transaction object must call `txn.completed;` which then
      // returns the actual future.
      // https://developer.mozilla.org/en-US/docs/Web/API/IDBTransaction
      unawaited(fun(txn));
    }
    await txn.completed;
    return;
  }

  Future<void> clear() async {
    for (final name in boxNames) {
      _db.deleteObjectStore(name);
    }
  }

  Future<void> close() async {
    assert(_txnCache == null, 'Database closed while in transaction!');
    return _db.close();
  }
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

  Box(this.name, this.boxCollection);

  Future<List<String>> getAllKeys([Transaction? txn]) async {
    if (_keysCached) return _cachedKeys!.toList();
    txn ??= boxCollection._db.transaction(name, 'readonly');
    final store = txn.objectStore(name);
    final request = store.getAllKeys(null);
    await request.onSuccess.first;
    final keys = request.result.cast<String>();
    _cachedKeys = keys.toSet();
    return keys;
  }

  Future<Map<String, V>> getAllValues([Transaction? txn]) async {
    txn ??= boxCollection._db.transaction(name, 'readonly');
    final store = txn.objectStore(name);
    final map = <String, V>{};
    final cursorStream = store.openCursor(autoAdvance: true);
    await for (final cursor in cursorStream) {
      map[cursor.key as String] = _fromValue(cursor.value) as V;
    }
    return map;
  }

  Future<V?> get(String key, [Transaction? txn]) async {
    if (_cache.containsKey(key)) return _cache[key];
    txn ??= boxCollection._db.transaction(name, 'readonly');
    final store = txn.objectStore(name);
    _cache[key] = await store.getObject(key).then(_fromValue);
    return _cache[key];
  }

  Future<List<V?>> getAll(List<String> keys, [Transaction? txn]) async {
    if (keys.every((key) => _cache.containsKey(key))) {
      return keys.map((key) => _cache[key]).toList();
    }
    txn ??= boxCollection._db.transaction(name, 'readonly');
    final store = txn.objectStore(name);
    final list = await Future.wait(
        keys.map((key) => store.getObject(key).then(_fromValue)));
    for (var i = 0; i < keys.length; i++) {
      _cache[keys[i]] = list[i];
    }
    return list;
  }

  Future<void> put(String key, V val, [Transaction? txn]) async {
    if (boxCollection._txnCache != null) {
      boxCollection._txnCache!.add((txn) => put(key, val, txn));
      _cache[key] = val;
      _cachedKeys?.add(key);
      return;
    }

    txn ??= boxCollection._db.transaction(name, 'readwrite');
    final store = txn.objectStore(name);
    await store.put(val as Object, key);
    _cache[key] = val;
    _cachedKeys?.add(key);
    return;
  }

  Future<void> delete(String key, [Transaction? txn]) async {
    if (boxCollection._txnCache != null) {
      boxCollection._txnCache!.add((txn) => delete(key, txn));
      _cache.remove(key);
      _cachedKeys?.remove(key);
      return;
    }

    txn ??= boxCollection._db.transaction(name, 'readwrite');
    final store = txn.objectStore(name);
    await store.delete(key);
    _cache.remove(key);
    _cachedKeys?.remove(key);
    return;
  }

  Future<void> deleteAll(List<String> keys, [Transaction? txn]) async {
    if (boxCollection._txnCache != null) {
      boxCollection._txnCache!.add((txn) => deleteAll(keys, txn));
      keys.forEach(_cache.remove);
      _cachedKeys?.removeAll(keys);
      return;
    }

    txn ??= boxCollection._db.transaction(name, 'readwrite');
    final store = txn.objectStore(name);
    for (final key in keys) {
      await store.delete(key);
      _cache.remove(key);
      _cachedKeys?.remove(key);
    }
    return;
  }

  Future<void> clear([Transaction? txn]) async {
    if (boxCollection._txnCache != null) {
      boxCollection._txnCache!.add((txn) => clear(txn));
      _cache.clear();
      _cachedKeys = null;
      return;
    }

    txn ??= boxCollection._db.transaction(name, 'readwrite');
    final store = txn.objectStore(name);
    await store.clear();
    _cache.clear();
    _cachedKeys = null;
    return;
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
