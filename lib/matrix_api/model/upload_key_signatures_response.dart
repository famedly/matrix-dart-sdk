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

import 'matrix_exception.dart';

class UploadKeySignaturesResponse {
  Map<String, Map<String, MatrixException>> failures;

  UploadKeySignaturesResponse.fromJson(Map<String, dynamic> json) {
    failures = json['failures'] != null
        ? (json['failures'] as Map).map(
            (k, v) => MapEntry(
              k,
              (v as Map).map((k, v) => MapEntry(
                    k,
                    MatrixException.fromJson(v),
                  )),
            ),
          )
        : null;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (failures != null) {
      data['failures'] = failures.map(
        (k, v) => MapEntry(
          k,
          v.map(
            (k, v) => MapEntry(
              k,
              v.raw,
            ),
          ),
        ),
      );
    }
    return data;
  }
}
