/// Experimental login method using User Interactive Authentication
library;

import 'dart:convert';

import 'package:http/http.dart' hide Client;

import 'package:matrix/matrix.dart';

extension UiaLogin on Client {
  /// Implementation of MSC2835:
  /// https://github.com/Sorunome/matrix-doc/blob/soru/uia-on-login/proposals/2835-uia-on-login.md
  /// Set `pathVersion` to `r0` if you need to use the previous
  /// version of the login endpoint.
  Future<LoginResponse> uiaLogin(
    String type, {
    String? address,
    String? deviceId,
    AuthenticationIdentifier? identifier,
    String? initialDeviceDisplayName,
    String? medium,
    String? password,
    String? token,
    String? user,
    AuthenticationData? auth,
    String pathVersion = 'v3',
    bool? refreshToken,
  }) async {
    final requestUri = Uri(path: '_matrix/client/$pathVersion/login');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(
      jsonEncode({
        if (address != null) 'address': address,
        if (deviceId != null) 'device_id': deviceId,
        if (identifier != null) 'identifier': identifier.toJson(),
        if (initialDeviceDisplayName != null)
          'initial_device_display_name': initialDeviceDisplayName,
        if (medium != null) 'medium': medium,
        if (password != null) 'password': password,
        if (token != null) 'token': token,
        'type': type,
        if (user != null) 'user': user,
        if (auth != null) 'auth': auth.toJson(),
        if (refreshToken != null) 'refresh_token': refreshToken,
      }),
    );
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return LoginResponse.fromJson(json);
  }
}
