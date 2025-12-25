import 'dart:async';

/// Retries the `retryFunction` after a set `timeInterval` until `dispose` is called
class RetryEventModel {
  final Duration timeInterval;
  final void Function(Timer? timer) retryFunction;

  final Timer? _timer;

  RetryEventModel({required this.timeInterval, required this.retryFunction})
      : _timer = Timer.periodic(timeInterval, retryFunction);

  void dispose() => _timer?.cancel();
}
