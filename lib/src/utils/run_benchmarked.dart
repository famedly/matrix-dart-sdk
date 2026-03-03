/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020 Famedly GmbH
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

import 'package:matrix/matrix.dart';

var kEnableMatrixSdkBenchmarks = false;

/// Calculates some benchmarks for this function. Give it a [name] and a [func]
/// to call and it will calculate the needed milliseconds. Give it an optional
/// [itemCount] to let it also calculate the needed milliseconds per item.
Future<T> runBenchmarked<T>(
  String name,
  Future<T> Function() func, [
  int? itemCount,
]) async {
  if (!kEnableMatrixSdkBenchmarks) {
    return func();
  }
  final start = DateTime.now();
  final result = await func();
  final milliseconds =
      DateTime.now().millisecondsSinceEpoch - start.millisecondsSinceEpoch;
  var message = 'Benchmark: $name -> $milliseconds ms';
  if (itemCount != null) {
    message +=
        ' ($itemCount items, ${itemCount > 0 ? milliseconds / itemCount : milliseconds} ms/item)';
  }
  Logs().d(message);
  return result;
}
