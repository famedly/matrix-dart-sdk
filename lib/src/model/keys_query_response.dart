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

import 'matrix_keys.dart';
import '../utils/map_copy_extension.dart';

class KeysQueryResponse {
  Map<String, dynamic> failures;
  Map<String, Map<String, MatrixDeviceKeys>> deviceKeys;
  Map<String, MatrixCrossSigningKey> masterKeys;
  Map<String, MatrixCrossSigningKey> selfSigningKeys;
  Map<String, MatrixCrossSigningKey> userSigningKeys;

  KeysQueryResponse.fromJson(Map<String, dynamic> json)
      : failures = (json['failures'] as Map<String, dynamic>)?.copy(),
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
            : null,
        masterKeys = json['master_keys'] != null
            ? (json['master_keys'] as Map).map(
                (k, v) => MapEntry(
                  k,
                  MatrixCrossSigningKey.fromJson(v),
                ),
              )
            : null,
        selfSigningKeys = json['self_signing_keys'] != null
            ? (json['self_signing_keys'] as Map).map(
                (k, v) => MapEntry(
                  k,
                  MatrixCrossSigningKey.fromJson(v),
                ),
              )
            : null,
        userSigningKeys = json['user_signing_keys'] != null
            ? (json['user_signing_keys'] as Map).map(
                (k, v) => MapEntry(
                  k,
                  MatrixCrossSigningKey.fromJson(v),
                ),
              )
            : null;

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
