import 'dart:async';

typedef ComputeCallback = Future<R> Function<Q, R>(
  FutureOr<R> Function(Q message) callback,
  Q message, {
  String? debugLabel,
});

// keep types in sync with [computeCallbackFromRunInBackground]
// ignore: unused-code
typedef ComputeRunner = Future<T> Function<T, U>(
  FutureOr<T> Function(U arg) function,
  U arg,
);
