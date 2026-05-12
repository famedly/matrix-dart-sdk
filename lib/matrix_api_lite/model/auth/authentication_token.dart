// SPDX-FileCopyrightText: 2019-2021 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite/model/auth/authentication_data.dart';
import 'package:matrix/matrix_api_lite/model/auth/authentication_types.dart';

class AuthenticationToken extends AuthenticationData {
  String token;

  /// removed in the unstable version of the spec
  String? txnId;

  AuthenticationToken({super.session, required this.token, this.txnId})
      : super(
          type: AuthenticationTypes.token,
        );

  AuthenticationToken.fromJson(super.json)
      : token = json['token'] as String,
        txnId = json['txn_id'] as String?,
        super.fromJson();

  @override
  Map<String, Object?> toJson() {
    final data = super.toJson();
    data['token'] = token;
    data['txn_id'] = txnId;
    return data;
  }
}
