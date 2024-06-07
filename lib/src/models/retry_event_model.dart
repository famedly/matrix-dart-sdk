import 'dart:async';

/// Retries the `retryFunction` after a set `timeInterval` until `dispose` is called
class RetryEventModel {
  final Duration timeInterval;
  void Function(Timer? timer) retryFunction;

  final Timer? _timer;

  RetryEventModel({
    required this.timeInterval,
    required this.retryFunction,
  }) : _timer = Timer.periodic(timeInterval, retryFunction) {
    // run it once because timer.periodic waits for duration before first run
    retryFunction(null);
  }

  void dispose() => _timer?.cancel();
}
