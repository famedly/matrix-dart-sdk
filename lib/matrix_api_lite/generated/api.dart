import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart';

import '../model/auth/authentication_data.dart';
import '../model/auth/authentication_identifier.dart';
import '../model/auth/authentication_types.dart';
import '../model/children_state.dart';
import '../model/matrix_event.dart';
import '../model/matrix_keys.dart';
import '../model/sync_update.dart';
import 'fixed_model.dart';
import 'internal.dart';
import 'model.dart';

class Api {
  Client httpClient;
  Uri? baseUri;
  String? bearerToken;
  Api({Client? httpClient, this.baseUri, this.bearerToken})
      : httpClient = httpClient ?? Client();
  Never unexpectedResponse(BaseResponse response, Uint8List body) {
    throw Exception('http error response');
  }

  /// Gets discovery information about the domain. The file may include
  /// additional keys, which MUST follow the Java package naming convention,
  /// e.g. `com.example.myapp.property`. This ensures property names are
  /// suitably namespaced for each application and reduces the risk of
  /// clashes.
  ///
  /// Note that this endpoint is not necessarily handled by the homeserver,
  /// but by another webserver, to be used for discovering the homeserver URL.
  Future<DiscoveryInformation> getWellknown() async {
    final requestUri = Uri(path: '.well-known/matrix/client');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return DiscoveryInformation.fromJson(json as Map<String, Object?>);
  }

  /// Queries the server to determine if a given registration token is still
  /// valid at the time of request. This is a point-in-time check where the
  /// token might still expire by the time it is used.
  ///
  /// Servers should be sure to rate limit this endpoint to avoid brute force
  /// attacks.
  ///
  /// [token] The token to check validity of.
  ///
  /// returns `valid`:
  /// True if the token is still valid, false otherwise. This should
  /// additionally be false if the token is not a recognised token by
  /// the server.
  Future<bool> registrationTokenValidity(String token) async {
    final requestUri = Uri(
        path: '_matrix/client/v1/register/m.login.registration_token/validity',
        queryParameters: {
          'token': token,
        });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return json['valid'] as bool;
  }

  /// Paginates over the space tree in a depth-first manner to locate child rooms of a given space.
  ///
  /// Where a child room is unknown to the local server, federation is used to fill in the details.
  /// The servers listed in the `via` array should be contacted to attempt to fill in missing rooms.
  ///
  /// Only [`m.space.child`](#mspacechild) state events of the room are considered. Invalid child
  /// rooms and parent events are not covered by this endpoint.
  ///
  /// [roomId] The room ID of the space to get a hierarchy for.
  ///
  /// [suggestedOnly] Optional (default `false`) flag to indicate whether or not the server should only consider
  /// suggested rooms. Suggested rooms are annotated in their [`m.space.child`](#mspacechild) event
  /// contents.
  ///
  /// [limit] Optional limit for the maximum number of rooms to include per response. Must be an integer
  /// greater than zero.
  ///
  /// Servers should apply a default value, and impose a maximum value to avoid resource exhaustion.
  ///
  /// [maxDepth] Optional limit for how far to go into the space. Must be a non-negative integer.
  ///
  /// When reached, no further child rooms will be returned.
  ///
  /// Servers should apply a default value, and impose a maximum value to avoid resource exhaustion.
  ///
  /// [from] A pagination token from a previous result. If specified, `max_depth` and `suggested_only` cannot
  /// be changed from the first request.
  Future<GetSpaceHierarchyResponse> getSpaceHierarchy(String roomId,
      {bool? suggestedOnly, int? limit, int? maxDepth, String? from}) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v1/rooms/${Uri.encodeComponent(roomId)}/hierarchy',
        queryParameters: {
          if (suggestedOnly != null) 'suggested_only': suggestedOnly.toString(),
          if (limit != null) 'limit': limit.toString(),
          if (maxDepth != null) 'max_depth': maxDepth.toString(),
          if (from != null) 'from': from,
        });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return GetSpaceHierarchyResponse.fromJson(json as Map<String, Object?>);
  }

  /// Retrieve all of the child events for a given parent event.
  ///
  /// Note that when paginating the `from` token should be "after" the `to` token in
  /// terms of topological ordering, because it is only possible to paginate "backwards"
  /// through events, starting at `from`.
  ///
  /// For example, passing a `from` token from page 2 of the results, and a `to` token
  /// from page 1, would return the empty set. The caller can use a `from` token from
  /// page 1 and a `to` token from page 2 to paginate over the same range, however.
  ///
  /// [roomId] The ID of the room containing the parent event.
  ///
  /// [eventId] The ID of the parent event whose child events are to be returned.
  ///
  /// [from] The pagination token to start returning results from. If not supplied, results
  /// start at the most recent topological event known to the server.
  ///
  /// Can be a `next_batch` or `prev_batch` token from a previous call, or a returned
  /// `start` token from [`/messages`](https://spec.matrix.org/unstable/client-server-api/#get_matrixclientv3roomsroomidmessages),
  /// or a `next_batch` token from [`/sync`](https://spec.matrix.org/unstable/client-server-api/#get_matrixclientv3sync).
  ///
  /// [to] The pagination token to stop returning results at. If not supplied, results
  /// continue up to `limit` or until there are no more events.
  ///
  /// Like `from`, this can be a previous token from a prior call to this endpoint
  /// or from `/messages` or `/sync`.
  ///
  /// [limit] The maximum number of results to return in a single `chunk`. The server can
  /// and should apply a maximum value to this parameter to avoid large responses.
  ///
  /// Similarly, the server should apply a default value when not supplied.
  ///
  /// [dir] Optional (default `b`) direction to return events from. If this is set to `f`, events
  /// will be returned in chronological order starting at `from`. If it
  /// is set to `b`, events will be returned in *reverse* chronological
  /// order, again starting at `from`.
  Future<GetRelatingEventsResponse> getRelatingEvents(
      String roomId, String eventId,
      {String? from, String? to, int? limit, Direction? dir}) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v1/rooms/${Uri.encodeComponent(roomId)}/relations/${Uri.encodeComponent(eventId)}',
        queryParameters: {
          if (from != null) 'from': from,
          if (to != null) 'to': to,
          if (limit != null) 'limit': limit.toString(),
          if (dir != null) 'dir': dir.name,
        });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return GetRelatingEventsResponse.fromJson(json as Map<String, Object?>);
  }

  /// Retrieve all of the child events for a given parent event which relate to the parent
  /// using the given `relType`.
  ///
  /// Note that when paginating the `from` token should be "after" the `to` token in
  /// terms of topological ordering, because it is only possible to paginate "backwards"
  /// through events, starting at `from`.
  ///
  /// For example, passing a `from` token from page 2 of the results, and a `to` token
  /// from page 1, would return the empty set. The caller can use a `from` token from
  /// page 1 and a `to` token from page 2 to paginate over the same range, however.
  ///
  /// [roomId] The ID of the room containing the parent event.
  ///
  /// [eventId] The ID of the parent event whose child events are to be returned.
  ///
  /// [relType] The [relationship type](https://spec.matrix.org/unstable/client-server-api/#relationship-types) to search for.
  ///
  /// [from] The pagination token to start returning results from. If not supplied, results
  /// start at the most recent topological event known to the server.
  ///
  /// Can be a `next_batch` or `prev_batch` token from a previous call, or a returned
  /// `start` token from [`/messages`](https://spec.matrix.org/unstable/client-server-api/#get_matrixclientv3roomsroomidmessages),
  /// or a `next_batch` token from [`/sync`](https://spec.matrix.org/unstable/client-server-api/#get_matrixclientv3sync).
  ///
  /// [to] The pagination token to stop returning results at. If not supplied, results
  /// continue up to `limit` or until there are no more events.
  ///
  /// Like `from`, this can be a previous token from a prior call to this endpoint
  /// or from `/messages` or `/sync`.
  ///
  /// [limit] The maximum number of results to return in a single `chunk`. The server can
  /// and should apply a maximum value to this parameter to avoid large responses.
  ///
  /// Similarly, the server should apply a default value when not supplied.
  ///
  /// [dir] Optional (default `b`) direction to return events from. If this is set to `f`, events
  /// will be returned in chronological order starting at `from`. If it
  /// is set to `b`, events will be returned in *reverse* chronological
  /// order, again starting at `from`.
  Future<GetRelatingEventsWithRelTypeResponse> getRelatingEventsWithRelType(
      String roomId, String eventId, String relType,
      {String? from, String? to, int? limit, Direction? dir}) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v1/rooms/${Uri.encodeComponent(roomId)}/relations/${Uri.encodeComponent(eventId)}/${Uri.encodeComponent(relType)}',
        queryParameters: {
          if (from != null) 'from': from,
          if (to != null) 'to': to,
          if (limit != null) 'limit': limit.toString(),
          if (dir != null) 'dir': dir.name,
        });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return GetRelatingEventsWithRelTypeResponse.fromJson(
        json as Map<String, Object?>);
  }

  /// Retrieve all of the child events for a given parent event which relate to the parent
  /// using the given `relType` and have the given `eventType`.
  ///
  /// Note that when paginating the `from` token should be "after" the `to` token in
  /// terms of topological ordering, because it is only possible to paginate "backwards"
  /// through events, starting at `from`.
  ///
  /// For example, passing a `from` token from page 2 of the results, and a `to` token
  /// from page 1, would return the empty set. The caller can use a `from` token from
  /// page 1 and a `to` token from page 2 to paginate over the same range, however.
  ///
  /// [roomId] The ID of the room containing the parent event.
  ///
  /// [eventId] The ID of the parent event whose child events are to be returned.
  ///
  /// [relType] The [relationship type](https://spec.matrix.org/unstable/client-server-api/#relationship-types) to search for.
  ///
  /// [eventType] The event type of child events to search for.
  ///
  /// Note that in encrypted rooms this will typically always be `m.room.encrypted`
  /// regardless of the event type contained within the encrypted payload.
  ///
  /// [from] The pagination token to start returning results from. If not supplied, results
  /// start at the most recent topological event known to the server.
  ///
  /// Can be a `next_batch` or `prev_batch` token from a previous call, or a returned
  /// `start` token from [`/messages`](https://spec.matrix.org/unstable/client-server-api/#get_matrixclientv3roomsroomidmessages),
  /// or a `next_batch` token from [`/sync`](https://spec.matrix.org/unstable/client-server-api/#get_matrixclientv3sync).
  ///
  /// [to] The pagination token to stop returning results at. If not supplied, results
  /// continue up to `limit` or until there are no more events.
  ///
  /// Like `from`, this can be a previous token from a prior call to this endpoint
  /// or from `/messages` or `/sync`.
  ///
  /// [limit] The maximum number of results to return in a single `chunk`. The server can
  /// and should apply a maximum value to this parameter to avoid large responses.
  ///
  /// Similarly, the server should apply a default value when not supplied.
  ///
  /// [dir] Optional (default `b`) direction to return events from. If this is set to `f`, events
  /// will be returned in chronological order starting at `from`. If it
  /// is set to `b`, events will be returned in *reverse* chronological
  /// order, again starting at `from`.
  Future<GetRelatingEventsWithRelTypeAndEventTypeResponse>
      getRelatingEventsWithRelTypeAndEventType(
          String roomId, String eventId, String relType, String eventType,
          {String? from, String? to, int? limit, Direction? dir}) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v1/rooms/${Uri.encodeComponent(roomId)}/relations/${Uri.encodeComponent(eventId)}/${Uri.encodeComponent(relType)}/${Uri.encodeComponent(eventType)}',
        queryParameters: {
          if (from != null) 'from': from,
          if (to != null) 'to': to,
          if (limit != null) 'limit': limit.toString(),
          if (dir != null) 'dir': dir.name,
        });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return GetRelatingEventsWithRelTypeAndEventTypeResponse.fromJson(
        json as Map<String, Object?>);
  }

  /// Paginates over the thread roots in a room, ordered by the `latest_event` of each thread root
  /// in its bundle.
  ///
  /// [roomId] The room ID where the thread roots are located.
  ///
  /// [include] Optional (default `all`) flag to denote which thread roots are of interest to the caller.
  /// When `all`, all thread roots found in the room are returned. When `participated`, only
  /// thread roots for threads the user has [participated in](https://spec.matrix.org/unstable/client-server-api/#server-side-aggregation-of-mthread-relationships)
  /// will be returned.
  ///
  /// [limit] Optional limit for the maximum number of thread roots to include per response. Must be an integer
  /// greater than zero.
  ///
  /// Servers should apply a default value, and impose a maximum value to avoid resource exhaustion.
  ///
  /// [from] A pagination token from a previous result. When not provided, the server starts paginating from
  /// the most recent event visible to the user (as per history visibility rules; topologically).
  Future<GetThreadRootsResponse> getThreadRoots(String roomId,
      {Include? include, int? limit, String? from}) async {
    final requestUri = Uri(
        path: '_matrix/client/v1/rooms/${Uri.encodeComponent(roomId)}/threads',
        queryParameters: {
          if (include != null) 'include': include.name,
          if (limit != null) 'limit': limit.toString(),
          if (from != null) 'from': from,
        });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return GetThreadRootsResponse.fromJson(json as Map<String, Object?>);
  }

  /// Get the ID of the event closest to the given timestamp, in the
  /// direction specified by the `dir` parameter.
  ///
  /// If the server does not have all of the room history and does not have
  /// an event suitably close to the requested timestamp, it can use the
  /// corresponding [federation endpoint](https://spec.matrix.org/unstable/server-server-api/#get_matrixfederationv1timestamp_to_eventroomid)
  /// to ask other servers for a suitable event.
  ///
  /// After calling this endpoint, clients can call
  /// [`/rooms/{roomId}/context/{eventId}`](#get_matrixclientv3roomsroomidcontexteventid)
  /// to obtain a pagination token to retrieve the events around the returned event.
  ///
  /// The event returned by this endpoint could be an event that the client
  /// cannot render, and so may need to paginate in order to locate an event
  /// that it can display, which may end up being outside of the client's
  /// suitable range.  Clients can employ different strategies to display
  /// something reasonable to the user.  For example, the client could try
  /// paginating in one direction for a while, while looking at the
  /// timestamps of the events that it is paginating through, and if it
  /// exceeds a certain difference from the target timestamp, it can try
  /// paginating in the opposite direction.  The client could also simply
  /// paginate in one direction and inform the user that the closest event
  /// found in that direction is outside of the expected range.
  ///
  /// [roomId] The ID of the room to search
  ///
  /// [ts] The timestamp to search from, as given in milliseconds
  /// since the Unix epoch.
  ///
  /// [dir] The direction in which to search.  `f` for forwards, `b` for backwards.
  Future<GetEventByTimestampResponse> getEventByTimestamp(
      String roomId, int ts, Direction dir) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v1/rooms/${Uri.encodeComponent(roomId)}/timestamp_to_event',
        queryParameters: {
          'ts': ts.toString(),
          'dir': dir.name,
        });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return GetEventByTimestampResponse.fromJson(json as Map<String, Object?>);
  }

  /// Gets a list of the third party identifiers that the homeserver has
  /// associated with the user's account.
  ///
  /// This is *not* the same as the list of third party identifiers bound to
  /// the user's Matrix ID in identity servers.
  ///
  /// Identifiers in this list may be used by the homeserver as, for example,
  /// identifiers that it will accept to reset the user's account password.
  ///
  /// returns `threepids`:
  ///
  Future<List<ThirdPartyIdentifier>?> getAccount3PIDs() async {
    final requestUri = Uri(path: '_matrix/client/v3/account/3pid');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ((v) => v != null
        ? (v as List)
            .map(
                (v) => ThirdPartyIdentifier.fromJson(v as Map<String, Object?>))
            .toList()
        : null)(json['threepids']);
  }

  /// Adds contact information to the user's account.
  ///
  /// This endpoint is deprecated in favour of the more specific `/3pid/add`
  /// and `/3pid/bind` endpoints.
  ///
  /// **Note:**
  /// Previously this endpoint supported a `bind` parameter. This parameter
  /// has been removed, making this endpoint behave as though it was `false`.
  /// This results in this endpoint being an equivalent to `/3pid/bind` rather
  /// than dual-purpose.
  ///
  /// [threePidCreds] The third party credentials to associate with the account.
  ///
  /// returns `submit_url`:
  /// An optional field containing a URL where the client must
  /// submit the validation token to, with identical parameters
  /// to the Identity Service API's `POST
  /// /validate/email/submitToken` endpoint (without the requirement
  /// for an access token). The homeserver must send this token to the
  /// user (if applicable), who should then be prompted to provide it
  /// to the client.
  ///
  /// If this field is not present, the client can assume that
  /// verification will happen without the client's involvement
  /// provided the homeserver advertises this specification version
  /// in the `/versions` response (ie: r0.5.0).
  @deprecated
  Future<Uri?> post3PIDs(ThreePidCredentials threePidCreds) async {
    final requestUri = Uri(path: '_matrix/client/v3/account/3pid');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      'three_pid_creds': threePidCreds.toJson(),
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ((v) =>
        v != null ? Uri.parse(v as String) : null)(json['submit_url']);
  }

  /// This API endpoint uses the [User-Interactive Authentication API](https://spec.matrix.org/unstable/client-server-api/#user-interactive-authentication-api).
  ///
  /// Adds contact information to the user's account. Homeservers should use 3PIDs added
  /// through this endpoint for password resets instead of relying on the identity server.
  ///
  /// Homeservers should prevent the caller from adding a 3PID to their account if it has
  /// already been added to another user's account on the homeserver.
  ///
  /// [auth] Additional authentication information for the
  /// user-interactive authentication API.
  ///
  /// [clientSecret] The client secret used in the session with the homeserver.
  ///
  /// [sid] The session identifier given by the homeserver.
  Future<void> add3PID(String clientSecret, String sid,
      {AuthenticationData? auth}) async {
    final requestUri = Uri(path: '_matrix/client/v3/account/3pid/add');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (auth != null) 'auth': auth.toJson(),
      'client_secret': clientSecret,
      'sid': sid,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// Binds a 3PID to the user's account through the specified identity server.
  ///
  /// Homeservers should not prevent this request from succeeding if another user
  /// has bound the 3PID. Homeservers should simply proxy any errors received by
  /// the identity server to the caller.
  ///
  /// Homeservers should track successful binds so they can be unbound later.
  ///
  /// [clientSecret] The client secret used in the session with the identity server.
  ///
  /// [idAccessToken] An access token previously registered with the identity server.
  ///
  /// [idServer] The identity server to use.
  ///
  /// [sid] The session identifier given by the identity server.
  Future<void> bind3PID(String clientSecret, String idAccessToken,
      String idServer, String sid) async {
    final requestUri = Uri(path: '_matrix/client/v3/account/3pid/bind');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      'client_secret': clientSecret,
      'id_access_token': idAccessToken,
      'id_server': idServer,
      'sid': sid,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// Removes a third party identifier from the user's account. This might not
  /// cause an unbind of the identifier from the identity server.
  ///
  /// Unlike other endpoints, this endpoint does not take an `id_access_token`
  /// parameter because the homeserver is expected to sign the request to the
  /// identity server instead.
  ///
  /// [address] The third party address being removed.
  ///
  /// [idServer] The identity server to unbind from. If not provided, the homeserver
  /// MUST use the `id_server` the identifier was added through. If the
  /// homeserver does not know the original `id_server`, it MUST return
  /// a `id_server_unbind_result` of `no-support`.
  ///
  /// [medium] The medium of the third party identifier being removed.
  ///
  /// returns `id_server_unbind_result`:
  /// An indicator as to whether or not the homeserver was able to unbind
  /// the 3PID from the identity server. `success` indicates that the
  /// identity server has unbound the identifier whereas `no-support`
  /// indicates that the identity server refuses to support the request
  /// or the homeserver was not able to determine an identity server to
  /// unbind from.
  Future<IdServerUnbindResult> delete3pidFromAccount(
      String address, ThirdPartyIdentifierMedium medium,
      {String? idServer}) async {
    final requestUri = Uri(path: '_matrix/client/v3/account/3pid/delete');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      'address': address,
      if (idServer != null) 'id_server': idServer,
      'medium': medium.name,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return IdServerUnbindResult.values
        .fromString(json['id_server_unbind_result'] as String)!;
  }

  /// The homeserver must check that the given email address is **not**
  /// already associated with an account on this homeserver. This API should
  /// be used to request validation tokens when adding an email address to an
  /// account. This API's parameters and response are identical to that of
  /// the [`/register/email/requestToken`](https://spec.matrix.org/unstable/client-server-api/#post_matrixclientv3registeremailrequesttoken)
  /// endpoint. The homeserver should validate
  /// the email itself, either by sending a validation email itself or by using
  /// a service it has control over.
  ///
  /// [clientSecret] A unique string generated by the client, and used to identify the
  /// validation attempt. It must be a string consisting of the characters
  /// `[0-9a-zA-Z.=_-]`. Its length must not exceed 255 characters and it
  /// must not be empty.
  ///
  ///
  /// [email] The email address to validate.
  ///
  /// [nextLink] Optional. When the validation is completed, the identity server will
  /// redirect the user to this URL. This option is ignored when submitting
  /// 3PID validation information through a POST request.
  ///
  /// [sendAttempt] The server will only send an email if the `send_attempt`
  /// is a number greater than the most recent one which it has seen,
  /// scoped to that `email` + `client_secret` pair. This is to
  /// avoid repeatedly sending the same email in the case of request
  /// retries between the POSTing user and the identity server.
  /// The client should increment this value if they desire a new
  /// email (e.g. a reminder) to be sent. If they do not, the server
  /// should respond with success but not resend the email.
  ///
  /// [idAccessToken] An access token previously registered with the identity server. Servers
  /// can treat this as optional to distinguish between r0.5-compatible clients
  /// and this specification version.
  ///
  /// Required if an `id_server` is supplied.
  ///
  /// [idServer] The hostname of the identity server to communicate with. May optionally
  /// include a port. This parameter is ignored when the homeserver handles
  /// 3PID verification.
  ///
  /// This parameter is deprecated with a plan to be removed in a future specification
  /// version for `/account/password` and `/register` requests.
  Future<RequestTokenResponse> requestTokenTo3PIDEmail(
      String clientSecret, String email, int sendAttempt,
      {String? nextLink, String? idAccessToken, String? idServer}) async {
    final requestUri =
        Uri(path: '_matrix/client/v3/account/3pid/email/requestToken');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      'client_secret': clientSecret,
      'email': email,
      if (nextLink != null) 'next_link': nextLink,
      'send_attempt': sendAttempt,
      if (idAccessToken != null) 'id_access_token': idAccessToken,
      if (idServer != null) 'id_server': idServer,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return RequestTokenResponse.fromJson(json as Map<String, Object?>);
  }

  /// The homeserver must check that the given phone number is **not**
  /// already associated with an account on this homeserver. This API should
  /// be used to request validation tokens when adding a phone number to an
  /// account. This API's parameters and response are identical to that of
  /// the [`/register/msisdn/requestToken`](https://spec.matrix.org/unstable/client-server-api/#post_matrixclientv3registermsisdnrequesttoken)
  /// endpoint. The homeserver should validate
  /// the phone number itself, either by sending a validation message itself or by using
  /// a service it has control over.
  ///
  /// [clientSecret] A unique string generated by the client, and used to identify the
  /// validation attempt. It must be a string consisting of the characters
  /// `[0-9a-zA-Z.=_-]`. Its length must not exceed 255 characters and it
  /// must not be empty.
  ///
  ///
  /// [country] The two-letter uppercase ISO-3166-1 alpha-2 country code that the
  /// number in `phone_number` should be parsed as if it were dialled from.
  ///
  /// [nextLink] Optional. When the validation is completed, the identity server will
  /// redirect the user to this URL. This option is ignored when submitting
  /// 3PID validation information through a POST request.
  ///
  /// [phoneNumber] The phone number to validate.
  ///
  /// [sendAttempt] The server will only send an SMS if the `send_attempt` is a
  /// number greater than the most recent one which it has seen,
  /// scoped to that `country` + `phone_number` + `client_secret`
  /// triple. This is to avoid repeatedly sending the same SMS in
  /// the case of request retries between the POSTing user and the
  /// identity server. The client should increment this value if
  /// they desire a new SMS (e.g. a reminder) to be sent.
  ///
  /// [idAccessToken] An access token previously registered with the identity server. Servers
  /// can treat this as optional to distinguish between r0.5-compatible clients
  /// and this specification version.
  ///
  /// Required if an `id_server` is supplied.
  ///
  /// [idServer] The hostname of the identity server to communicate with. May optionally
  /// include a port. This parameter is ignored when the homeserver handles
  /// 3PID verification.
  ///
  /// This parameter is deprecated with a plan to be removed in a future specification
  /// version for `/account/password` and `/register` requests.
  Future<RequestTokenResponse> requestTokenTo3PIDMSISDN(
      String clientSecret, String country, String phoneNumber, int sendAttempt,
      {String? nextLink, String? idAccessToken, String? idServer}) async {
    final requestUri =
        Uri(path: '_matrix/client/v3/account/3pid/msisdn/requestToken');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      'client_secret': clientSecret,
      'country': country,
      if (nextLink != null) 'next_link': nextLink,
      'phone_number': phoneNumber,
      'send_attempt': sendAttempt,
      if (idAccessToken != null) 'id_access_token': idAccessToken,
      if (idServer != null) 'id_server': idServer,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return RequestTokenResponse.fromJson(json as Map<String, Object?>);
  }

  /// Removes a user's third party identifier from the provided identity server
  /// without removing it from the homeserver.
  ///
  /// Unlike other endpoints, this endpoint does not take an `id_access_token`
  /// parameter because the homeserver is expected to sign the request to the
  /// identity server instead.
  ///
  /// [address] The third party address being removed.
  ///
  /// [idServer] The identity server to unbind from. If not provided, the homeserver
  /// MUST use the `id_server` the identifier was added through. If the
  /// homeserver does not know the original `id_server`, it MUST return
  /// a `id_server_unbind_result` of `no-support`.
  ///
  /// [medium] The medium of the third party identifier being removed.
  ///
  /// returns `id_server_unbind_result`:
  /// An indicator as to whether or not the identity server was able to unbind
  /// the 3PID. `success` indicates that the identity server has unbound the
  /// identifier whereas `no-support` indicates that the identity server
  /// refuses to support the request or the homeserver was not able to determine
  /// an identity server to unbind from.
  Future<IdServerUnbindResult> unbind3pidFromAccount(
      String address, ThirdPartyIdentifierMedium medium,
      {String? idServer}) async {
    final requestUri = Uri(path: '_matrix/client/v3/account/3pid/unbind');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      'address': address,
      if (idServer != null) 'id_server': idServer,
      'medium': medium.name,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return IdServerUnbindResult.values
        .fromString(json['id_server_unbind_result'] as String)!;
  }

  /// Deactivate the user's account, removing all ability for the user to
  /// login again.
  ///
  /// This API endpoint uses the [User-Interactive Authentication API](https://spec.matrix.org/unstable/client-server-api/#user-interactive-authentication-api).
  ///
  /// An access token should be submitted to this endpoint if the client has
  /// an active session.
  ///
  /// The homeserver may change the flows available depending on whether a
  /// valid access token is provided.
  ///
  /// Unlike other endpoints, this endpoint does not take an `id_access_token`
  /// parameter because the homeserver is expected to sign the request to the
  /// identity server instead.
  ///
  /// [auth] Additional authentication information for the user-interactive authentication API.
  ///
  /// [idServer] The identity server to unbind all of the user's 3PIDs from.
  /// If not provided, the homeserver MUST use the `id_server`
  /// that was originally use to bind each identifier. If the
  /// homeserver does not know which `id_server` that was,
  /// it must return an `id_server_unbind_result` of
  /// `no-support`.
  ///
  /// returns `id_server_unbind_result`:
  /// An indicator as to whether or not the homeserver was able to unbind
  /// the user's 3PIDs from the identity server(s). `success` indicates
  /// that all identifiers have been unbound from the identity server while
  /// `no-support` indicates that one or more identifiers failed to unbind
  /// due to the identity server refusing the request or the homeserver
  /// being unable to determine an identity server to unbind from. This
  /// must be `success` if the homeserver has no identifiers to unbind
  /// for the user.
  Future<IdServerUnbindResult> deactivateAccount(
      {AuthenticationData? auth, String? idServer}) async {
    final requestUri = Uri(path: '_matrix/client/v3/account/deactivate');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (auth != null) 'auth': auth.toJson(),
      if (idServer != null) 'id_server': idServer,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return IdServerUnbindResult.values
        .fromString(json['id_server_unbind_result'] as String)!;
  }

  /// Changes the password for an account on this homeserver.
  ///
  /// This API endpoint uses the [User-Interactive Authentication API](https://spec.matrix.org/unstable/client-server-api/#user-interactive-authentication-api) to
  /// ensure the user changing the password is actually the owner of the
  /// account.
  ///
  /// An access token should be submitted to this endpoint if the client has
  /// an active session.
  ///
  /// The homeserver may change the flows available depending on whether a
  /// valid access token is provided. The homeserver SHOULD NOT revoke the
  /// access token provided in the request. Whether other access tokens for
  /// the user are revoked depends on the request parameters.
  ///
  /// [auth] Additional authentication information for the user-interactive authentication API.
  ///
  /// [logoutDevices] Whether the user's other access tokens, and their associated devices, should be
  /// revoked if the request succeeds. Defaults to true.
  ///
  /// When `false`, the server can still take advantage of the [soft logout method](https://spec.matrix.org/unstable/client-server-api/#soft-logout)
  /// for the user's remaining devices.
  ///
  /// [newPassword] The new password for the account.
  Future<void> changePassword(String newPassword,
      {AuthenticationData? auth, bool? logoutDevices}) async {
    final requestUri = Uri(path: '_matrix/client/v3/account/password');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (auth != null) 'auth': auth.toJson(),
      if (logoutDevices != null) 'logout_devices': logoutDevices,
      'new_password': newPassword,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// The homeserver must check that the given email address **is
  /// associated** with an account on this homeserver. This API should be
  /// used to request validation tokens when authenticating for the
  /// `/account/password` endpoint.
  ///
  /// This API's parameters and response are identical to that of the
  /// [`/register/email/requestToken`](https://spec.matrix.org/unstable/client-server-api/#post_matrixclientv3registeremailrequesttoken)
  /// endpoint, except that
  /// `M_THREEPID_NOT_FOUND` may be returned if no account matching the
  /// given email address could be found. The server may instead send an
  /// email to the given address prompting the user to create an account.
  /// `M_THREEPID_IN_USE` may not be returned.
  ///
  /// The homeserver should validate the email itself, either by sending a
  /// validation email itself or by using a service it has control over.
  ///
  /// [clientSecret] A unique string generated by the client, and used to identify the
  /// validation attempt. It must be a string consisting of the characters
  /// `[0-9a-zA-Z.=_-]`. Its length must not exceed 255 characters and it
  /// must not be empty.
  ///
  ///
  /// [email] The email address to validate.
  ///
  /// [nextLink] Optional. When the validation is completed, the identity server will
  /// redirect the user to this URL. This option is ignored when submitting
  /// 3PID validation information through a POST request.
  ///
  /// [sendAttempt] The server will only send an email if the `send_attempt`
  /// is a number greater than the most recent one which it has seen,
  /// scoped to that `email` + `client_secret` pair. This is to
  /// avoid repeatedly sending the same email in the case of request
  /// retries between the POSTing user and the identity server.
  /// The client should increment this value if they desire a new
  /// email (e.g. a reminder) to be sent. If they do not, the server
  /// should respond with success but not resend the email.
  ///
  /// [idAccessToken] An access token previously registered with the identity server. Servers
  /// can treat this as optional to distinguish between r0.5-compatible clients
  /// and this specification version.
  ///
  /// Required if an `id_server` is supplied.
  ///
  /// [idServer] The hostname of the identity server to communicate with. May optionally
  /// include a port. This parameter is ignored when the homeserver handles
  /// 3PID verification.
  ///
  /// This parameter is deprecated with a plan to be removed in a future specification
  /// version for `/account/password` and `/register` requests.
  Future<RequestTokenResponse> requestTokenToResetPasswordEmail(
      String clientSecret, String email, int sendAttempt,
      {String? nextLink, String? idAccessToken, String? idServer}) async {
    final requestUri =
        Uri(path: '_matrix/client/v3/account/password/email/requestToken');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      'client_secret': clientSecret,
      'email': email,
      if (nextLink != null) 'next_link': nextLink,
      'send_attempt': sendAttempt,
      if (idAccessToken != null) 'id_access_token': idAccessToken,
      if (idServer != null) 'id_server': idServer,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return RequestTokenResponse.fromJson(json as Map<String, Object?>);
  }

  /// The homeserver must check that the given phone number **is
  /// associated** with an account on this homeserver. This API should be
  /// used to request validation tokens when authenticating for the
  /// `/account/password` endpoint.
  ///
  /// This API's parameters and response are identical to that of the
  /// [`/register/msisdn/requestToken`](https://spec.matrix.org/unstable/client-server-api/#post_matrixclientv3registermsisdnrequesttoken)
  /// endpoint, except that
  /// `M_THREEPID_NOT_FOUND` may be returned if no account matching the
  /// given phone number could be found. The server may instead send the SMS
  /// to the given phone number prompting the user to create an account.
  /// `M_THREEPID_IN_USE` may not be returned.
  ///
  /// The homeserver should validate the phone number itself, either by sending a
  /// validation message itself or by using a service it has control over.
  ///
  /// [clientSecret] A unique string generated by the client, and used to identify the
  /// validation attempt. It must be a string consisting of the characters
  /// `[0-9a-zA-Z.=_-]`. Its length must not exceed 255 characters and it
  /// must not be empty.
  ///
  ///
  /// [country] The two-letter uppercase ISO-3166-1 alpha-2 country code that the
  /// number in `phone_number` should be parsed as if it were dialled from.
  ///
  /// [nextLink] Optional. When the validation is completed, the identity server will
  /// redirect the user to this URL. This option is ignored when submitting
  /// 3PID validation information through a POST request.
  ///
  /// [phoneNumber] The phone number to validate.
  ///
  /// [sendAttempt] The server will only send an SMS if the `send_attempt` is a
  /// number greater than the most recent one which it has seen,
  /// scoped to that `country` + `phone_number` + `client_secret`
  /// triple. This is to avoid repeatedly sending the same SMS in
  /// the case of request retries between the POSTing user and the
  /// identity server. The client should increment this value if
  /// they desire a new SMS (e.g. a reminder) to be sent.
  ///
  /// [idAccessToken] An access token previously registered with the identity server. Servers
  /// can treat this as optional to distinguish between r0.5-compatible clients
  /// and this specification version.
  ///
  /// Required if an `id_server` is supplied.
  ///
  /// [idServer] The hostname of the identity server to communicate with. May optionally
  /// include a port. This parameter is ignored when the homeserver handles
  /// 3PID verification.
  ///
  /// This parameter is deprecated with a plan to be removed in a future specification
  /// version for `/account/password` and `/register` requests.
  Future<RequestTokenResponse> requestTokenToResetPasswordMSISDN(
      String clientSecret, String country, String phoneNumber, int sendAttempt,
      {String? nextLink, String? idAccessToken, String? idServer}) async {
    final requestUri =
        Uri(path: '_matrix/client/v3/account/password/msisdn/requestToken');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      'client_secret': clientSecret,
      'country': country,
      if (nextLink != null) 'next_link': nextLink,
      'phone_number': phoneNumber,
      'send_attempt': sendAttempt,
      if (idAccessToken != null) 'id_access_token': idAccessToken,
      if (idServer != null) 'id_server': idServer,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return RequestTokenResponse.fromJson(json as Map<String, Object?>);
  }

  /// Gets information about the owner of a given access token.
  ///
  /// Note that, as with the rest of the Client-Server API,
  /// Application Services may masquerade as users within their
  /// namespace by giving a `user_id` query parameter. In this
  /// situation, the server should verify that the given `user_id`
  /// is registered by the appservice, and return it in the response
  /// body.
  Future<TokenOwnerInfo> getTokenOwner() async {
    final requestUri = Uri(path: '_matrix/client/v3/account/whoami');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return TokenOwnerInfo.fromJson(json as Map<String, Object?>);
  }

  /// Gets information about a particular user.
  ///
  /// This API may be restricted to only be called by the user being looked
  /// up, or by a server admin. Server-local administrator privileges are not
  /// specified in this document.
  ///
  /// [userId] The user to look up.
  Future<WhoIsInfo> getWhoIs(String userId) async {
    final requestUri = Uri(
        path: '_matrix/client/v3/admin/whois/${Uri.encodeComponent(userId)}');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return WhoIsInfo.fromJson(json as Map<String, Object?>);
  }

  /// Gets information about the server's supported feature set
  /// and other relevant capabilities.
  ///
  /// returns `capabilities`:
  /// The custom capabilities the server supports, using the
  /// Java package naming convention.
  Future<Capabilities> getCapabilities() async {
    final requestUri = Uri(path: '_matrix/client/v3/capabilities');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return Capabilities.fromJson(json['capabilities'] as Map<String, Object?>);
  }

  /// Create a new room with various configuration options.
  ///
  /// The server MUST apply the normal state resolution rules when creating
  /// the new room, including checking power levels for each event. It MUST
  /// apply the events implied by the request in the following order:
  ///
  /// 1. The `m.room.create` event itself. Must be the first event in the
  ///    room.
  ///
  /// 2. An `m.room.member` event for the creator to join the room. This is
  ///    needed so the remaining events can be sent.
  ///
  /// 3. A default `m.room.power_levels` event, giving the room creator
  ///    (and not other members) permission to send state events. Overridden
  ///    by the `power_level_content_override` parameter.
  ///
  /// 4. An `m.room.canonical_alias` event if `room_alias_name` is given.
  ///
  /// 5. Events set by the `preset`. Currently these are the `m.room.join_rules`,
  ///    `m.room.history_visibility`, and `m.room.guest_access` state events.
  ///
  /// 6. Events listed in `initial_state`, in the order that they are
  ///    listed.
  ///
  /// 7. Events implied by `name` and `topic` (`m.room.name` and `m.room.topic`
  ///    state events).
  ///
  /// 8. Invite events implied by `invite` and `invite_3pid` (`m.room.member` with
  ///    `membership: invite` and `m.room.third_party_invite`).
  ///
  /// The available presets do the following with respect to room state:
  ///
  /// | Preset                 | `join_rules` | `history_visibility` | `guest_access` | Other |
  /// |------------------------|--------------|----------------------|----------------|-------|
  /// | `private_chat`         | `invite`     | `shared`             | `can_join`     |       |
  /// | `trusted_private_chat` | `invite`     | `shared`             | `can_join`     | All invitees are given the same power level as the room creator. |
  /// | `public_chat`          | `public`     | `shared`             | `forbidden`    |       |
  ///
  /// The server will create a `m.room.create` event in the room with the
  /// requesting user as the creator, alongside other keys provided in the
  /// `creation_content`.
  ///
  /// [creationContent] Extra keys, such as `m.federate`, to be added to the content
  /// of the [`m.room.create`](https://spec.matrix.org/unstable/client-server-api/#mroomcreate) event. The server will overwrite the following
  /// keys: `creator`, `room_version`. Future versions of the specification
  /// may allow the server to overwrite other keys.
  ///
  /// [initialState] A list of state events to set in the new room. This allows
  /// the user to override the default state events set in the new
  /// room. The expected format of the state events are an object
  /// with type, state_key and content keys set.
  ///
  /// Takes precedence over events set by `preset`, but gets
  /// overridden by `name` and `topic` keys.
  ///
  /// [invite] A list of user IDs to invite to the room. This will tell the
  /// server to invite everyone in the list to the newly created room.
  ///
  /// [invite3pid] A list of objects representing third party IDs to invite into
  /// the room.
  ///
  /// [isDirect] This flag makes the server set the `is_direct` flag on the
  /// `m.room.member` events sent to the users in `invite` and
  /// `invite_3pid`. See [Direct Messaging](https://spec.matrix.org/unstable/client-server-api/#direct-messaging) for more information.
  ///
  /// [name] If this is included, an `m.room.name` event will be sent
  /// into the room to indicate the name of the room. See Room
  /// Events for more information on `m.room.name`.
  ///
  /// [powerLevelContentOverride] The power level content to override in the default power level
  /// event. This object is applied on top of the generated
  /// [`m.room.power_levels`](https://spec.matrix.org/unstable/client-server-api/#mroompower_levels)
  /// event content prior to it being sent to the room. Defaults to
  /// overriding nothing.
  ///
  /// [preset] Convenience parameter for setting various default state events
  /// based on a preset.
  ///
  /// If unspecified, the server should use the `visibility` to determine
  /// which preset to use. A visbility of `public` equates to a preset of
  /// `public_chat` and `private` visibility equates to a preset of
  /// `private_chat`.
  ///
  /// [roomAliasName] The desired room alias **local part**. If this is included, a
  /// room alias will be created and mapped to the newly created
  /// room. The alias will belong on the *same* homeserver which
  /// created the room. For example, if this was set to "foo" and
  /// sent to the homeserver "example.com" the complete room alias
  /// would be `#foo:example.com`.
  ///
  /// The complete room alias will become the canonical alias for
  /// the room and an `m.room.canonical_alias` event will be sent
  /// into the room.
  ///
  /// [roomVersion] The room version to set for the room. If not provided, the homeserver is
  /// to use its configured default. If provided, the homeserver will return a
  /// 400 error with the errcode `M_UNSUPPORTED_ROOM_VERSION` if it does not
  /// support the room version.
  ///
  /// [topic] If this is included, an `m.room.topic` event will be sent
  /// into the room to indicate the topic for the room. See Room
  /// Events for more information on `m.room.topic`.
  ///
  /// [visibility] A `public` visibility indicates that the room will be shown
  /// in the published room list. A `private` visibility will hide
  /// the room from the published room list. Rooms default to
  /// `private` visibility if this key is not included. NB: This
  /// should not be confused with `join_rules` which also uses the
  /// word `public`.
  ///
  /// returns `room_id`:
  /// The created room's ID.
  Future<String> createRoom(
      {Map<String, Object?>? creationContent,
      List<StateEvent>? initialState,
      List<String>? invite,
      List<Invite3pid>? invite3pid,
      bool? isDirect,
      String? name,
      Map<String, Object?>? powerLevelContentOverride,
      CreateRoomPreset? preset,
      String? roomAliasName,
      String? roomVersion,
      String? topic,
      Visibility? visibility}) async {
    final requestUri = Uri(path: '_matrix/client/v3/createRoom');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (creationContent != null) 'creation_content': creationContent,
      if (initialState != null)
        'initial_state': initialState.map((v) => v.toJson()).toList(),
      if (invite != null) 'invite': invite.map((v) => v).toList(),
      if (invite3pid != null)
        'invite_3pid': invite3pid.map((v) => v.toJson()).toList(),
      if (isDirect != null) 'is_direct': isDirect,
      if (name != null) 'name': name,
      if (powerLevelContentOverride != null)
        'power_level_content_override': powerLevelContentOverride,
      if (preset != null) 'preset': preset.name,
      if (roomAliasName != null) 'room_alias_name': roomAliasName,
      if (roomVersion != null) 'room_version': roomVersion,
      if (topic != null) 'topic': topic,
      if (visibility != null) 'visibility': visibility.name,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return json['room_id'] as String;
  }

  /// This API endpoint uses the [User-Interactive Authentication API](https://spec.matrix.org/unstable/client-server-api/#user-interactive-authentication-api).
  ///
  /// Deletes the given devices, and invalidates any access token associated with them.
  ///
  /// [auth] Additional authentication information for the
  /// user-interactive authentication API.
  ///
  /// [devices] The list of device IDs to delete.
  Future<void> deleteDevices(List<String> devices,
      {AuthenticationData? auth}) async {
    final requestUri = Uri(path: '_matrix/client/v3/delete_devices');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (auth != null) 'auth': auth.toJson(),
      'devices': devices.map((v) => v).toList(),
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// Gets information about all devices for the current user.
  ///
  /// returns `devices`:
  /// A list of all registered devices for this user.
  Future<List<Device>?> getDevices() async {
    final requestUri = Uri(path: '_matrix/client/v3/devices');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ((v) => v != null
        ? (v as List)
            .map((v) => Device.fromJson(v as Map<String, Object?>))
            .toList()
        : null)(json['devices']);
  }

  /// This API endpoint uses the [User-Interactive Authentication API](https://spec.matrix.org/unstable/client-server-api/#user-interactive-authentication-api).
  ///
  /// Deletes the given device, and invalidates any access token associated with it.
  ///
  /// [deviceId] The device to delete.
  ///
  /// [auth] Additional authentication information for the
  /// user-interactive authentication API.
  Future<void> deleteDevice(String deviceId, {AuthenticationData? auth}) async {
    final requestUri =
        Uri(path: '_matrix/client/v3/devices/${Uri.encodeComponent(deviceId)}');
    final request = Request('DELETE', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (auth != null) 'auth': auth.toJson(),
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// Gets information on a single device, by device id.
  ///
  /// [deviceId] The device to retrieve.
  Future<Device> getDevice(String deviceId) async {
    final requestUri =
        Uri(path: '_matrix/client/v3/devices/${Uri.encodeComponent(deviceId)}');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return Device.fromJson(json as Map<String, Object?>);
  }

  /// Updates the metadata on the given device.
  ///
  /// [deviceId] The device to update.
  ///
  /// [displayName] The new display name for this device. If not given, the
  /// display name is unchanged.
  Future<void> updateDevice(String deviceId, {String? displayName}) async {
    final requestUri =
        Uri(path: '_matrix/client/v3/devices/${Uri.encodeComponent(deviceId)}');
    final request = Request('PUT', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (displayName != null) 'display_name': displayName,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// Updates the visibility of a given room on the application service's room
  /// directory.
  ///
  /// This API is similar to the room directory visibility API used by clients
  /// to update the homeserver's more general room directory.
  ///
  /// This API requires the use of an application service access token (`as_token`)
  /// instead of a typical client's access_token. This API cannot be invoked by
  /// users who are not identified as application services.
  ///
  /// [networkId] The protocol (network) ID to update the room list for. This would
  /// have been provided by the application service as being listed as
  /// a supported protocol.
  ///
  /// [roomId] The room ID to add to the directory.
  ///
  /// [visibility] Whether the room should be visible (public) in the directory
  /// or not (private).
  Future<Map<String, Object?>> updateAppserviceRoomDirectoryVisibility(
      String networkId, String roomId, Visibility visibility) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/directory/list/appservice/${Uri.encodeComponent(networkId)}/${Uri.encodeComponent(roomId)}');
    final request = Request('PUT', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      'visibility': visibility.name,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return json as Map<String, Object?>;
  }

  /// Gets the visibility of a given room on the server's public room directory.
  ///
  /// [roomId] The room ID.
  ///
  /// returns `visibility`:
  /// The visibility of the room in the directory.
  Future<Visibility?> getRoomVisibilityOnDirectory(String roomId) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/directory/list/room/${Uri.encodeComponent(roomId)}');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ((v) => v != null
        ? Visibility.values.fromString(v as String)!
        : null)(json['visibility']);
  }

  /// Sets the visibility of a given room in the server's public room
  /// directory.
  ///
  /// Servers may choose to implement additional access control checks
  /// here, for instance that room visibility can only be changed by
  /// the room creator or a server administrator.
  ///
  /// [roomId] The room ID.
  ///
  /// [visibility] The new visibility setting for the room.
  /// Defaults to 'public'.
  Future<void> setRoomVisibilityOnDirectory(String roomId,
      {Visibility? visibility}) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/directory/list/room/${Uri.encodeComponent(roomId)}');
    final request = Request('PUT', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (visibility != null) 'visibility': visibility.name,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// Remove a mapping of room alias to room ID.
  ///
  /// Servers may choose to implement additional access control checks here, for instance that
  /// room aliases can only be deleted by their creator or a server administrator.
  ///
  /// **Note:**
  /// Servers may choose to update the `alt_aliases` for the `m.room.canonical_alias`
  /// state event in the room when an alias is removed. Servers which choose to update the
  /// canonical alias event are recommended to, in addition to their other relevant permission
  /// checks, delete the alias and return a successful response even if the user does not
  /// have permission to update the `m.room.canonical_alias` event.
  ///
  /// [roomAlias] The room alias to remove. Its format is defined
  /// [in the appendices](https://spec.matrix.org/unstable/appendices/#room-aliases).
  ///
  Future<void> deleteRoomAlias(String roomAlias) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/directory/room/${Uri.encodeComponent(roomAlias)}');
    final request = Request('DELETE', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// Requests that the server resolve a room alias to a room ID.
  ///
  /// The server will use the federation API to resolve the alias if the
  /// domain part of the alias does not correspond to the server's own
  /// domain.
  ///
  /// [roomAlias] The room alias. Its format is defined
  /// [in the appendices](https://spec.matrix.org/unstable/appendices/#room-aliases).
  ///
  Future<GetRoomIdByAliasResponse> getRoomIdByAlias(String roomAlias) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/directory/room/${Uri.encodeComponent(roomAlias)}');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return GetRoomIdByAliasResponse.fromJson(json as Map<String, Object?>);
  }

  ///
  ///
  /// [roomAlias] The room alias to set. Its format is defined
  /// [in the appendices](https://spec.matrix.org/unstable/appendices/#room-aliases).
  ///
  ///
  /// [roomId] The room ID to set.
  Future<void> setRoomAlias(String roomAlias, String roomId) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/directory/room/${Uri.encodeComponent(roomAlias)}');
    final request = Request('PUT', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      'room_id': roomId,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// This will listen for new events and return them to the caller. This will
  /// block until an event is received, or until the `timeout` is reached.
  ///
  /// This endpoint was deprecated in r0 of this specification. Clients
  /// should instead call the [`/sync`](https://spec.matrix.org/unstable/client-server-api/#get_matrixclientv3sync)
  /// endpoint with a `since` parameter. See
  /// the [migration guide](https://matrix.org/docs/guides/migrating-from-client-server-api-v-1#deprecated-endpoints).
  ///
  /// [from] The token to stream from. This token is either from a previous
  /// request to this API or from the initial sync API.
  ///
  /// [timeout] The maximum time in milliseconds to wait for an event.
  @deprecated
  Future<GetEventsResponse> getEvents({String? from, int? timeout}) async {
    final requestUri = Uri(path: '_matrix/client/v3/events', queryParameters: {
      if (from != null) 'from': from,
      if (timeout != null) 'timeout': timeout.toString(),
    });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return GetEventsResponse.fromJson(json as Map<String, Object?>);
  }

  /// This will listen for new events related to a particular room and return
  /// them to the caller. This will block until an event is received, or until
  /// the `timeout` is reached.
  ///
  /// This API is the same as the normal `/events` endpoint, but can be
  /// called by users who have not joined the room.
  ///
  /// Note that the normal `/events` endpoint has been deprecated. This
  /// API will also be deprecated at some point, but its replacement is not
  /// yet known.
  ///
  /// [from] The token to stream from. This token is either from a previous
  /// request to this API or from the initial sync API.
  ///
  /// [timeout] The maximum time in milliseconds to wait for an event.
  ///
  /// [roomId] The room ID for which events should be returned.
  Future<PeekEventsResponse> peekEvents(
      {String? from, int? timeout, String? roomId}) async {
    final requestUri = Uri(path: '_matrix/client/v3/events', queryParameters: {
      if (from != null) 'from': from,
      if (timeout != null) 'timeout': timeout.toString(),
      if (roomId != null) 'room_id': roomId,
    });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return PeekEventsResponse.fromJson(json as Map<String, Object?>);
  }

  /// Get a single event based on `event_id`. You must have permission to
  /// retrieve this event e.g. by being a member in the room for this event.
  ///
  /// This endpoint was deprecated in r0 of this specification. Clients
  /// should instead call the
  /// [/rooms/{roomId}/event/{eventId}](https://spec.matrix.org/unstable/client-server-api/#get_matrixclientv3roomsroomideventeventid) API
  /// or the [/rooms/{roomId}/context/{eventId](https://spec.matrix.org/unstable/client-server-api/#get_matrixclientv3roomsroomidcontexteventid) API.
  ///
  /// [eventId] The event ID to get.
  @deprecated
  Future<MatrixEvent> getOneEvent(String eventId) async {
    final requestUri =
        Uri(path: '_matrix/client/v3/events/${Uri.encodeComponent(eventId)}');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return MatrixEvent.fromJson(json as Map<String, Object?>);
  }

  /// *Note that this API takes either a room ID or alias, unlike* `/rooms/{roomId}/join`.
  ///
  /// This API starts a user participating in a particular room, if that user
  /// is allowed to participate in that room. After this call, the client is
  /// allowed to see all current state events in the room, and all subsequent
  /// events associated with the room until the user leaves the room.
  ///
  /// After a user has joined a room, the room will appear as an entry in the
  /// response of the [`/initialSync`](https://spec.matrix.org/unstable/client-server-api/#get_matrixclientv3initialsync)
  /// and [`/sync`](https://spec.matrix.org/unstable/client-server-api/#get_matrixclientv3sync) APIs.
  ///
  /// [roomIdOrAlias] The room identifier or alias to join.
  ///
  /// [serverName] The servers to attempt to join the room through. One of the servers
  /// must be participating in the room.
  ///
  /// [reason] Optional reason to be included as the `reason` on the subsequent
  /// membership event.
  ///
  /// [thirdPartySigned] If a `third_party_signed` was supplied, the homeserver must verify
  /// that it matches a pending `m.room.third_party_invite` event in the
  /// room, and perform key validity checking if required by the event.
  ///
  /// returns `room_id`:
  /// The joined room ID.
  Future<String> joinRoom(String roomIdOrAlias,
      {List<String>? serverName,
      String? reason,
      ThirdPartySigned? thirdPartySigned}) async {
    final requestUri = Uri(
        path: '_matrix/client/v3/join/${Uri.encodeComponent(roomIdOrAlias)}',
        queryParameters: {
          if (serverName != null)
            'server_name': serverName.map((v) => v).toList(),
        });
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (reason != null) 'reason': reason,
      if (thirdPartySigned != null)
        'third_party_signed': thirdPartySigned.toJson(),
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return json['room_id'] as String;
  }

  /// This API returns a list of the user's current rooms.
  ///
  /// returns `joined_rooms`:
  /// The ID of each room in which the user has `joined` membership.
  Future<List<String>> getJoinedRooms() async {
    final requestUri = Uri(path: '_matrix/client/v3/joined_rooms');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return (json['joined_rooms'] as List).map((v) => v as String).toList();
  }

  /// Gets a list of users who have updated their device identity keys since a
  /// previous sync token.
  ///
  /// The server should include in the results any users who:
  ///
  /// * currently share a room with the calling user (ie, both users have
  ///   membership state `join`); *and*
  /// * added new device identity keys or removed an existing device with
  ///   identity keys, between `from` and `to`.
  ///
  /// [from] The desired start point of the list. Should be the `next_batch` field
  /// from a response to an earlier call to [`/sync`](https://spec.matrix.org/unstable/client-server-api/#get_matrixclientv3sync). Users who have not
  /// uploaded new device identity keys since this point, nor deleted
  /// existing devices with identity keys since then, will be excluded
  /// from the results.
  ///
  /// [to] The desired end point of the list. Should be the `next_batch`
  /// field from a recent call to [`/sync`](https://spec.matrix.org/unstable/client-server-api/#get_matrixclientv3sync) - typically the most recent
  /// such call. This may be used by the server as a hint to check its
  /// caches are up to date.
  Future<GetKeysChangesResponse> getKeysChanges(String from, String to) async {
    final requestUri =
        Uri(path: '_matrix/client/v3/keys/changes', queryParameters: {
      'from': from,
      'to': to,
    });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return GetKeysChangesResponse.fromJson(json as Map<String, Object?>);
  }

  /// Claims one-time keys for use in pre-key messages.
  ///
  /// [oneTimeKeys] The keys to be claimed. A map from user ID, to a map from
  /// device ID to algorithm name.
  ///
  /// [timeout] The time (in milliseconds) to wait when downloading keys from
  /// remote servers. 10 seconds is the recommended default.
  Future<ClaimKeysResponse> claimKeys(
      Map<String, Map<String, String>> oneTimeKeys,
      {int? timeout}) async {
    final requestUri = Uri(path: '_matrix/client/v3/keys/claim');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      'one_time_keys': oneTimeKeys
          .map((k, v) => MapEntry(k, v.map((k, v) => MapEntry(k, v)))),
      if (timeout != null) 'timeout': timeout,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ClaimKeysResponse.fromJson(json as Map<String, Object?>);
  }

  /// Publishes cross-signing keys for the user.
  ///
  /// This API endpoint uses the [User-Interactive Authentication API](https://spec.matrix.org/unstable/client-server-api/#user-interactive-authentication-api).
  ///
  /// [auth] Additional authentication information for the
  /// user-interactive authentication API.
  ///
  /// [masterKey] Optional. The user\'s master key.
  ///
  /// [selfSigningKey] Optional. The user\'s self-signing key. Must be signed by
  /// the accompanying master key, or by the user\'s most recently
  /// uploaded master key if no master key is included in the
  /// request.
  ///
  /// [userSigningKey] Optional. The user\'s user-signing key. Must be signed by
  /// the accompanying master key, or by the user\'s most recently
  /// uploaded master key if no master key is included in the
  /// request.
  Future<void> uploadCrossSigningKeys(
      {AuthenticationData? auth,
      MatrixCrossSigningKey? masterKey,
      MatrixCrossSigningKey? selfSigningKey,
      MatrixCrossSigningKey? userSigningKey}) async {
    final requestUri =
        Uri(path: '_matrix/client/v3/keys/device_signing/upload');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (auth != null) 'auth': auth.toJson(),
      if (masterKey != null) 'master_key': masterKey.toJson(),
      if (selfSigningKey != null) 'self_signing_key': selfSigningKey.toJson(),
      if (userSigningKey != null) 'user_signing_key': userSigningKey.toJson(),
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// Returns the current devices and identity keys for the given users.
  ///
  /// [deviceKeys] The keys to be downloaded. A map from user ID, to a list of
  /// device IDs, or to an empty list to indicate all devices for the
  /// corresponding user.
  ///
  /// [timeout] The time (in milliseconds) to wait when downloading keys from
  /// remote servers. 10 seconds is the recommended default.
  ///
  /// [token] If the client is fetching keys as a result of a device update received
  /// in a sync request, this should be the 'since' token of that sync request,
  /// or any later sync token. This allows the server to ensure its response
  /// contains the keys advertised by the notification in that sync.
  Future<QueryKeysResponse> queryKeys(Map<String, List<String>> deviceKeys,
      {int? timeout, String? token}) async {
    final requestUri = Uri(path: '_matrix/client/v3/keys/query');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      'device_keys':
          deviceKeys.map((k, v) => MapEntry(k, v.map((v) => v).toList())),
      if (timeout != null) 'timeout': timeout,
      if (token != null) 'token': token,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return QueryKeysResponse.fromJson(json as Map<String, Object?>);
  }

  /// Publishes cross-signing signatures for the user.  The request body is a
  /// map from user ID to key ID to signed JSON object.
  ///
  /// [signatures] The signatures to be published.
  ///
  /// returns `failures`:
  /// A map from user ID to key ID to an error for any signatures
  /// that failed.  If a signature was invalid, the `errcode` will
  /// be set to `M_INVALID_SIGNATURE`.
  Future<Map<String, Map<String, Map<String, Object?>>>?>
      uploadCrossSigningSignatures(
          Map<String, Map<String, Map<String, Object?>>> signatures) async {
    final requestUri = Uri(path: '_matrix/client/v3/keys/signatures/upload');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode(signatures
        .map((k, v) => MapEntry(k, v.map((k, v) => MapEntry(k, v))))));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ((v) => v != null
        ? (v as Map<String, Object?>).map((k, v) => MapEntry(
            k,
            (v as Map<String, Object?>)
                .map((k, v) => MapEntry(k, v as Map<String, Object?>))))
        : null)(json['failures']);
  }

  /// *Note that this API takes either a room ID or alias, unlike other membership APIs.*
  ///
  /// This API "knocks" on the room to ask for permission to join, if the user
  /// is allowed to knock on the room. Acceptance of the knock happens out of
  /// band from this API, meaning that the client will have to watch for updates
  /// regarding the acceptance/rejection of the knock.
  ///
  /// If the room history settings allow, the user will still be able to see
  /// history of the room while being in the "knock" state. The user will have
  /// to accept the invitation to join the room (acceptance of knock) to see
  /// messages reliably. See the `/join` endpoints for more information about
  /// history visibility to the user.
  ///
  /// The knock will appear as an entry in the response of the
  /// [`/sync`](https://spec.matrix.org/unstable/client-server-api/#get_matrixclientv3sync) API.
  ///
  /// [roomIdOrAlias] The room identifier or alias to knock upon.
  ///
  /// [serverName] The servers to attempt to knock on the room through. One of the servers
  /// must be participating in the room.
  ///
  /// [reason] Optional reason to be included as the `reason` on the subsequent
  /// membership event.
  ///
  /// returns `room_id`:
  /// The knocked room ID.
  Future<String> knockRoom(String roomIdOrAlias,
      {List<String>? serverName, String? reason}) async {
    final requestUri = Uri(
        path: '_matrix/client/v3/knock/${Uri.encodeComponent(roomIdOrAlias)}',
        queryParameters: {
          if (serverName != null)
            'server_name': serverName.map((v) => v).toList(),
        });
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (reason != null) 'reason': reason,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return json['room_id'] as String;
  }

  /// Gets the homeserver's supported login types to authenticate users. Clients
  /// should pick one of these and supply it as the `type` when logging in.
  ///
  /// returns `flows`:
  /// The homeserver's supported login types
  Future<List<LoginFlow>?> getLoginFlows() async {
    final requestUri = Uri(path: '_matrix/client/v3/login');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ((v) => v != null
        ? (v as List)
            .map((v) => LoginFlow.fromJson(v as Map<String, Object?>))
            .toList()
        : null)(json['flows']);
  }

  /// Authenticates the user, and issues an access token they can
  /// use to authorize themself in subsequent requests.
  ///
  /// If the client does not supply a `device_id`, the server must
  /// auto-generate one.
  ///
  /// The returned access token must be associated with the `device_id`
  /// supplied by the client or generated by the server. The server may
  /// invalidate any access token previously associated with that device. See
  /// [Relationship between access tokens and devices](https://spec.matrix.org/unstable/client-server-api/#relationship-between-access-tokens-and-devices).
  ///
  /// [address] Third party identifier for the user.  Deprecated in favour of `identifier`.
  ///
  /// [deviceId] ID of the client device. If this does not correspond to a
  /// known client device, a new device will be created. The given
  /// device ID must not be the same as a
  /// [cross-signing](https://spec.matrix.org/unstable/client-server-api/#cross-signing) key ID.
  /// The server will auto-generate a device_id
  /// if this is not specified.
  ///
  /// [identifier] Identification information for a user
  ///
  /// [initialDeviceDisplayName] A display name to assign to the newly-created device. Ignored
  /// if `device_id` corresponds to a known device.
  ///
  /// [medium] When logging in using a third party identifier, the medium of the identifier. Must be 'email'.  Deprecated in favour of `identifier`.
  ///
  /// [password] Required when `type` is `m.login.password`. The user's
  /// password.
  ///
  /// [refreshToken] If true, the client supports refresh tokens.
  ///
  /// [token] Required when `type` is `m.login.token`. Part of Token-based login.
  ///
  /// [type] The login type being used.
  ///
  /// [user] The fully qualified user ID or just local part of the user ID, to log in.  Deprecated in favour of `identifier`.
  Future<LoginResponse> login(LoginType type,
      {String? address,
      String? deviceId,
      AuthenticationIdentifier? identifier,
      String? initialDeviceDisplayName,
      String? medium,
      String? password,
      bool? refreshToken,
      String? token,
      String? user}) async {
    final requestUri = Uri(path: '_matrix/client/v3/login');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (address != null) 'address': address,
      if (deviceId != null) 'device_id': deviceId,
      if (identifier != null) 'identifier': identifier.toJson(),
      if (initialDeviceDisplayName != null)
        'initial_device_display_name': initialDeviceDisplayName,
      if (medium != null) 'medium': medium,
      if (password != null) 'password': password,
      if (refreshToken != null) 'refresh_token': refreshToken,
      if (token != null) 'token': token,
      'type': type.name,
      if (user != null) 'user': user,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return LoginResponse.fromJson(json as Map<String, Object?>);
  }

  /// Invalidates an existing access token, so that it can no longer be used for
  /// authorization. The device associated with the access token is also deleted.
  /// [Device keys](https://spec.matrix.org/unstable/client-server-api/#device-keys) for the device are deleted alongside the device.
  Future<void> logout() async {
    final requestUri = Uri(path: '_matrix/client/v3/logout');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// Invalidates all access tokens for a user, so that they can no longer be used for
  /// authorization. This includes the access token that made this request. All devices
  /// for the user are also deleted. [Device keys](https://spec.matrix.org/unstable/client-server-api/#device-keys) for the device are
  /// deleted alongside the device.
  ///
  /// This endpoint does not use the [User-Interactive Authentication API](https://spec.matrix.org/unstable/client-server-api/#user-interactive-authentication-api) because
  /// User-Interactive Authentication is designed to protect against attacks where the
  /// someone gets hold of a single access token then takes over the account. This
  /// endpoint invalidates all access tokens for the user, including the token used in
  /// the request, and therefore the attacker is unable to take over the account in
  /// this way.
  Future<void> logoutAll() async {
    final requestUri = Uri(path: '_matrix/client/v3/logout/all');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// This API is used to paginate through the list of events that the
  /// user has been, or would have been notified about.
  ///
  /// [from] Pagination token to continue from. This should be the `next_token`
  /// returned from an earlier call to this endpoint.
  ///
  /// [limit] Limit on the number of events to return in this request.
  ///
  /// [only] Allows basic filtering of events returned. Supply `highlight`
  /// to return only events where the notification had the highlight
  /// tweak set.
  Future<GetNotificationsResponse> getNotifications(
      {String? from, int? limit, String? only}) async {
    final requestUri =
        Uri(path: '_matrix/client/v3/notifications', queryParameters: {
      if (from != null) 'from': from,
      if (limit != null) 'limit': limit.toString(),
      if (only != null) 'only': only,
    });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return GetNotificationsResponse.fromJson(json as Map<String, Object?>);
  }

  /// Get the given user's presence state.
  ///
  /// [userId] The user whose presence state to get.
  Future<GetPresenceResponse> getPresence(String userId) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/presence/${Uri.encodeComponent(userId)}/status');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return GetPresenceResponse.fromJson(json as Map<String, Object?>);
  }

  /// This API sets the given user's presence state. When setting the status,
  /// the activity time is updated to reflect that activity; the client does
  /// not need to specify the `last_active_ago` field. You cannot set the
  /// presence state of another user.
  ///
  /// [userId] The user whose presence state to update.
  ///
  /// [presence] The new presence state.
  ///
  /// [statusMsg] The status message to attach to this state.
  Future<void> setPresence(String userId, PresenceType presence,
      {String? statusMsg}) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/presence/${Uri.encodeComponent(userId)}/status');
    final request = Request('PUT', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      'presence': presence.name,
      if (statusMsg != null) 'status_msg': statusMsg,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// Get the combined profile information for this user. This API may be used
  /// to fetch the user's own profile information or other users; either
  /// locally or on remote homeservers. This API may return keys which are not
  /// limited to `displayname` or `avatar_url`.
  ///
  /// [userId] The user whose profile information to get.
  Future<ProfileInformation> getUserProfile(String userId) async {
    final requestUri =
        Uri(path: '_matrix/client/v3/profile/${Uri.encodeComponent(userId)}');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ProfileInformation.fromJson(json as Map<String, Object?>);
  }

  /// Get the user's avatar URL. This API may be used to fetch the user's
  /// own avatar URL or to query the URL of other users; either locally or
  /// on remote homeservers.
  ///
  /// [userId] The user whose avatar URL to get.
  ///
  /// returns `avatar_url`:
  /// The user's avatar URL if they have set one, otherwise not present.
  Future<Uri?> getAvatarUrl(String userId) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/profile/${Uri.encodeComponent(userId)}/avatar_url');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ((v) =>
        v != null ? Uri.parse(v as String) : null)(json['avatar_url']);
  }

  /// This API sets the given user's avatar URL. You must have permission to
  /// set this user's avatar URL, e.g. you need to have their `access_token`.
  ///
  /// [userId] The user whose avatar URL to set.
  ///
  /// [avatarUrl] The new avatar URL for this user.
  Future<void> setAvatarUrl(String userId, Uri? avatarUrl) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/profile/${Uri.encodeComponent(userId)}/avatar_url');
    final request = Request('PUT', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (avatarUrl != null) 'avatar_url': avatarUrl.toString(),
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// Get the user's display name. This API may be used to fetch the user's
  /// own displayname or to query the name of other users; either locally or
  /// on remote homeservers.
  ///
  /// [userId] The user whose display name to get.
  ///
  /// returns `displayname`:
  /// The user's display name if they have set one, otherwise not present.
  Future<String?> getDisplayName(String userId) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/profile/${Uri.encodeComponent(userId)}/displayname');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ((v) => v != null ? v as String : null)(json['displayname']);
  }

  /// This API sets the given user's display name. You must have permission to
  /// set this user's display name, e.g. you need to have their `access_token`.
  ///
  /// [userId] The user whose display name to set.
  ///
  /// [displayname] The new display name for this user.
  Future<void> setDisplayName(String userId, String? displayname) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/profile/${Uri.encodeComponent(userId)}/displayname');
    final request = Request('PUT', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (displayname != null) 'displayname': displayname,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// Lists the public rooms on the server.
  ///
  /// This API returns paginated responses. The rooms are ordered by the number
  /// of joined members, with the largest rooms first.
  ///
  /// [limit] Limit the number of results returned.
  ///
  /// [since] A pagination token from a previous request, allowing clients to
  /// get the next (or previous) batch of rooms.
  /// The direction of pagination is specified solely by which token
  /// is supplied, rather than via an explicit flag.
  ///
  /// [server] The server to fetch the public room lists from. Defaults to the
  /// local server.
  Future<GetPublicRoomsResponse> getPublicRooms(
      {int? limit, String? since, String? server}) async {
    final requestUri =
        Uri(path: '_matrix/client/v3/publicRooms', queryParameters: {
      if (limit != null) 'limit': limit.toString(),
      if (since != null) 'since': since,
      if (server != null) 'server': server,
    });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return GetPublicRoomsResponse.fromJson(json as Map<String, Object?>);
  }

  /// Lists the public rooms on the server, with optional filter.
  ///
  /// This API returns paginated responses. The rooms are ordered by the number
  /// of joined members, with the largest rooms first.
  ///
  /// [server] The server to fetch the public room lists from. Defaults to the
  /// local server.
  ///
  /// [filter] Filter to apply to the results.
  ///
  /// [includeAllNetworks] Whether or not to include all known networks/protocols from
  /// application services on the homeserver. Defaults to false.
  ///
  /// [limit] Limit the number of results returned.
  ///
  /// [since] A pagination token from a previous request, allowing clients
  /// to get the next (or previous) batch of rooms.  The direction
  /// of pagination is specified solely by which token is supplied,
  /// rather than via an explicit flag.
  ///
  /// [thirdPartyInstanceId] The specific third party network/protocol to request from the
  /// homeserver. Can only be used if `include_all_networks` is false.
  Future<QueryPublicRoomsResponse> queryPublicRooms(
      {String? server,
      PublicRoomQueryFilter? filter,
      bool? includeAllNetworks,
      int? limit,
      String? since,
      String? thirdPartyInstanceId}) async {
    final requestUri =
        Uri(path: '_matrix/client/v3/publicRooms', queryParameters: {
      if (server != null) 'server': server,
    });
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (filter != null) 'filter': filter.toJson(),
      if (includeAllNetworks != null)
        'include_all_networks': includeAllNetworks,
      if (limit != null) 'limit': limit,
      if (since != null) 'since': since,
      if (thirdPartyInstanceId != null)
        'third_party_instance_id': thirdPartyInstanceId,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return QueryPublicRoomsResponse.fromJson(json as Map<String, Object?>);
  }

  /// Gets all currently active pushers for the authenticated user.
  ///
  /// returns `pushers`:
  /// An array containing the current pushers for the user
  Future<List<Pusher>?> getPushers() async {
    final requestUri = Uri(path: '_matrix/client/v3/pushers');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ((v) => v != null
        ? (v as List)
            .map((v) => Pusher.fromJson(v as Map<String, Object?>))
            .toList()
        : null)(json['pushers']);
  }

  /// Retrieve all push rulesets for this user. Clients can "drill-down" on
  /// the rulesets by suffixing a `scope` to this path e.g.
  /// `/pushrules/global/`. This will return a subset of this data under the
  /// specified key e.g. the `global` key.
  ///
  /// returns `global`:
  /// The global ruleset.
  Future<PushRuleSet> getPushRules() async {
    final requestUri = Uri(path: '_matrix/client/v3/pushrules/');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return PushRuleSet.fromJson(json['global'] as Map<String, Object?>);
  }

  /// This endpoint removes the push rule defined in the path.
  ///
  /// [scope] `global` to specify global rules.
  ///
  /// [kind] The kind of rule
  ///
  ///
  /// [ruleId] The identifier for the rule.
  ///
  Future<void> deletePushRule(
      String scope, PushRuleKind kind, String ruleId) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/pushrules/${Uri.encodeComponent(scope)}/${Uri.encodeComponent(kind.name)}/${Uri.encodeComponent(ruleId)}');
    final request = Request('DELETE', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// Retrieve a single specified push rule.
  ///
  /// [scope] `global` to specify global rules.
  ///
  /// [kind] The kind of rule
  ///
  ///
  /// [ruleId] The identifier for the rule.
  ///
  Future<PushRule> getPushRule(
      String scope, PushRuleKind kind, String ruleId) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/pushrules/${Uri.encodeComponent(scope)}/${Uri.encodeComponent(kind.name)}/${Uri.encodeComponent(ruleId)}');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return PushRule.fromJson(json as Map<String, Object?>);
  }

  /// This endpoint allows the creation and modification of user defined push
  /// rules.
  ///
  /// If a rule with the same `rule_id` already exists among rules of the same
  /// kind, it is updated with the new parameters, otherwise a new rule is
  /// created.
  ///
  /// If both `after` and `before` are provided, the new or updated rule must
  /// be the next most important rule with respect to the rule identified by
  /// `before`.
  ///
  /// If neither `after` nor `before` are provided and the rule is created, it
  /// should be added as the most important user defined rule among rules of
  /// the same kind.
  ///
  /// When creating push rules, they MUST be enabled by default.
  ///
  /// [scope] `global` to specify global rules.
  ///
  /// [kind] The kind of rule
  ///
  ///
  /// [ruleId] The identifier for the rule. If the string starts with a dot ("."),
  /// the request MUST be rejected as this is reserved for server-default
  /// rules. Slashes ("/") and backslashes ("\\") are also not allowed.
  ///
  ///
  /// [before] Use 'before' with a `rule_id` as its value to make the new rule the
  /// next-most important rule with respect to the given user defined rule.
  /// It is not possible to add a rule relative to a predefined server rule.
  ///
  /// [after] This makes the new rule the next-less important rule relative to the
  /// given user defined rule. It is not possible to add a rule relative
  /// to a predefined server rule.
  ///
  /// [actions] The action(s) to perform when the conditions for this rule are met.
  ///
  /// [conditions] The conditions that must hold true for an event in order for a
  /// rule to be applied to an event. A rule with no conditions
  /// always matches. Only applicable to `underride` and `override` rules.
  ///
  /// [pattern] Only applicable to `content` rules. The glob-style pattern to match against.
  Future<void> setPushRule(
      String scope, PushRuleKind kind, String ruleId, List<Object?> actions,
      {String? before,
      String? after,
      List<PushCondition>? conditions,
      String? pattern}) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/pushrules/${Uri.encodeComponent(scope)}/${Uri.encodeComponent(kind.name)}/${Uri.encodeComponent(ruleId)}',
        queryParameters: {
          if (before != null) 'before': before,
          if (after != null) 'after': after,
        });
    final request = Request('PUT', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      'actions': actions.map((v) => v).toList(),
      if (conditions != null)
        'conditions': conditions.map((v) => v.toJson()).toList(),
      if (pattern != null) 'pattern': pattern,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// This endpoint get the actions for the specified push rule.
  ///
  /// [scope] Either `global` or `device/<profile_tag>` to specify global
  /// rules or device rules for the given `profile_tag`.
  ///
  /// [kind] The kind of rule
  ///
  ///
  /// [ruleId] The identifier for the rule.
  ///
  ///
  /// returns `actions`:
  /// The action(s) to perform for this rule.
  Future<List<Object?>> getPushRuleActions(
      String scope, PushRuleKind kind, String ruleId) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/pushrules/${Uri.encodeComponent(scope)}/${Uri.encodeComponent(kind.name)}/${Uri.encodeComponent(ruleId)}/actions');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return (json['actions'] as List).map((v) => v as Object?).toList();
  }

  /// This endpoint allows clients to change the actions of a push rule.
  /// This can be used to change the actions of builtin rules.
  ///
  /// [scope] `global` to specify global rules.
  ///
  /// [kind] The kind of rule
  ///
  ///
  /// [ruleId] The identifier for the rule.
  ///
  ///
  /// [actions] The action(s) to perform for this rule.
  Future<void> setPushRuleActions(String scope, PushRuleKind kind,
      String ruleId, List<Object?> actions) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/pushrules/${Uri.encodeComponent(scope)}/${Uri.encodeComponent(kind.name)}/${Uri.encodeComponent(ruleId)}/actions');
    final request = Request('PUT', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      'actions': actions.map((v) => v).toList(),
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// This endpoint gets whether the specified push rule is enabled.
  ///
  /// [scope] Either `global` or `device/<profile_tag>` to specify global
  /// rules or device rules for the given `profile_tag`.
  ///
  /// [kind] The kind of rule
  ///
  ///
  /// [ruleId] The identifier for the rule.
  ///
  ///
  /// returns `enabled`:
  /// Whether the push rule is enabled or not.
  Future<bool> isPushRuleEnabled(
      String scope, PushRuleKind kind, String ruleId) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/pushrules/${Uri.encodeComponent(scope)}/${Uri.encodeComponent(kind.name)}/${Uri.encodeComponent(ruleId)}/enabled');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return json['enabled'] as bool;
  }

  /// This endpoint allows clients to enable or disable the specified push rule.
  ///
  /// [scope] `global` to specify global rules.
  ///
  /// [kind] The kind of rule
  ///
  ///
  /// [ruleId] The identifier for the rule.
  ///
  ///
  /// [enabled] Whether the push rule is enabled or not.
  Future<void> setPushRuleEnabled(
      String scope, PushRuleKind kind, String ruleId, bool enabled) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/pushrules/${Uri.encodeComponent(scope)}/${Uri.encodeComponent(kind.name)}/${Uri.encodeComponent(ruleId)}/enabled');
    final request = Request('PUT', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      'enabled': enabled,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

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
  Future<RefreshResponse> refresh(String refreshToken) async {
    final requestUri = Uri(path: '_matrix/client/v3/refresh');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      'refresh_token': refreshToken,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return RefreshResponse.fromJson(json as Map<String, Object?>);
  }

  /// This API endpoint uses the [User-Interactive Authentication API](https://spec.matrix.org/unstable/client-server-api/#user-interactive-authentication-api), except in
  /// the cases where a guest account is being registered.
  ///
  /// Register for an account on this homeserver.
  ///
  /// There are two kinds of user account:
  ///
  /// - `user` accounts. These accounts may use the full API described in this specification.
  ///
  /// - `guest` accounts. These accounts may have limited permissions and may not be supported by all servers.
  ///
  /// If registration is successful, this endpoint will issue an access token
  /// the client can use to authorize itself in subsequent requests.
  ///
  /// If the client does not supply a `device_id`, the server must
  /// auto-generate one.
  ///
  /// The server SHOULD register an account with a User ID based on the
  /// `username` provided, if any. Note that the grammar of Matrix User ID
  /// localparts is restricted, so the server MUST either map the provided
  /// `username` onto a `user_id` in a logical manner, or reject
  /// `username`\s which do not comply to the grammar, with
  /// `M_INVALID_USERNAME`.
  ///
  /// Matrix clients MUST NOT assume that localpart of the registered
  /// `user_id` matches the provided `username`.
  ///
  /// The returned access token must be associated with the `device_id`
  /// supplied by the client or generated by the server. The server may
  /// invalidate any access token previously associated with that device. See
  /// [Relationship between access tokens and devices](https://spec.matrix.org/unstable/client-server-api/#relationship-between-access-tokens-and-devices).
  ///
  /// When registering a guest account, all parameters in the request body
  /// with the exception of `initial_device_display_name` MUST BE ignored
  /// by the server. The server MUST pick a `device_id` for the account
  /// regardless of input.
  ///
  /// Any user ID returned by this API must conform to the grammar given in the
  /// [Matrix specification](https://spec.matrix.org/unstable/appendices/#user-identifiers).
  ///
  /// [kind] The kind of account to register. Defaults to `user`.
  ///
  /// [auth] Additional authentication information for the
  /// user-interactive authentication API. Note that this
  /// information is *not* used to define how the registered user
  /// should be authenticated, but is instead used to
  /// authenticate the `register` call itself.
  ///
  /// [deviceId] ID of the client device. If this does not correspond to a
  /// known client device, a new device will be created. The server
  /// will auto-generate a device_id if this is not specified.
  ///
  /// [inhibitLogin] If true, an `access_token` and `device_id` should not be
  /// returned from this call, therefore preventing an automatic
  /// login. Defaults to false.
  ///
  /// [initialDeviceDisplayName] A display name to assign to the newly-created device. Ignored
  /// if `device_id` corresponds to a known device.
  ///
  /// [password] The desired password for the account.
  ///
  /// [refreshToken] If true, the client supports refresh tokens.
  ///
  /// [username] The basis for the localpart of the desired Matrix ID. If omitted,
  /// the homeserver MUST generate a Matrix ID local part.
  Future<RegisterResponse> register(
      {AccountKind? kind,
      AuthenticationData? auth,
      String? deviceId,
      bool? inhibitLogin,
      String? initialDeviceDisplayName,
      String? password,
      bool? refreshToken,
      String? username}) async {
    final requestUri =
        Uri(path: '_matrix/client/v3/register', queryParameters: {
      if (kind != null) 'kind': kind.name,
    });
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (auth != null) 'auth': auth.toJson(),
      if (deviceId != null) 'device_id': deviceId,
      if (inhibitLogin != null) 'inhibit_login': inhibitLogin,
      if (initialDeviceDisplayName != null)
        'initial_device_display_name': initialDeviceDisplayName,
      if (password != null) 'password': password,
      if (refreshToken != null) 'refresh_token': refreshToken,
      if (username != null) 'username': username,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return RegisterResponse.fromJson(json as Map<String, Object?>);
  }

  /// Checks to see if a username is available, and valid, for the server.
  ///
  /// The server should check to ensure that, at the time of the request, the
  /// username requested is available for use. This includes verifying that an
  /// application service has not claimed the username and that the username
  /// fits the server's desired requirements (for example, a server could dictate
  /// that it does not permit usernames with underscores).
  ///
  /// Matrix clients may wish to use this API prior to attempting registration,
  /// however the clients must also be aware that using this API does not normally
  /// reserve the username. This can mean that the username becomes unavailable
  /// between checking its availability and attempting to register it.
  ///
  /// [username] The username to check the availability of.
  ///
  /// returns `available`:
  /// A flag to indicate that the username is available. This should always
  /// be `true` when the server replies with 200 OK.
  Future<bool?> checkUsernameAvailability(String username) async {
    final requestUri =
        Uri(path: '_matrix/client/v3/register/available', queryParameters: {
      'username': username,
    });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ((v) => v != null ? v as bool : null)(json['available']);
  }

  /// The homeserver must check that the given email address is **not**
  /// already associated with an account on this homeserver. The homeserver
  /// should validate the email itself, either by sending a validation email
  /// itself or by using a service it has control over.
  ///
  /// [clientSecret] A unique string generated by the client, and used to identify the
  /// validation attempt. It must be a string consisting of the characters
  /// `[0-9a-zA-Z.=_-]`. Its length must not exceed 255 characters and it
  /// must not be empty.
  ///
  ///
  /// [email] The email address to validate.
  ///
  /// [nextLink] Optional. When the validation is completed, the identity server will
  /// redirect the user to this URL. This option is ignored when submitting
  /// 3PID validation information through a POST request.
  ///
  /// [sendAttempt] The server will only send an email if the `send_attempt`
  /// is a number greater than the most recent one which it has seen,
  /// scoped to that `email` + `client_secret` pair. This is to
  /// avoid repeatedly sending the same email in the case of request
  /// retries between the POSTing user and the identity server.
  /// The client should increment this value if they desire a new
  /// email (e.g. a reminder) to be sent. If they do not, the server
  /// should respond with success but not resend the email.
  ///
  /// [idAccessToken] An access token previously registered with the identity server. Servers
  /// can treat this as optional to distinguish between r0.5-compatible clients
  /// and this specification version.
  ///
  /// Required if an `id_server` is supplied.
  ///
  /// [idServer] The hostname of the identity server to communicate with. May optionally
  /// include a port. This parameter is ignored when the homeserver handles
  /// 3PID verification.
  ///
  /// This parameter is deprecated with a plan to be removed in a future specification
  /// version for `/account/password` and `/register` requests.
  Future<RequestTokenResponse> requestTokenToRegisterEmail(
      String clientSecret, String email, int sendAttempt,
      {String? nextLink, String? idAccessToken, String? idServer}) async {
    final requestUri =
        Uri(path: '_matrix/client/v3/register/email/requestToken');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      'client_secret': clientSecret,
      'email': email,
      if (nextLink != null) 'next_link': nextLink,
      'send_attempt': sendAttempt,
      if (idAccessToken != null) 'id_access_token': idAccessToken,
      if (idServer != null) 'id_server': idServer,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return RequestTokenResponse.fromJson(json as Map<String, Object?>);
  }

  /// The homeserver must check that the given phone number is **not**
  /// already associated with an account on this homeserver. The homeserver
  /// should validate the phone number itself, either by sending a validation
  /// message itself or by using a service it has control over.
  ///
  /// [clientSecret] A unique string generated by the client, and used to identify the
  /// validation attempt. It must be a string consisting of the characters
  /// `[0-9a-zA-Z.=_-]`. Its length must not exceed 255 characters and it
  /// must not be empty.
  ///
  ///
  /// [country] The two-letter uppercase ISO-3166-1 alpha-2 country code that the
  /// number in `phone_number` should be parsed as if it were dialled from.
  ///
  /// [nextLink] Optional. When the validation is completed, the identity server will
  /// redirect the user to this URL. This option is ignored when submitting
  /// 3PID validation information through a POST request.
  ///
  /// [phoneNumber] The phone number to validate.
  ///
  /// [sendAttempt] The server will only send an SMS if the `send_attempt` is a
  /// number greater than the most recent one which it has seen,
  /// scoped to that `country` + `phone_number` + `client_secret`
  /// triple. This is to avoid repeatedly sending the same SMS in
  /// the case of request retries between the POSTing user and the
  /// identity server. The client should increment this value if
  /// they desire a new SMS (e.g. a reminder) to be sent.
  ///
  /// [idAccessToken] An access token previously registered with the identity server. Servers
  /// can treat this as optional to distinguish between r0.5-compatible clients
  /// and this specification version.
  ///
  /// Required if an `id_server` is supplied.
  ///
  /// [idServer] The hostname of the identity server to communicate with. May optionally
  /// include a port. This parameter is ignored when the homeserver handles
  /// 3PID verification.
  ///
  /// This parameter is deprecated with a plan to be removed in a future specification
  /// version for `/account/password` and `/register` requests.
  Future<RequestTokenResponse> requestTokenToRegisterMSISDN(
      String clientSecret, String country, String phoneNumber, int sendAttempt,
      {String? nextLink, String? idAccessToken, String? idServer}) async {
    final requestUri =
        Uri(path: '_matrix/client/v3/register/msisdn/requestToken');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      'client_secret': clientSecret,
      'country': country,
      if (nextLink != null) 'next_link': nextLink,
      'phone_number': phoneNumber,
      'send_attempt': sendAttempt,
      if (idAccessToken != null) 'id_access_token': idAccessToken,
      if (idServer != null) 'id_server': idServer,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return RequestTokenResponse.fromJson(json as Map<String, Object?>);
  }

  /// Delete the keys from the backup.
  ///
  /// [version] The backup from which to delete the key
  Future<RoomKeysUpdateResponse> deleteRoomKeys(String version) async {
    final requestUri =
        Uri(path: '_matrix/client/v3/room_keys/keys', queryParameters: {
      'version': version,
    });
    final request = Request('DELETE', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return RoomKeysUpdateResponse.fromJson(json as Map<String, Object?>);
  }

  /// Retrieve the keys from the backup.
  ///
  /// [version] The backup from which to retrieve the keys.
  Future<RoomKeys> getRoomKeys(String version) async {
    final requestUri =
        Uri(path: '_matrix/client/v3/room_keys/keys', queryParameters: {
      'version': version,
    });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return RoomKeys.fromJson(json as Map<String, Object?>);
  }

  /// Store several keys in the backup.
  ///
  /// [version] The backup in which to store the keys. Must be the current backup.
  ///
  /// [backupData] The backup data.
  Future<RoomKeysUpdateResponse> putRoomKeys(
      String version, RoomKeys backupData) async {
    final requestUri =
        Uri(path: '_matrix/client/v3/room_keys/keys', queryParameters: {
      'version': version,
    });
    final request = Request('PUT', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode(backupData.toJson()));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return RoomKeysUpdateResponse.fromJson(json as Map<String, Object?>);
  }

  /// Delete the keys from the backup for a given room.
  ///
  /// [roomId] The ID of the room that the specified key is for.
  ///
  /// [version] The backup from which to delete the key.
  Future<RoomKeysUpdateResponse> deleteRoomKeysByRoomId(
      String roomId, String version) async {
    final requestUri = Uri(
        path: '_matrix/client/v3/room_keys/keys/${Uri.encodeComponent(roomId)}',
        queryParameters: {
          'version': version,
        });
    final request = Request('DELETE', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return RoomKeysUpdateResponse.fromJson(json as Map<String, Object?>);
  }

  /// Retrieve the keys from the backup for a given room.
  ///
  /// [roomId] The ID of the room that the requested key is for.
  ///
  /// [version] The backup from which to retrieve the key.
  Future<RoomKeyBackup> getRoomKeysByRoomId(
      String roomId, String version) async {
    final requestUri = Uri(
        path: '_matrix/client/v3/room_keys/keys/${Uri.encodeComponent(roomId)}',
        queryParameters: {
          'version': version,
        });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return RoomKeyBackup.fromJson(json as Map<String, Object?>);
  }

  /// Store several keys in the backup for a given room.
  ///
  /// [roomId] The ID of the room that the keys are for.
  ///
  /// [version] The backup in which to store the keys. Must be the current backup.
  ///
  /// [backupData] The backup data
  Future<RoomKeysUpdateResponse> putRoomKeysByRoomId(
      String roomId, String version, RoomKeyBackup backupData) async {
    final requestUri = Uri(
        path: '_matrix/client/v3/room_keys/keys/${Uri.encodeComponent(roomId)}',
        queryParameters: {
          'version': version,
        });
    final request = Request('PUT', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode(backupData.toJson()));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return RoomKeysUpdateResponse.fromJson(json as Map<String, Object?>);
  }

  /// Delete a key from the backup.
  ///
  /// [roomId] The ID of the room that the specified key is for.
  ///
  /// [sessionId] The ID of the megolm session whose key is to be deleted.
  ///
  /// [version] The backup from which to delete the key
  Future<RoomKeysUpdateResponse> deleteRoomKeyBySessionId(
      String roomId, String sessionId, String version) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/room_keys/keys/${Uri.encodeComponent(roomId)}/${Uri.encodeComponent(sessionId)}',
        queryParameters: {
          'version': version,
        });
    final request = Request('DELETE', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return RoomKeysUpdateResponse.fromJson(json as Map<String, Object?>);
  }

  /// Retrieve a key from the backup.
  ///
  /// [roomId] The ID of the room that the requested key is for.
  ///
  /// [sessionId] The ID of the megolm session whose key is requested.
  ///
  /// [version] The backup from which to retrieve the key.
  Future<KeyBackupData> getRoomKeyBySessionId(
      String roomId, String sessionId, String version) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/room_keys/keys/${Uri.encodeComponent(roomId)}/${Uri.encodeComponent(sessionId)}',
        queryParameters: {
          'version': version,
        });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return KeyBackupData.fromJson(json as Map<String, Object?>);
  }

  /// Store a key in the backup.
  ///
  /// [roomId] The ID of the room that the key is for.
  ///
  /// [sessionId] The ID of the megolm session that the key is for.
  ///
  /// [version] The backup in which to store the key. Must be the current backup.
  ///
  /// [data] The key data.
  Future<RoomKeysUpdateResponse> putRoomKeyBySessionId(String roomId,
      String sessionId, String version, KeyBackupData data) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/room_keys/keys/${Uri.encodeComponent(roomId)}/${Uri.encodeComponent(sessionId)}',
        queryParameters: {
          'version': version,
        });
    final request = Request('PUT', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode(data.toJson()));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return RoomKeysUpdateResponse.fromJson(json as Map<String, Object?>);
  }

  /// Get information about the latest backup version.
  Future<GetRoomKeysVersionCurrentResponse> getRoomKeysVersionCurrent() async {
    final requestUri = Uri(path: '_matrix/client/v3/room_keys/version');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return GetRoomKeysVersionCurrentResponse.fromJson(
        json as Map<String, Object?>);
  }

  /// Creates a new backup.
  ///
  /// [algorithm] The algorithm used for storing backups.
  ///
  /// [authData] Algorithm-dependent data. See the documentation for the backup
  /// algorithms in [Server-side key backups](https://spec.matrix.org/unstable/client-server-api/#server-side-key-backups) for more information on the
  /// expected format of the data.
  ///
  /// returns `version`:
  /// The backup version. This is an opaque string.
  Future<String> postRoomKeysVersion(
      BackupAlgorithm algorithm, Map<String, Object?> authData) async {
    final requestUri = Uri(path: '_matrix/client/v3/room_keys/version');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      'algorithm': algorithm.name,
      'auth_data': authData,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return json['version'] as String;
  }

  /// Delete an existing key backup. Both the information about the backup,
  /// as well as all key data related to the backup will be deleted.
  ///
  /// [version] The backup version to delete, as returned in the `version`
  /// parameter in the response of
  /// [`POST /_matrix/client/v3/room_keys/version`](https://spec.matrix.org/unstable/client-server-api/#post_matrixclientv3room_keysversion)
  /// or [`GET /_matrix/client/v3/room_keys/version/{version}`](https://spec.matrix.org/unstable/client-server-api/#get_matrixclientv3room_keysversionversion).
  Future<void> deleteRoomKeysVersion(String version) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/room_keys/version/${Uri.encodeComponent(version)}');
    final request = Request('DELETE', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// Get information about an existing backup.
  ///
  /// [version] The backup version to get, as returned in the `version` parameter
  /// of the response in
  /// [`POST /_matrix/client/v3/room_keys/version`](https://spec.matrix.org/unstable/client-server-api/#post_matrixclientv3room_keysversion)
  /// or this endpoint.
  Future<GetRoomKeysVersionResponse> getRoomKeysVersion(String version) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/room_keys/version/${Uri.encodeComponent(version)}');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return GetRoomKeysVersionResponse.fromJson(json as Map<String, Object?>);
  }

  /// Update information about an existing backup.  Only `auth_data` can be modified.
  ///
  /// [version] The backup version to update, as returned in the `version`
  /// parameter in the response of
  /// [`POST /_matrix/client/v3/room_keys/version`](https://spec.matrix.org/unstable/client-server-api/#post_matrixclientv3room_keysversion)
  /// or [`GET /_matrix/client/v3/room_keys/version/{version}`](https://spec.matrix.org/unstable/client-server-api/#get_matrixclientv3room_keysversionversion).
  ///
  /// [algorithm] The algorithm used for storing backups.  Must be the same as
  /// the algorithm currently used by the backup.
  ///
  /// [authData] Algorithm-dependent data. See the documentation for the backup
  /// algorithms in [Server-side key backups](https://spec.matrix.org/unstable/client-server-api/#server-side-key-backups) for more information on the
  /// expected format of the data.
  Future<Map<String, Object?>> putRoomKeysVersion(String version,
      BackupAlgorithm algorithm, Map<String, Object?> authData) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/room_keys/version/${Uri.encodeComponent(version)}');
    final request = Request('PUT', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      'algorithm': algorithm.name,
      'auth_data': authData,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return json as Map<String, Object?>;
  }

  /// Get a list of aliases maintained by the local server for the
  /// given room.
  ///
  /// This endpoint can be called by users who are in the room (external
  /// users receive an `M_FORBIDDEN` error response). If the room's
  /// `m.room.history_visibility` maps to `world_readable`, any
  /// user can call this endpoint.
  ///
  /// Servers may choose to implement additional access control checks here,
  /// such as allowing server administrators to view aliases regardless of
  /// membership.
  ///
  /// **Note:**
  /// Clients are recommended not to display this list of aliases prominently
  /// as they are not curated, unlike those listed in the `m.room.canonical_alias`
  /// state event.
  ///
  /// [roomId] The room ID to find local aliases of.
  ///
  /// returns `aliases`:
  /// The server's local aliases on the room. Can be empty.
  Future<List<String>> getLocalAliases(String roomId) async {
    final requestUri = Uri(
        path: '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/aliases');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return (json['aliases'] as List).map((v) => v as String).toList();
  }

  /// Ban a user in the room. If the user is currently in the room, also kick them.
  ///
  /// When a user is banned from a room, they may not join it or be invited to it until they are unbanned.
  ///
  /// The caller must have the required power level in order to perform this operation.
  ///
  /// [roomId] The room identifier (not alias) from which the user should be banned.
  ///
  /// [reason] The reason the user has been banned. This will be supplied as the `reason` on the target's updated [`m.room.member`](https://spec.matrix.org/unstable/client-server-api/#mroommember) event.
  ///
  /// [userId] The fully qualified user ID of the user being banned.
  Future<void> ban(String roomId, String userId, {String? reason}) async {
    final requestUri =
        Uri(path: '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/ban');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (reason != null) 'reason': reason,
      'user_id': userId,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// This API returns a number of events that happened just before and
  /// after the specified event. This allows clients to get the context
  /// surrounding an event.
  ///
  /// *Note*: This endpoint supports lazy-loading of room member events. See
  /// [Lazy-loading room members](https://spec.matrix.org/unstable/client-server-api/#lazy-loading-room-members) for more information.
  ///
  /// [roomId] The room to get events from.
  ///
  /// [eventId] The event to get context around.
  ///
  /// [limit] The maximum number of context events to return. The limit applies
  /// to the sum of the `events_before` and `events_after` arrays. The
  /// requested event ID is always returned in `event` even if `limit` is
  /// 0. Defaults to 10.
  ///
  /// [filter] A JSON `RoomEventFilter` to filter the returned events with. The
  /// filter is only applied to `events_before`, `events_after`, and
  /// `state`. It is not applied to the `event` itself. The filter may
  /// be applied before or/and after the `limit` parameter - whichever the
  /// homeserver prefers.
  ///
  /// See [Filtering](https://spec.matrix.org/unstable/client-server-api/#filtering) for more information.
  Future<EventContext> getEventContext(String roomId, String eventId,
      {int? limit, String? filter}) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/context/${Uri.encodeComponent(eventId)}',
        queryParameters: {
          if (limit != null) 'limit': limit.toString(),
          if (filter != null) 'filter': filter,
        });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return EventContext.fromJson(json as Map<String, Object?>);
  }

  /// Get a single event based on `roomId/eventId`. You must have permission to
  /// retrieve this event e.g. by being a member in the room for this event.
  ///
  /// [roomId] The ID of the room the event is in.
  ///
  /// [eventId] The event ID to get.
  Future<MatrixEvent> getOneRoomEvent(String roomId, String eventId) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/event/${Uri.encodeComponent(eventId)}');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return MatrixEvent.fromJson(json as Map<String, Object?>);
  }

  /// This API stops a user remembering about a particular room.
  ///
  /// In general, history is a first class citizen in Matrix. After this API
  /// is called, however, a user will no longer be able to retrieve history
  /// for this room. If all users on a homeserver forget a room, the room is
  /// eligible for deletion from that homeserver.
  ///
  /// If the user is currently joined to the room, they must leave the room
  /// before calling this API.
  ///
  /// [roomId] The room identifier to forget.
  Future<void> forgetRoom(String roomId) async {
    final requestUri = Uri(
        path: '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/forget');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// *Note that there are two forms of this API, which are documented separately.
  /// This version of the API does not require that the inviter know the Matrix
  /// identifier of the invitee, and instead relies on third party identifiers.
  /// The homeserver uses an identity server to perform the mapping from
  /// third party identifier to a Matrix identifier. The other is documented in the*
  /// [joining rooms section](https://spec.matrix.org/unstable/client-server-api/#post_matrixclientv3roomsroomidinvite).
  ///
  /// This API invites a user to participate in a particular room.
  /// They do not start participating in the room until they actually join the
  /// room.
  ///
  /// Only users currently in a particular room can invite other users to
  /// join that room.
  ///
  /// If the identity server did know the Matrix user identifier for the
  /// third party identifier, the homeserver will append a `m.room.member`
  /// event to the room.
  ///
  /// If the identity server does not know a Matrix user identifier for the
  /// passed third party identifier, the homeserver will issue an invitation
  /// which can be accepted upon providing proof of ownership of the third
  /// party identifier. This is achieved by the identity server generating a
  /// token, which it gives to the inviting homeserver. The homeserver will
  /// add an `m.room.third_party_invite` event into the graph for the room,
  /// containing that token.
  ///
  /// When the invitee binds the invited third party identifier to a Matrix
  /// user ID, the identity server will give the user a list of pending
  /// invitations, each containing:
  ///
  /// - The room ID to which they were invited
  ///
  /// - The token given to the homeserver
  ///
  /// - A signature of the token, signed with the identity server's private key
  ///
  /// - The matrix user ID who invited them to the room
  ///
  /// If a token is requested from the identity server, the homeserver will
  /// append a `m.room.third_party_invite` event to the room.
  ///
  /// [roomId] The room identifier (not alias) to which to invite the user.
  ///
  /// [address] The invitee's third party identifier.
  ///
  /// [idAccessToken] An access token previously registered with the identity server. Servers
  /// can treat this as optional to distinguish between r0.5-compatible clients
  /// and this specification version.
  ///
  /// [idServer] The hostname+port of the identity server which should be used for third party identifier lookups.
  ///
  /// [medium] The kind of address being passed in the address field, for example
  /// `email` (see [the list of recognised values](https://spec.matrix.org/unstable/appendices/#3pid-types)).
  Future<void> inviteBy3PID(String roomId, String address, String idAccessToken,
      String idServer, String medium) async {
    final requestUri = Uri(
        path: '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/invite');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      'address': address,
      'id_access_token': idAccessToken,
      'id_server': idServer,
      'medium': medium,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// *Note that there are two forms of this API, which are documented separately.
  /// This version of the API requires that the inviter knows the Matrix
  /// identifier of the invitee. The other is documented in the
  /// [third party invites](https://spec.matrix.org/unstable/client-server-api/#third-party-invites) section.*
  ///
  /// This API invites a user to participate in a particular room.
  /// They do not start participating in the room until they actually join the
  /// room.
  ///
  /// Only users currently in a particular room can invite other users to
  /// join that room.
  ///
  /// If the user was invited to the room, the homeserver will append a
  /// `m.room.member` event to the room.
  ///
  /// [roomId] The room identifier (not alias) to which to invite the user.
  ///
  /// [reason] Optional reason to be included as the `reason` on the subsequent
  /// membership event.
  ///
  /// [userId] The fully qualified user ID of the invitee.
  Future<void> inviteUser(String roomId, String userId,
      {String? reason}) async {
    final requestUri = Uri(
        path: '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/invite');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (reason != null) 'reason': reason,
      'user_id': userId,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// *Note that this API requires a room ID, not alias.*
  /// `/join/{roomIdOrAlias}` *exists if you have a room alias.*
  ///
  /// This API starts a user participating in a particular room, if that user
  /// is allowed to participate in that room. After this call, the client is
  /// allowed to see all current state events in the room, and all subsequent
  /// events associated with the room until the user leaves the room.
  ///
  /// After a user has joined a room, the room will appear as an entry in the
  /// response of the [`/initialSync`](https://spec.matrix.org/unstable/client-server-api/#get_matrixclientv3initialsync)
  /// and [`/sync`](https://spec.matrix.org/unstable/client-server-api/#get_matrixclientv3sync) APIs.
  ///
  /// [roomId] The room identifier (not alias) to join.
  ///
  /// [reason] Optional reason to be included as the `reason` on the subsequent
  /// membership event.
  ///
  /// [thirdPartySigned] If supplied, the homeserver must verify that it matches a pending
  /// `m.room.third_party_invite` event in the room, and perform
  /// key validity checking if required by the event.
  ///
  /// returns `room_id`:
  /// The joined room ID.
  Future<String> joinRoomById(String roomId,
      {String? reason, ThirdPartySigned? thirdPartySigned}) async {
    final requestUri = Uri(
        path: '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/join');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (reason != null) 'reason': reason,
      if (thirdPartySigned != null)
        'third_party_signed': thirdPartySigned.toJson(),
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return json['room_id'] as String;
  }

  /// This API returns a map of MXIDs to member info objects for members of the room. The current user must be in the room for it to work, unless it is an Application Service in which case any of the AS's users must be in the room. This API is primarily for Application Services and should be faster to respond than `/members` as it can be implemented more efficiently on the server.
  ///
  /// [roomId] The room to get the members of.
  ///
  /// returns `joined`:
  /// A map from user ID to a RoomMember object.
  Future<Map<String, RoomMember>?> getJoinedMembersByRoom(String roomId) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/joined_members');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ((v) => v != null
        ? (v as Map<String, Object?>).map((k, v) =>
            MapEntry(k, RoomMember.fromJson(v as Map<String, Object?>)))
        : null)(json['joined']);
  }

  /// Kick a user from the room.
  ///
  /// The caller must have the required power level in order to perform this operation.
  ///
  /// Kicking a user adjusts the target member's membership state to be `leave` with an
  /// optional `reason`. Like with other membership changes, a user can directly adjust
  /// the target member's state by making a request to `/rooms/<room id>/state/m.room.member/<user id>`.
  ///
  /// [roomId] The room identifier (not alias) from which the user should be kicked.
  ///
  /// [reason] The reason the user has been kicked. This will be supplied as the
  /// `reason` on the target's updated [`m.room.member`](https://spec.matrix.org/unstable/client-server-api/#mroommember) event.
  ///
  /// [userId] The fully qualified user ID of the user being kicked.
  Future<void> kick(String roomId, String userId, {String? reason}) async {
    final requestUri = Uri(
        path: '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/kick');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (reason != null) 'reason': reason,
      'user_id': userId,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// This API stops a user participating in a particular room.
  ///
  /// If the user was already in the room, they will no longer be able to see
  /// new events in the room. If the room requires an invite to join, they
  /// will need to be re-invited before they can re-join.
  ///
  /// If the user was invited to the room, but had not joined, this call
  /// serves to reject the invite.
  ///
  /// The user will still be allowed to retrieve history from the room which
  /// they were previously allowed to see.
  ///
  /// [roomId] The room identifier to leave.
  ///
  /// [reason] Optional reason to be included as the `reason` on the subsequent
  /// membership event.
  Future<void> leaveRoom(String roomId, {String? reason}) async {
    final requestUri = Uri(
        path: '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/leave');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (reason != null) 'reason': reason,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// Get the list of members for this room.
  ///
  /// [roomId] The room to get the member events for.
  ///
  /// [at] The point in time (pagination token) to return members for in the room.
  /// This token can be obtained from a `prev_batch` token returned for
  /// each room by the sync API. Defaults to the current state of the room,
  /// as determined by the server.
  ///
  /// [membership] The kind of membership to filter for. Defaults to no filtering if
  /// unspecified. When specified alongside `not_membership`, the two
  /// parameters create an 'or' condition: either the membership *is*
  /// the same as `membership` **or** *is not* the same as `not_membership`.
  ///
  /// [notMembership] The kind of membership to exclude from the results. Defaults to no
  /// filtering if unspecified.
  ///
  /// returns `chunk`:
  ///
  Future<List<MatrixEvent>?> getMembersByRoom(String roomId,
      {String? at, Membership? membership, Membership? notMembership}) async {
    final requestUri = Uri(
        path: '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/members',
        queryParameters: {
          if (at != null) 'at': at,
          if (membership != null) 'membership': membership.name,
          if (notMembership != null) 'not_membership': notMembership.name,
        });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ((v) => v != null
        ? (v as List)
            .map((v) => MatrixEvent.fromJson(v as Map<String, Object?>))
            .toList()
        : null)(json['chunk']);
  }

  /// This API returns a list of message and state events for a room. It uses
  /// pagination query parameters to paginate history in the room.
  ///
  /// *Note*: This endpoint supports lazy-loading of room member events. See
  /// [Lazy-loading room members](https://spec.matrix.org/unstable/client-server-api/#lazy-loading-room-members) for more information.
  ///
  /// [roomId] The room to get events from.
  ///
  /// [from] The token to start returning events from. This token can be obtained
  /// from a `prev_batch` or `next_batch` token returned by the `/sync` endpoint,
  /// or from an `end` token returned by a previous request to this endpoint.
  ///
  /// This endpoint can also accept a value returned as a `start` token
  /// by a previous request to this endpoint, though servers are not
  /// required to support this. Clients should not rely on the behaviour.
  ///
  /// If it is not provided, the homeserver shall return a list of messages
  /// from the first or last (per the value of the `dir` parameter) visible
  /// event in the room history for the requesting user.
  ///
  /// [to] The token to stop returning events at. This token can be obtained from
  /// a `prev_batch` or `next_batch` token returned by the `/sync` endpoint,
  /// or from an `end` token returned by a previous request to this endpoint.
  ///
  /// [dir] The direction to return events from. If this is set to `f`, events
  /// will be returned in chronological order starting at `from`. If it
  /// is set to `b`, events will be returned in *reverse* chronological
  /// order, again starting at `from`.
  ///
  /// [limit] The maximum number of events to return. Default: 10.
  ///
  /// [filter] A JSON RoomEventFilter to filter returned events with.
  Future<GetRoomEventsResponse> getRoomEvents(String roomId, Direction dir,
      {String? from, String? to, int? limit, String? filter}) async {
    final requestUri = Uri(
        path: '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/messages',
        queryParameters: {
          if (from != null) 'from': from,
          if (to != null) 'to': to,
          'dir': dir.name,
          if (limit != null) 'limit': limit.toString(),
          if (filter != null) 'filter': filter,
        });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return GetRoomEventsResponse.fromJson(json as Map<String, Object?>);
  }

  /// Sets the position of the read marker for a given room, and optionally
  /// the read receipt's location.
  ///
  /// [roomId] The room ID to set the read marker in for the user.
  ///
  /// [mFullyRead] The event ID the read marker should be located at. The
  /// event MUST belong to the room.
  ///
  /// [mRead] The event ID to set the read receipt location at. This is
  /// equivalent to calling `/receipt/m.read/$elsewhere:example.org`
  /// and is provided here to save that extra call.
  ///
  /// [mReadPrivate] The event ID to set the *private* read receipt location at. This
  /// equivalent to calling `/receipt/m.read.private/$elsewhere:example.org`
  /// and is provided here to save that extra call.
  Future<void> setReadMarker(String roomId,
      {String? mFullyRead, String? mRead, String? mReadPrivate}) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/read_markers');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (mFullyRead != null) 'm.fully_read': mFullyRead,
      if (mRead != null) 'm.read': mRead,
      if (mReadPrivate != null) 'm.read.private': mReadPrivate,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// This API updates the marker for the given receipt type to the event ID
  /// specified.
  ///
  /// [roomId] The room in which to send the event.
  ///
  /// [receiptType] The type of receipt to send. This can also be `m.fully_read` as an
  /// alternative to [`/read_markers`](https://spec.matrix.org/unstable/client-server-api/#post_matrixclientv3roomsroomidread_markers).
  ///
  /// Note that `m.fully_read` does not appear under `m.receipt`: this endpoint
  /// effectively calls `/read_markers` internally when presented with a receipt
  /// type of `m.fully_read`.
  ///
  /// [eventId] The event ID to acknowledge up to.
  ///
  /// [threadId] The root thread event's ID (or `main`) for which
  /// thread this receipt is intended to be under. If
  /// not specified, the read receipt is *unthreaded*
  /// (default).
  Future<void> postReceipt(
      String roomId, ReceiptType receiptType, String eventId,
      {String? threadId}) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/receipt/${Uri.encodeComponent(receiptType.name)}/${Uri.encodeComponent(eventId)}');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (threadId != null) 'thread_id': threadId,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// Strips all information out of an event which isn't critical to the
  /// integrity of the server-side representation of the room.
  ///
  /// This cannot be undone.
  ///
  /// Any user with a power level greater than or equal to the `m.room.redaction`
  /// event power level may send redaction events in the room. If the user's power
  /// level greater is also greater than or equal to the `redact` power level
  /// of the room, the user may redact events sent by other users.
  ///
  /// Server administrators may redact events sent by users on their server.
  ///
  /// [roomId] The room from which to redact the event.
  ///
  /// [eventId] The ID of the event to redact
  ///
  /// [txnId] The [transaction ID](https://spec.matrix.org/unstable/client-server-api/#transaction-identifiers) for this event. Clients should generate a
  /// unique ID; it will be used by the server to ensure idempotency of requests.
  ///
  /// [reason] The reason for the event being redacted.
  ///
  /// returns `event_id`:
  /// A unique identifier for the event.
  Future<String?> redactEvent(String roomId, String eventId, String txnId,
      {String? reason}) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/redact/${Uri.encodeComponent(eventId)}/${Uri.encodeComponent(txnId)}');
    final request = Request('PUT', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (reason != null) 'reason': reason,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ((v) => v != null ? v as String : null)(json['event_id']);
  }

  /// Reports an event as inappropriate to the server, which may then notify
  /// the appropriate people.
  ///
  /// [roomId] The room in which the event being reported is located.
  ///
  /// [eventId] The event to report.
  ///
  /// [reason] The reason the content is being reported. May be blank.
  ///
  /// [score] The score to rate this content as where -100 is most offensive
  /// and 0 is inoffensive.
  Future<void> reportContent(String roomId, String eventId,
      {String? reason, int? score}) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/report/${Uri.encodeComponent(eventId)}');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (reason != null) 'reason': reason,
      if (score != null) 'score': score,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// This endpoint is used to send a message event to a room. Message events
  /// allow access to historical events and pagination, making them suited
  /// for "once-off" activity in a room.
  ///
  /// The body of the request should be the content object of the event; the
  /// fields in this object will vary depending on the type of event. See
  /// [Room Events](https://spec.matrix.org/unstable/client-server-api/#room-events) for the m. event specification.
  ///
  /// [roomId] The room to send the event to.
  ///
  /// [eventType] The type of event to send.
  ///
  /// [txnId] The [transaction ID](https://spec.matrix.org/unstable/client-server-api/#transaction-identifiers) for this event. Clients should generate an
  /// ID unique across requests with the same access token; it will be
  /// used by the server to ensure idempotency of requests.
  ///
  /// [body]
  ///
  /// returns `event_id`:
  /// A unique identifier for the event.
  Future<String> sendMessage(String roomId, String eventType, String txnId,
      Map<String, Object?> body) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/send/${Uri.encodeComponent(eventType)}/${Uri.encodeComponent(txnId)}');
    final request = Request('PUT', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode(body));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return json['event_id'] as String;
  }

  /// Get the state events for the current state of a room.
  ///
  /// [roomId] The room to look up the state for.
  Future<List<MatrixEvent>> getRoomState(String roomId) async {
    final requestUri = Uri(
        path: '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/state');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return (json as List)
        .map((v) => MatrixEvent.fromJson(v as Map<String, Object?>))
        .toList();
  }

  /// Looks up the contents of a state event in a room. If the user is
  /// joined to the room then the state is taken from the current
  /// state of the room. If the user has left the room then the state is
  /// taken from the state of the room when they left.
  ///
  /// [roomId] The room to look up the state in.
  ///
  /// [eventType] The type of state to look up.
  ///
  /// [stateKey] The key of the state to look up. Defaults to an empty string. When
  /// an empty string, the trailing slash on this endpoint is optional.
  Future<Map<String, Object?>> getRoomStateWithKey(
      String roomId, String eventType, String stateKey) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/state/${Uri.encodeComponent(eventType)}/${Uri.encodeComponent(stateKey)}');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return json as Map<String, Object?>;
  }

  /// State events can be sent using this endpoint.  These events will be
  /// overwritten if `<room id>`, `<event type>` and `<state key>` all
  /// match.
  ///
  /// Requests to this endpoint **cannot use transaction IDs**
  /// like other `PUT` paths because they cannot be differentiated from the
  /// `state_key`. Furthermore, `POST` is unsupported on state paths.
  ///
  /// The body of the request should be the content object of the event; the
  /// fields in this object will vary depending on the type of event. See
  /// [Room Events](https://spec.matrix.org/unstable/client-server-api/#room-events) for the `m.` event specification.
  ///
  /// If the event type being sent is `m.room.canonical_alias` servers
  /// SHOULD ensure that any new aliases being listed in the event are valid
  /// per their grammar/syntax and that they point to the room ID where the
  /// state event is to be sent. Servers do not validate aliases which are
  /// being removed or are already present in the state event.
  ///
  ///
  /// [roomId] The room to set the state in
  ///
  /// [eventType] The type of event to send.
  ///
  /// [stateKey] The state_key for the state to send. Defaults to the empty string. When
  /// an empty string, the trailing slash on this endpoint is optional.
  ///
  /// [body]
  ///
  /// returns `event_id`:
  /// A unique identifier for the event.
  Future<String> setRoomStateWithKey(String roomId, String eventType,
      String stateKey, Map<String, Object?> body) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/state/${Uri.encodeComponent(eventType)}/${Uri.encodeComponent(stateKey)}');
    final request = Request('PUT', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode(body));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return json['event_id'] as String;
  }

  /// This tells the server that the user is typing for the next N
  /// milliseconds where N is the value specified in the `timeout` key.
  /// Alternatively, if `typing` is `false`, it tells the server that the
  /// user has stopped typing.
  ///
  /// [userId] The user who has started to type.
  ///
  /// [roomId] The room in which the user is typing.
  ///
  /// [timeout] The length of time in milliseconds to mark this user as typing.
  ///
  /// [typing] Whether the user is typing or not. If `false`, the `timeout`
  /// key can be omitted.
  Future<void> setTyping(String userId, String roomId, bool typing,
      {int? timeout}) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/typing/${Uri.encodeComponent(userId)}');
    final request = Request('PUT', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (timeout != null) 'timeout': timeout,
      'typing': typing,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// Unban a user from the room. This allows them to be invited to the room,
  /// and join if they would otherwise be allowed to join according to its join rules.
  ///
  /// The caller must have the required power level in order to perform this operation.
  ///
  /// [roomId] The room identifier (not alias) from which the user should be unbanned.
  ///
  /// [reason] Optional reason to be included as the `reason` on the subsequent
  /// membership event.
  ///
  /// [userId] The fully qualified user ID of the user being unbanned.
  Future<void> unban(String roomId, String userId, {String? reason}) async {
    final requestUri = Uri(
        path: '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/unban');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (reason != null) 'reason': reason,
      'user_id': userId,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// Upgrades the given room to a particular room version.
  ///
  /// [roomId] The ID of the room to upgrade.
  ///
  /// [newVersion] The new version for the room.
  ///
  /// returns `replacement_room`:
  /// The ID of the new room.
  Future<String> upgradeRoom(String roomId, String newVersion) async {
    final requestUri = Uri(
        path: '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/upgrade');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      'new_version': newVersion,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return json['replacement_room'] as String;
  }

  /// Performs a full text search across different categories.
  ///
  /// [nextBatch] The point to return events from. If given, this should be a
  /// `next_batch` result from a previous call to this endpoint.
  ///
  /// [searchCategories] Describes which categories to search in and their criteria.
  Future<SearchResults> search(Categories searchCategories,
      {String? nextBatch}) async {
    final requestUri = Uri(path: '_matrix/client/v3/search', queryParameters: {
      if (nextBatch != null) 'next_batch': nextBatch,
    });
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      'search_categories': searchCategories.toJson(),
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return SearchResults.fromJson(json as Map<String, Object?>);
  }

  /// This endpoint is used to send send-to-device events to a set of
  /// client devices.
  ///
  /// [eventType] The type of event to send.
  ///
  /// [txnId] The [transaction ID](https://spec.matrix.org/unstable/client-server-api/#transaction-identifiers) for this event. Clients should generate an
  /// ID unique across requests with the same access token; it will be
  /// used by the server to ensure idempotency of requests.
  ///
  /// [messages] The messages to send. A map from user ID, to a map from
  /// device ID to message body. The device ID may also be `*`,
  /// meaning all known devices for the user.
  Future<void> sendToDevice(String eventType, String txnId,
      Map<String, Map<String, Map<String, Object?>>> messages) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/sendToDevice/${Uri.encodeComponent(eventType)}/${Uri.encodeComponent(txnId)}');
    final request = Request('PUT', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      'messages':
          messages.map((k, v) => MapEntry(k, v.map((k, v) => MapEntry(k, v)))),
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// Synchronise the client's state with the latest state on the server.
  /// Clients use this API when they first log in to get an initial snapshot
  /// of the state on the server, and then continue to call this API to get
  /// incremental deltas to the state, and to receive new messages.
  ///
  /// *Note*: This endpoint supports lazy-loading. See [Filtering](https://spec.matrix.org/unstable/client-server-api/#filtering)
  /// for more information. Lazy-loading members is only supported on a `StateFilter`
  /// for this endpoint. When lazy-loading is enabled, servers MUST include the
  /// syncing user's own membership event when they join a room, or when the
  /// full state of rooms is requested, to aid discovering the user's avatar &
  /// displayname.
  ///
  /// Further, like other members, the user's own membership event is eligible
  /// for being considered redundant by the server. When a sync is `limited`,
  /// the server MUST return membership events for events in the gap
  /// (between `since` and the start of the returned timeline), regardless
  /// as to whether or not they are redundant. This ensures that joins/leaves
  /// and profile changes which occur during the gap are not lost.
  ///
  /// Note that the default behaviour of `state` is to include all membership
  /// events, alongside other state, when lazy-loading is not enabled.
  ///
  /// [filter] The ID of a filter created using the filter API or a filter JSON
  /// object encoded as a string. The server will detect whether it is
  /// an ID or a JSON object by whether the first character is a `"{"`
  /// open brace. Passing the JSON inline is best suited to one off
  /// requests. Creating a filter using the filter API is recommended for
  /// clients that reuse the same filter multiple times, for example in
  /// long poll requests.
  ///
  /// See [Filtering](https://spec.matrix.org/unstable/client-server-api/#filtering) for more information.
  ///
  /// [since] A point in time to continue a sync from. This should be the
  /// `next_batch` token returned by an earlier call to this endpoint.
  ///
  /// [fullState] Controls whether to include the full state for all rooms the user
  /// is a member of.
  ///
  /// If this is set to `true`, then all state events will be returned,
  /// even if `since` is non-empty. The timeline will still be limited
  /// by the `since` parameter. In this case, the `timeout` parameter
  /// will be ignored and the query will return immediately, possibly with
  /// an empty timeline.
  ///
  /// If `false`, and `since` is non-empty, only state which has
  /// changed since the point indicated by `since` will be returned.
  ///
  /// By default, this is `false`.
  ///
  /// [setPresence] Controls whether the client is automatically marked as online by
  /// polling this API. If this parameter is omitted then the client is
  /// automatically marked as online when it uses this API. Otherwise if
  /// the parameter is set to "offline" then the client is not marked as
  /// being online when it uses this API. When set to "unavailable", the
  /// client is marked as being idle.
  ///
  /// [timeout] The maximum time to wait, in milliseconds, before returning this
  /// request. If no events (or other data) become available before this
  /// time elapses, the server will return a response with empty fields.
  ///
  /// By default, this is `0`, so the server will return immediately
  /// even if the response is empty.
  Future<SyncUpdate> sync(
      {String? filter,
      String? since,
      bool? fullState,
      PresenceType? setPresence,
      int? timeout}) async {
    final requestUri = Uri(path: '_matrix/client/v3/sync', queryParameters: {
      if (filter != null) 'filter': filter,
      if (since != null) 'since': since,
      if (fullState != null) 'full_state': fullState.toString(),
      if (setPresence != null) 'set_presence': setPresence.name,
      if (timeout != null) 'timeout': timeout.toString(),
    });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return SyncUpdate.fromJson(json as Map<String, Object?>);
  }

  /// Retrieve an array of third party network locations from a Matrix room
  /// alias.
  ///
  /// [alias] The Matrix room alias to look up.
  Future<List<Location>> queryLocationByAlias(String alias) async {
    final requestUri =
        Uri(path: '_matrix/client/v3/thirdparty/location', queryParameters: {
      'alias': alias,
    });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return (json as List)
        .map((v) => Location.fromJson(v as Map<String, Object?>))
        .toList();
  }

  /// Requesting this endpoint with a valid protocol name results in a list
  /// of successful mapping results in a JSON array. Each result contains
  /// objects to represent the Matrix room or rooms that represent a portal
  /// to this third party network. Each has the Matrix room alias string,
  /// an identifier for the particular third party network protocol, and an
  /// object containing the network-specific fields that comprise this
  /// identifier. It should attempt to canonicalise the identifier as much
  /// as reasonably possible given the network type.
  ///
  /// [protocol] The protocol used to communicate to the third party network.
  ///
  /// [searchFields] One or more custom fields to help identify the third party
  /// location.
  Future<List<Location>> queryLocationByProtocol(String protocol,
      {String? searchFields}) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/thirdparty/location/${Uri.encodeComponent(protocol)}',
        queryParameters: {
          if (searchFields != null) 'searchFields': searchFields,
        });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return (json as List)
        .map((v) => Location.fromJson(v as Map<String, Object?>))
        .toList();
  }

  /// Fetches the metadata from the homeserver about a particular third party protocol.
  ///
  /// [protocol] The name of the protocol.
  Future<Protocol> getProtocolMetadata(String protocol) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/thirdparty/protocol/${Uri.encodeComponent(protocol)}');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return Protocol.fromJson(json as Map<String, Object?>);
  }

  /// Fetches the overall metadata about protocols supported by the
  /// homeserver. Includes both the available protocols and all fields
  /// required for queries against each protocol.
  Future<Map<String, Protocol>> getProtocols() async {
    final requestUri = Uri(path: '_matrix/client/v3/thirdparty/protocols');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return (json as Map<String, Object?>).map(
        (k, v) => MapEntry(k, Protocol.fromJson(v as Map<String, Object?>)));
  }

  /// Retrieve an array of third party users from a Matrix User ID.
  ///
  /// [userid] The Matrix User ID to look up.
  Future<List<ThirdPartyUser>> queryUserByID(String userid) async {
    final requestUri =
        Uri(path: '_matrix/client/v3/thirdparty/user', queryParameters: {
      'userid': userid,
    });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return (json as List)
        .map((v) => ThirdPartyUser.fromJson(v as Map<String, Object?>))
        .toList();
  }

  /// Retrieve a Matrix User ID linked to a user on the third party service, given
  /// a set of user parameters.
  ///
  /// [protocol] The name of the protocol.
  ///
  /// [fields] One or more custom fields that are passed to the AS to help identify the user.
  Future<List<ThirdPartyUser>> queryUserByProtocol(String protocol,
      {String? fields}) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/thirdparty/user/${Uri.encodeComponent(protocol)}',
        queryParameters: {
          if (fields != null) 'fields...': fields,
        });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return (json as List)
        .map((v) => ThirdPartyUser.fromJson(v as Map<String, Object?>))
        .toList();
  }

  /// Get some account data for the client. This config is only visible to the user
  /// that set the account data.
  ///
  /// [userId] The ID of the user to get account data for. The access token must be
  /// authorized to make requests for this user ID.
  ///
  /// [type] The event type of the account data to get. Custom types should be
  /// namespaced to avoid clashes.
  Future<Map<String, Object?>> getAccountData(
      String userId, String type) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/user/${Uri.encodeComponent(userId)}/account_data/${Uri.encodeComponent(type)}');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return json as Map<String, Object?>;
  }

  /// Set some account data for the client. This config is only visible to the user
  /// that set the account data. The config will be available to clients through the
  /// top-level `account_data` field in the homeserver response to
  /// [/sync](#get_matrixclientv3sync).
  ///
  /// [userId] The ID of the user to set account data for. The access token must be
  /// authorized to make requests for this user ID.
  ///
  /// [type] The event type of the account data to set. Custom types should be
  /// namespaced to avoid clashes.
  ///
  /// [content] The content of the account data.
  Future<void> setAccountData(
      String userId, String type, Map<String, Object?> content) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/user/${Uri.encodeComponent(userId)}/account_data/${Uri.encodeComponent(type)}');
    final request = Request('PUT', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode(content));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// Uploads a new filter definition to the homeserver.
  /// Returns a filter ID that may be used in future requests to
  /// restrict which events are returned to the client.
  ///
  /// [userId] The id of the user uploading the filter. The access token must be authorized to make requests for this user id.
  ///
  /// [filter] The filter to upload.
  ///
  /// returns `filter_id`:
  /// The ID of the filter that was created. Cannot start
  /// with a `{` as this character is used to determine
  /// if the filter provided is inline JSON or a previously
  /// declared filter by homeservers on some APIs.
  Future<String> defineFilter(String userId, Filter filter) async {
    final requestUri = Uri(
        path: '_matrix/client/v3/user/${Uri.encodeComponent(userId)}/filter');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode(filter.toJson()));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return json['filter_id'] as String;
  }

  ///
  ///
  /// [userId] The user ID to download a filter for.
  ///
  /// [filterId] The filter ID to download.
  Future<Filter> getFilter(String userId, String filterId) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/user/${Uri.encodeComponent(userId)}/filter/${Uri.encodeComponent(filterId)}');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return Filter.fromJson(json as Map<String, Object?>);
  }

  /// Gets an OpenID token object that the requester may supply to another
  /// service to verify their identity in Matrix. The generated token is only
  /// valid for exchanging for user information from the federation API for
  /// OpenID.
  ///
  /// The access token generated is only valid for the OpenID API. It cannot
  /// be used to request another OpenID access token or call `/sync`, for
  /// example.
  ///
  /// [userId] The user to request an OpenID token for. Should be the user who
  /// is authenticated for the request.
  ///
  /// [body] An empty object. Reserved for future expansion.
  Future<OpenIdCredentials> requestOpenIdToken(
      String userId, Map<String, Object?> body) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/user/${Uri.encodeComponent(userId)}/openid/request_token');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode(body));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return OpenIdCredentials.fromJson(json as Map<String, Object?>);
  }

  /// Get some account data for the client on a given room. This config is only
  /// visible to the user that set the account data.
  ///
  /// [userId] The ID of the user to get account data for. The access token must be
  /// authorized to make requests for this user ID.
  ///
  /// [roomId] The ID of the room to get account data for.
  ///
  /// [type] The event type of the account data to get. Custom types should be
  /// namespaced to avoid clashes.
  Future<Map<String, Object?>> getAccountDataPerRoom(
      String userId, String roomId, String type) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/user/${Uri.encodeComponent(userId)}/rooms/${Uri.encodeComponent(roomId)}/account_data/${Uri.encodeComponent(type)}');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return json as Map<String, Object?>;
  }

  /// Set some account data for the client on a given room. This config is only
  /// visible to the user that set the account data. The config will be delivered to
  /// clients in the per-room entries via [/sync](#get_matrixclientv3sync).
  ///
  /// [userId] The ID of the user to set account data for. The access token must be
  /// authorized to make requests for this user ID.
  ///
  /// [roomId] The ID of the room to set account data on.
  ///
  /// [type] The event type of the account data to set. Custom types should be
  /// namespaced to avoid clashes.
  ///
  /// [content] The content of the account data.
  Future<void> setAccountDataPerRoom(String userId, String roomId, String type,
      Map<String, Object?> content) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/user/${Uri.encodeComponent(userId)}/rooms/${Uri.encodeComponent(roomId)}/account_data/${Uri.encodeComponent(type)}');
    final request = Request('PUT', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode(content));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// List the tags set by a user on a room.
  ///
  /// [userId] The id of the user to get tags for. The access token must be
  /// authorized to make requests for this user ID.
  ///
  /// [roomId] The ID of the room to get tags for.
  ///
  /// returns `tags`:
  ///
  Future<Map<String, Tag>?> getRoomTags(String userId, String roomId) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/user/${Uri.encodeComponent(userId)}/rooms/${Uri.encodeComponent(roomId)}/tags');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ((v) => v != null
        ? (v as Map<String, Object?>)
            .map((k, v) => MapEntry(k, Tag.fromJson(v as Map<String, Object?>)))
        : null)(json['tags']);
  }

  /// Remove a tag from the room.
  ///
  /// [userId] The id of the user to remove a tag for. The access token must be
  /// authorized to make requests for this user ID.
  ///
  /// [roomId] The ID of the room to remove a tag from.
  ///
  /// [tag] The tag to remove.
  Future<void> deleteRoomTag(String userId, String roomId, String tag) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/user/${Uri.encodeComponent(userId)}/rooms/${Uri.encodeComponent(roomId)}/tags/${Uri.encodeComponent(tag)}');
    final request = Request('DELETE', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// Add a tag to the room.
  ///
  /// [userId] The id of the user to add a tag for. The access token must be
  /// authorized to make requests for this user ID.
  ///
  /// [roomId] The ID of the room to add a tag to.
  ///
  /// [tag] The tag to add.
  ///
  /// [order] A number in a range `[0,1]` describing a relative
  /// position of the room under the given tag.
  Future<void> setRoomTag(String userId, String roomId, String tag,
      {double? order,
      Map<String, Object?> additionalProperties = const {}}) async {
    final requestUri = Uri(
        path:
            '_matrix/client/v3/user/${Uri.encodeComponent(userId)}/rooms/${Uri.encodeComponent(roomId)}/tags/${Uri.encodeComponent(tag)}');
    final request = Request('PUT', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      ...additionalProperties,
      if (order != null) 'order': order,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ignore(json);
  }

  /// Performs a search for users. The homeserver may
  /// determine which subset of users are searched, however the homeserver
  /// MUST at a minimum consider the users the requesting user shares a
  /// room with and those who reside in public rooms (known to the homeserver).
  /// The search MUST consider local users to the homeserver, and SHOULD
  /// query remote users as part of the search.
  ///
  /// The search is performed case-insensitively on user IDs and display
  /// names preferably using a collation determined based upon the
  /// `Accept-Language` header provided in the request, if present.
  ///
  /// [limit] The maximum number of results to return. Defaults to 10.
  ///
  /// [searchTerm] The term to search for
  Future<SearchUserDirectoryResponse> searchUserDirectory(String searchTerm,
      {int? limit}) async {
    final requestUri = Uri(path: '_matrix/client/v3/user_directory/search');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode({
      if (limit != null) 'limit': limit,
      'search_term': searchTerm,
    }));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return SearchUserDirectoryResponse.fromJson(json as Map<String, Object?>);
  }

  /// This API provides credentials for the client to use when initiating
  /// calls.
  Future<TurnServerCredentials> getTurnServer() async {
    final requestUri = Uri(path: '_matrix/client/v3/voip/turnServer');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return TurnServerCredentials.fromJson(json as Map<String, Object?>);
  }

  /// Gets the versions of the specification supported by the server.
  ///
  /// Values will take the form `vX.Y` or `rX.Y.Z` in historical cases. See
  /// [the Specification Versioning](../#specification-versions) for more
  /// information.
  ///
  /// The server may additionally advertise experimental features it supports
  /// through `unstable_features`. These features should be namespaced and
  /// may optionally include version information within their name if desired.
  /// Features listed here are not for optionally toggling parts of the Matrix
  /// specification and should only be used to advertise support for a feature
  /// which has not yet landed in the spec. For example, a feature currently
  /// undergoing the proposal process may appear here and eventually be taken
  /// off this list once the feature lands in the spec and the server deems it
  /// reasonable to do so. Servers may wish to keep advertising features here
  /// after they've been released into the spec to give clients a chance to
  /// upgrade appropriately. Additionally, clients should avoid using unstable
  /// features in their stable releases.
  Future<GetVersionsResponse> getVersions() async {
    final requestUri = Uri(path: '_matrix/client/versions');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return GetVersionsResponse.fromJson(json as Map<String, Object?>);
  }

  /// This endpoint allows clients to retrieve the configuration of the content
  /// repository, such as upload limitations.
  /// Clients SHOULD use this as a guide when using content repository endpoints.
  /// All values are intentionally left optional. Clients SHOULD follow
  /// the advice given in the field description when the field is not available.
  ///
  /// **NOTE:** Both clients and server administrators should be aware that proxies
  /// between the client and the server may affect the apparent behaviour of content
  /// repository APIs, for example, proxies may enforce a lower upload size limit
  /// than is advertised by the server on this endpoint.
  Future<ServerConfig> getConfig() async {
    final requestUri = Uri(path: '_matrix/media/v3/config');
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ServerConfig.fromJson(json as Map<String, Object?>);
  }

  ///
  ///
  /// [serverName] The server name from the `mxc://` URI (the authoritory component)
  ///
  ///
  /// [mediaId] The media ID from the `mxc://` URI (the path component)
  ///
  ///
  /// [allowRemote] Indicates to the server that it should not attempt to fetch the media if it is deemed
  /// remote. This is to prevent routing loops where the server contacts itself. Defaults to
  /// true if not provided.
  ///
  Future<FileResponse> getContent(String serverName, String mediaId,
      {bool? allowRemote}) async {
    final requestUri = Uri(
        path:
            '_matrix/media/v3/download/${Uri.encodeComponent(serverName)}/${Uri.encodeComponent(mediaId)}',
        queryParameters: {
          if (allowRemote != null) 'allow_remote': allowRemote.toString(),
        });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    return FileResponse(
        contentType: response.headers['content-type'], data: responseBody);
  }

  /// This will download content from the content repository (same as
  /// the previous endpoint) but replace the target file name with the one
  /// provided by the caller.
  ///
  /// [serverName] The server name from the `mxc://` URI (the authoritory component)
  ///
  ///
  /// [mediaId] The media ID from the `mxc://` URI (the path component)
  ///
  ///
  /// [fileName] A filename to give in the `Content-Disposition` header.
  ///
  /// [allowRemote] Indicates to the server that it should not attempt to fetch the media if it is deemed
  /// remote. This is to prevent routing loops where the server contacts itself. Defaults to
  /// true if not provided.
  ///
  Future<FileResponse> getContentOverrideName(
      String serverName, String mediaId, String fileName,
      {bool? allowRemote}) async {
    final requestUri = Uri(
        path:
            '_matrix/media/v3/download/${Uri.encodeComponent(serverName)}/${Uri.encodeComponent(mediaId)}/${Uri.encodeComponent(fileName)}',
        queryParameters: {
          if (allowRemote != null) 'allow_remote': allowRemote.toString(),
        });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    return FileResponse(
        contentType: response.headers['content-type'], data: responseBody);
  }

  /// Get information about a URL for the client. Typically this is called when a
  /// client sees a URL in a message and wants to render a preview for the user.
  ///
  /// **Note:**
  /// Clients should consider avoiding this endpoint for URLs posted in encrypted
  /// rooms. Encrypted rooms often contain more sensitive information the users
  /// do not want to share with the homeserver, and this can mean that the URLs
  /// being shared should also not be shared with the homeserver.
  ///
  /// [url] The URL to get a preview of.
  ///
  /// [ts] The preferred point in time to return a preview for. The server may
  /// return a newer version if it does not have the requested version
  /// available.
  Future<GetUrlPreviewResponse> getUrlPreview(Uri url, {int? ts}) async {
    final requestUri =
        Uri(path: '_matrix/media/v3/preview_url', queryParameters: {
      'url': url.toString(),
      if (ts != null) 'ts': ts.toString(),
    });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return GetUrlPreviewResponse.fromJson(json as Map<String, Object?>);
  }

  /// Download a thumbnail of content from the content repository.
  /// See the [Thumbnails](https://spec.matrix.org/unstable/client-server-api/#thumbnails) section for more information.
  ///
  /// [serverName] The server name from the `mxc://` URI (the authoritory component)
  ///
  ///
  /// [mediaId] The media ID from the `mxc://` URI (the path component)
  ///
  ///
  /// [width] The *desired* width of the thumbnail. The actual thumbnail may be
  /// larger than the size specified.
  ///
  /// [height] The *desired* height of the thumbnail. The actual thumbnail may be
  /// larger than the size specified.
  ///
  /// [method] The desired resizing method. See the [Thumbnails](https://spec.matrix.org/unstable/client-server-api/#thumbnails)
  /// section for more information.
  ///
  /// [allowRemote] Indicates to the server that it should not attempt to fetch
  /// the media if it is deemed remote. This is to prevent routing loops
  /// where the server contacts itself. Defaults to true if not provided.
  Future<FileResponse> getContentThumbnail(
      String serverName, String mediaId, int width, int height,
      {Method? method, bool? allowRemote}) async {
    final requestUri = Uri(
        path:
            '_matrix/media/v3/thumbnail/${Uri.encodeComponent(serverName)}/${Uri.encodeComponent(mediaId)}',
        queryParameters: {
          'width': width.toString(),
          'height': height.toString(),
          if (method != null) 'method': method.name,
          if (allowRemote != null) 'allow_remote': allowRemote.toString(),
        });
    final request = Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    return FileResponse(
        contentType: response.headers['content-type'], data: responseBody);
  }

  ///
  ///
  /// [filename] The name of the file being uploaded
  ///
  /// [content] The content to be uploaded.
  ///
  /// [contentType] The content type of the file being uploaded
  ///
  /// returns `content_uri`:
  /// The [MXC URI](https://spec.matrix.org/unstable/client-server-api/#matrix-content-mxc-uris) to the uploaded content.
  Future<Uri> uploadContent(Uint8List content,
      {String? filename, String? contentType}) async {
    final requestUri = Uri(path: '_matrix/media/v3/upload', queryParameters: {
      if (filename != null) 'filename': filename,
    });
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    if (contentType != null) request.headers['content-type'] = contentType;
    request.bodyBytes = content;
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return Uri.parse(json['content_uri'] as String);
  }
}
