
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
  late List<ThreepidCreds> threepidCreds;

  AuthenticationThreePidCreds({String? session, required String type, required this.threepidCreds})
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
  String/*!*/ sid;
  String clientSecret;
  String idServer;
  String idAccessToken;

  ThreepidCreds(
      {required this.sid, required this.clientSecret, required this.idServer, required this.idAccessToken});

  ThreepidCreds.fromJson(Map<String, dynamic> json)
      : sid = json['sid'],
        clientSecret = json['client_secret'],
        idServer = json['id_server'],
        idAccessToken = json['id_access_token'];

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['sid'] = sid;
    data['client_secret'] = clientSecret;
    data['id_server'] = idServer;
    data['id_access_token'] = idAccessToken;
    return data;
  }
}
