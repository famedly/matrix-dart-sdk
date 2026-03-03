import 'dart:typed_data';

extension PickleKeyStringExtension on String {
  Uint8List toPickleKey() {
    final bytes = Uint8List.fromList(codeUnits);
    final missing = 32 - bytes.length;
    if (missing > 0) {
      return Uint8List.fromList([
        ...bytes,
        ...List.filled(missing, 0),
      ]);
    }
    return Uint8List.fromList(bytes.getRange(0, 32).toList());
  }
}
