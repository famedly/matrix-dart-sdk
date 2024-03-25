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

import 'package:matrix/matrix_api_lite/model/auth/authentication_phone_identifier.dart';
import 'package:matrix/matrix_api_lite/model/auth/authentication_third_party_identifier.dart';
import 'package:matrix/matrix_api_lite/model/auth/authentication_types.dart';
import 'package:matrix/matrix_api_lite/model/auth/authentication_user_identifier.dart';

class AuthenticationIdentifier {
  String type;

  AuthenticationIdentifier({required this.type});

  AuthenticationIdentifier.fromJson(Map<String, Object?> json)
      : type = json['type'] as String;

  factory AuthenticationIdentifier.subFromJson(Map<String, Object?> json) {
    switch (json['type']) {
      case AuthenticationIdentifierTypes.userId:
        return AuthenticationUserIdentifier.fromJson(json);
      case AuthenticationIdentifierTypes.phone:
        return AuthenticationPhoneIdentifier.fromJson(json);
      case AuthenticationIdentifierTypes.thirdParty:
        return AuthenticationThirdPartyIdentifier.fromJson(json);
      default:
        return AuthenticationIdentifier.fromJson(json);
    }
  }

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    data['type'] = type;
    return data;
  }
}
