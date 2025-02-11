import 'dart:convert';

import 'package:http/http.dart' hide Client;

import 'package:matrix/matrix.dart';

extension OidcProviderMetadataExtension on Client {
  /// High-level function to get the OIDC auth metadata for the homeserver
  ///
  /// Performs checks on all three revisions of MSC2965 for OIDC discovery.
  ///
  /// In case the homeserver supports OIDC, this will store the OIDC Auth
  /// Metadata provided by the homeserver.
  ///
  /// This function might usually be called by [checkHomeserver]. Works similar
  /// to [getWellknown].
  Future<Map<String, Object?>?> getOidcDiscoveryInformation() async {
    Map<String, Object?>? oidcMetadata;

    // MSC2965 no longer expects any information on whether OIDC is supported
    // to be present in .well-known - the only way to figure out is sadly
    // calling the /auth_metadata endpoint.

    try {
      oidcMetadata = await getOidcAuthMetadata();
    } catch (e) {
      Logs().v(
        '[OIDC] auth_metadata endpoint not supported. '
        'Fallback on legacy .well-known discovery.',
        e,
      );
    }
    if (oidcMetadata == null) {
      try {
        // even though no longer required, a homeserver *might* still prefer
        // the fallback on .well-known discovery as per
        // https://openid.net/specs/openid-connect-discovery-1_0.html
        final issuer =
            // ignore: deprecated_member_use_from_same_package
            wellKnown?.authentication?.issuer ?? await oidcAuthIssuer();
        // ignore: deprecated_member_use_from_same_package
        oidcMetadata = await getOidcAuthWellKnown(issuer);
      } catch (e) {
        Logs().v('[OIDC] Homeserver does not support OIDC delegation.', e);
      }
    }
    if (oidcMetadata == null) {
      return null;
    }

    Logs().v('[OIDC] Found auth metadata document.');

    await database?.storeOidcAuthMetadata(oidcMetadata);
    return oidcMetadata;
  }

  /// Loads the Auth Metadata from the homeserver
  ///
  /// Even though homeservers might still use the previous proposed approaches
  /// for delegating OIDC discovery, this is the preferred way to fetch the
  /// OIDC Auth Metadata.
  ///
  /// Since the OIDC spec is very flexible with what to expect in this document,
  /// the result is simply returned as a [Map].
  ///
  /// Reference: https://github.com/sandhose/matrix-spec-proposals/blob/msc/sandhose/oidc-discovery/proposals/2965-auth-metadata.md#get-auth_metadata
  Future<Map<String, Object?>> getOidcAuthMetadata() async {
    /// _matrix/client/v1/auth_metadata
    final requestUri =
        Uri(path: '/_matrix/client/unstable/org.matrix.msc2965/auth_metadata');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['content-type'] = 'application/json';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) {
      unexpectedResponse(response, responseBody);
    }
    final responseString = utf8.decode(responseBody);
    return jsonDecode(responseString);
  }

  /// fallback on OIDC discovery via .well-known as per MSC 2965
  ///
  /// Reference: https://openid.net/specs/openid-connect-discovery-1_0.html .
  ///
  /// https://github.com/sandhose/matrix-spec-proposals/blob/msc/sandhose/oidc-discovery/proposals/2965-auth-metadata.md#discovery-via-openid-connect-discovery
  @Deprecated('Use [getOidcAuthMetadata] instead.')
  Future<Map<String, Object?>> getOidcAuthWellKnown(Uri issuer) async {
    final requestUri = Uri(path: '/.well-known/openid-configuration');
    final request = Request('GET', issuer.resolveUri(requestUri));
    request.headers['content-type'] = 'application/json';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) {
      unexpectedResponse(response, responseBody);
    }
    final responseString = utf8.decode(responseBody);
    return jsonDecode(responseString);
  }

  /// fallback on OIDC discovery as per MSC 2965
  ///
  /// This can be used along with https://openid.net/specs/openid-connect-discovery-1_0.html .
  ///
  /// https://github.com/sandhose/matrix-spec-proposals/blob/msc/sandhose/oidc-discovery/proposals/2965-auth-metadata.md#discovery-via-openid-connect-discovery
  @Deprecated('Use [getOidcAuthMetadata] instead.')
  Future<Uri> oidcAuthIssuer() async {
    /// _matrix/client/v1/auth_issuer
    final requestUri =
        Uri(path: '/_matrix/client/unstable/org.matrix.msc2965/auth_issuer');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['content-type'] = 'application/json';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) {
      unexpectedResponse(response, responseBody);
    }
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return Uri.parse(json['issuer'] as String);
  }
}

// fallback on .well-known as per MSC 2965
// https://github.com/sandhose/matrix-spec-proposals/blob/msc/sandhose/oidc-discovery/proposals/2965-auth-metadata.md#discovery-via-the-well-known-client-discovery
extension WellKnownAuthenticationExtension on DiscoveryInformation {
  @Deprecated('Use [getOidcAuthMetadata] instead.')
  DiscoveryInformationAuthenticationData? get authentication =>
      DiscoveryInformationAuthenticationData.fromJson(
        // m.authentication
        additionalProperties['org.matrix.msc2965.authentication'],
      );
}

// Authentication discovery fallback on .well-known as per MSC 2965
///
/// You most probably want to use [Client.getOidcAuthMetadata] instead.
///
/// https://github.com/sandhose/matrix-spec-proposals/blob/msc/sandhose/oidc-discovery/proposals/2965-auth-metadata.md#discovery-via-the-well-known-client-discovery
class DiscoveryInformationAuthenticationData {
  const DiscoveryInformationAuthenticationData({this.issuer, this.account});

  final Uri? issuer;
  final Uri? account;

  static DiscoveryInformationAuthenticationData? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final issuer = json['issuer'] as String?;
    final account = json['account'] as String?;
    return DiscoveryInformationAuthenticationData(
      issuer: issuer == null ? null : Uri.tryParse(issuer),
      account: account == null ? null : Uri.tryParse(account),
    );
  }

  Map<String, String> toJson() => {
        if (issuer != null) 'issuer': issuer.toString(),
        if (account != null) 'account': account.toString(),
      };
}
