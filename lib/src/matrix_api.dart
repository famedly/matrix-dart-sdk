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

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../matrix_api_lite.dart';
import 'generated/api.dart';
import 'model/matrix_connection_exception.dart';
import 'model/matrix_exception.dart';
import 'model/matrix_keys.dart';

enum RequestType { GET, POST, PUT, DELETE }

class MatrixApi extends Api {
  /// The homeserver this client is communicating with.
  Uri? get homeserver => baseUri;

  set homeserver(Uri? uri) => baseUri = uri;

  /// This is the access token for the matrix client. When it is undefined, then
  /// the user needs to sign in first.
  String? get accessToken => bearerToken;

  set accessToken(String? token) => bearerToken = token;

  @override
  Never unexpectedResponse(http.BaseResponse response, Uint8List responseBody) {
    if (response.statusCode >= 400 && response.statusCode < 500) {
      throw MatrixException.fromJson(json.decode(utf8.decode(responseBody)));
    }
    super.unexpectedResponse(response, responseBody);
  }

  MatrixApi({
    Uri? homeserver,
    String? accessToken,
    http.Client? httpClient,
  }) : super(
            httpClient: httpClient,
            baseUri: homeserver,
            bearerToken: accessToken);

  /// Used for all Matrix json requests using the [c2s API](https://matrix.org/docs/spec/client_server/r0.6.0.html).
  ///
  /// Throws: FormatException, MatrixException
  ///
  /// You must first set [this.homeserver] and for some endpoints also
  /// [this.accessToken] before you can use this! For example to send a
  /// message to a Matrix room with the id '!fjd823j:example.com' you call:
  /// ```
  /// final resp = await request(
  ///   RequestType.PUT,
  ///   '/r0/rooms/!fjd823j:example.com/send/m.room.message/$txnId',
  ///   data: {
  ///     'msgtype': 'm.text',
  ///     'body': 'hello'
  ///   }
  ///  );
  /// ```
  ///
  Future<Map<String, dynamic>> request(
    RequestType type,
    String action, {
    dynamic data = '',
    String contentType = 'application/json',
    Map<String, dynamic>? query,
  }) async {
    if (homeserver == null) {
      throw ('No homeserver specified.');
    }
    dynamic json;
    (!(data is String)) ? json = jsonEncode(data) : json = data;
    if (data is List<int> || action.startsWith('/media/r0/upload')) json = data;

    final url = homeserver!
        .resolveUri(Uri(path: '_matrix$action', queryParameters: query));

    final headers = <String, String>{};
    if (type == RequestType.PUT || type == RequestType.POST) {
      headers['Content-Type'] = contentType;
    }
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    late http.Response resp;
    Map<String, dynamic>? jsonResp = <String, dynamic>{};
    try {
      switch (type) {
        case RequestType.GET:
          resp = await httpClient.get(url, headers: headers);
          break;
        case RequestType.POST:
          resp = await httpClient.post(url, body: json, headers: headers);
          break;
        case RequestType.PUT:
          resp = await httpClient.put(url, body: json, headers: headers);
          break;
        case RequestType.DELETE:
          resp = await httpClient.delete(url, headers: headers);
          break;
      }
      var respBody = resp.body;
      try {
        respBody = utf8.decode(resp.bodyBytes);
      } catch (_) {
        // No-OP
      }
      if (resp.statusCode >= 500 && resp.statusCode < 600) {
        throw Exception(respBody);
      }
      var jsonString = String.fromCharCodes(respBody.runes);
      if (jsonString.startsWith('[') && jsonString.endsWith(']')) {
        jsonString = '\{"chunk":$jsonString\}';
      }
      jsonResp = jsonDecode(jsonString)
          as Map<String, dynamic>?; // May throw FormatException
    } catch (e, s) {
      throw MatrixConnectionException(e, s);
    }
    if (resp.statusCode >= 400 && resp.statusCode < 500) {
      throw MatrixException(resp);
    }

    return jsonResp!;
  }

  /// Publishes end-to-end encryption keys for the device.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-keys-query
  Future<Map<String, int>> uploadKeys(
      {MatrixDeviceKeys? deviceKeys,
      Map<String, dynamic>? oneTimeKeys,
      Map<String, dynamic>? fallbackKeys}) async {
    final response = await request(
      RequestType.POST,
      '/client/r0/keys/upload',
      data: {
        if (deviceKeys != null) 'device_keys': deviceKeys.toJson(),
        if (oneTimeKeys != null) 'one_time_keys': oneTimeKeys,
        if (fallbackKeys != null) ...{
          'fallback_keys': fallbackKeys,
          'org.matrix.msc2732.fallback_keys': fallbackKeys,
        },
      },
    );
    return Map<String, int>.from(response['one_time_key_counts']);
  }

  /// This endpoint allows the creation, modification and deletion of pushers
  /// for this user ID. The behaviour of this endpoint varies depending on the
  /// values in the JSON body.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-pushers-set
  Future<void> postPusher(Pusher pusher, {bool? append}) async {
    final data = pusher.toJson();
    if (append != null) {
      data['append'] = append;
    }
    await request(
      RequestType.POST,
      '/client/r0/pushers/set',
      data: data,
    );
    return;
  }

  /// This API provides credentials for the client to use when initiating
  /// calls.
  @override
  Future<TurnServerCredentials> getTurnServer() async {
    final json = await request(RequestType.GET, '/client/r0/voip/turnServer');

    // fix invalid responses from synapse
    // https://github.com/matrix-org/synapse/pull/10922
    json['ttl'] = json['ttl'].toInt();

    return TurnServerCredentials.fromJson(json);
  }
}
