// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:collection';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

import 'package:matrix/matrix.dart' hide Event;
import 'package:matrix/src/utils/web_worker/native_implementations_web_worker.dart';

///
///
/// CAUTION: THIS FILE NEEDS TO BE MANUALLY COMPILED
///
/// 1. in your project, create a file `web/web_worker.dart`
/// 2. add the following contents:
/// ```dart
/// import 'package:hive/hive.dart';
///
/// Future<void> main() => startWebWorker();
/// ```
/// 3. compile the file using:
/// ```shell
/// dart compile js -o web/web_worker.dart.js -m web/web_worker.dart
/// ```
///
/// You should not check in that file into your VCS. Instead, you should compile
/// the web worker in your CI pipeline.
///

DedicatedWorkerGlobalScope get _workerScope =>
    (globalContext as DedicatedWorkerGlobalScope).self
        as DedicatedWorkerGlobalScope;

@pragma('dart2js:tryInline')
Future<void> startWebWorker() async {
  Logs().i('[native implementations worker]: Starting...');
  _workerScope.onmessage = (MessageEvent event) {
    final data = event.data.dartify() as LinkedHashMap;
    try {
      final operation = WebWorkerData.fromJson(data);
      switch (operation.name) {
        case WebWorkerOperations.shrinkImage:
          final result = MatrixImageFile.resizeImplementation(
            MatrixImageFileResizeArguments.fromJson(
              Map.from(operation.data as Map),
            ),
          );
          _sendResponse(
            operation.label as double,
            result?.toJson(),
          );
          break;
        case WebWorkerOperations.calcImageMetadata:
          final result = MatrixImageFile.calcMetadataImplementation(
            Uint8List.fromList(
              (operation.data as List).whereType<int>().toList(),
            ),
          );
          _sendResponse(
            operation.label as double,
            result?.toJson(),
          );
          break;
        default:
          throw TypeError();
      }
    } catch (e, s) {
      _replyError(e, s, data['label'] as double);
    }
  }.toJS;
}

void _sendResponse(
  double label,
  dynamic response,
) {
  try {
    _workerScope.postMessage(
      {
        'label': label,
        'data': response,
      }.jsify(),
    );
  } catch (e, s) {
    Logs().e('[native implementations worker] Error responding: $e, $s');
  }
}

void _replyError(
  Object? error,
  StackTrace stackTrace,
  double origin,
) {
  if (error != null) {
    try {
      final jsError = error.jsify();
      if (jsError != null) {
        error = jsError;
      }
    } catch (e) {
      error = error.toString();
    }
  }
  try {
    _workerScope.postMessage(
      {
        'label': 'stacktrace',
        'origin': origin,
        'error': error,
        'stacktrace': stackTrace.toString(),
      }.jsify(),
    );
  } catch (e, s) {
    Logs().e('[native implementations worker] Error responding: $e, $s');
  }
}
