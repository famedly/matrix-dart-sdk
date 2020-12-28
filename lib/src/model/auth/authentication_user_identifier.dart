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

import 'authentication_identifier.dart';
import 'authentication_types.dart';

class AuthenticationUserIdentifier extends AuthenticationIdentifier {
  String user;

  AuthenticationUserIdentifier({this.user})
      : super(type: AuthenticationIdentifierTypes.userId);

  AuthenticationUserIdentifier.fromJson(Map<String, dynamic> json)
      : super.fromJson(json) {
    user = json['user'];
  }

  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson();
    data['user'] = user;
    return data;
  }
}
