import 'dart:convert';

import 'package:http/http.dart' hide Client;

import 'package:matrix/matrix.dart';

extension OidcDynamicClientRegistrationExtension on Client {
  /// checks whether an OIDC Dynamic Client ID is present for the current
  /// homeserver or creates one in case not.
  ///
  /// returns the registered client ID or null in case the homeserver does not
  /// support OIDC.
  Future<String?> oidcEnsureDynamicClientId({
    required OidcDynamicRegistrationData registrationData,
    bool enforceNewDynamicClient = false,
  }) async {
    if (!enforceNewDynamicClient) {
      final account = await database.getClient(clientName);
      final storedOidcClientId =
          oidcDynamicClientId = account?['oidc_dynamic_client_id'];

      if (storedOidcClientId is String) {
        Logs().d('[OIDC] Reusing Dynamic Client ID $storedOidcClientId.');
        return storedOidcClientId;
      }
    }

    GetAuthMetadataResponse? metadata;

    try {
      metadata = await getAuthMetadata();
    } catch (_) {
      return null;
    }

    final endpoint = metadata.registrationEndpoint;

    final oidcClientId = await oidcRegisterOAuth2Client(
      registrationEndpoint: endpoint,
      registrationData: registrationData,
    );
    await database.storeOidcDynamicClientId(oidcClientId);
    Logs().d('[OIDC] Registered Dynamic Client ID $oidcClientId.');
    return oidcDynamicClientId = oidcClientId;
  }

  /// MSC 2966
  ///
  /// Performs an OIDC Dynamic Client registration at the given
  /// `registrationEndpoint` with the provided `registrationData`.
  ///
  /// As a client developer, you will likely want to use
  /// [oidcEnsureDynamicClientId] for a high-level interface instead.
  Future<String> oidcRegisterOAuth2Client({
    required Uri registrationEndpoint,
    required OidcDynamicRegistrationData registrationData,
  }) async {
    final request = Request('POST', registrationEndpoint);
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode(registrationData.toJson()));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode >= 400) {
      unexpectedResponse(response, responseBody);
    }
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return json['client_id'] as String;
  }
}

/// The OIDC Dynamic Client registration data
///
/// Use [OidcDynamicRegistrationData.localized] for a high-level interface
/// providing all data required for MAS including localization.
class OidcDynamicRegistrationData {
  const OidcDynamicRegistrationData({
    required this.clientName,
    required this.contacts,
    required this.url,
    required this.logo,
    required this.tos,
    required this.policy,
    required this.redirect,
    this.responseTypes = const {
      'code',
    },
    this.grantTypes = const {
      'authorization_code',
      'refresh_token',
    },
    required this.applicationType,
  });

  factory OidcDynamicRegistrationData.localized({
    required Uri url,
    required Set<String> contacts,
    required LocalizedOidcClientMetadata defaultLocale,
    required Set<Uri> redirect,
    String applicationType = 'native',
    Map<String, LocalizedOidcClientMetadata> localizations = const {},
  }) {
    return OidcDynamicRegistrationData(
      clientName: {
        null: defaultLocale.clientName,
        ...localizations.map(
          (locale, localizations) => MapEntry(locale, localizations.clientName),
        ),
      },
      contacts: contacts,
      url: url,
      logo: {
        null: defaultLocale.logo,
        ...localizations.map(
          (locale, localizations) => MapEntry(locale, localizations.logo),
        ),
      },
      tos: {
        null: defaultLocale.tos,
        ...localizations.map(
          (locale, localizations) => MapEntry(locale, localizations.tos),
        ),
      },
      policy: {
        null: defaultLocale.policy,
        ...localizations.map(
          (locale, localizations) => MapEntry(locale, localizations.policy),
        ),
      },
      redirect: redirect,
      applicationType: applicationType,
    );
  }

  final Map<String?, String> clientName;
  final Uri url;
  final Map<String?, Uri> logo;
  final Map<String?, Uri> tos;
  final Map<String?, Uri> policy;
  final Set<String> contacts;
  final Set<Uri> redirect;
  final Set<String> responseTypes;
  final Set<String> grantTypes;
  final String applicationType;

  String _localizedKey(String key, String? localeName) =>
      localeName == null ? key : '$key#$localeName';

  Map<String, Object?> toJson() => {
        ...clientName.map<String, String>(
          (localeName, value) =>
              MapEntry(_localizedKey('client_name', localeName), value),
        ),
        'client_uri': url.toString(),
        'contacts': contacts.toList(),
        ...logo.map<String, String>(
          (localeName, value) => MapEntry(
            _localizedKey('logo_uri', localeName),
            value.toString(),
          ),
        ),
        ...tos.map<String, String>(
          (localeName, value) => MapEntry(
            _localizedKey('tos_uri', localeName),
            value.toString(),
          ),
        ),
        ...policy.map<String, String>(
          (localeName, value) => MapEntry(
            _localizedKey('policy_uri', localeName),
            value.toString(),
          ),
        ),
        // https://github.com/element-hq/matrix-authentication-service/issues/3638#issuecomment-2527352709
        'token_endpoint_auth_method': 'none',
        'redirect_uris': redirect.map<String>((uri) => uri.toString()).toList(),
        'response_types': responseTypes.toList(),
        'grant_types': grantTypes.toList(),
        'application_type': applicationType,
      };
}

/// A tiny helper class around the localizable OIDC Dynamic Client Registration
/// data fields.
class LocalizedOidcClientMetadata {
  const LocalizedOidcClientMetadata({
    required this.clientName,
    required this.logo,
    required this.tos,
    required this.policy,
  });

  // client_name
  final String clientName;

  // logo_uri
  final Uri logo;

  // tos_uri
  final Uri tos;

  // policy_uri
  final Uri policy;
}
