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

import 'matrix_device_keys.dart';

class KeysQueryResponse {
  Map<String, dynamic> failures;
  Map<String, Map<String, MatrixDeviceKeys>> deviceKeys;

  KeysQueryResponse.fromJson(Map<String, dynamic> json) {
    failures = Map<String, dynamic>.from(json['failures']);
    deviceKeys = json['device_keys'] != null
        ? (json['device_keys'] as Map).map(
            (k, v) => MapEntry(
              k,
              (v as Map).map(
                (k, v) => MapEntry(
                  k,
                  MatrixDeviceKeys.fromJson(v),
                ),
              ),
            ),
          )
        : null;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (failures != null) {
      data['failures'] = failures;
    }
    if (deviceKeys != null) {
      data['device_keys'] = deviceKeys.map(
        (k, v) => MapEntry(
          k,
          v.map(
            (k, v) => MapEntry(
              k,
              v.toJson(),
            ),
          ),
        ),
      );
    }
    return data;
  }
}
