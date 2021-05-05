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

import '../../matrix_api_lite.dart';

enum RoomKeysAlgorithmType { v1Curve25519AesSha2 }

extension RoomKeysAlgorithmTypeExtension on RoomKeysAlgorithmType {
  String get algorithmString {
    switch (this) {
      case RoomKeysAlgorithmType.v1Curve25519AesSha2:
        return AlgorithmTypes.megolmBackupV1Curve25519AesSha2;
      default:
        return null;
    }
  }

  static RoomKeysAlgorithmType fromAlgorithmString(String s) {
    switch (s) {
      case AlgorithmTypes.megolmBackupV1Curve25519AesSha2:
        return RoomKeysAlgorithmType.v1Curve25519AesSha2;
      default:
        return null;
    }
  }
}

class RoomKeysVersionResponse {
  RoomKeysAlgorithmType algorithm;
  Map<String, dynamic> authData;
  int count;
  String etag;
  String version;

  RoomKeysVersionResponse.fromJson(Map<String, dynamic> json)
      : algorithm = RoomKeysAlgorithmTypeExtension.fromAlgorithmString(
            json['algorithm']),
        authData = json['auth_data'],
        count = json['count'],
        etag = json['etag']
            .toString(), // synapse replies an int but docs say string?
        version = json['version'];

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['algorithm'] = algorithm?.algorithmString;
    data['auth_data'] = authData;
    data['count'] = count;
    data['etag'] = etag;
    data['version'] = version;
    return data;
  }
}
