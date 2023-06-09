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

import 'package:test/test.dart';

import 'package:matrix_api_lite/matrix_api_lite.dart';

void main() {
  group('Try-get-map-extension', () {
    Logs().level = Level.verbose;
    test('it should work', () {
      final data = <String, Object?>{
        'str': 'foxies',
        'int': 42,
        'list': [2, 3, 4],
        'map': <String, Object?>{
          'beep': 'boop',
        },
      };
      expect(data.tryGet<String>('str'), 'foxies');
      expect(data.tryGet<int>('str'), null);
      expect(data.tryGet<int>('int'), 42);
      expect(data.tryGet<List<int>>('list'), [2, 3, 4]);
      expect(data.tryGetMap<String, Object?>('map')?.tryGet<String>('beep'),
          'boop');
      expect(
          data.tryGetMap<String, Object?>('map')?.tryGet<String>('meep'), null);
      expect(
          data.tryGetMap<String, Object?>('pam')?.tryGet<String>('beep'), null);
    });
  });
}
