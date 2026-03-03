import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:matrix/matrix.dart';

enum DelayedEventAction { send, cancel, restart }

extension DelayedEventsHandler on Client {
  static const _delayedEventsEndpoint =
      '_matrix/client/unstable/org.matrix.msc4140/delayed_events';

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
  /// [delayInMs] Optional number of milliseconds the homeserver should wait before sending the event.
  /// If no delay is provided, the event is sent immediately as normal.
  ///
  /// [body]
  ///
  /// returns `event_id`:
  /// A unique identifier for the event.
  /// If a delay is provided, the homeserver schedules the event to be sent with the specified delay
  /// and responds with an opaque delay_id field (omitting the event_id as it is not available)
  Future<String> setRoomStateWithKeyWithDelay(
    String roomId,
    String eventType,
    String stateKey,
    int? delayInMs,
    Map<String, Object?> body,
  ) async {
    final requestUri = Uri(
      path:
          '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/state/${Uri.encodeComponent(eventType)}/${Uri.encodeComponent(stateKey)}',
      queryParameters: {
        if (delayInMs != null) 'org.matrix.msc4140.delay': delayInMs.toString(),
      },
    );

    final request = http.Request('PUT', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode(body));
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return json['event_id'] ?? json['delay_id'] as String;
  }

  Future<void> manageDelayedEvent(
    String delayedId,
    DelayedEventAction delayedEventAction,
  ) async {
    final requestUri = Uri(
      path: '$_delayedEventsEndpoint/$delayedId',
    );

    final request = http.Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(
      jsonEncode({
        'action': delayedEventAction.name,
      }),
    );
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
  }

  // This should use the /delayed_events/scheduled endpoint
  // but synapse implementation uses the /delayed_events
  Future<ScheduledDelayedEventsResponse> getScheduledDelayedEvents({
    String? from,
  }) async {
    final requestUri = Uri(
      path: _delayedEventsEndpoint,
      queryParameters: {if (from != null) 'from': from},
    );

    final request = http.Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) {
      return await _getScheduledDelayedEventsAccordingToSpec(from: from);
    }
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    final res = ScheduledDelayedEventsResponse.fromJson(json);
    return res;
  }

  // maybe the synapse impl changes, I don't want stuff to break
  Future<ScheduledDelayedEventsResponse>
      _getScheduledDelayedEventsAccordingToSpec({
    String? from,
  }) async {
    final requestUri = Uri(
      path: '$_delayedEventsEndpoint/scheduled',
      queryParameters: {if (from != null) 'from': from},
    );

    final request = http.Request('GET', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    final res = ScheduledDelayedEventsResponse.fromJson(json);
    return res;
  }

  /// TODO: implement the remaining APIs
  /// GET /_matrix/client/unstable/org.matrix.msc4140/delayed_events/finalised
}
