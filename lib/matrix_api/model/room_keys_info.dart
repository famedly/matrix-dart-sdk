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

enum RoomKeysAlgorithmType { v1Curve25519AesSha2 }

extension RoomKeysAlgorithmTypeExtension on RoomKeysAlgorithmType {
  String get algorithmString {
    switch (this) {
      case RoomKeysAlgorithmType.v1Curve25519AesSha2:
        return 'm.megolm_backup.v1.curve25519-aes-sha2';
      default:
        return null;
    }
  }

  static RoomKeysAlgorithmType fromAlgorithmString(String s) {
    switch (s) {
      case 'm.megolm_backup.v1.curve25519-aes-sha2':
        return RoomKeysAlgorithmType.v1Curve25519AesSha2;
      default:
        return null;
    }
  }
}

abstract class RoomKeysAuthData {
  // This object is used for signing so we need the raw json too
  Map<String, dynamic> _json;

  RoomKeysAuthData.fromJson(Map<String, dynamic> json) {
    _json = json;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class RoomKeysAuthDataV1Curve25519AesSha2 extends RoomKeysAuthData {
  String publicKey;
  Map<String, Map<String, String>> signatures;

  RoomKeysAuthDataV1Curve25519AesSha2.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    publicKey = json['public_key'];
    signatures = json['signatures'] is Map
        ? Map<String, Map<String, String>>.from((json['signatures'] as Map)
            .map((k, v) => MapEntry(k, Map<String, String>.from(v))))
        : null;
  }

  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson();
    data['public_key'] = publicKey;
    if (signatures != null) {
      data['signatures'] = signatures;
    }
    return data;
  }
}

class RoomKeysVersionResponse {
  RoomKeysAlgorithmType algorithm;
  RoomKeysAuthData authData;
  int count;
  String etag;
  String version;

  RoomKeysVersionResponse.fromJson(Map<String, dynamic> json) {
    algorithm = RoomKeysAlgorithmTypeExtension.fromAlgorithmString(json['algorithm']);
    switch (algorithm) {
      case RoomKeysAlgorithmType.v1Curve25519AesSha2:
        authData = RoomKeysAuthDataV1Curve25519AesSha2.fromJson(json['auth_data']);
        break;
      default:
        authData = null;
    }
    count = json['count'];
    etag = json['etag'].toString(); // synapse replies an int but docs say string?
    version = json['version'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['algorithm'] = algorithm?.algorithmString;
    data['auth_data'] = authData?.toJson();
    data['count'] = count;
    data['etag'] = etag;
    data['version'] = version;
    return data;
  }
}
