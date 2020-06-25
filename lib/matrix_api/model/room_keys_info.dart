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

class RoomKeysVersionResponse {
  RoomKeysAlgorithmType algorithm;
  Map<String, dynamic> authData;
  int count;
  String etag;
  String version;

  RoomKeysVersionResponse.fromJson(Map<String, dynamic> json) {
    algorithm =
        RoomKeysAlgorithmTypeExtension.fromAlgorithmString(json['algorithm']);
    authData = json['auth_data'];
    count = json['count'];
    etag =
        json['etag'].toString(); // synapse replies an int but docs say string?
    version = json['version'];
  }

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
