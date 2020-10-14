/*
 *   Famedly Matrix SDK
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

import 'package:isolate/isolate.dart';
import 'dart:async';

Future<T> runInBackground<T, U>(
    FutureOr<T> Function(U arg) function, U arg) async {
  IsolateRunner isolate;
  try {
    isolate = await IsolateRunner.spawn();
  } on UnsupportedError {
    // web does not support isolates (yet), so we fall back to calling the method directly
    return await function(arg);
  }
  try {
    return await isolate.run(function, arg);
  } finally {
    await isolate.close();
  }
}
