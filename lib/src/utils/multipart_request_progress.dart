import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

extension ToBytesWithProgress on http.ByteStream {
  /// Collects the data of this stream in a [Uint8List].
  Future<Uint8List> toBytesWithProgress(void Function(int)? onProgress) {
    var length = 0;
    final completer = Completer<Uint8List>();
    final sink = ByteConversionSink.withCallback(
      (bytes) => completer.complete(Uint8List.fromList(bytes)),
    );
    listen(
      (bytes) {
        sink.add(bytes);
        onProgress?.call(length += bytes.length);
      },
      onError: completer.completeError,
      onDone: sink.close,
      cancelOnError: true,
    );
    return completer.future;
  }
}
