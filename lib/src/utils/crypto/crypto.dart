export 'native.dart' if (dart.library.js) 'js.dart';

import 'dart:typed_data';
import 'dart:math';

Uint8List secureRandomBytes(int len) {
  final rng = Random.secure();
  final list = Uint8List(len);
  list.setAll(0, Iterable.generate(list.length, (i) => rng.nextInt(256)));
  return list;
}
