// SPDX-FileCopyrightText: 2026-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:http/http.dart';
import 'package:matrix/matrix_api_lite/generated/api.dart';

extension Msc3912RedactWithRelTypes on Api {
  /// Modified version of `Client.redactEvent()` with MSC3912 to also redact
  /// relationship types.
  /// https://github.com/matrix-org/matrix-spec-proposals/pull/3912
  Future<String?> redactEventWithRelTypes(
    String roomId,
    String eventId,
    String txnId, {
    String? reason,
    List<String>? withRelTypes,
  }) async {
    final requestUri = Uri(
      path:
          '_matrix/client/v3/rooms/${Uri.encodeComponent(roomId)}/redact/${Uri.encodeComponent(eventId)}/${Uri.encodeComponent(txnId)}',
    );
    final request = Request('PUT', baseUri!.resolveUri(requestUri));
    request.headers['authorization'] = 'Bearer ${bearerToken!}';
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(
      jsonEncode({'reason': ?reason, 'with_rel_types': ?withRelTypes}),
    );
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return ((v) => v != null ? v as String : null)(json['event_id']);
  }
}
