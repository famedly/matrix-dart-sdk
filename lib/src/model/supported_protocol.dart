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

class SupportedProtocol {
  List<String> userFields;
  List<String> locationFields;
  String icon;
  Map<String, ProtocolFieldType> fieldTypes;
  List<ProtocolInstance> instances;

  SupportedProtocol.fromJson(Map<String, dynamic> json)
      : userFields = json['user_fields'].cast<String>(),
        locationFields = json['location_fields'].cast<String>(),
        icon = json['icon'],
        fieldTypes = (json['field_types'] as Map)
            .map((k, v) => MapEntry(k, ProtocolFieldType.fromJson(v))),
        instances = (json['instances'] as List)
            .map((v) => ProtocolInstance.fromJson(v))
            .toList();

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

  ProtocolFieldType.fromJson(Map<String, dynamic> json)
      : regexp = json['regexp'],
        placeholder = json['placeholder'];

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
  String? icon;
  dynamic fields;

  ProtocolInstance.fromJson(Map<String, dynamic> json)
      : networkId = json['network_id'],
        desc = json['desc'],
        icon = json['icon'],
        fields = json['fields'];

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
