/* MIT License
* 
* Copyright (C) 2019, 2020, 2021 Famedly GmbH
* 
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
* 
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
* 
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

import 'authentication_data.dart';

/// For email based identity:
/// https://matrix.org/docs/spec/client_server/r0.6.1#email-based-identity-homeserver
/// Or phone number based identity:
/// https://matrix.org/docs/spec/client_server/r0.6.1#phone-number-msisdn-based-identity-homeserver
class AuthenticationThreePidCreds extends AuthenticationData {
  late ThreepidCreds threepidCreds;

  AuthenticationThreePidCreds(
      {String? session, required String type, required this.threepidCreds})
      : super(
          type: type,
          session: session,
        );

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

  ThreepidCreds(
      {required this.sid,
      required this.clientSecret,
      this.idServer,
      this.idAccessToken});

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
