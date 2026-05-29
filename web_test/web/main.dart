// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';

Future<void> main() async {
  final client = Client(
    'web_test',
    database: await MatrixSdkDatabase.init('web_test'),
  );
  await client.init();
}
