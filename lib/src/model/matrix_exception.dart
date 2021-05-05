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
  MatrixException.fromJson(Map<String, dynamic> content) : raw = content;

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
  bool get requireAdditionalAuthentication => response != null
      ? response.statusCode == 401
      : authenticationFlows != null;

  /// For each endpoint, a server offers one or more 'flows' that the client can use
  /// to authenticate itself. Each flow comprises a series of stages. If this request
  /// doesn't need additional authentication, then this is null.
  List<AuthenticationFlow> get authenticationFlows {
    if (!raw.containsKey('flows') || !(raw['flows'] is List)) return null;
    return (raw['flows'] as List)
        .map((flow) => flow['stages'])
        .whereType<List>()
        .map((stages) => AuthenticationFlow(List<String>.from(stages)))
        .toList();
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
