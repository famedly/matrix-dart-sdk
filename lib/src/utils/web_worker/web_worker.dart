// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:html';
import 'dart:indexed_db';
import 'dart:js';
import 'dart:typed_data';

import 'package:js/js.dart';
import 'package:js/js_util.dart';

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

@pragma('dart2js:tryInline')
Future<void> startWebWorker() async {
  print('[native implementations worker]: Starting...');
  setProperty(
    context['self'] as Object,
    'onmessage',
    allowInterop(
      (MessageEvent event) async {
        final data = event.data;
        try {
          final operation = WebWorkerData.fromJson(data);
          switch (operation.name) {
            case WebWorkerOperations.shrinkImage:
              final result = MatrixImageFile.resizeImplementation(
                MatrixImageFileResizeArguments.fromJson(
                  Map.from(operation.data as Map),
                ),
              );
              sendResponse(operation.label as double, result?.toJson());
              break;
            case WebWorkerOperations.calcImageMetadata:
              final result = MatrixImageFile.calcMetadataImplementation(
                Uint8List.fromList(
                  (operation.data as JsArray).whereType<int>().toList(),
                ),
              );
              sendResponse(operation.label as double, result?.toJson());
              break;
            default:
              throw TypeError();
          }
        } on Event catch (e, s) {
          allowInterop(_replyError)
              .call((e.target as Request).error, s, data['label'] as double);
        } catch (e, s) {
          allowInterop(_replyError).call(e, s, data['label'] as double);
        }
      },
    ),
  );
}

void sendResponse(double label, dynamic response) {
  try {
    self.postMessage({
      'label': label,
      'data': response,
    });
  } catch (e, s) {
    print('[native implementations worker] Error responding: $e, $s');
  }
}

void _replyError(Object? error, StackTrace stackTrace, double origin) {
  if (error != null) {
    try {
      final jsError = jsify(error);
      if (jsError != null) {
        error = jsError;
      }
    } catch (e) {
      error = error.toString();
    }
  }
  try {
    self.postMessage({
      'label': 'stacktrace',
      'origin': origin,
      'error': error,
      'stacktrace': stackTrace.toString(),
    });
  } catch (e, s) {
    print('[native implementations worker] Error responding: $e, $s');
  }
}

/// represents the [WorkerGlobalScope] the worker currently runs in.
@JS('self')
external WorkerGlobalScope get self;

/// adding all missing WebWorker-only properties to the [WorkerGlobalScope]
extension on WorkerGlobalScope {
  void postMessage(Object data) {
    callMethod(self, 'postMessage', [jsify(data)]);
  }
}
