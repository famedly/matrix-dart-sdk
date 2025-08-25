import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:matrix/matrix_api_lite.dart';

extension PrintLogs on LogEvent {
  void printOut() {
    var logsStr = '[Matrix] $title';
    if (exception != null) {
      logsStr += ' - ${exception.toString()}';
    }
    if (stackTrace != null) {
      logsStr += '\n${stackTrace.toString()}';
    }
    switch (level) {
      case Level.wtf:
        web.console.error('!!!CRITICAL!!! $logsStr'.toJS);
        break;
      case Level.error:
        web.console.error(logsStr.toJS);
        break;
      case Level.warning:
        web.console.warn(logsStr.toJS);
        break;
      case Level.info:
        web.console.info(logsStr.toJS);
        break;
      case Level.debug:
        web.console.debug(logsStr.toJS);
        break;
      case Level.verbose:
        web.console.log(logsStr.toJS);
        break;
    }
  }
}
