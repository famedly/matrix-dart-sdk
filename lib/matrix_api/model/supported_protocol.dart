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

class SupportedProtocol {
  List<String> userFields;
  List<String> locationFields;
  String icon;
  Map<String, ProtocolFieldType> fieldTypes;
  List<ProtocolInstance> instances;

  SupportedProtocol.fromJson(Map<String, dynamic> json) {
    userFields = json['user_fields'].cast<String>();
    locationFields = json['location_fields'].cast<String>();
    icon = json['icon'];
    fieldTypes = (json['field_types'] as Map)
        .map((k, v) => MapEntry(k, ProtocolFieldType.fromJson(v)));
    instances = <ProtocolInstance>[];
    json['instances'].forEach((v) {
      instances.add(ProtocolInstance.fromJson(v));
    });
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['user_fields'] = userFields;
    data['location_fields'] = locationFields;
    data['icon'] = icon;
    data['field_types'] = fieldTypes.map((k, v) => MapEntry(k, v.toJson()));

    data['instances'] = instances.map((v) => v.toJson()).toList();

    return data;
  }
}

class ProtocolFieldType {
  String regexp;
  String placeholder;

  ProtocolFieldType.fromJson(Map<String, dynamic> json) {
    regexp = json['regexp'];
    placeholder = json['placeholder'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['regexp'] = regexp;
    data['placeholder'] = placeholder;
    return data;
  }
}

class ProtocolInstance {
  String networkId;
  String desc;
  String icon;
  dynamic fields;

  ProtocolInstance.fromJson(Map<String, dynamic> json) {
    networkId = json['network_id'];
    desc = json['desc'];
    icon = json['icon'];
    fields = json['fields'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['network_id'] = networkId;
    data['desc'] = desc;
    if (icon != null) {
      data['icon'] = icon;
    }
    data['fields'] = fields;

    return data;
  }
}
