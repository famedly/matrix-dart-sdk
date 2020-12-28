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

import 'authentication_data.dart';
import 'authentication_types.dart';

class AuthenticationToken extends AuthenticationData {
  String token;
  String txnId;

  AuthenticationToken({String session, this.token, this.txnId})
      : super(
          type: AuthenticationTypes.token,
          session: session,
        );

  AuthenticationToken.fromJson(Map<String, dynamic> json)
      : super.fromJson(json) {
    token = json['token'];
    txnId = json['txn_id'];
  }

  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson();
    data['token'] = token;
    data['txn_id'] = txnId;
    return data;
  }
}
