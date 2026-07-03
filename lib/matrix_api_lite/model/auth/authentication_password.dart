// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite/model/auth/authentication_data.dart';
import 'package:matrix/matrix_api_lite/model/auth/authentication_identifier.dart';
import 'package:matrix/matrix_api_lite/model/auth/authentication_types.dart';
import 'package:matrix/matrix_api_lite/model/auth/authentication_user_identifier.dart';

class AuthenticationPassword extends AuthenticationData {
  String password;

  /// You may want to cast this as [AuthenticationUserIdentifier] or other
  /// Identifier classes extending AuthenticationIdentifier.
  AuthenticationIdentifier identifier;

  AuthenticationPassword({
    super.session,
    required this.password,
    required this.identifier,
  }) : super(type: AuthenticationTypes.password);

  AuthenticationPassword.fromJson(super.json)
    : password = json['password'] as String,
      identifier = AuthenticationIdentifier.subFromJson(
        json['identifier'] as Map<String, Object?>,
      ),
      super.fromJson();

  @override
  Map<String, Object?> toJson() {
    final data = super.toJson();
    data['password'] = password;
    data['identifier'] = identifier.toJson();
    return data;
  }
}
