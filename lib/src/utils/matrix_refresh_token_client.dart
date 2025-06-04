import 'package:http/http.dart' hide Client;

import 'package:matrix/matrix.dart';

/// a [BaseClient] implementation handling [Client.onSoftLogout]
///
/// This client wrapper takes matrix [Client] as parameter and handles token
/// rotation.
///
/// Before dispatching any request, it will check whether the [Client] supports
/// token refresh by checking [Client.accessTokenExpiresAt]. Token rotation is
/// done when :
/// - refresh is supported ([Client.accessTokenExpiresAt])
/// - we are actually initialized ([Client.onSync.value])
/// - the request is to the homeserver rather than e.g. IDP ([BaseRequest.url])
/// - the request is authenticated ([BaseRequest.headers])
/// - we're logged in ([Client.isLogged])
///
/// In this case, [Client.ensureNotSoftLoggedOut] is awaited before running
/// [BaseClient.send]. If the [Client.bearerToken] was changed meanwhile,
/// the [BaseRequest] is being adjusted.
class MatrixRefreshTokenClient extends BaseClient {
  MatrixRefreshTokenClient({
    required this.inner,
    required this.client,
  });

  /// the matrix [Client] to handle token rotation for
  final Client client;

  /// the inner [BaseClient] to dispatch requests with
  final BaseClient inner;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    Request? req;
    if ( // only refresh if
        // refresh is supported
        client.accessTokenExpiresAt != null &&
            // we are actually initialized
            client.onSync.value != null &&
            // the request is to the homeserver rather than e.g. IDP
            request.url.host == client.homeserver?.host &&
            // the request is authenticated
            request.headers
                .map((k, v) => MapEntry(k.toLowerCase(), v))
                .containsKey('authorization') &&
            // and last but not least we're logged in
            client.isLogged()) {
      try {
        await client.ensureNotSoftLoggedOut();
      } catch (e) {
        Logs().w('Could not rotate token before dispatching HTTP request.', e);
      }
      // in every case ensure we run with the latest bearer token to avoid
      // race conditions
      finally {
        final headers = request.headers;
        // hours wasted : unknown :facepalm:
        headers.removeWhere((k, _) => k.toLowerCase() == 'authorization');
        headers['Authorization'] = 'Bearer ${client.bearerToken!}';
        req = Request(request.method, request.url);
        req.headers.addAll(headers);
        if (request is Request) {
          req.bodyBytes = request.bodyBytes;
        }
      }
    }
    return inner.send(req ?? request);
  }
}
