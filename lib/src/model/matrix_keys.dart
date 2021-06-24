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

import '../utils/map_copy_extension.dart';

class MatrixSignableKey {
  String userId;
  String identifier;
  Map<String, String> keys;
  Map<String, Map<String, String>> signatures;
  Map<String, dynamic> unsigned;

  MatrixSignableKey(this.userId, this.identifier, this.keys, this.signatures,
      {this.unsigned});

  // This object is used for signing so we need the raw json too
  Map<String, dynamic> _json;

  MatrixSignableKey.fromJson(Map<String, dynamic> json)
      : _json = json,
        userId = json['user_id'],
        keys = Map<String, String>.from(json['keys']),
        // we need to manually copy to ensure that our map is Map<String, Map<String, String>>
        signatures = json['signatures'] is Map
            ? Map<String, Map<String, String>>.from((json['signatures'] as Map)
                .map((k, v) => MapEntry(k, Map<String, String>.from(v))))
            : null,
        unsigned = (json['unsigned'] as Map<String, dynamic>)?.copy();

  Map<String, dynamic> toJson() {
    final data = _json ?? <String, dynamic>{};
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
  String get publicKey => identifier;

  MatrixCrossSigningKey(
    String userId,
    this.usage,
    Map<String, String> keys,
    Map<String, Map<String, String>> signatures, {
    Map<String, dynamic> unsigned,
  }) : super(userId, keys?.values?.first, keys, signatures, unsigned: unsigned);

  @override
  MatrixCrossSigningKey.fromJson(Map<String, dynamic> json)
      : super.fromJson(json) {
    usage = List<String>.from(json['usage']);
    identifier = keys?.values?.first;
  }

  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson();
    data['usage'] = usage;
    return data;
  }
}

class MatrixDeviceKeys extends MatrixSignableKey {
  String get deviceId => identifier;
  List<String> algorithms;
  String get deviceDisplayName =>
      unsigned != null ? unsigned['device_display_name'] : null;

  MatrixDeviceKeys(
    String userId,
    String deviceId,
    this.algorithms,
    Map<String, String> keys,
    Map<String, Map<String, String>> signatures, {
    Map<String, dynamic> unsigned,
  }) : super(userId, deviceId, keys, signatures, unsigned: unsigned);

  @override
  MatrixDeviceKeys.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    identifier = json['device_id'];
    algorithms = json['algorithms'].cast<String>();
  }

  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson();
    data['device_id'] = deviceId;
    data['algorithms'] = algorithms;
    return data;
  }
}
