// SPDX-FileCopyrightText: 2019-Present, 2021 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/src/utils/multilock.dart';
import 'package:test/test.dart';

void main() {
  group('lock', () {
    final lock = MultiLock<String>();
    test('lock and unlock', () async {
      // lock and unlock
      await lock.lock(['fox']);
      lock.unlock(['fox']);
      expect(true, true); // we were able to reach this line of code!
    });
    test('lock the same lock', () async {
      var counter = 0;
      await lock.lock(['fox']);
      final future = lock.lock(['fox']).then((_) {
        counter++;
        lock.unlock(['fox']);
      });
      await Future.delayed(Duration(milliseconds: 50));
      expect(counter, 0);
      lock.unlock(['fox']);
      await future;
      expect(counter, 1);
    });
    test('multilock', () async {
      var counter = 0;
      await lock.lock(['fox']);
      final future1 = lock.lock(['fox', 'raccoon']).then((_) {
        counter++;
        lock.unlock(['fox', 'raccoon']);
      });
      await Future.delayed(Duration(milliseconds: 50));
      expect(counter, 0);
      await lock.lock(['raccoon']);
      lock.unlock(['fox']);
      await Future.delayed(Duration(milliseconds: 50));
      expect(counter, 0);
      lock.unlock(['raccoon']);
      await future1;
      expect(counter, 1);
    });
  });
}
