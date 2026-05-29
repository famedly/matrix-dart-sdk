// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:js_interop';

import 'package:web/web.dart';

import 'package:matrix/matrix_api_lite.dart';

// ignore_for_file: unused-code
extension PrintLogs on LogEvent {
  void printOut() {
    var logsStr = '[Matrix] $title';
    if (exception != null) {
      logsStr += ' - $exception';
    }
    if (stackTrace != null) {
      logsStr += '\n$stackTrace';
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
