// SPDX-FileCopyrightText: 2019-2021 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite/model/auth/authentication_data.dart';
import 'package:matrix/matrix_api_lite/model/auth/authentication_types.dart';

class AuthenticationRecaptcha extends AuthenticationData {
  String response;

  AuthenticationRecaptcha({required String session, required this.response})
      : super(
          type: AuthenticationTypes.recaptcha,
          session: session,
        );

  AuthenticationRecaptcha.fromJson(super.json)
      : response = json['response'] as String,
        super.fromJson();

  @override
  Map<String, Object?> toJson() {
    final data = super.toJson();
    data['response'] = response;
    return data;
  }
}
