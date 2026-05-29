// SPDX-FileCopyrightText: 2019-Present, 2021 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:http/http.dart' as http;

http.StreamedResponse replaceStream(
  http.StreamedResponse base,
  Stream<List<int>> stream,
) =>
    http.StreamedResponse(
      http.ByteStream(stream),
      base.statusCode,
      contentLength: base.contentLength,
      request: base.request,
      headers: base.headers,
      isRedirect: base.isRedirect,
      persistentConnection: base.persistentConnection,
      reasonPhrase: base.reasonPhrase,
    );

/// Http Client that enforces a timeout on requests.
/// Timeout calculation is done in a subclass.
abstract class TimeoutHttpClient extends http.BaseClient {
  TimeoutHttpClient(this.inner);

  http.Client inner;

  Duration get timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await inner.send(request);
    return replaceStream(response, response.stream.timeout(timeout));
  }
}

class FixedTimeoutHttpClient extends TimeoutHttpClient {
  FixedTimeoutHttpClient(super.inner, this.timeout);
  @override
  Duration timeout;
}
