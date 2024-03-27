/* MIT License
* 
* Copyright (C) 2019, 2020, 2021 Famedly GmbH
* 
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
* 
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
* 
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

import 'package:matrix/matrix_api_lite/utils/print_logs_native.dart'
    if (dart.library.html) 'print_logs_web.dart';

enum Level {
  wtf,
  error,
  warning,
  info,
  debug,
  verbose,
}

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

  Logs._internal();

  void addLogEvent(LogEvent logEvent) {
    outputEvents.add(logEvent);
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
}
