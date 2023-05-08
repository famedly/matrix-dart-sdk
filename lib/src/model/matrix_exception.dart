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

import 'package:matrix_api_lite/matrix_api_lite.dart';

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
  M_BAD_JSON,
  M_NOT_JSON,
  M_UNAUTHORIZED,
  M_USER_DEACTIVATED,
  M_INVALID_USERNAME,
  M_ROOM_IN_USE,
  M_INVALID_ROOM_STATE,
  M_SERVER_NOT_TRUSTED,
  M_INCOMPATIBLE_ROOM_VERSION,
  M_BAD_STATE,
  M_GUEST_ACCESS_FORBIDDEN,
  M_CAPTCHA_NEEDED,
  M_CAPTCHA_INVALID,
  M_INVALID_PARAM,
  M_EXCLUSIVE,
  M_RESOURCE_LIMIT_EXCEEDED,
  M_CANNOT_LEAVE_SERVER_NOTICE_ROOM,
}

/// Represents a special response from the Homeserver for errors.
class MatrixException implements Exception {
  final Map<String, dynamic> raw;

  /// The unique identifier for this error.
  String get errcode =>
      raw.tryGet<String>('errcode') ??
      (requireAdditionalAuthentication ? 'M_FORBIDDEN' : 'M_UNKNOWN');

  /// A human readable error description.
  String get errorMessage =>
      raw.tryGet<String>('error') ??
      (requireAdditionalAuthentication
          ? 'Require additional authentication'
          : 'Unknown error');

  /// The frozen request which triggered this Error
  http.Response? response;

  MatrixException(http.Response this.response)
      : raw = json.decode(response.body) as Map<String, dynamic>;

  MatrixException.fromJson(Map<String, dynamic> content) : raw = content;

  @override
  String toString() => '$errcode: $errorMessage';

  /// Returns the errcode as an [MatrixError].
  MatrixError get error => MatrixError.values.firstWhere(
        (e) => e.name == errcode,
        orElse: () => MatrixError.M_UNKNOWN,
      );

  int? get retryAfterMs => raw.tryGet<int>('retry_after_ms');

  /// This is a session identifier that the client must pass back to the homeserver, if one is provided,
  /// in subsequent attempts to authenticate in the same API call.
  String? get session => raw.tryGet<String>('session');

  /// Returns true if the server requires additional authentication.
  bool get requireAdditionalAuthentication => response != null
      ? response!.statusCode == 401
      : authenticationFlows != null;

  /// For each endpoint, a server offers one or more 'flows' that the client can use
  /// to authenticate itself. Each flow comprises a series of stages. If this request
  /// doesn't need additional authentication, then this is null.
  List<AuthenticationFlow>? get authenticationFlows => raw
      .tryGet<List<dynamic>>('flows')
      ?.whereType<Map<String, dynamic>>()
      .map((flow) => flow['stages'])
      .whereType<List<dynamic>>()
      .map((stages) =>
          AuthenticationFlow(List<String>.from(stages.whereType<String>())))
      .toList();

  /// This section contains any information that the client will need to know in order to use a given type
  /// of authentication. For each authentication type presented, that type may be present as a key in this
  /// dictionary. For example, the public part of an OAuth client ID could be given here.
  Map<String, dynamic>? get authenticationParams =>
      raw.tryGetMap<String, dynamic>('params');

  /// Returns the list of already completed authentication flows from previous requests.
  List<String> get completedAuthenticationFlows =>
      raw.tryGetList<String>('completed') ?? [];
}

/// For each endpoint, a server offers one or more 'flows' that the client can use
/// to authenticate itself. Each flow comprises a series of stages
class AuthenticationFlow {
  final List<String> stages;

  const AuthenticationFlow(this.stages);
}
