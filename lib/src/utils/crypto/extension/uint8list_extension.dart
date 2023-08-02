
import 'dart:convert';
import 'dart:typed_data';

extension Unit8ListExtension on Uint8List {
  String toBase64() {
    return base64Url.encode(this).replaceAll('=', '');
  }
}