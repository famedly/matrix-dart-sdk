// SPDX-FileCopyrightText: 2019, 2020 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';
import 'package:test/test.dart';

import 'fake_client.dart';

void main() {
  /// All Tests related to device keys
  group('Matrix File', tags: 'olm', () {
    setUpAll(() async {
      await getClient(); // To trigger vodozemac init
    });
    Logs().level = Level.error;
    test('Decrypt', () async {
      const text = 'hello world';
      final file = MatrixFile(
        name: 'file.txt',
        bytes: Uint8List.fromList(text.codeUnits),
      );

      final encryptedFile = await file.encrypt();
      expect(encryptedFile.data.isNotEmpty, true);
    });

    test('Shrink', () async {
      final resp = await http.get(
        Uri.parse(
          'https://upload.wikimedia.org/wikipedia/commons/5/5f/Salagou_Lake%2C_Celles_cf01.jpg',
        ),
      );

      if (resp.statusCode == 200) {
        final file = MatrixImageFile(
          name: 'file.jpg',
          bytes: resp.bodyBytes,
        );
        expect(file.bytes.isNotEmpty, true);
        expect(file.height, null);
        expect(file.width, null);

        final thumb = await file.generateThumbnail();

        expect(thumb != null, true);

        // and the image size where updated
        expect(file.height, 4552);
        expect(file.width, 7283);
      }
    });
  });
}
