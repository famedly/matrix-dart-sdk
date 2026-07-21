// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class AuthenticationData {
  // Should be non-nullable according to the spec but this leads to this problem
  // https://github.com/matrix-org/matrix-doc/issues/3370
  String? type;
  String? session;
  Map<String, Object?>? additionalFields;

  AuthenticationData({this.type, this.session, this.additionalFields});

  AuthenticationData.fromJson(Map<String, Object?> json)
    : type = json['type'] as String?,
      session = json['session'] as String?,
      additionalFields = json;

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    if (type != null) data['type'] = type;
    if (session != null) data['session'] = session;
    if (additionalFields != null) {
      data.addAll(additionalFields!);
    }
    return data;
  }
}
