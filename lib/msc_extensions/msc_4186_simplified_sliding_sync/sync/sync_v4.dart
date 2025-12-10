import 'dart:convert';

import 'package:http/http.dart' hide Client;

import 'package:matrix/matrix.dart';

const _unstablePrefix = 'org.matrix.simplified_msc3575';

extension Msc4186SimplifiedSlidingSync on Client {
  Future<SyncRequestResponse> syncV4(SyncRequestBody body) async {
    final requestUri = Uri(path: '_matrix/client/$_unstablePrefix/sync');
    final request = Request('POST', baseUri!.resolveUri(requestUri));
    request.headers['content-type'] = 'application/json';
    request.bodyBytes = utf8.encode(
      jsonEncode(body),
    );
    final response = await httpClient.send(request);
    final responseBody = await response.stream.toBytes();
    if (response.statusCode != 200) unexpectedResponse(response, responseBody);
    final responseString = utf8.decode(responseBody);
    final json = jsonDecode(responseString);
    return SyncRequestResponse.fromJson(json);
  }
}
