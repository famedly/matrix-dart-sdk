import 'dart:async';

typedef ComputeCallback = Future<R> Function<Q, R>(
  FutureOr<R> Function(Q message) callback,
  Q message, {
  String? debugLabel,
});

// keep types in sync with [computeCallbackFromRunInBackground]
typedef ComputeRunner = Future<T> Function<T, U>(
  FutureOr<T> Function(U arg) function,
  U arg,
);

ComputeCallback computeCallbackFromRunInBackground(ComputeRunner runner) {
  return <U, T>(
    FutureOr<T> Function(U arg) callback,
    U arg, {
    String? debugLabel,
  }) =>
      runner.call(callback, arg);
}
