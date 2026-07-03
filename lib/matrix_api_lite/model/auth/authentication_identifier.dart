// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite/model/auth/authentication_phone_identifier.dart';
import 'package:matrix/matrix_api_lite/model/auth/authentication_third_party_identifier.dart';
import 'package:matrix/matrix_api_lite/model/auth/authentication_types.dart';
import 'package:matrix/matrix_api_lite/model/auth/authentication_user_identifier.dart';

class AuthenticationIdentifier {
  String type;

  AuthenticationIdentifier({required this.type});

  AuthenticationIdentifier.fromJson(Map<String, Object?> json)
    : type = json['type'] as String;

  factory AuthenticationIdentifier.subFromJson(Map<String, Object?> json) {
    switch (json['type']) {
      case AuthenticationIdentifierTypes.userId:
        return AuthenticationUserIdentifier.fromJson(json);
      case AuthenticationIdentifierTypes.phone:
        return AuthenticationPhoneIdentifier.fromJson(json);
      case AuthenticationIdentifierTypes.thirdParty:
        return AuthenticationThirdPartyIdentifier.fromJson(json);
      default:
        return AuthenticationIdentifier.fromJson(json);
    }
  }

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    data['type'] = type;
    return data;
  }
}
