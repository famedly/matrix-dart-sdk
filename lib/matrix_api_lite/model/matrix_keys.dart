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

import 'package:matrix/matrix_api_lite.dart';

abstract class MatrixSignableKey {
  String userId;

  String? get identifier;

  Map<String, String> keys;
  Map<String, Map<String, String>>? signatures;
  Map<String, Object?>? unsigned;

  MatrixSignableKey(this.userId, this.keys, this.signatures, {this.unsigned});

  // This object is used for signing so we need the raw json too
  Map<String, Object?>? _json;

  MatrixSignableKey.fromJson(Map<String, Object?> json)
      : _json = json,
        userId = json['user_id'] as String,
        keys = Map<String, String>.from(json['keys'] as Map<String, Object?>),
        // we need to manually copy to ensure that our map is Map<String, Map<String, String>>
        signatures = (() {
          final orig = json.tryGetMap<String, Object?>('signatures');
          final res = <String, Map<String, String>>{};
          for (final entry
              in (orig?.entries ?? <MapEntry<String, Object?>>[])) {
            final deviceSigs = entry.value;
            if (deviceSigs is Map<String, Object?>) {
              for (final nestedEntry in deviceSigs.entries) {
                final nestedValue = nestedEntry.value;
                if (nestedValue is String) {
                  (res[entry.key] ??= <String, String>{})[nestedEntry.key] =
                      nestedValue;
                }
              }
            }
          }
          return res;
        }()),
        unsigned = json.tryGetMap<String, Object?>('unsigned')?.copy();

  Map<String, Object?> toJson() {
    final data = _json ?? <String, Object?>{};
    data['user_id'] = userId;
    data['keys'] = keys;

    if (signatures != null) {
      data['signatures'] = signatures;
    }
    if (unsigned != null) {
      data['unsigned'] = unsigned;
    }
    return data;
  }
}

class MatrixCrossSigningKey extends MatrixSignableKey {
  List<String> usage;

  String? get publicKey => identifier;

  MatrixCrossSigningKey(
    String userId,
    this.usage,
    Map<String, String> keys,
    Map<String, Map<String, String>> signatures, {
    Map<String, Object?>? unsigned,
  }) : super(userId, keys, signatures, unsigned: unsigned);

  @override
  String? get identifier => keys.values.first;

  @override
  MatrixCrossSigningKey.fromJson(super.json)
      : usage = json.tryGetList<String>('usage') ?? [],
        super.fromJson();

  @override
  Map<String, Object?> toJson() {
    final data = super.toJson();
    data['usage'] = usage;
    return data;
  }
}

class MatrixDeviceKeys extends MatrixSignableKey {
  String deviceId;
  List<String> algorithms;

  String? get deviceDisplayName =>
      unsigned?.tryGet<String>('device_display_name');

  MatrixDeviceKeys(
    String userId,
    this.deviceId,
    this.algorithms,
    Map<String, String> keys,
    Map<String, Map<String, String>> signatures, {
    Map<String, Object?>? unsigned,
  }) : super(userId, keys, signatures, unsigned: unsigned);

  @override
  String? get identifier => deviceId;

  @override
  MatrixDeviceKeys.fromJson(super.json)
      : algorithms = json.tryGetList<String>('algorithms') ?? [],
        deviceId = json['device_id'] as String,
        super.fromJson();

  @override
  Map<String, Object?> toJson() {
    final data = super.toJson();
    data['device_id'] = deviceId;
    data['algorithms'] = algorithms;
    return data;
  }
}
