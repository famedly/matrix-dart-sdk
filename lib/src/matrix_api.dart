// @dart=2.9
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
import 'model/auth/authentication_data.dart';
import 'model/events_sync_update.dart';
import 'model/matrix_connection_exception.dart';
import 'model/matrix_exception.dart';
import 'model/matrix_keys.dart';
import 'model/request_token_response.dart';
import 'model/room_keys_keys.dart';
import 'model/supported_protocol.dart';
import 'model/third_party_location.dart';
import 'model/third_party_user.dart';
import 'model/upload_key_signatures_response.dart';

import 'generated/api.dart';

enum RequestType { GET, POST, PUT, DELETE }

String describeEnum(Object enumEntry) {
  final description = enumEntry.toString();
  final indexOfDot = description.indexOf('.');
  assert(indexOfDot != -1 && indexOfDot < description.length - 1);
  return description.substring(indexOfDot + 1);
}

class MatrixApi extends Api {
  /// The homeserver this client is communicating with.
  Uri get homeserver => baseUri;
  set homeserver(Uri uri) => baseUri = uri;

  /// This is the access token for the matrix client. When it is undefined, then
  /// the user needs to sign in first.
  String get accessToken => bearerToken;
  set accessToken(String token) => bearerToken = token;

  @override
  Null unexpectedResponse(http.BaseResponse response, Uint8List responseBody) {
    if (response.statusCode >= 400 && response.statusCode < 500) {
      throw MatrixException.fromJson(json.decode(utf8.decode(responseBody)));
    }
    super.unexpectedResponse(response, responseBody);
  }

  MatrixApi({
    Uri homeserver,
    String accessToken,
    http.Client httpClient,
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
    Map<String, dynamic> query,
  }) async {
    if (homeserver == null) {
      throw ('No homeserver specified.');
    }
    dynamic json;
    (!(data is String)) ? json = jsonEncode(data) : json = data;
    if (data is List<int> || action.startsWith('/media/r0/upload')) json = data;

    final url = homeserver
        .resolveUri(Uri(path: '_matrix$action', queryParameters: query));

    final headers = <String, String>{};
    if (type == RequestType.PUT || type == RequestType.POST) {
      headers['Content-Type'] = contentType;
    }
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    http.Response resp;
    var jsonResp = <String, dynamic>{};
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
          as Map<String, dynamic>; // May throw FormatException
    } catch (e, s) {
      throw MatrixConnectionException(e, s);
    }
    if (resp.statusCode >= 400 && resp.statusCode < 500) {
      throw MatrixException(resp);
    }

    return jsonResp;
  }

  /// The homeserver must check that the given email address is not already associated
  /// with an account on this homeserver. The homeserver should validate the email
  /// itself, either by sending a validation email itself or by using a service it
  /// has control over.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#post-matrix-client-r0-register-email-requesttoken
  Future<RequestTokenResponse> requestEmailToken(
    String email,
    String clientSecret,
    int sendAttempt, {
    String nextLink,
    String idServer,
    String idAccessToken,
  }) async {
    final response = await request(
        RequestType.POST, '/client/r0/register/email/requestToken',
        data: {
          'email': email,
          'send_attempt': sendAttempt,
          'client_secret': clientSecret,
          if (nextLink != null) 'next_link': nextLink,
          if (idServer != null) 'id_server': idServer,
          if (idAccessToken != null) 'id_access_token': idAccessToken,
        });
    return RequestTokenResponse.fromJson(response);
  }

  /// The homeserver must check that the given phone number is not already associated with an
  /// account on this homeserver. The homeserver should validate the phone number itself,
  /// either by sending a validation message itself or by using a service it has control over.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#post-matrix-client-r0-register-msisdn-requesttoken
  Future<RequestTokenResponse> requestMsisdnToken(
    String country,
    String phoneNumber,
    String clientSecret,
    int sendAttempt, {
    String nextLink,
    String idServer,
    String idAccessToken,
  }) async {
    final response = await request(
        RequestType.POST, '/client/r0/register/msisdn/requestToken',
        data: {
          'country': country,
          'phone_number': phoneNumber,
          'send_attempt': sendAttempt,
          'client_secret': clientSecret,
          if (nextLink != null) 'next_link': nextLink,
          if (idServer != null) 'id_server': idServer,
          if (idAccessToken != null) 'id_access_token': idAccessToken,
        });
    return RequestTokenResponse.fromJson(response);
  }

  /// The homeserver must check that the given email address is associated with
  /// an account on this homeserver. This API should be used to request
  /// validation tokens when authenticating for the /account/password endpoint.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#post-matrix-client-r0-account-password-email-requesttoken
  Future<RequestTokenResponse> resetPasswordUsingEmail(
    String email,
    String clientSecret,
    int sendAttempt, {
    String nextLink,
    String idServer,
    String idAccessToken,
  }) async {
    final response = await request(
        RequestType.POST, '/client/r0/account/password/email/requestToken',
        data: {
          'email': email,
          'send_attempt': sendAttempt,
          'client_secret': clientSecret,
          if (nextLink != null) 'next_link': nextLink,
          if (idServer != null) 'id_server': idServer,
          if (idAccessToken != null) 'id_access_token': idAccessToken,
        });
    return RequestTokenResponse.fromJson(response);
  }

  /// The homeserver must check that the given phone number is associated with
  /// an account on this homeserver. This API should be used to request validation
  /// tokens when authenticating for the /account/password endpoint.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#post-matrix-client-r0-account-password-msisdn-requesttoken
  Future<RequestTokenResponse> resetPasswordUsingMsisdn(
    String country,
    String phoneNumber,
    String clientSecret,
    int sendAttempt, {
    String nextLink,
    String idServer,
    String idAccessToken,
  }) async {
    final response = await request(
        RequestType.POST, '/client/r0/account/password/msisdn/requestToken',
        data: {
          'country': country,
          'phone_number': phoneNumber,
          'send_attempt': sendAttempt,
          'client_secret': clientSecret,
          if (nextLink != null) 'next_link': nextLink,
          if (idServer != null) 'id_server': idServer,
          if (idAccessToken != null) 'id_access_token': idAccessToken,
        });
    return RequestTokenResponse.fromJson(response);
  }

  /// This API should be used to request validation tokens when adding an email address to an account.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#post-matrix-client-r0-account-3pid-email-requesttoken
  Future<RequestTokenResponse> requestEmailValidationToken(
    String email,
    String clientSecret,
    int sendAttempt, {
    String nextLink,
    String idServer,
    String idAccessToken,
  }) async {
    final response = await request(
        RequestType.POST, '/client/r0/account/3pid/email/requestToken',
        data: {
          'email': email,
          'send_attempt': sendAttempt,
          'client_secret': clientSecret,
          if (nextLink != null) 'next_link': nextLink,
          if (idServer != null) 'id_server': idServer,
          if (idAccessToken != null) 'id_access_token': idAccessToken,
        });
    return RequestTokenResponse.fromJson(response);
  }

  /// This API should be used to request validation tokens when adding a phone number to an account.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#post-matrix-client-r0-account-3pid-msisdn-requesttoken
  Future<RequestTokenResponse> requestMsisdnValidationToken(
    String country,
    String phoneNumber,
    String clientSecret,
    int sendAttempt, {
    String nextLink,
    String idServer,
    String idAccessToken,
  }) async {
    final response = await request(
        RequestType.POST, '/client/r0/account/3pid/msisdn/requestToken',
        data: {
          'country': country,
          'phone_number': phoneNumber,
          'send_attempt': sendAttempt,
          'client_secret': clientSecret,
          if (nextLink != null) 'next_link': nextLink,
          if (idServer != null) 'id_server': idServer,
          if (idAccessToken != null) 'id_access_token': idAccessToken,
        });
    return RequestTokenResponse.fromJson(response);
  }

  /// Looks up the contents of a state event in a room. If the user is joined to the room then the
  /// state is taken from the current state of the room. If the user has left the room then the
  /// state is taken from the state of the room when they left.
  /// https://matrix.org/docs/spec/client_server/r0.6.0#get-matrix-client-r0-rooms-roomid-state-eventtype-statekey
  Future<Map<String, dynamic>> requestStateContent(
      String roomId, String eventType,
      [String stateKey]) async {
    var url =
        '/client/r0/rooms/${Uri.encodeComponent(roomId)}/state/${Uri.encodeComponent(eventType)}/';
    if (stateKey != null) {
      url += Uri.encodeComponent(stateKey);
    }
    final response = await request(
      RequestType.GET,
      url,
    );
    return response;
  }

  /// Gets the visibility of a given room on the server's public room directory.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-directory-list-room-roomid
  Future<Visibility> getRoomVisibilityOnDirectory(String roomId) async {
    final response = await request(
      RequestType.GET,
      '/client/r0/directory/list/room/${Uri.encodeComponent(roomId)}',
    );
    return Visibility.values
        .firstWhere((v) => describeEnum(v) == response['visibility']);
  }

  /// Sets the visibility of a given room in the server's public room directory.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#put-matrix-client-r0-directory-list-room-roomid
  Future<void> setRoomVisibilityOnDirectory(
      String roomId, Visibility visibility) async {
    await request(
      RequestType.PUT,
      '/client/r0/directory/list/room/${Uri.encodeComponent(roomId)}',
      data: {
        'visibility': describeEnum(visibility),
      },
    );
    return;
  }

  /// Publishes end-to-end encryption keys for the device.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-keys-query
  Future<Map<String, int>> uploadKeys(
      {MatrixDeviceKeys deviceKeys,
      Map<String, dynamic> oneTimeKeys,
      Map<String, dynamic> fallbackKeys}) async {
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

  /// Uploads your own cross-signing keys.
  /// https://github.com/matrix-org/matrix-doc/pull/2536
  Future<void> uploadDeviceSigningKeys({
    MatrixCrossSigningKey masterKey,
    MatrixCrossSigningKey selfSigningKey,
    MatrixCrossSigningKey userSigningKey,
    AuthenticationData auth,
  }) async {
    await request(
      RequestType.POST,
      '/client/unstable/keys/device_signing/upload',
      data: {
        if (masterKey != null) 'master_key': masterKey.toJson(),
        if (selfSigningKey != null) 'self_signing_key': selfSigningKey.toJson(),
        if (userSigningKey != null) 'user_signing_key': userSigningKey.toJson(),
        if (auth != null) 'auth': auth.toJson(),
      },
    );
  }

  /// Uploads new signatures of keys
  /// https://github.com/matrix-org/matrix-doc/pull/2536
  Future<UploadKeySignaturesResponse> uploadKeySignatures(
      List<MatrixSignableKey> keys) async {
    final payload = <String, dynamic>{};
    for (final key in keys) {
      if (key.identifier == null ||
          key.signatures == null ||
          key.signatures.isEmpty) {
        continue;
      }
      if (!payload.containsKey(key.userId)) {
        payload[key.userId] = <String, dynamic>{};
      }
      if (payload[key.userId].containsKey(key.identifier)) {
        // we need to merge signature objects
        payload[key.userId][key.identifier]['signatures']
            .addAll(key.signatures);
      } else {
        // we can just add signatures
        payload[key.userId][key.identifier] = key.toJson();
      }
    }
    final response = await request(
      RequestType.POST,
      '/client/r0/keys/signatures/upload',
      data: payload,
    );
    return UploadKeySignaturesResponse.fromJson(response);
  }

  /// This endpoint allows the creation, modification and deletion of pushers
  /// for this user ID. The behaviour of this endpoint varies depending on the
  /// values in the JSON body.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#post-matrix-client-r0-pushers-set
  Future<void> postPusher(Pusher pusher, {bool append}) async {
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

  /// This will listen for new events related to a particular room and return them to the
  /// caller. This will block until an event is received, or until the timeout is reached.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-events
  Future<EventsSyncUpdate> getEvents({
    String from,
    int timeout,
    String roomId,
  }) async {
    final response =
        await request(RequestType.GET, '/client/r0/events', query: {
      if (from != null) 'from': from,
      if (timeout != null) 'timeout': timeout.toString(),
      if (roomId != null) 'roomId': roomId,
    });
    return EventsSyncUpdate.fromJson(response);
  }

  /// Fetches the overall metadata about protocols supported by the homeserver. Includes
  /// both the available protocols and all fields required for queries against each protocol.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-thirdparty-protocols
  Future<Map<String, SupportedProtocol>> requestSupportedProtocols() async {
    final response = await request(
      RequestType.GET,
      '/client/r0/thirdparty/protocols',
    );
    return response.map((k, v) => MapEntry(k, SupportedProtocol.fromJson(v)));
  }

  /// Fetches the metadata from the homeserver about a particular third party protocol.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-thirdparty-protocol-protocol
  Future<SupportedProtocol> requestSupportedProtocol(String protocol) async {
    final response = await request(
      RequestType.GET,
      '/client/r0/thirdparty/protocol/${Uri.encodeComponent(protocol)}',
    );
    return SupportedProtocol.fromJson(response);
  }

  /// Requesting this endpoint with a valid protocol name results in a list of successful
  /// mapping results in a JSON array.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-thirdparty-location-protocol
  Future<List<ThirdPartyLocation>> requestThirdPartyLocations(
      String protocol) async {
    final response = await request(
      RequestType.GET,
      '/client/r0/thirdparty/location/${Uri.encodeComponent(protocol)}',
    );
    return (response['chunk'] as List)
        .map((i) => ThirdPartyLocation.fromJson(i))
        .toList();
  }

  /// Retrieve a Matrix User ID linked to a user on the third party service, given a set of
  /// user parameters.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-thirdparty-user-protocol
  Future<List<ThirdPartyUser>> requestThirdPartyUsers(String protocol) async {
    final response = await request(
      RequestType.GET,
      '/client/r0/thirdparty/user/${Uri.encodeComponent(protocol)}',
    );
    return (response['chunk'] as List)
        .map((i) => ThirdPartyUser.fromJson(i))
        .toList();
  }

  /// Retrieve an array of third party network locations from a Matrix room alias.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-thirdparty-location
  Future<List<ThirdPartyLocation>> requestThirdPartyLocationsByAlias(
      String alias) async {
    final response = await request(
        RequestType.GET, '/client/r0/thirdparty/location',
        query: {
          'alias': alias,
        });
    return (response['chunk'] as List)
        .map((i) => ThirdPartyLocation.fromJson(i))
        .toList();
  }

  /// Retrieve an array of third party users from a Matrix User ID.
  /// https://matrix.org/docs/spec/client_server/r0.6.1#get-matrix-client-r0-thirdparty-user
  Future<List<ThirdPartyUser>> requestThirdPartyUsersByUserId(
      String userId) async {
    final response =
        await request(RequestType.GET, '/client/r0/thirdparty/user', query: {
      'userid': userId,
    });
    return (response['chunk'] as List)
        .map((i) => ThirdPartyUser.fromJson(i))
        .toList();
  }

  /// Deletes a room key backup
  /// https://matrix.org/docs/spec/client_server/unstable#delete-matrix-client-r0-room-keys-version-version
  Future<void> deleteRoomKeysBackup(String version) async {
    await request(
      RequestType.DELETE,
      '/client/unstable/room_keys/version/${Uri.encodeComponent(version)}',
    );
  }

  /// Gets a single room key
  /// https://matrix.org/docs/spec/client_server/unstable#get-matrix-client-r0-room-keys-keys-roomid-sessionid
  Future<RoomKeysSingleKey> getRoomKeysSingleKey(
      String roomId, String sessionId, String version) async {
    final ret = await request(
      RequestType.GET,
      '/client/unstable/room_keys/keys/${Uri.encodeComponent(roomId)}/${Uri.encodeComponent(sessionId)}',
      query: {'version': version},
    );
    return RoomKeysSingleKey.fromJson(ret);
  }

  /// Deletes a single room key
  /// https://matrix.org/docs/spec/client_server/unstable#delete-matrix-client-r0-room-keys-keys-roomid-sessionid
  Future<RoomKeysUpdateResponse> deleteRoomKeysSingleKey(
      String roomId, String sessionId, String version) async {
    final ret = await request(
      RequestType.DELETE,
      '/client/unstable/room_keys/keys/${Uri.encodeComponent(roomId)}/${Uri.encodeComponent(sessionId)}',
      query: {'version': version},
    );
    return RoomKeysUpdateResponse.fromJson(ret);
  }

  /// Gets room keys for a room
  /// https://matrix.org/docs/spec/client_server/unstable#get-matrix-client-r0-room-keys-keys-roomid
  Future<RoomKeysRoom> getRoomKeysRoom(String roomId, String version) async {
    final ret = await request(
      RequestType.GET,
      '/client/unstable/room_keys/keys/${Uri.encodeComponent(roomId)}',
      query: {'version': version},
    );
    return RoomKeysRoom.fromJson(ret);
  }

  /// Deletes room keys for a room
  /// https://matrix.org/docs/spec/client_server/unstable#delete-matrix-client-r0-room-keys-keys-roomid
  Future<RoomKeysUpdateResponse> deleteRoomKeysRoom(
      String roomId, String version) async {
    final ret = await request(
      RequestType.DELETE,
      '/client/unstable/room_keys/keys/${Uri.encodeComponent(roomId)}',
      query: {'version': version},
    );
    return RoomKeysUpdateResponse.fromJson(ret);
  }

  /// get all room keys
  /// https://matrix.org/docs/spec/client_server/unstable#get-matrix-client-r0-room-keys-keys
  Future<RoomKeys> getRoomKeys(String version) async {
    final ret = await request(
      RequestType.GET,
      '/client/unstable/room_keys/keys',
      query: {'version': version},
    );
    return RoomKeys.fromJson(ret);
  }

  /// delete all room keys
  /// https://matrix.org/docs/spec/client_server/unstable#delete-matrix-client-r0-room-keys-keys
  Future<RoomKeysUpdateResponse> deleteRoomKeys(String version) async {
    final ret = await request(
      RequestType.DELETE,
      '/client/unstable/room_keys/keys',
      query: {'version': version},
    );
    return RoomKeysUpdateResponse.fromJson(ret);
  }
}
