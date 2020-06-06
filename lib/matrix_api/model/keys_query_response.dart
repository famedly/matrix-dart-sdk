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

import 'matrix_keys.dart';

class KeysQueryResponse {
  Map<String, dynamic> failures;
  Map<String, Map<String, MatrixDeviceKeys>> deviceKeys;
  Map<String, MatrixCrossSigningKey> masterKeys;
  Map<String, MatrixCrossSigningKey> selfSigningKeys;
  Map<String, MatrixCrossSigningKey> userSigningKeys;

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
    masterKeys = json['master_keys'] != null
        ? (json['master_keys'] as Map).map(
            (k, v) => MapEntry(
              k,
              MatrixCrossSigningKey.fromJson(v),
            ),
          )
        : null;

    selfSigningKeys = json['self_signing_keys'] != null
        ? (json['self_signing_keys'] as Map).map(
            (k, v) => MapEntry(
              k,
              MatrixCrossSigningKey.fromJson(v),
            ),
          )
        : null;

    userSigningKeys = json['user_signing_keys'] != null
        ? (json['user_signing_keys'] as Map).map(
            (k, v) => MapEntry(
              k,
              MatrixCrossSigningKey.fromJson(v),
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
    if (masterKeys != null) {
      data['master_keys'] = masterKeys.map(
        (k, v) => MapEntry(
          k,
          v.toJson(),
        ),
      );
    }
    if (selfSigningKeys != null) {
      data['self_signing_keys'] = selfSigningKeys.map(
        (k, v) => MapEntry(
          k,
          v.toJson(),
        ),
      );
    }
    if (userSigningKeys != null) {
      data['user_signing_keys'] = userSigningKeys.map(
        (k, v) => MapEntry(
          k,
          v.toJson(),
        ),
      );
    }
    return data;
  }
}
