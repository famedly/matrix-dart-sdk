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
  }) : super(
          type: AuthenticationTypes.password,
        );

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
