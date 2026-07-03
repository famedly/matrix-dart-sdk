// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite/utils/print_logs_native.dart'
    if (dart.library.js_interop) 'print_logs_web.dart';

enum Level { wtf, error, warning, info, debug, verbose }

typedef LogCallback = void Function(LogEvent event);

class Logs {
  static final Logs _singleton = Logs._internal();

  /// Override this function if you want to convert a stacktrace for some reason
  /// for example to apply a source map in the browser.
  static StackTrace? Function(StackTrace?) stackTraceConverter = (s) => s;

  factory Logs() {
    return _singleton;
  }

  Level level = Level.info;
  bool nativeColors = true;

  final List<LogEvent> outputEvents = [];

  /// Callback to receive log events for external logging (e.g., Sentry).
  /// Called before console output on all platforms including web.
  LogCallback? onLog;

  Logs._internal();

  void addLogEvent(LogEvent logEvent) {
    outputEvents.add(logEvent);

    // Call external logger callback if set
    onLog?.call(logEvent);

    if (logEvent.level.index <= level.index) {
      logEvent.printOut();
    }
  }

  void wtf(String title, [Object? exception, StackTrace? stackTrace]) =>
      addLogEvent(
        LogEvent(
          title,
          exception: exception,
          stackTrace: stackTraceConverter(stackTrace),
          level: Level.wtf,
        ),
      );

  void e(String title, [Object? exception, StackTrace? stackTrace]) =>
      addLogEvent(
        LogEvent(
          title,
          exception: exception,
          stackTrace: stackTraceConverter(stackTrace),
          level: Level.error,
        ),
      );

  void w(String title, [Object? exception, StackTrace? stackTrace]) =>
      addLogEvent(
        LogEvent(
          title,
          exception: exception,
          stackTrace: stackTraceConverter(stackTrace),
          level: Level.warning,
        ),
      );

  void i(String title, [Object? exception, StackTrace? stackTrace]) =>
      addLogEvent(
        LogEvent(
          title,
          exception: exception,
          stackTrace: stackTraceConverter(stackTrace),
          level: Level.info,
        ),
      );

  void d(String title, [Object? exception, StackTrace? stackTrace]) =>
      addLogEvent(
        LogEvent(
          title,
          exception: exception,
          stackTrace: stackTraceConverter(stackTrace),
          level: Level.debug,
        ),
      );

  void v(String title, [Object? exception, StackTrace? stackTrace]) =>
      addLogEvent(
        LogEvent(
          title,
          exception: exception,
          stackTrace: stackTraceConverter(stackTrace),
          level: Level.verbose,
        ),
      );
}

// ignore: avoid_print
class LogEvent {
  final String title;
  final Object? exception;
  final StackTrace? stackTrace;
  final Level level;

  LogEvent(
    this.title, {
    this.exception,
    this.stackTrace,
    this.level = Level.debug,
  });

  /// Returns a formatted string representation of this log event.
  /// Useful for sending to external logging systems.
  String toFormattedString() {
    var logsStr = title;
    if (exception != null) {
      logsStr += ' - $exception';
    }
    if (stackTrace != null) {
      logsStr += '\n$stackTrace';
    }
    return logsStr;
  }

  /// Returns a map representation of this log event.
  /// Useful for structured logging systems.
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'level': level.name,
      if (exception != null) 'exception': exception.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString(),
    };
  }
}
