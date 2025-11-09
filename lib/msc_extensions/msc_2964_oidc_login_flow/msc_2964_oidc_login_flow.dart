import 'dart:convert';
import 'dart:math';

import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/crypto/crypto.dart';

extension Msc2964OidcLoginFlow on Client {
  /// Initializes a new OIDC Login session by creating a state, a code verifier
  /// and an authorization URI.
  /// It needs an already created OIDC Client from `Client.registerOidcClient()`
  /// and the `authMetadata` from `Client.checkHomeserver()`.
  /// Use the authorization URI to open it in browser and fetch `code` and
  /// `state` from the query parameters of the redirect URI to login with
  /// `Client.oidcLogin()`.
  Future<OidcLoginSession> initOidcLoginSession({
    required OidcClientData oidcClientData,
    required Uri redirectUri,
    String? deviceId,
    Set<String>? scopes,
    int codeVerifierBytesLength = 32,
    OidcResponseMode? responseMode,
    String? prompt,
  }) async {
    final authMetadata = await getAuthMetadata();
    deviceId ??= generateRandomDeviceId();
    scopes ??= {
      'openid',
      //'urn:matrix:client:api:*',
      //'urn:matrix:device:$deviceId',
      // For some reason MAS crashes when not using the msc prefixed scopes:
      'urn:matrix:org.matrix.msc2967.client:api:*',
      'urn:matrix:org.matrix.msc2967.client:device:$deviceId',
    };
    responseMode ??= redirectUri.scheme == 'https'
        ? OidcResponseMode.fragment
        : OidcResponseMode.query;

    final state = base64UrlEncodeNoPadding(secureRandomBytes(32));
    final codeVerifier =
        base64UrlEncodeNoPadding(secureRandomBytes(codeVerifierBytesLength));
    final codeChallenge = base64UrlEncodeNoPadding(
      vod.CryptoUtils.sha256(input: ascii.encode(codeVerifier)),
    );
    final authenticationUri = authMetadata.authorizationEndpoint.replace(
      queryParameters: {
        'client_id': oidcClientData.clientId,
        'response_type': 'code',
        'redirect_uri': redirectUri.toString(),
        'scope': scopes.join(' '),
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'response_mode': responseMode.name,
        'state': state,
        if (prompt != null) 'prompt': prompt,
      },
    );

    return OidcLoginSession(
      oidcClientData: oidcClientData,
      authenticationUri: authenticationUri,
      redirectUri: redirectUri,
      codeVerifier: codeVerifier,
      state: state,
    );
  }

  /// Performs a login with OIDC. It needs an `OidcLoginSession` from
  /// `Client.initOidcLoginSession()` and the `code` and `state` from the
  /// query parameters of the returned URL.
  Future<void> oidcLogin({
    required OidcLoginSession session,
    required String code,
    required String state,
  }) async {
    if (session.state != state) {
      throw Exception(
        'OIDC state differs from initial session. This could either be a bug or a man-in-the-middle attack.',
      );
    }
    final body = <String, String>{
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': session.redirectUri.toString(),
      'client_id': session.oidcClientData.clientId,
      'code_verifier': session.codeVerifier,
    };
    final authMetadata = await getAuthMetadata();
    final response = await httpClient.post(
      authMetadata.tokenEndpoint,
      body: body,
      headers: {'content-type': 'application/x-www-form-urlencoded'},
    );
    if (response.statusCode != 200) {
      unexpectedResponse(
        response,
        response.bodyBytes,
      );
    }
    final responseString = utf8.decode(response.bodyBytes);
    final json = jsonDecode(responseString);
    await init(
      newHomeserver: homeserver,
      newToken: json['access_token'],
      newRefreshToken: json['refresh_token'],
      newTokenExpiresAt:
          DateTime.now().add(Duration(milliseconds: json['expires_in'] as int)),
    );
  }
}

class OidcLoginSession {
  final OidcClientData oidcClientData;
  final Uri authenticationUri, redirectUri;
  final String codeVerifier, state;

  OidcLoginSession({
    required this.oidcClientData,
    required this.authenticationUri,
    required this.redirectUri,
    required this.codeVerifier,
    required this.state,
  });
}

enum OidcResponseMode { fragment, query }

String base64UrlEncodeNoPadding(List<int> bytes) {
  return base64UrlEncode(bytes).replaceAll('=', ''); // URL-safe & unpadded
}

String generateRandomDeviceId() {
  const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  final random = Random.secure();
  return List.generate(10, (_) => letters[random.nextInt(letters.length)])
      .join();
}
