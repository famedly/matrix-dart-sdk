// SPDX-FileCopyrightText: 2019-Present, 2020 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:test/test.dart';

import 'package:matrix/matrix.dart';

void main() {
  group('UIA', () {
    Logs().level = Level.error;
    test('it should work', () async {
      final completed = <String>[];
      var updated = 0;
      var finished = false;
      final request = UiaRequest(
        request: (auth) async {
          if (auth != null &&
              auth.session != null &&
              auth.session != 'foxies') {
            throw MatrixException.fromJson(<String, dynamic>{});
          }
          if (auth != null && auth.type == 'stage1') {
            if (completed.isEmpty) {
              completed.add('stage1');
            }
          } else if (auth != null && auth.type == 'stage2') {
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
        onUpdate: (state) {
          if (state == UiaRequestState.done) {
            finished = true;
          }
          updated++;
        },
      );
      await Future.delayed(Duration(milliseconds: 50));
      expect(request.nextStages.contains('stage1'), true);
      expect(request.nextStages.length, 1);
      expect(updated, 1);
      expect(finished, false);
      await request.completeStage(AuthenticationData(type: 'stage1'));
      expect(request.nextStages.contains('stage2'), true);
      expect(request.nextStages.length, 1);
      expect(updated, 3);
      expect(finished, false);
      final res =
          await request.completeStage(AuthenticationData(type: 'stage2'));
      expect(res, 'FOXIES ARE FLOOOOOFY!!!!!');
      expect(request.result, 'FOXIES ARE FLOOOOOFY!!!!!');
      expect(request.state, UiaRequestState.done);
      expect(updated, 5);
      expect(finished, true);
    });
    test('it should throw errors', () async {
      var updated = false;
      var finished = false;
      final request = UiaRequest(
        request: (auth) async {
          throw Exception('nope');
        },
        onUpdate: (state) {
          if (state == UiaRequestState.fail) {
            finished = true;
          }
          updated = true;
        },
      );
      await Future.delayed(Duration(milliseconds: 50));
      expect(request.state, UiaRequestState.fail);
      expect(updated, true);
      expect(finished, true);
      expect(request.error.toString(), Exception('nope').toString());
    });
  });
}
