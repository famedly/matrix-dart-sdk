// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite.dart';
import 'package:test/test.dart';

void main() {
  test('outputEvents is capped and keeps the newest events', () {
    final logs = Logs();
    final oldMax = logs.maxOutputEvents;
    logs.maxOutputEvents = 3;
    for (var i = 0; i < 10; i++) {
      logs.v('event $i');
    }
    expect(logs.outputEvents.map((e) => e.title), [
      'event 7',
      'event 8',
      'event 9',
    ]);
    logs.maxOutputEvents = oldMax;
  });
}
