import 'dart:convert';

import 'package:http/http.dart';

import 'package:matrix/matrix.dart';

extension MscUnpublishedCustomRefreshTokenLifetime on MatrixApi {
  static const String customFieldKey = 'com.famedly.refresh_token_lifetime_ms';

  /// Refresh an access token. Clients should use the returned access token
  /// when making subsequent API calls, and store the returned refresh token
  /// (if given) in order to refresh the new access token when necessary.
  ///
  /// After an access token has been refreshed, a server can choose to
  /// invalidate the old access token immediately, or can choose not to, for
  /// example if the access token would expire soon anyways. Clients should
  /// not make any assumptions about the old access token still being valid,
  /// and should use the newly provided access token instead.
  ///
  /// The old refresh token remains valid until the new access token or refresh token
  /// is used, at which point the old refresh token is revoked.
  ///
  /// Note that this endpoint does not require authentication via an
  /// access token. Authentication is provided via the refresh token.
  ///
  /// Application Service identity assertion is disabled for this endpoint.
  ///
  /// [refreshToken] The refresh token
  Future<RefreshResponse> refreshWithCustomRefreshTokenLifetime(
    String refreshToken, {
    /// This allows clients to pass an extra parameter when refreshing a token,
    /// which overrides the configured refresh token timeout in the Synapse
    /// config. This allows a client to opt into a shorter (or longer) lifetime
    /// for their refresh token, which could be used to sign out web sessions
    /// with a specific timeout.
    ///
    /// Experimental implementation in Synapse:
    /// https://github.com/famedly/synapse/pull/10
    int? refreshTokenLifetimeMs,
  }) async {
    final requestUri = Uri(path: '_matrix/client/v3/refresh');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(
      jsonEncode({
        'refresh_token': refreshToken,
        if (refreshTokenLifetimeMs != null)
          customFieldKey: refreshTokenLifetimeMs,
      }),
    );
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return RefreshResponse.fromJson(json as Map<String, Object?>);
  }
}
