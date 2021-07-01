
/* MIT License
*
* Copyright (C) 2019, 2020, 2021 Famedly GmbH
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

import 'package:matrix_api_lite/matrix_api_lite.dart';
import 'package:test/test.dart';

void main() {
  group('Map-copy-extension', () {
    test('it should work', () {
      final original = <String, dynamic>{
        'attr': 'fox',
        'child': <String, dynamic>{
          'attr': 'bunny',
          'list': [1, 2],
        },
      };
      final copy = original.copy();
      original['child']['attr'] = 'raccoon';
      expect(copy['child']['attr'], 'bunny');
      original['child']['list'].add(3);
      expect(copy['child']['list'], [1, 2]);
    });
    test('should do arrays', () {
      final original = <String, dynamic>{
        'arr': [
          [1, 2],
          {'beep': 'boop'},
        ],
      };
      final copy = original.copy();
      original['arr'][0].add(3);
      expect(copy['arr'][0], [1, 2]);
      original['arr'][1]['beep'] = 'blargh';
      expect(copy['arr'][1]['beep'], 'boop');
    });
  });
}
