import 'dart:convert';

import 'package:http/http.dart' hide Client;

import 'package:matrix/matrix.dart';

extension OidcProviderMetadataExtension on Client {
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
