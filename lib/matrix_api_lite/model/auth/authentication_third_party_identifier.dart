// SPDX-FileCopyrightText: 2019-2021 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite/model/auth/authentication_identifier.dart';
import 'package:matrix/matrix_api_lite/model/auth/authentication_types.dart';

class AuthenticationThirdPartyIdentifier extends AuthenticationIdentifier {
  String medium;
  String address;

  AuthenticationThirdPartyIdentifier({
    required this.medium,
    required this.address,
  }) : super(type: AuthenticationIdentifierTypes.thirdParty);

  AuthenticationThirdPartyIdentifier.fromJson(super.json)
      : medium = json['medium'] as String,
        address = json['address'] as String,
        super.fromJson();

  @override
  Map<String, Object?> toJson() {
    final data = super.toJson();
    data['medium'] = medium;
    data['address'] = address;
    return data;
  }
}
