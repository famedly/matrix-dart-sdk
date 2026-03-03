import 'dart:js_interop';

import 'package:web/web.dart';

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
        console.error('!!!CRITICAL!!! $logsStr'.toJS);
        break;
      case Level.error:
        console.error(logsStr.toJS);
        break;
      case Level.warning:
        console.warn(logsStr.toJS);
        break;
      case Level.info:
        console.info(logsStr.toJS);
        break;
      case Level.debug:
        console.debug(logsStr.toJS);
        break;
      case Level.verbose:
        console.log(logsStr.toJS);
        break;
    }
  }
}
