// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite/model/auth/authentication_identifier.dart';
import 'package:matrix/matrix_api_lite/model/auth/authentication_types.dart';

class AuthenticationPhoneIdentifier extends AuthenticationIdentifier {
  String country;
  String phone;

  AuthenticationPhoneIdentifier({required this.country, required this.phone})
    : super(type: AuthenticationIdentifierTypes.phone);

  AuthenticationPhoneIdentifier.fromJson(super.json)
    : country = json['country'] as String,
      phone = json['phone'] as String,
      super.fromJson();

  @override
  Map<String, Object?> toJson() {
    final data = super.toJson();
    data['country'] = country;
    data['phone'] = phone;
    return data;
  }
}
