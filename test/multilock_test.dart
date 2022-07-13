/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2021 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:test/test.dart';

import 'package:matrix/src/utils/multilock.dart';

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
