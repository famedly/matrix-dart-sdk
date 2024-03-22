import 'dart:html';

import 'package:matrix_api_lite/matrix_api_lite.dart';

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
        window.console.error('!!!CRITICAL!!! $logsStr');
        break;
      case Level.error:
        window.console.error(logsStr);
        break;
      case Level.warning:
        window.console.warn(logsStr);
        break;
      case Level.info:
        window.console.info(logsStr);
        break;
      case Level.debug:
        window.console.debug(logsStr);
        break;
      case Level.verbose:
        window.console.log(logsStr);
        break;
    }
  }
}
