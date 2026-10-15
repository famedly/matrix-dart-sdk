// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:meta/meta.dart';

import '../../matrix_api_lite/utils/logs.dart';
import 'zone_transaction_mixin.dart';

/// The writes of a box that are not committed yet. Reads apply them over
/// what the store returns.
class Overlay<V> {
  /// Writes not committed yet, null marks a deletion.
  Map<String, V?> pending = {};

  /// Whether the box was cleared before [pending].
  bool pendingClear = false;

  /// The writes of the running commit, readable until it is done.
  Map<String, V?> committing = {};
  bool committingClear = false;

  bool get isEmpty => pending.isEmpty && !pendingClear;

  /// The uncommitted value of [key], null if it has no uncommitted write.
  ({V? value})? lookup(String key) {
    if (pending.containsKey(key)) return (value: pending[key]);
    if (pendingClear) return (value: null);
    if (committing.containsKey(key)) return (value: committing[key]);
    if (committingClear) return (value: null);
    return null;
  }

  void clear() {
    pending.clear();
    pendingClear = true;
  }

  /// Moves the pending writes into [committing] and returns them.
  Map<String, V?> startCommit() {
    committing = pending;
    committingClear = pendingClear;
    pending = {};
    pendingClear = false;
    return committing;
  }

  void endCommit({required bool success}) {
    // A failed commit stays uncommitted, under the writes made since.
    if (!success && !pendingClear) {
      pending = {...committing, ...pending};
      pendingClear = committingClear;
    }
    committing = {};
    committingClear = false;
  }

  /// The uncommitted writes, oldest first, after the last clear.
  Iterable<Map<String, V?>> get _writes => [
    if (!pendingClear) committing,
    pending,
  ];

  /// Applies the writes to keys read from the store. Called after the store
  /// answered, so a commit that ended meanwhile is in the answer.
  List<String> keys(Iterable<String> storeKeys, [String prefix = '']) {
    final keys = {if (!pendingClear && !committingClear) ...storeKeys};
    for (final writes in _writes) {
      for (final MapEntry(:key, :value) in writes.entries) {
        if (!key.startsWith(prefix)) continue;
        value == null ? keys.remove(key) : keys.add(key);
      }
    }
    return keys.toList();
  }

  /// Applies the writes to [values] read from the store.
  Map<String, V> values(Map<String, V> values) {
    if (pendingClear || committingClear) values.clear();
    for (final writes in _writes) {
      for (final MapEntry(:key, :value) in writes.entries) {
        value == null ? values.remove(key) : values[key] = value;
      }
    }
    return values;
  }
}

abstract interface class OverlayBox {
  Overlay get overlay;
}

/// Commits the writes of all boxes of a collection in groups: writes made
/// during a commit go into the next one, a transaction's writes into one
/// commit when it ends.
mixin GroupCommit<B extends OverlayBox> on ZoneTransactionMixin {
  /// Boxes with writes that are not committed yet.
  final _dirtyBoxes = <B>{};

  /// Whether a transaction collects the writes, to commit them when it ends.
  bool _inTransaction = false;

  /// Completes with the commit that contains the writes made so far.
  Completer<void>? _nextCommit;
  bool _committing = false;

  /// Writes the started commits of [boxes] to the store at once.
  @protected
  Future<void> commitBoxes(List<B> boxes);

  /// Called by [box] after a write. Completes when it is committed, or at
  /// once in a transaction, which commits it when it ends.
  Future<void> written(B box) {
    _dirtyBoxes.add(box);
    if (_inTransaction) return Future.value();
    return flush();
  }

  /// Commits all writes made so far, so concurrent writers share commits.
  Future<void> flush() {
    final next = _nextCommit ??= Completer<void>();
    if (!_committing) {
      _committing = true;
      // In a microtask, so that writes made in the same go share the commit.
      scheduleMicrotask(_commitLoop);
    }
    return next.future;
  }

  Future<void> _commitLoop() async {
    // A running transaction commits everything when it ends. Committing now
    // would store half of its writes.
    while (_nextCommit != null && !_inTransaction) {
      final done = _nextCommit!;
      _nextCommit = null;
      try {
        await _commit();
        done.complete();
      } catch (e, s) {
        done.completeError(e, s);
      }
    }
    _committing = false;
  }

  Future<void> _commit() async {
    final boxes = _dirtyBoxes.toList();
    _dirtyBoxes.clear();
    if (boxes.isEmpty) return;
    try {
      await commitBoxes(boxes);
    } catch (_) {
      for (final box in boxes) {
        box.overlay.endCommit(success: false);
        if (!box.overlay.isEmpty) _dirtyBoxes.add(box);
      }
      rethrow;
    }
    for (final box in boxes) {
      box.overlay.endCommit(success: true);
    }
  }

  /// Runs [action] and commits its writes, and those other code makes
  /// meanwhile, at once. Transactions are serialized, a nested transaction
  /// runs in the outer one. Nothing is rolled back: if [action] throws, its
  /// writes are committed anyway.
  Future<void> transaction(Future<void> Function() action) =>
      zoneTransaction(() async {
        if (_inTransaction) return action();
        _inTransaction = true;
        Object? error;
        StackTrace? stackTrace;
        try {
          await action();
        } catch (e, s) {
          error = e;
          stackTrace = s;
        }
        _inTransaction = false;
        try {
          await flush();
        } catch (e, s) {
          error ??= e;
          stackTrace ??= s;
        }
        if (error != null) Error.throwWithStackTrace(error, stackTrace!);
      });

  /// Commits what is left and closes the store with [closeStore]. A failing
  /// commit does not keep the store open, e.g. for deleting a full database.
  Future<void> closeAfterCommit(FutureOr<void> Function() closeStore) =>
      zoneTransaction(() async {
        try {
          await flush();
        } catch (e, s) {
          Logs().e('[BoxCollection] Writes lost on close', e, s);
        }
        await closeStore();
      });
}
