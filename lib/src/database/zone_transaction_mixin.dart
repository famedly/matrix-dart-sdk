import 'dart:async';

// we want transactions to lock, however NOT if transactoins are run inside of each other.
// to be able to do this, we use dart zones (https://dart.dev/articles/archive/zones).
// _transactionZones holds a set of all zones which are currently running a transaction.
// _transactionLock holds the lock.
mixin ZoneTransactionMixin {
  Completer<void>? _transactionLock;
  final _transactionZones = <Zone>{};

  Future<void> zoneTransaction(Future<void> Function() action) async {
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

          await action();
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
}
