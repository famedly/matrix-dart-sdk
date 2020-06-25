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

  MatrixSignableKey.fromJson(Map<String, dynamic> json) {
    _json = json;
    userId = json['user_id'];
    keys = Map<String, String>.from(json['keys']);
    signatures = json['signatures'] is Map
        ? Map<String, Map<String, String>>.from((json['signatures'] as Map)
            .map((k, v) => MapEntry(k, Map<String, String>.from(v))))
        : null;
    unsigned = json['unsigned'] is Map
        ? Map<String, dynamic>.from(json['unsigned'])
        : null;
  }

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
