/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020, 2021 Famedly GmbH
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

import 'package:async/async.dart';

extension AsyncCacheTryFetch<T> on AsyncCache<T> {
  /// Makes sure that in case of an error the error is not stored forever and
  /// blocking the cache but invalidates it.
  Future<T> tryFetch(Future<T> Function() callback) async {
    try {
      return await fetch(callback);
    } catch (_) {
      invalidate();
      rethrow;
    }
  }
}
