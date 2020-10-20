/*
 *   Ansible inventory script used at Famedly GmbH for managing many hosts
 *   Copyright (C) 2020 Famedly GmbH
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

import 'dart:async';

import 'package:famedlysdk/famedlysdk.dart';
import 'package:test/test.dart';

void main() {
  group('UIA', () {
    test('it should work', () async {
      var completed = <String>[];
      var updated = 0;
      var finished = false;
      final request = UiaRequest(
        request: (auth) async {
          if (auth['session'] != null && auth['session'] != 'foxies') {
            throw MatrixException.fromJson(<String, dynamic>{});
          }
          if (auth['type'] == 'stage1') {
            if (completed.isEmpty) {
              completed.add('stage1');
            }
          } else if (auth['type'] == 'stage2') {
            if (completed.length == 1 && completed[0] == 'stage1') {
              // okay, we are done!
              return 'FOXIES ARE FLOOOOOFY!!!!!';
            }
          }
          final res = <String, dynamic>{
            'session': 'foxies',
            'completed': completed,
            'flows': [
              <String, dynamic>{
                'stages': ['stage1', 'stage2'],
              }
            ],
            'params': <String, dynamic>{},
          };
          throw MatrixException.fromJson(res);
        },
        onUpdate: () => updated++,
        onDone: () => finished = true,
      );
      await Future.delayed(Duration(milliseconds: 50));
      expect(request.nextStages.contains('stage1'), true);
      expect(request.nextStages.length, 1);
      expect(updated, 1);
      expect(finished, false);
      await request.completeStage('stage1');
      expect(request.nextStages.contains('stage2'), true);
      expect(request.nextStages.length, 1);
      expect(updated, 2);
      expect(finished, false);
      final res = await request.completeStage('stage2');
      expect(res, 'FOXIES ARE FLOOOOOFY!!!!!');
      expect(request.result, 'FOXIES ARE FLOOOOOFY!!!!!');
      expect(request.done, true);
      expect(updated, 3);
      expect(finished, true);
    });
    test('it should throw errors', () async {
      var updated = false;
      var finished = false;
      final request = UiaRequest(
        request: (auth) async {
          throw 'nope';
        },
        onUpdate: () => updated = true,
        onDone: () => finished = true,
      );
      await Future.delayed(Duration(milliseconds: 50));
      expect(request.fail, true);
      expect(updated, true);
      expect(finished, true);
      expect(request.error.toString(), Exception('nope').toString());
    });
  });
}
