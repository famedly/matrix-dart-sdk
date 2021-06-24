// @dart=2.9
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
  T tryGet<T>(String key, [T fallbackValue]) {
    final value = this[key];
    if (value != null && !(value is T)) {
      Logs().w(
          'Expected "${T.runtimeType}" in event content for the Key "$key" but got "${value.runtimeType}".');
      return fallbackValue;
    }
    if (value == null && fallbackValue != null) {
      Logs().w(
          'Required field in event content for the Key "$key" is null. Set to "$fallbackValue".');
      return fallbackValue;
    }
    return value;
  }

  List<T> tryGetList<T>(String key, [List<T> fallbackValue]) {
    final value = this[key];
    if (value != null && !(value is List)) {
      Logs().w(
          'Expected "List<${T.runtimeType}>" in event content for the key "$key" but got "${value.runtimeType}".');
      return fallbackValue;
    }
    if (value == null && fallbackValue != null) {
      Logs().w(
          'Required field in event content for the key "$key" is null. Set to "$fallbackValue".');
      return fallbackValue;
    }
    try {
      return (value as List).cast<T>();
    } catch (_) {
      Logs().w(
          'Unable to create "List<${T.runtimeType}>" in event content for the key "$key"');
      return fallbackValue;
    }
  }

  Map<A, B> tryGetMap<A, B>(String key, [Map<A, B> fallbackValue]) {
    final value = this[key];
    if (value != null && !(value is Map)) {
      Logs().w(
          'Expected "Map<${A.runtimeType},${B.runtimeType}>" in event content for the key "$key" but got "${value.runtimeType}".');
      return fallbackValue;
    }
    if (value == null && fallbackValue != null) {
      Logs().w(
          'Required field in event content for the key "$key" is null. Set to "$fallbackValue".');
      return fallbackValue;
    }
    try {
      return (value as Map).cast<A, B>();
    } catch (_) {
      Logs().w(
          'Unable to create "Map<${A.runtimeType},${B.runtimeType}>" in event content for the key "$key"');
      return fallbackValue;
    }
  }
}
