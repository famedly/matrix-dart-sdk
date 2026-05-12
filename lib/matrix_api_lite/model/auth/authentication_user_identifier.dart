// SPDX-FileCopyrightText: 2019-2021 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite/model/auth/authentication_identifier.dart';
import 'package:matrix/matrix_api_lite/model/auth/authentication_types.dart';

class AuthenticationUserIdentifier extends AuthenticationIdentifier {
  String user;

  AuthenticationUserIdentifier({required this.user})
      : super(type: AuthenticationIdentifierTypes.userId);

  AuthenticationUserIdentifier.fromJson(super.json)
      : user = json['user'] as String,
        super.fromJson();

  @override
  Map<String, Object?> toJson() {
    final data = super.toJson();
    data['user'] = user;
    return data;
  }
}
