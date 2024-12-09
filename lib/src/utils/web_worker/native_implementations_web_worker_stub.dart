import 'dart:async';

import 'package:matrix/matrix.dart';

class NativeImplementationsWebWorker extends NativeImplementations {
  /// the default handler for stackTraces in web workers
  static StackTrace defaultStackTraceHandler(String obfuscatedStackTrace) {
    return StackTrace.fromString(obfuscatedStackTrace);
  }

  NativeImplementationsWebWorker(
    Uri href, {
    Duration timeout = const Duration(seconds: 30),
    WebWorkerStackTraceCallback onStackTrace = defaultStackTraceHandler,
  });
}

class WebWorkerError extends Error {
  /// the error thrown in the web worker. Usually a [String]
  final Object? error;

  /// de-serialized [StackTrace]
  @override
  final StackTrace stackTrace;

  WebWorkerError({required this.error, required this.stackTrace});

  @override
  String toString() {
    return '$error, $stackTrace';
  }
}

/// converts a stringifyed, obfuscated [StackTrace] into a [StackTrace]
typedef WebWorkerStackTraceCallback = FutureOr<StackTrace> Function(
  String obfuscatedStackTrace,
);
