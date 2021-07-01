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

import 'logs.dart';

extension TryGetMapExtension on Map<String, dynamic> {
  T? tryGet<T extends Object>(String key) {
    final value = this[key];
    if (value != null && !(value is T)) {
      Logs().w(
          'Expected "${T.runtimeType}" in event content for the Key "$key" but got "${value.runtimeType}".',
          StackTrace.current);
      return null;
    }
    return value;
  }

  /// Same as tryGet but without logging any warnings.
  /// This is helpful if you have a field that can mean multiple things on purpose.
  T? silentTryGet<T extends Object>(String key) {
    final value = this[key];
    if (value != null && !(value is T)) {
      return null;
    }
    return value;
  }

  List<T>? tryGetList<T>(String key) {
    final value = this[key];
    if (value != null && !(value is List)) {
      Logs().w(
          'Expected "List<${T.runtimeType}>" in event content for the key "$key" but got "${value.runtimeType}".',
          StackTrace.current);
      return null;
    }
    try {
      return (value as List).cast<T>();
    } catch (_) {
      Logs().w(
          'Unable to create "List<${T.runtimeType}>" in event content for the key "$key"');
      return null;
    }
  }

  Map<A, B>? tryGetMap<A, B>(String key) {
    final value = this[key];
    if (value != null && !(value is Map)) {
      Logs().w(
          'Expected "Map<${A.runtimeType},${B.runtimeType}>" in event content for the key "$key" but got "${value.runtimeType}".');
      return null;
    }
    try {
      return (value as Map).cast<A, B>();
    } catch (_) {
      Logs().w(
          'Unable to create "Map<${A.runtimeType},${B.runtimeType}>" in event content for the key "$key"');
      return null;
    }
  }
}
