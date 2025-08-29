/// Media linking MSC, that allows attaching media to events or profiles.
/// https://github.com/matrix-org/matrix-spec-proposals/pull/3911
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart';

import 'package:matrix/matrix_api_lite/generated/api.dart';

/// Uploads MSC3911 restricted media, that needs to be attached on send.
/// (Only difference to normal uploadContent is the url and the server behaviour.)
///
/// [filename] The name of the file being uploaded
///
/// [body]
///
/// [contentType] **Optional.** The content type of the file being uploaded.
///
/// Clients SHOULD always supply this header.
///
/// Defaults to `application/octet-stream` if it is not set.
///
///
/// returns `content_uri`:
/// The [`mxc://` URI](https://spec.matrix.org/unstable/client-server-api/#matrix-content-mxc-uris) to the uploaded content.
extension Msc3911 on Api {
  Future<Uri> uploadRestrictedContent(
    Uint8List body, {
    String? filename,
    String? contentType,
  }) async {
    final requestUri = Uri(
      path: '_matrix/client/unstable/org.matrix.msc3911/media/upload',
      queryParameters: {
        if (filename != null) 'filename': filename,
      },
    );
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    if (contentType != null) request.headers['content-type'] = contentType;
    request.bodyBytes = body;
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ((json['content_uri'] as String).startsWith('mxc://')
        ? Uri.parse(json['content_uri'] as String)
        : throw Exception('Uri not an mxc URI'));
  }

  /// This is a copy of sendMessage, but allows a user to attach media ids to the sent event according to MSC3911.
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
  Future<String> sendRestrictedMediaMessage(
    String roomId,
    String eventType,
    String txnId,
    List<String>? attachedMediaIds,
    Map<String, Object?> body,
  ) async {
    final Map<String, Object?> queryParameters = {};
    if (attachedMediaIds != null) {
      queryParameters['org.matrix.msc3911.attach_media'] = attachedMediaIds;
    }

    final requestUri = Uri(
      path:
          '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/send/${Uri.encodeComponent(eventType)}/${Uri.encodeComponent(txnId)}',
      queryParameters: queryParameters,
    );
    final request = Request('PUT', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(jsonEncode(body));
    const maxBodySize = 60000;
    if (request.bodyBytes.length > maxBodySize) {
      bodySizeExceeded(maxBodySize, request.bodyBytes.length);
    }
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return json['event_id'] as String;
  }

  /// State events can be sent using this endpoint.  These events will be
  /// overwritten if `<room id>`, `<event type>` and `<state key>` all
  /// match. This implements the attachedMediaIds needed by MSC3911, but
  /// is otherwise identical to setRoomStateWithKey.
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
  Future<String> setRestrictedMediaRoomStateWithKey(
    String roomId,
    String eventType,
    String stateKey,
    List<String>? attachedMediaIds,
    Map<String, Object?> body,
  ) async {
    final Map<String, Object?> queryParameters = {};
    if (attachedMediaIds != null) {
      queryParameters['org.matrix.msc3911.attach_media'] = attachedMediaIds;
    }

    final requestUri = Uri(
      path:
          '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/state/${Uri.encodeComponent(eventType)}/${Uri.encodeComponent(stateKey)}',
      queryParameters: queryParameters,
    );
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
}
