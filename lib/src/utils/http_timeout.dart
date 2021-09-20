/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2021 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';

import 'package:http/http.dart' as http;

import '../../matrix.dart';

/// Stream.timeout fails if no progress is made in timeLimit.
/// In contrast, streamTotalTimeout fails if the stream isn't completed
/// until timeoutFuture.
Stream<T> streamTotalTimeout<T>(
    Stream<T> stream, Future<Never> timeoutFuture) async* {
  final si = StreamIterator(stream);
  while (await Future.any([si.moveNext(), timeoutFuture])) {
    yield si.current;
  }
}

http.StreamedResponse replaceStream(
        http.StreamedResponse base, Stream<List<int>> stream) =>
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
    final timeoutFuture = Completer<Never>().future.timeout(timeout);
    final response = await Future.any([inner.send(request), timeoutFuture]);
    return replaceStream(
        response, streamTotalTimeout(response.stream, timeoutFuture));
  }
}

class FixedTimeoutHttpClient extends TimeoutHttpClient {
  FixedTimeoutHttpClient(http.Client inner, this.timeout) : super(inner);
  @override
  Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      super.send(request);
}

class VariableTimeoutHttpClient extends TimeoutHttpClient {
  /// Matrix synchronisation is done with https long polling. This needs a
  /// timeout which is usually 30 seconds.
  int syncTimeoutSec;

  int _timeoutFactor = 1;

  @override
  Duration get timeout =>
      Duration(seconds: _timeoutFactor * syncTimeoutSec + 5);

  VariableTimeoutHttpClient(http.Client inner, [this.syncTimeoutSec = 30])
      : super(inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request,
      {Duration? timeout}) async {
    try {
      final response = await super.send(request);
      return replaceStream(response, (() async* {
        try {
          await for (final chunk in response.stream) {
            yield chunk;
          }
          _timeoutFactor = 1;
        } on TimeoutException catch (e, s) {
          _timeoutFactor *= 2;
          throw MatrixConnectionException(e, s);
        } catch (e, s) {
          throw MatrixConnectionException(e, s);
        }
      })());
    } on TimeoutException catch (e, s) {
      _timeoutFactor *= 2;
      throw MatrixConnectionException(e, s);
    } catch (e, s) {
      throw MatrixConnectionException(e, s);
    }
  }
}
