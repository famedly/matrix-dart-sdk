import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' hide Client;

import 'package:matrix/matrix.dart';

extension OidcOauthGrantFlowExtension on Client {
  Future<void> oidcAuthorizationGrantFlow({
    required Completer<OidcCallbackResponse> nativeCompleter,
    required String oidcClientId,
    required String responseType,
    required Uri redirectUri,
    required String responseMode,
    String? initialDeviceDisplayName,
    bool enforceNewDeviceId = false,
    String? prompt,
    void Function(InitState)? onInitStateChanged,
  }) async {
    final verifier = oidcGenerateUnreservedString();
    final state = oidcGenerateUnreservedString();

    final deviceId = await oidcEnsureDeviceId(enforceNewDeviceId);

    await oidcAuthMetadataLoading;

    Uri authEndpoint;
    Uri tokenEndpoint;

    try {
      final authData = await getAuthMetadata();
      authEndpoint = authData.authorizationEndpoint;
      tokenEndpoint = authData.tokenEndpoint;
      // ensure we only hand over permitted prompts
      if (prompt != null) {
        final supported = authData.promptValuesSupported;
        if (supported != null && !supported.contains(prompt)) {
          prompt = null;
        }
      }
      // we do not check the *_supported flags since we assume the homeserver
      // is properly set up
      // https://github.com/sandhose/matrix-spec-proposals/blob/msc/sandhose/oauth2-profile/proposals/2964-oauth2-profile.md#prerequisites
    } catch (e, s) {
      Logs().e('[OIDC] Auth Metadata not valid according to MSC2965.', e, s);
      rethrow;
    }

    // launch the OAuth2 request at the IDP
    await oidcStartOAuth2(
      authorizationEndpoint: authEndpoint,
      oidcClientId: oidcClientId,
      responseType: responseType,
      redirectUri: redirectUri,
      scope: [
        'openid',
        // 'urn:matrix:client:api:*',
        'urn:matrix:org.matrix.msc2967.client:api:*',
        // 'urn:matrix:client:device:*',
        'urn:matrix:org.matrix.msc2967.client:device:$deviceId',
      ],
      responseMode: responseMode,
      state: state,
      codeVerifier: verifier,
      prompt: prompt,
    );

    // wait for the matrix client to receive the redirect callback from the IDP
    final nativeResponse = await nativeCompleter.future;

    // check whether the native redirect contains a successful state
    final oAuth2Code = nativeResponse.code;
    if (nativeResponse.error != null || oAuth2Code == null) {
      Logs().e(
        '[OIDC] OAuth2 error ${nativeResponse.error}: ${nativeResponse.errorDescription} - ${nativeResponse.errorUri}',
      );
      throw nativeResponse;
    }

    // exchange the OAuth2 code into a token
    final oidcToken = await oidcRequestToken(
      tokenEndpoint: tokenEndpoint,
      oidcClientId: oidcClientId,
      oAuth2Code: oAuth2Code,
      redirectUri: redirectUri,
      codeVerifier: verifier,
    );

    // figure out who we are
    bearerToken = oidcToken.accessToken;
    final matrixTokenInfo = await getTokenOwner();
    bearerToken = null;

    final homeserver = this.homeserver;
    if (homeserver == null) {
      throw Exception('OIDC flow successful but homeserver is null.');
    }

    final tokenExpiresAt =
        DateTime.now().add(Duration(milliseconds: oidcToken.expiresIn));

    await init(
      newToken: oidcToken.accessToken,
      newTokenExpiresAt: tokenExpiresAt,
      newRefreshToken: oidcToken.refreshToken,
      newUserID: matrixTokenInfo.userId,
      newHomeserver: homeserver,
      newDeviceName: initialDeviceDisplayName ?? '',
      newDeviceID: matrixTokenInfo.deviceId,
      onInitStateChanged: onInitStateChanged,
    );
  }

  /// Starts an OAuth2 flow
  ///
  /// - generates the challenge for the `codeVerifier` as per RFC 7636
  /// - dispatches the request
  ///
  /// Parameters: https://github.com/sandhose/matrix-spec-proposals/blob/msc/sandhose/oauth2-profile/proposals/2964-oauth2-profile.md#flow-parameters
  Future<void> oidcStartOAuth2({
    required Uri authorizationEndpoint,
    required String oidcClientId,
    required String responseType,
    required Uri redirectUri,
    required List<String> scope,
    required String responseMode,
    required String state,
    required String codeVerifier,
    String? prompt,
  }) async {
    // https://datatracker.ietf.org/doc/html/rfc7636#section-4.2
    final codeChallenge = sha256.convert(latin1.encode(codeVerifier)).bytes;

    final requestUri = authorizationEndpoint.replace(
      queryParameters: {
        'client_id': oidcClientId,
        'response_type': responseType,
        'response_mode': responseMode,
        'redirect_uri': redirectUri.toString(),
        'scope': scope.join(' '),
        if (prompt != null) 'prompt': prompt,
        'code_challenge': base64Encode(codeChallenge),
        'code_challenge_method': 'S256',
      },
    );
    final request = Request('GET', requestUri);
    request.headers['content-type'] = 'application/json';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) {
      unexpectedResponse(response, responseBody);
    }
  }

  /// Exchanges an OIDC OAuth2 code into an access token
  ///
  /// Reference: https://github.com/sandhose/matrix-spec-proposals/blob/msc/sandhose/oauth2-profile/proposals/2964-oauth2-profile.md#token-request
  Future<OidcTokenResponse> oidcRequestToken({
    required Uri tokenEndpoint,
    required String oidcClientId,
    required String oAuth2Code,
    required Uri redirectUri,
    required String codeVerifier,
  }) async {
    final request = Request('POST', tokenEndpoint);
    request.bodyFields.addAll({
      'grant_type': 'authorization_code',
      'code': oAuth2Code,
      'redirect_uri': redirectUri.toString(),
      'client_id': oidcClientId,
      'code_verifier': codeVerifier,
    });
    request.headers['content-type'] = 'application/x-www-form-urlencoded';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) {
      unexpectedResponse(response, responseBody);
    }
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return OidcTokenResponse.fromJson(json);
  }

  /// Refreshes an OIDC refresh token
  ///
  /// Reference: https://github.com/sandhose/matrix-spec-proposals/blob/msc/sandhose/oauth2-profile/proposals/2964-oauth2-profile.md#token-refresh
  Future<OidcTokenResponse> oidcRefreshToken({
    required Uri tokenEndpoint,
    required String refreshToken,
    required String oidcClientId,
  }) async {
    final request = Request('POST', tokenEndpoint);
    request.bodyFields.addAll({
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'client_id': oidcClientId,
    });
    request.headers['content-type'] = 'application/x-www-form-urlencoded';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) {
      unexpectedResponse(response, responseBody);
    }
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return OidcTokenResponse.fromJson(json);
  }

  /// generates a high-entropy String with the given `length`
  ///
  /// The String will only contain characters considered as "unreserved"
  /// according to RFC 7636.
  ///
  /// Reference: https://datatracker.ietf.org/doc/html/rfc7636
  String oidcGenerateUnreservedString([int length = 128]) {
    final random = Random.secure();

    // https://datatracker.ietf.org/doc/html/rfc3986#section-2.3
    const unreserved =
        // [A-Z]
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        // [a-z]
        'abcdefghijklmnopqrstuvwxyz'
        // [0-9]
        '0123456789'
        // "-" / "." / "_" / "~"
        '-._~';

    return String.fromCharCodes(
      List.generate(
        length,
        (_) => unreserved.codeUnitAt(random.nextInt(unreserved.length)),
      ),
    );
  }
}

class OidcCallbackResponse {
  const OidcCallbackResponse(
    this.state, {
    this.code,
    this.error,
    this.errorDescription,
    this.errorUri,
  });

  /// parses the raw redirect Uri received into an [OidcCallbackResponse]
  factory OidcCallbackResponse.parse(
    String redirectUri, [
    String responseMode = 'fragment',
  ]) {
    if (responseMode == 'fragment') {
      redirectUri = redirectUri.replaceFirst('#', '?');
    }
    final uri = Uri.parse(redirectUri);
    return OidcCallbackResponse(
      uri.queryParameters['state']!,
      code: uri.queryParameters['code'],
      error: uri.queryParameters['error'],
      errorDescription: uri.queryParameters['error_description'],
      errorUri: uri.queryParameters['code_uri'],
    );
  }

  final String state;
  final String? code;
  final String? error;
  final String? errorDescription;
  final String? errorUri;
}

/// represents a minimal Token Response as per
class OidcTokenResponse {
  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final String refreshToken;
  final Set<String> scope;

  const OidcTokenResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.refreshToken,
    required this.scope,
  });

  factory OidcTokenResponse.fromJson(Map<String, Object?> json) =>
      OidcTokenResponse(
        accessToken: json['access_token'] as String,
        tokenType: json['token_type'] as String,
        expiresIn: json['expires_in'] as int,
        refreshToken: json['refresh_token'] as String,
        scope: (json['scope'] as String).split(RegExp(r'\s')).toSet(),
      );

  Map<String, Object?> toJson() => {
        'access_token': accessToken,
        'token_type': tokenType,
        'expires_in': expiresIn,
        'refresh_token': refreshToken,
        'scope': scope.join(' '),
      };
}
