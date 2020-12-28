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

/// For email based identity:
/// https://matrix.org/docs/spec/client_server/r0.6.1#email-based-identity-homeserver
/// Or phone number based identity:
/// https://matrix.org/docs/spec/client_server/r0.6.1#phone-number-msisdn-based-identity-homeserver
class AuthenticationThreePidCreds extends AuthenticationData {
  List<ThreepidCreds> threepidCreds;

  AuthenticationThreePidCreds({String session, String type, this.threepidCreds})
      : super(
          type: type,
          session: session,
        );

  AuthenticationThreePidCreds.fromJson(Map<String, dynamic> json)
      : super.fromJson(json) {
    if (json['threepidCreds'] != null) {
      threepidCreds = (json['threepidCreds'] as List)
          .map((item) => ThreepidCreds.fromJson(item))
          .toList();
    }

    // This is so extremly stupid... kill it with fire!
    if (json['threepid_creds'] != null) {
      threepidCreds = (json['threepid_creds'] as List)
          .map((item) => ThreepidCreds.fromJson(item))
          .toList();
    }
  }

  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson();
    data['threepidCreds'] = threepidCreds.map((t) => t.toJson()).toList();
    // Help me! I'm prisoned in a developer factory against my will,
    // where we are forced to work with json like this!!
    data['threepid_creds'] = threepidCreds.map((t) => t.toJson()).toList();
    return data;
  }
}

class ThreepidCreds {
  String sid;
  String clientSecret;
  String idServer;
  String idAccessToken;

  ThreepidCreds(
      {this.sid, this.clientSecret, this.idServer, this.idAccessToken});

  ThreepidCreds.fromJson(Map<String, dynamic> json) {
    sid = json['sid'];
    clientSecret = json['client_secret'];
    idServer = json['id_server'];
    idAccessToken = json['id_access_token'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['sid'] = sid;
    data['client_secret'] = clientSecret;
    data['id_server'] = idServer;
    data['id_access_token'] = idAccessToken;
    return data;
  }
}
