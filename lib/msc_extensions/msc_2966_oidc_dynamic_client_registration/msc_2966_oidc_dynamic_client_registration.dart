import 'dart:convert';

import 'package:matrix/matrix.dart';

extension Msc2966OidcDynamicClientRegistration on Client {
  /// Registers a new OIDC Client to retrieve a Client ID for OIDC login.
  /// Please be aware that there are certain requirements for the [redirectUris],
  /// and the Urls in `clientInformation`.
  /// All the URIs MUST use the https scheme and use the client_uri as a common
  /// base, as defined by the previous section.
  /// Learn more at: https://github.com/matrix-org/matrix-spec-proposals/pull/2966
  /// and: https://tools.ietf.org/html/rfc7591
  Future<OidcClientData> registerOidcClient({
    /// Please read carefully the redirect URI validation rules:
    /// https://github.com/sandhose/matrix-spec-proposals/blob/msc/sandhose/oauth2-dynamic-registration/proposals/2966-oauth2-dynamic-registration.md#redirect-uri-validation
    required List<Uri> redirectUris,
    required OidcApplicationType applicationType,
    required OidcClientInformation clientInformation,
    Map<String, OidcClientInformation>? localizedClientInformation,
    String tokenEndpointAuthMethod = 'none',
    List<String> responseTypes = const ['code'],
    List<String> grantTypes = const ['authorization_code', 'refresh_token'],
    Map<String, Object?>? additionalProperties,
  }) async {
    final authMetadata = await getAuthMetadata();
    if (redirectUris.isEmpty) {
      throw Exception('At least one redirect URI is required!');
    }
    switch (applicationType) {
      case OidcApplicationType.web:
        if (redirectUris.any((uri) => uri.scheme != 'https')) {
          throw Exception('Redirect URI MUST use the https scheme on web!');
        }
        if (redirectUris.any(
          (uri) => !uri.host.contains(clientInformation.clientUri.host),
        )) {
          throw Exception(
            'MUST use the client URI as a common base for the authority component!',
          );
        }
        break;
      case OidcApplicationType.native:
        const allowedHosts = {'localhost', '127.0.0.1', '[::1]'};
        if (redirectUris.any(
          (uri) => uri.scheme == 'http' && !allowedHosts.contains(uri.host),
        )) {
          throw Exception(
            'For http loopback interfaces, the host must be one of $allowedHosts',
          );
        }
        break;
    }
    final body = <String, Object?>{
      if (additionalProperties != null) ...additionalProperties,
      'redirect_uris': redirectUris.map((uri) => uri.toString()).toList(),
      'token_endpoint_auth_method': tokenEndpointAuthMethod,
      'response_types': responseTypes,
      'grant_types': grantTypes,
      'application_type': applicationType.name,
      ...clientInformation.toJson(),
      if (localizedClientInformation != null)
        for (final entry in localizedClientInformation.entries)
          ...entry.value.toJson(entry.key),
    };

    final response = await httpClient.post(
      authMetadata.registrationEndpoint,
      body: jsonEncode(body),
      headers: {'content-type': 'application/json'},
    );
    if (response.statusCode != 201) {
      unexpectedResponse(
        response,
        response.bodyBytes,
      );
    }
    final responseString = utf8.decode(response.bodyBytes);
    final json = jsonDecode(responseString);
    return OidcClientData.fromJson(json);
  }
}

enum OidcApplicationType { web, native }

class OidcClientData {
  final String clientId;
  final DateTime? clientIdIssuedAt;
  final OidcClientInformation clientInformation;
  final Map<String, Object?> additionalProperties;

  const OidcClientData({
    required this.clientId,
    required this.clientIdIssuedAt,
    required this.clientInformation,
    required this.additionalProperties,
  });

  factory OidcClientData.fromJson(Map<String, Object?> json) => OidcClientData(
        clientId: json['client_id'] as String,
        clientIdIssuedAt: json['client_id_issued_at'] is int
            ? DateTime.fromMillisecondsSinceEpoch(
                json['client_id_issued_at'] as int,
              )
            : null,
        clientInformation: OidcClientInformation.fromJson(json),
        additionalProperties: json,
      );

  Map<String, Object?> toJson() => additionalProperties;
}

class OidcClientInformation {
  final String? clientName;
  final Uri clientUri;
  final Uri? logoUri, tosUri, policyUri;

  OidcClientInformation({
    required this.clientName,
    required this.clientUri,
    required this.logoUri,
    required this.tosUri,
    required this.policyUri,
  }) {
    if (clientUri.scheme != 'https' ||
        (logoUri != null && logoUri?.scheme != 'https') ||
        (tosUri != null && tosUri?.scheme != 'https') ||
        (policyUri != null && policyUri?.scheme != 'https')) {
      throw Exception('All the URIs MUST use the https scheme!');
    }
    if (logoUri?.host.endsWith(clientUri.host) == false ||
        tosUri?.host.endsWith(clientUri.host) == false ||
        policyUri?.host.endsWith(clientUri.host) == false) {
      throw Exception(
        'All the URIs MUST use the `clientUri` as a common base!',
      );
    }
  }

  factory OidcClientInformation.fromJson(Map<String, Object?> json) =>
      OidcClientInformation(
        clientName: json['client_name'] as String?,
        clientUri: Uri.parse(json['client_uri'] as String),
        logoUri: json['logo_uri'] is String
            ? Uri.tryParse(json['logo_uri'] as String)
            : null,
        tosUri: json['tos_uri'] is String
            ? Uri.tryParse(json['tos_uri'] as String)
            : null,
        policyUri: json['policy_uri'] is String
            ? Uri.tryParse(json['policy_uri'] as String)
            : null,
      );

  Map<String, String> toJson([String? locale]) {
    final clientName = this.clientName;
    final clientUri = this.clientUri;
    final logoUri = this.logoUri;
    final tosUri = this.tosUri;
    final policyUri = this.policyUri;
    final localeSuffix = locale == null ? '' : '#$locale';
    return {
      if (clientName != null) 'client_name$localeSuffix': clientName,
      'client_uri$localeSuffix': clientUri.toString(),
      if (logoUri != null) 'logo_uri$localeSuffix': logoUri.toString(),
      if (tosUri != null) 'tos_uri$localeSuffix': tosUri.toString(),
      if (policyUri != null) 'policy_uri$localeSuffix': policyUri.toString(),
    };
  }
}
