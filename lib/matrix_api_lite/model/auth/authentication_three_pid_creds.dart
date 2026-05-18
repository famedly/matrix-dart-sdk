// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite/model/auth/authentication_data.dart';

/// For email based identity:
/// https://matrix.org/docs/spec/client_server/r0.6.1#email-based-identity-homeserver
/// Or phone number based identity:
/// https://matrix.org/docs/spec/client_server/r0.6.1#phone-number-msisdn-based-identity-homeserver
class AuthenticationThreePidCreds extends AuthenticationData {
  late ThreepidCreds threepidCreds;

  AuthenticationThreePidCreds({
    super.session,
    required String super.type,
    required this.threepidCreds,
  });

  AuthenticationThreePidCreds.fromJson(Map<String, Object?> json)
      : super.fromJson(json) {
    final creds = json['threepid_creds'];
    if (creds is Map<String, Object?>) {
      threepidCreds = ThreepidCreds.fromJson(creds);
    }
  }

  @override
  Map<String, Object?> toJson() {
    final data = super.toJson();
    data['threepid_creds'] = threepidCreds.toJson();
    return data;
  }
}

class ThreepidCreds {
  String sid;
  String clientSecret;
  String? idServer;
  String? idAccessToken;

  ThreepidCreds({
    required this.sid,
    required this.clientSecret,
    this.idServer,
    this.idAccessToken,
  });

  ThreepidCreds.fromJson(Map<String, Object?> json)
      : sid = json['sid'] as String,
        clientSecret = json['client_secret'] as String,
        idServer = json['id_server'] as String?,
        idAccessToken = json['id_access_token'] as String?;

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    data['sid'] = sid;
    data['client_secret'] = clientSecret;
    if (idServer != null) data['id_server'] = idServer;
    if (idAccessToken != null) data['id_access_token'] = idAccessToken;
    return data;
  }
}
