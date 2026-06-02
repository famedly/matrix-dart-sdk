// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart';
import 'package:test/test.dart';

import 'fake_database.dart';

const _mxc = 'mxc://example.org/abcd1234';
const _encryptedMxc = 'mxc://example.com/file';
const _accessToken = 'test-token';
const _encryptedFileKey = '7aPRNIDPeUAUqD6SPR3vVX5W9liyMG98NexVJ9udnCc';
const _encryptedFileIv = 'Wdsf+tnOHIoAAAAAAAAAAA';
const _encryptedFileSha256 = 'WgC7fw2alBC5t+xDx+PFlZxfFJXtIstQCg+j0WDaXxE';

MatrixContentScannerConfig _config({
  bool withAuthHeader = true,
  bool scanBeforePreview = false,
}) =>
    MatrixContentScannerConfig(
      downloadUri: Uri.parse(
        'https://scanner.example/_matrix/media_proxy/unstable/download/',
      ),
      downloadThumbnailUri: Uri.parse(
        'https://scanner.example/_matrix/media_proxy/unstable/thumbnail/',
      ),
      downloadEncryptedUri: Uri.parse(
        'https://scanner.example/_matrix/media_proxy/unstable/download_encrypted',
      ),
      withAuthHeader: withAuthHeader,
      scanBeforePreview: scanBeforePreview,
    );

class _ScannerTestClient extends Client {
  _ScannerTestClient({
    required DatabaseApi database,
    required http.Client httpClient,
    MatrixContentScannerConfig? scanner,
    NativeImplementations nativeImplementations = NativeImplementations.dummy,
    this.encryptionEnabledForTest = false,
  }) : super(
          'scanner-test',
          database: database,
          httpClient: httpClient,
          contentScannerConfig: scanner,
          nativeImplementations: nativeImplementations,
        );

  final bool encryptionEnabledForTest;

  @override
  bool get encryptionEnabled => encryptionEnabledForTest;
}

Future<Client> _freshClient({
  required http.Client httpClient,
  MatrixContentScannerConfig? scanner,
  NativeImplementations nativeImplementations = NativeImplementations.dummy,
  bool encryptionEnabled = false,
}) async {
  final client = _ScannerTestClient(
    database: await getDatabase(),
    httpClient: httpClient,
    scanner: scanner,
    nativeImplementations: nativeImplementations,
    encryptionEnabledForTest: encryptionEnabled,
  );
  client.accessToken = _accessToken;
  return client;
}

class _DecryptingNativeImplementations extends NativeImplementationsDummy {
  _DecryptingNativeImplementations({
    required this.expectedEncryptedBytes,
    required this.decryptedBytes,
  });

  final Uint8List expectedEncryptedBytes;
  final Uint8List decryptedBytes;
  EncryptedFile? seenFile;

  @override
  Future<Uint8List?> decryptFile(
    EncryptedFile file, {
    bool retryInDummy = true,
  }) async {
    seenFile = file;
    return _bytesEqual(file.data, expectedEncryptedBytes) &&
            file.k == _encryptedFileKey &&
            file.iv == _encryptedFileIv &&
            file.sha256 == _encryptedFileSha256
        ? decryptedBytes
        : null;
  }
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void main() {
  Logs().level = Level.error;

  group('MatrixContentScannerConfig', () {
    test('fromJson / toJson roundtrip', () {
      final json = {
        'download_uri':
            'https://scanner.example/_matrix/media_proxy/unstable/download/',
        'download_thumbnail_uri':
            'https://scanner.example/_matrix/media_proxy/unstable/thumbnail/',
        'download_encrypted':
            'https://scanner.example/_matrix/media_proxy/unstable/download_encrypted',
        'with_auth_header': true,
        'scan_before_preview': true,
      };
      final cfg = MatrixContentScannerConfig.fromJson(json);
      expect(cfg.downloadUri.toString(), json['download_uri']);
      expect(
        cfg.downloadThumbnailUri.toString(),
        json['download_thumbnail_uri'],
      );
      expect(cfg.downloadEncryptedUri.toString(), json['download_encrypted']);
      expect(cfg.withAuthHeader, true);
      expect(cfg.scanBeforePreview, true);
      expect(cfg.toJson(), json);
    });

    test('fromJson defaults optional flags', () {
      final cfg = MatrixContentScannerConfig.fromJson({
        'download_uri': 'https://s.example/download/',
        'download_thumbnail_uri': 'https://s.example/thumbnail/',
        'download_encrypted': 'https://s.example/download_encrypted',
      });
      expect(cfg.withAuthHeader, true);
      expect(cfg.scanBeforePreview, false);
    });

    test('ensures trailing slash on base URIs', () {
      final cfg = MatrixContentScannerConfig(
        downloadUri: Uri.parse('https://s.example/download'),
        downloadThumbnailUri: Uri.parse('https://s.example/thumb'),
        downloadEncryptedUri: Uri.parse('https://s.example/download_encrypted'),
      );
      expect(cfg.downloadUri.toString(), 'https://s.example/download/');
      expect(cfg.downloadThumbnailUri.toString(), 'https://s.example/thumb/');
    });
  });

  group('URI routing', () {
    test('getDownloadUri routes through scanner when config is set', () async {
      final client = await _freshClient(
        httpClient: MockClient((_) async => http.Response('', 404)),
        scanner: _config(),
      );
      final uri = await Uri.parse(_mxc).getDownloadUri(client);
      expect(
        uri.toString(),
        'https://scanner.example/_matrix/media_proxy/unstable/download/example.org/abcd1234',
      );
      await client.dispose(closeDatabase: true);
    });

    test('getThumbnailUri routes through scanner and preserves query params',
        () async {
      final client = await _freshClient(
        httpClient: MockClient((_) async => http.Response('', 404)),
        scanner: _config(),
      );
      final uri = await Uri.parse(_mxc).getThumbnailUri(
        client,
        width: 80,
        height: 60,
        method: ThumbnailMethod.scale,
        animated: true,
      );
      expect(
        uri.toString(),
        'https://scanner.example/_matrix/media_proxy/unstable/thumbnail/example.org/abcd1234'
        '?width=80&height=60&method=scale&animated=true',
      );
      await client.dispose(closeDatabase: true);
    });

    test('getDownloadUri preserves MXC port in server part', () async {
      final client = await _freshClient(
        httpClient: MockClient((_) async => http.Response('', 404)),
        scanner: _config(),
      );
      final uri = await Uri.parse('mxc://example.org:8448/media123')
          .getDownloadUri(client);
      expect(
        uri.toString(),
        'https://scanner.example/_matrix/media_proxy/unstable/download/example.org:8448/media123',
      );
      await client.dispose(closeDatabase: true);
    });
  });

  group('ContentScannerException', () {
    test('parses reason and info from JSON error body', () {
      final resp = http.Response(
        jsonEncode({'reason': 'MCS_MEDIA_NOT_CLEAN', 'info': '***VIRUS***'}),
        403,
      );
      final ex = parseContentScannerError(resp);
      expect(ex.reason, 'MCS_MEDIA_NOT_CLEAN');
      expect(ex.info, '***VIRUS***');
      expect(ex.statusCode, 403);
      expect(
        ex.toString(),
        contains('ContentScannerException(403 MCS_MEDIA_NOT_CLEAN)'),
      );
    });

    test('falls back to M_UNKNOWN on non-JSON body', () {
      final resp = http.Response('<html>500</html>', 500, reasonPhrase: 'oops');
      final ex = parseContentScannerError(resp);
      expect(ex.reason, 'M_UNKNOWN');
      expect(ex.info, 'oops');
      expect(ex.statusCode, 500);
    });

    test('accepts Matrix-style {errcode, error} shape for router 404s', () {
      final resp = http.Response(
        jsonEncode({
          'errcode': 'M_UNRECOGNIZED',
          'error': 'Unrecognized request',
        }),
        404,
      );
      final ex = parseContentScannerError(resp);
      expect(ex.reason, 'M_UNRECOGNIZED');
      expect(ex.info, 'Unrecognized request');
      expect(ex.statusCode, 404);
    });
  });

  group('downloadAndDecryptAttachment + scanner', () {
    Event buildEncryptedEvent(Room room) => Event.fromJson(
          {
            'type': EventTypes.Message,
            'event_id': '\$evt1',
            'sender': '@alice:example.org',
            'origin_server_ts': 0,
            'content': {
              'msgtype': 'm.file',
              'body': 'secret.bin',
              'filename': 'secret.bin',
              'info': {'mimetype': 'application/octet-stream', 'size': 5},
              'file': {
                'v': 'v2',
                'url': _encryptedMxc,
                'key': {
                  'alg': 'A256CTR',
                  'ext': true,
                  'key_ops': ['encrypt', 'decrypt'],
                  'kty': 'oct',
                  'k': _encryptedFileKey,
                },
                'iv': _encryptedFileIv,
                'hashes': {'sha256': _encryptedFileSha256},
              },
            },
          },
          room,
        );

    test('POSTs to download_encrypted with file JSON and auth header',
        () async {
      http.Request? seenRequest;
      final mockHttp = MockClient((req) async {
        seenRequest = req;
        return http.Response(
          jsonEncode({'reason': 'MCS_MEDIA_REQUEST_FAILED', 'info': 'boom'}),
          502,
        );
      });
      final client = await _freshClient(
        httpClient: mockHttp,
        scanner: _config(),
        encryptionEnabled: true,
      );
      final room = Room(id: '!room:example.org', client: client);
      final event = buildEncryptedEvent(room);

      await expectLater(
        event.downloadAndDecryptAttachment(),
        throwsA(isA<ContentScannerException>()),
      );

      expect(seenRequest, isNotNull);
      expect(seenRequest!.method, 'POST');
      expect(
        seenRequest!.url.toString(),
        'https://scanner.example/_matrix/media_proxy/unstable/download_encrypted',
      );
      expect(seenRequest!.headers['content-type'], 'application/json');
      expect(seenRequest!.headers['authorization'], 'Bearer $_accessToken');
      final body = jsonDecode(seenRequest!.body) as Map<String, Object?>;
      final fileMap = body['file'] as Map<String, Object?>;
      expect(fileMap['url'], _encryptedMxc);
      expect(fileMap['iv'], _encryptedFileIv);
      expect(fileMap['v'], 'v2');

      await client.dispose(closeDatabase: true);
    });

    test('decrypts encrypted bytes returned by download_encrypted', () async {
      http.Request? seenRequest;
      final encryptedBytes = Uint8List.fromList([0x3B, 0x6B, 0xB2, 0x8C, 0xAF]);
      final decryptedBytes = Uint8List.fromList([0x74, 0x65, 0x73, 0x74, 0x0A]);
      final nativeImplementations = _DecryptingNativeImplementations(
        expectedEncryptedBytes: encryptedBytes,
        decryptedBytes: decryptedBytes,
      );
      final mockHttp = MockClient((req) async {
        seenRequest = req;
        return http.Response.bytes(encryptedBytes, 200);
      });
      final client = await _freshClient(
        httpClient: mockHttp,
        scanner: _config(),
        nativeImplementations: nativeImplementations,
        encryptionEnabled: true,
      );
      final room = Room(id: '!room:example.org', client: client);
      final event = buildEncryptedEvent(room);

      final file = await event.downloadAndDecryptAttachment();

      expect(file.bytes, decryptedBytes);
      expect(seenRequest!.method, 'POST');
      expect(
        seenRequest!.url.toString(),
        'https://scanner.example/_matrix/media_proxy/unstable/download_encrypted',
      );
      expect(seenRequest!.headers['content-type'], 'application/json');
      expect(seenRequest!.headers['authorization'], 'Bearer $_accessToken');
      final body = jsonDecode(seenRequest!.body) as Map<String, Object?>;
      final fileMap = body['file'] as Map<String, Object?>;
      expect(fileMap['url'], _encryptedMxc);
      expect(fileMap['iv'], _encryptedFileIv);
      expect(fileMap['hashes'], {'sha256': _encryptedFileSha256});
      expect(nativeImplementations.seenFile, isNotNull);
      expect(nativeImplementations.seenFile!.data, encryptedBytes);
      expect(nativeImplementations.seenFile!.k, _encryptedFileKey);
      expect(nativeImplementations.seenFile!.iv, _encryptedFileIv);
      expect(nativeImplementations.seenFile!.sha256, _encryptedFileSha256);

      await client.dispose(closeDatabase: true);
    });

    test('omits Authorization when withAuthHeader is false', () async {
      http.Request? seenRequest;
      final mockHttp = MockClient((req) async {
        seenRequest = req;
        return http.Response(
          jsonEncode({'reason': 'MCS_MEDIA_REQUEST_FAILED', 'info': 'boom'}),
          502,
        );
      });
      final client = await _freshClient(
        httpClient: mockHttp,
        scanner: _config(withAuthHeader: false),
        encryptionEnabled: true,
      );
      final room = Room(id: '!room:example.org', client: client);
      final event = buildEncryptedEvent(room);

      await expectLater(
        event.downloadAndDecryptAttachment(),
        throwsA(isA<ContentScannerException>()),
      );
      expect(seenRequest!.headers.containsKey('authorization'), false);

      await client.dispose(closeDatabase: true);
    });

    test('unencrypted file GETs scanner download URL with auth header',
        () async {
      http.BaseRequest? seenRequest;
      final payload = Uint8List.fromList([7, 7, 7]);
      final mockHttp = MockClient((req) async {
        seenRequest = req;
        return http.Response.bytes(payload, 200);
      });
      final client = await _freshClient(
        httpClient: mockHttp,
        scanner: _config(),
      );
      final room = Room(id: '!room:example.org', client: client);
      final event = Event.fromJson(
        {
          'type': EventTypes.Message,
          'event_id': '\$evt2',
          'sender': '@alice:example.org',
          'origin_server_ts': 0,
          'content': {
            'msgtype': 'm.file',
            'body': 'note.txt',
            'filename': 'note.txt',
            'info': {'mimetype': 'text/plain', 'size': 3},
            'url': _mxc,
          },
        },
        room,
      );

      final file = await event.downloadAndDecryptAttachment();
      expect(file.bytes, payload);
      expect(seenRequest!.method, 'GET');
      expect(
        seenRequest!.url.toString(),
        'https://scanner.example/_matrix/media_proxy/unstable/download/example.org/abcd1234',
      );
      expect(seenRequest!.headers['authorization'], 'Bearer $_accessToken');

      await client.dispose(closeDatabase: true);
    });

    test('unencrypted file omits Authorization when withAuthHeader is false',
        () async {
      http.BaseRequest? seenRequest;
      final payload = Uint8List.fromList([7, 7, 7]);
      final mockHttp = MockClient((req) async {
        seenRequest = req;
        return http.Response.bytes(payload, 200);
      });
      final client = await _freshClient(
        httpClient: mockHttp,
        scanner: _config(withAuthHeader: false),
      );
      final room = Room(id: '!room:example.org', client: client);
      final event = Event.fromJson(
        {
          'type': EventTypes.Message,
          'event_id': '\$evt3',
          'sender': '@alice:example.org',
          'origin_server_ts': 0,
          'content': {
            'msgtype': 'm.file',
            'body': 'note.txt',
            'filename': 'note.txt',
            'info': {'mimetype': 'text/plain', 'size': 3},
            'url': _mxc,
          },
        },
        room,
      );

      final file = await event.downloadAndDecryptAttachment();
      expect(file.bytes, payload);
      expect(seenRequest!.method, 'GET');
      expect(seenRequest!.headers.containsKey('authorization'), false);

      await client.dispose(closeDatabase: true);
    });

    test('unencrypted non-2xx response throws ContentScannerException',
        () async {
      final mockHttp = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'reason': 'MCS_MEDIA_NOT_CLEAN',
            'info': 'virus detected',
          }),
          403,
        );
      });
      final client = await _freshClient(
        httpClient: mockHttp,
        scanner: _config(),
      );
      final room = Room(id: '!room:example.org', client: client);
      final event = Event.fromJson(
        {
          'type': EventTypes.Message,
          'event_id': '\$evt4',
          'sender': '@alice:example.org',
          'origin_server_ts': 0,
          'content': {
            'msgtype': 'm.file',
            'body': 'note.txt',
            'filename': 'note.txt',
            'info': {'mimetype': 'text/plain', 'size': 3},
            'url': _mxc,
          },
        },
        room,
      );

      await expectLater(
        event.downloadAndDecryptAttachment(),
        throwsA(
          isA<ContentScannerException>()
              .having((e) => e.reason, 'reason', 'MCS_MEDIA_NOT_CLEAN')
              .having((e) => e.info, 'info', 'virus detected')
              .having((e) => e.statusCode, 'statusCode', 403),
        ),
      );

      await client.dispose(closeDatabase: true);
    });

    test('non-2xx response throws ContentScannerException', () async {
      final nativeImplementations = _DecryptingNativeImplementations(
        expectedEncryptedBytes: Uint8List.fromList([1, 2, 3]),
        decryptedBytes: Uint8List.fromList([4, 5, 6]),
      );
      final mockHttp = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'reason': 'MCS_MEDIA_NOT_CLEAN',
            'info': 'virus detected',
          }),
          403,
        );
      });
      final client = await _freshClient(
        httpClient: mockHttp,
        scanner: _config(),
        nativeImplementations: nativeImplementations,
        encryptionEnabled: true,
      );
      final room = Room(id: '!room:example.org', client: client);
      final event = buildEncryptedEvent(room);

      await expectLater(
        event.downloadAndDecryptAttachment(),
        throwsA(
          isA<ContentScannerException>()
              .having((e) => e.reason, 'reason', 'MCS_MEDIA_NOT_CLEAN')
              .having((e) => e.info, 'info', 'virus detected')
              .having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
      expect(nativeImplementations.seenFile, isNull);

      await client.dispose(closeDatabase: true);
    });
  });
}
