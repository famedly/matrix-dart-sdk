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

import 'dart:core';

import 'logs.dart';

abstract class TryGet {
  void call(String key, Type expected, Type actual);

  static const TryGet required = _RequiredLog();
  static const TryGet optional = _OptionalLog();

  /// This is helpful if you have a field that can mean multiple things on purpose.
  static const TryGet silent = _SilentLog();
}

class _RequiredLog implements TryGet {
  const _RequiredLog();
  @override
  void call(String key, Type expected, Type actual) => Logs().w(
      'Expected required "$expected" in event content for the Key "$key" but got "$actual" at ${StackTrace.current.firstLine}');
}

class _OptionalLog implements TryGet {
  const _OptionalLog();
  @override
  void call(String key, Type expected, Type actual) {
    if (actual != Null) {
      Logs().w(
          'Expected optional "$expected" in event content for the Key "$key" but got "$actual" at ${StackTrace.current.firstLine}');
    }
  }
}

class _SilentLog implements TryGet {
  const _SilentLog();
  @override
  void call(String key, Type expected, Type actual) {}
}

extension TryGetMapExtension on Map<String, Object?> {
  T? tryGet<T extends Object>(String key, [TryGet log = TryGet.optional]) {
    final Object? value = this[key];
    if (value is! T) {
      log(key, T, value.runtimeType);
      return null;
    }
    return value;
  }

  List<T>? tryGetList<T>(String key, [TryGet log = TryGet.optional]) {
    final Object? value = this[key];
    if (value is! List) {
      log(key, T, value.runtimeType);
      return null;
    }
    try {
      // copy entries to ensure type check failures here and not an access
      return value.cast<T>().toList();
    } catch (_) {
      Logs().v(
          'Unable to create "List<$T>" in event content for the key "$key" at ${StackTrace.current.firstLine}');
      return null;
    }
  }

  Map<A, B>? tryGetMap<A, B>(String key, [TryGet log = TryGet.optional]) {
    final Object? value = this[key];
    if (value is! Map) {
      log(key, <A, B>{}.runtimeType, value.runtimeType);
      return null;
    }
    try {
      // copy map to ensure type check failures here and not an access
      return Map.from(value.cast<A, B>());
    } catch (_) {
      Logs().v(
          'Unable to create "Map<$A,$B>" in event content for the key "$key" at ${StackTrace.current.firstLine}');
      return null;
    }
  }

  A? tryGetFromJson<A>(String key, A Function(Map<String, Object?>) fromJson,
      [TryGet log = TryGet.optional]) {
    final value = tryGetMap<String, Object?>(key, log);

    return value != null ? fromJson(value) : null;
  }
}

extension on StackTrace {
  String get firstLine {
    final lines = toString().split('\n');
    return lines.length >= 3
        ? lines[2].replaceFirst('#2      ', '')
        : lines.isNotEmpty
            ? lines.first
            : '(unknown position)';
  }
}
