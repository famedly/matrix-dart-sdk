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

import 'package:famedlysdk/matrix_api/model/auth/authentication_user_identifier.dart';

import 'authentication_data.dart';
import 'authentication_identifier.dart';
import 'authentication_phone_identifier.dart';
import 'authentication_third_party_identifier.dart';
import 'authentication_types.dart';

class AuthenticationPassword extends AuthenticationData {
  String user;
  String password;

  /// You may want to cast this as [AuthenticationUserIdentifier] or other
  /// Identifier classes extending AuthenticationIdentifier.
  AuthenticationIdentifier identifier;

  AuthenticationPassword(
      {String session, this.password, this.user, this.identifier})
      : super(
          type: AuthenticationTypes.password,
          session: session,
        );

  AuthenticationPassword.fromJson(Map<String, dynamic> json)
      : super.fromJson(json) {
    user = json['user'];
    password = json['password'];
    identifier = AuthenticationIdentifier.fromJson(json['identifier']);
    switch (identifier.type) {
      case AuthenticationIdentifierTypes.userId:
        identifier = AuthenticationUserIdentifier.fromJson(json['identifier']);
        break;
      case AuthenticationIdentifierTypes.phone:
        identifier = AuthenticationPhoneIdentifier.fromJson(json['identifier']);
        break;
      case AuthenticationIdentifierTypes.thirdParty:
        identifier =
            AuthenticationThirdPartyIdentifier.fromJson(json['identifier']);
        break;
    }
  }

  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson();
    if (user != null) data['user'] = user;
    data['password'] = password;
    switch (identifier.type) {
      case AuthenticationIdentifierTypes.userId:
        data['identifier'] =
            (identifier as AuthenticationUserIdentifier).toJson();
        break;
      case AuthenticationIdentifierTypes.phone:
        data['identifier'] =
            (identifier as AuthenticationPhoneIdentifier).toJson();
        break;
      case AuthenticationIdentifierTypes.thirdParty:
        data['identifier'] =
            (identifier as AuthenticationThirdPartyIdentifier).toJson();
        break;
      default:
        data['identifier'] = identifier.toJson();
        break;
    }
    return data;
  }
}
