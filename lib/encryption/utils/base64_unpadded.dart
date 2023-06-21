import 'dart:convert';
import 'dart:typed_data';

/// decodes base64
///
/// Dart's native [base64.decode] requires a padded base64 input String.
/// This function allows unpadded base64 too.
///
/// See: https://github.com/dart-lang/sdk/issues/39510
Uint8List base64decodeUnpadded(String s) {
  final needEquals = (4 - (s.length % 4)) % 4;
  return base64.decode(s + ('=' * needEquals));
}

String encodeBase64Unpadded(List<int> s) {
  return base64Encode(s).replaceAll(RegExp(r'=+$', multiLine: true), '');
}
