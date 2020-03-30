/*
 * Copyright (c) 2019 Zender & Kurtz GbR.
 *
 * Authors:
 *   Christian Pauly <krille@famedly.com>
 *   Marcel Radzio <mtrnord@famedly.com>
 *
 * This file is part of famedlysdk.
 *
 * famedlysdk is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * famedlysdk is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with famedlysdk.  If not, see <http://www.gnu.org/licenses/>.
 */

import 'dart:convert';

import 'package:http/http.dart' as http;

enum MatrixError {
  M_UNKNOWN,
  M_UNKNOWN_TOKEN,
  M_NOT_FOUND,
  M_FORBIDDEN,
  M_LIMIT_EXCEEDED,
  M_USER_IN_USE,
  M_THREEPID_IN_USE,
  M_THREEPID_DENIED,
  M_THREEPID_NOT_FOUND,
  M_THREEPID_AUTH_FAILED,
  M_TOO_LARGE,
  M_MISSING_PARAM,
  M_UNSUPPORTED_ROOM_VERSION,
  M_UNRECOGNIZED,
}

/// Represents a special response from the Homeserver for errors.
class MatrixException implements Exception {
  final Map<String, dynamic> raw;

  /// The unique identifier for this error.
  String get errcode =>
      raw['errcode'] ??
      (requireAdditionalAuthentication ? 'M_FORBIDDEN' : 'M_UNKNOWN');

  /// A human readable error description.
  String get errorMessage =>
      raw['error'] ??
      (requireAdditionalAuthentication
          ? 'Require additional authentication'
          : 'Unknown error');

  /// The frozen request which triggered this Error
  http.Response response;

  MatrixException(this.response) : raw = json.decode(response.body);

  @override
  String toString() => '$errcode: $errorMessage';

  /// Returns the [ResponseError]. Is ResponseError.NONE if there wasn't an error.
  MatrixError get error => MatrixError.values.firstWhere(
      (e) => e.toString() == 'MatrixError.${(raw["errcode"] ?? "")}',
      orElse: () => MatrixError.M_UNKNOWN);

  int get retryAfterMs => raw['retry_after_ms'];

  /// This is a session identifier that the client must pass back to the homeserver, if one is provided,
  /// in subsequent attempts to authenticate in the same API call.
  String get session => raw['session'];

  /// Returns true if the server requires additional authentication.
  bool get requireAdditionalAuthentication => response.statusCode == 401;

  /// For each endpoint, a server offers one or more 'flows' that the client can use
  /// to authenticate itself. Each flow comprises a series of stages. If this request
  /// doesn't need additional authentication, then this is null.
  List<AuthenticationFlow> get authenticationFlows {
    if (!raw.containsKey('flows') || !(raw['flows'] is List)) return null;
    var flows = <AuthenticationFlow>[];
    for (Map<String, dynamic> flow in raw['flows']) {
      if (flow['stages'] is List) {
        flows.add(AuthenticationFlow(List<String>.from(flow['stages'])));
      }
    }
    return flows;
  }

  /// This section contains any information that the client will need to know in order to use a given type
  /// of authentication. For each authentication type presented, that type may be present as a key in this
  /// dictionary. For example, the public part of an OAuth client ID could be given here.
  Map<String, dynamic> get authenticationParams => raw['params'];

  /// Returns the list of already completed authentication flows from previous requests.
  List<String> get completedAuthenticationFlows =>
      List<String>.from(raw['completed'] ?? []);
}

/// For each endpoint, a server offers one or more 'flows' that the client can use
/// to authenticate itself. Each flow comprises a series of stages
class AuthenticationFlow {
  final List<String> stages;
  const AuthenticationFlow(this.stages);
}
