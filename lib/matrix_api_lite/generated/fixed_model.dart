// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:typed_data';

class FileResponse {
  FileResponse({this.contentType, required this.data});
  String? contentType;
  Uint8List data;
}
