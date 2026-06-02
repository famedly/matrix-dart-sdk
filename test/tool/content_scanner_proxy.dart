#!/usr/bin/env dart
// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

// ignore_for_file: avoid_print

// Starts a local scanner proxy and runs an encrypted Matrix media smoke test
// using the real SDK Client. The test exercises MatrixContentScannerConfig and
// downloadAndDecryptAttachment against /download_encrypted on a live scanner.
//
// The password is used only for SDK login. It is not written to disk or passed
// to Docker.
//
// Optional environment variables:
//   CONTENT_SCANNER_HOMESERVER=https://example.invalid
//   CONTENT_SCANNER_PORT=18083
//   CONTENT_SCANNER_CONTAINER=mcs-proxy
//   CONTENT_SCANNER_IMAGE=vectorim/matrix-content-scanner:v1.3.0
//   CONTENT_SCANNER_DOCKER_DNS=9.9.9.9,1.1.1.1
//   CONTENT_SCANNER_DATA_DIR=/tmp/mcs-proxy
//   CONTENT_SCANNER_VERBOSE=true
//   MATRIX_USER_ID=test-user
//   MATRIX_PASSWORD=...
//   CONTENT_SCANNER_ROOM_ID=!room:example.invalid
//
// Usage:
//   dart tool/content_scanner_proxy.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as path_joiner;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

const _defaultPort = '8080';
const _defaultContainerName = 'mcs-proxy';
const _defaultImage = 'vectorim/matrix-content-scanner:v1.3.0';

Future<void> main() async {
  try {
    await _run();
  } catch (e) {
    stderr.writeln('ERROR: $e');
    exitCode = 1;
  }
}

Future<void> _run() async {
  final homeserverInput = _homeserverFromEnvOrPrompt();
  final userId = _userIdFromEnvOrPrompt();
  final password = _passwordFromEnvOrPrompt();
  final port = Platform.environment['CONTENT_SCANNER_PORT'] ?? _defaultPort;
  final containerName = Platform.environment['CONTENT_SCANNER_CONTAINER'] ??
      _defaultContainerName;
  final image = Platform.environment['CONTENT_SCANNER_IMAGE'] ?? _defaultImage;

  final mcsData = _mcsDataDirectory(containerName);
  final baseUrl = 'http://localhost:$port/_matrix/media_proxy/unstable';

  print('=== matrix-content-scanner SDK integration smoke test ===\n');

  await _preflightHomeserver(homeserverInput);

  // Init Vodozemac before creating the client so encryption is available for
  // encrypted rooms. Aborts if init fails — encrypted rooms require it.
  await _initVodozemac();

  // Create SDK Client with in-memory DB (maxFileSize: 0 so every download must
  // hit the scanner — no cache bypass).
  final tmpDbDir = await Directory(
    path_joiner.join(
      Directory.systemTemp.path,
      'mcs-smoke-${DateTime.now().microsecondsSinceEpoch}',
    ),
  ).create(recursive: true);
  sqfliteFfiInit();
  final db = await MatrixSdkDatabase.init(
    'scanner-smoke',
    database: await databaseFactoryFfi.openDatabase(
      ':memory:',
      options: OpenDatabaseOptions(singleInstance: false),
    ),
    sqfliteFactory: databaseFactoryFfi,
    fileStorageLocation: tmpDbDir.uri,
    maxFileSize: 0,
  );

  final scannerConfig = MatrixContentScannerConfig(
    downloadUri: Uri.parse('$baseUrl/download/'),
    downloadThumbnailUri: Uri.parse('$baseUrl/thumbnail/'),
    downloadEncryptedUri: Uri.parse('$baseUrl/download_encrypted'),
    withAuthHeader: true,
  );

  final client = Client(
    'scanner-smoke',
    database: db,
    contentScannerConfig: scannerConfig,
  );

  try {
    // Resolve homeserver via SDK (well-known skipped: tool takes concrete URL).
    await client.checkHomeserver(
      Uri.parse(homeserverInput),
      checkWellKnown: false,
    );
    final resolvedHomeserver = client.homeserver!.toString();

    // Write scanner config.yaml using the SDK-resolved homeserver URL.
    await _ensureMcsData(mcsData, resolvedHomeserver);
    print('Scanner data directory: ${mcsData.path}');

    await _replaceContainer(
      containerName: containerName,
      image: image,
      port: port,
      mcsData: mcsData,
    );
    await _waitForScanner(baseUrl);

    print('Proxy is running as container `$containerName`.\n');
    print('Use this SDK config:');
    print('''
contentScannerConfig: MatrixContentScannerConfig(
  downloadUri: Uri.parse('$baseUrl/download/'),
  downloadThumbnailUri: Uri.parse('$baseUrl/thumbnail/'),
  downloadEncryptedUri: Uri.parse('$baseUrl/download_encrypted'),
  withAuthHeader: true,
),''');
    print('\nStop it with: docker stop $containerName');

    print('\nLogging in as $userId...');
    await client.login(
      LoginType.mLoginPassword,
      identifier: AuthenticationUserIdentifier(user: userId),
      password: password,
    );
    print('Logged in as ${client.userID}.');

    final room = await _pickRoom(client);
    if (room == null) {
      print('\nNo encrypted room selected; proxy is still running.');
      return;
    }

    await _runEncryptedSmokeTest(client: client, room: room);
  } finally {
    try {
      await client.logout();
      print('Logged out test session.');
    } catch (_) {}
    await client.dispose(closeDatabase: true);
    try {
      await tmpDbDir.delete(recursive: true);
    } catch (_) {}
    await _printScannerLogs(containerName);
  }
}

Future<void> _initVodozemac() async {
  try {
    await vod.init(
      wasmPath: './pkg/',
      libraryPath: './rust/target/debug/',
    );
    print('Vodozemac initialised (encryption available).');
  } catch (e) {
    throw Exception('Vodozemac init failed: $e');
  }
}

Future<Room?> _pickRoom(Client client) async {
  final fromEnv = Platform.environment['CONTENT_SCANNER_ROOM_ID']?.trim();
  if (fromEnv != null && fromEnv.isNotEmpty) {
    final room = client.getRoomById(fromEnv);
    if (room == null) {
      _die('CONTENT_SCANNER_ROOM_ID "$fromEnv" not found in joined rooms.');
    }
    if (!room.encrypted) {
      _die('CONTENT_SCANNER_ROOM_ID "$fromEnv" is not an encrypted room.');
    }
    return room;
  }

  if (!stdin.hasTerminal) return null;

  final rooms = client.rooms.where((room) => room.encrypted).toList()
    ..sort((a, b) => (a.displayname).compareTo(b.displayname));

  if (rooms.isEmpty) {
    print('No encrypted joined rooms found after sync.');
    return null;
  }

  print('\nChoose an encrypted room to send a test m.file event:');
  for (var i = 0; i < rooms.length; i++) {
    final r = rooms[i];
    print('  ${i + 1}. ${r.displayname} (${r.id}) [encrypted]');
  }
  stdout.write('Room number or room ID (Enter to skip): ');
  final choice = stdin.readLineSync()?.trim();
  if (choice == null || choice.isEmpty) return null;

  final selectedIndex = int.tryParse(choice);
  if (selectedIndex != null &&
      selectedIndex >= 1 &&
      selectedIndex <= rooms.length) {
    return rooms[selectedIndex - 1];
  }
  final room = client.getRoomById(choice);
  if (room != null && !room.encrypted) {
    _die('Room "$choice" is not encrypted.');
  }
  return room;
}

Future<void> _runEncryptedSmokeTest({
  required Client client,
  required Room room,
}) async {
  print('\n--- Encrypted room smoke test ---');

  if (!client.encryptionEnabled) {
    _die(
      'Room is encrypted but client.encryptionEnabled is false. '
      'Ensure Vodozemac initialised correctly.',
    );
  }

  final plaintext = Uint8List.fromList(_testPayload());
  const filename = 'content-scanner-smoke-enc.bin';
  const contentType = 'application/octet-stream';

  print('Encrypting test file...');
  final encrypted =
      await MatrixFile(bytes: plaintext, name: filename).encrypt();

  print('Uploading encrypted bytes via client.uploadContent...');
  final mxc = await client.uploadContent(
    encrypted.data,
    filename: 'crypt',
    contentType: 'application/octet-stream',
  );
  print('  mxc: $mxc');

  final fileMap = <String, Object?>{
    'v': 'v2',
    'url': mxc.toString(),
    'mimetype': contentType,
    'key': {
      'alg': 'A256CTR',
      'ext': true,
      'k': encrypted.k,
      'key_ops': ['encrypt', 'decrypt'],
      'kty': 'oct',
    },
    'iv': encrypted.iv,
    'hashes': {'sha256': encrypted.sha256},
  };

  print('Sending m.file event with encrypted file map...');
  final eventId = await room.sendEvent(
    {
      'msgtype': 'm.file',
      'body': filename,
      'filename': filename,
      'file': fileMap,
      'info': {'mimetype': contentType, 'size': plaintext.length},
    },
    displayPendingEvent: false,
  );
  if (eventId == null) _die('room.sendEvent returned null — send failed.');
  print('  event_id: $eventId');

  print('Downloading via event.downloadAndDecryptAttachment (SDK path)...');
  final event = Event.fromJson(
    {
      'type': EventTypes.Message,
      'event_id': eventId,
      'sender': client.userID,
      'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
      'content': {
        'msgtype': 'm.file',
        'body': filename,
        'file': fileMap,
        'info': {'mimetype': contentType, 'size': plaintext.length},
      },
    },
    room,
  );
  final downloaded = await event.downloadAndDecryptAttachment();

  if (!_bytesEqual(plaintext, downloaded.bytes)) {
    _die(
      'Decrypted bytes do not match original plaintext '
      '(${downloaded.bytes.length} != ${plaintext.length}).',
    );
  }

  print(
    'Smoke test passed: ${downloaded.bytes.length} bytes via scanner POST /download_encrypted.',
  );
}

List<int> _testPayload() {
  final random = Random.secure();
  final randomBytes = List<int>.generate(24, (_) => random.nextInt(256));
  final body = [
    'matrix-dart-sdk content scanner SDK smoke test',
    'created_at: ${DateTime.now().toUtc().toIso8601String()}',
    'random_base64: ${base64Encode(randomBytes)}',
    '',
  ].join('\n');
  return utf8.encode(body);
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// Infrastructure (unchanged from original)
// ---------------------------------------------------------------------------

Future<void> _preflightHomeserver(String homeserverUrl) async {
  final homeserver = Uri.parse(homeserverUrl);
  if (!homeserver.hasScheme || homeserver.host.isEmpty) {
    _die('Invalid CONTENT_SCANNER_HOMESERVER: $homeserverUrl');
  }

  try {
    final addresses = await InternetAddress.lookup(homeserver.host);
    if (addresses.isEmpty) {
      _die('Could not resolve ${homeserver.host}. Connect VPN/internal DNS.');
    }
  } on SocketException catch (e) {
    _die(
      'Could not resolve ${homeserver.host}. Connect VPN/internal DNS, then '
      'rerun this script.\n$e',
    );
  }
}

Future<void> _ensureMcsData(Directory mcsData, String homeserver) async {
  await mcsData.create(recursive: true);
  await Process.run('chmod', ['700', mcsData.path]);

  final tmpDir = Directory('${mcsData.path}/tmp');
  await tmpDir.create(recursive: true);

  await File('${mcsData.path}/config.yaml').writeAsString('''
web:
  host: 0.0.0.0
  port: 8080

scan:
  script: /data/scan.sh
  temp_directory: /data/tmp
  removal_command: rm

download:
  base_homeserver_url: "$homeserver"

crypto:
  request_secret_path: /data/request_secret

result_cache:
  max_size: 128
  ttl: "10m"
''');

  final scanScript = File('${mcsData.path}/scan.sh');
  await scanScript.writeAsString('''
#!/bin/sh
exit 0
''');
  await Process.run('chmod', ['+x', scanScript.path]);

  final secret = File('${mcsData.path}/request_secret');
  if (!await secret.exists()) {
    await secret.writeAsString('${_generateRequestSecret()}\n');
  }
}

String _generateRequestSecret() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Encode(bytes);
}

Directory _mcsDataDirectory(String containerName) {
  final configured = Platform.environment['CONTENT_SCANNER_DATA_DIR']?.trim();
  if (configured != null && configured.isNotEmpty) {
    return Directory(configured);
  }

  final safeContainerName = containerName.replaceAll(
    RegExp(r'[^a-zA-Z0-9_.-]'),
    '_',
  );
  return Directory(
    '${Directory.systemTemp.path}/matrix-dart-sdk-$safeContainerName',
  );
}

Future<void> _replaceContainer({
  required String containerName,
  required String image,
  required String port,
  required Directory mcsData,
}) async {
  await Process.run('docker', ['rm', '-f', containerName]);

  print('Starting scanner container...');
  final result = await Process.run('docker', [
    'run',
    '--rm',
    '--name',
    containerName,
    '--platform',
    'linux/amd64',
    ..._dockerDnsArgs(),
    '-d',
    '-p',
    '$port:8080',
    '-v',
    '${mcsData.path}:/data',
    image,
  ]);
  if (result.exitCode != 0) {
    _die('docker run failed:\n${result.stderr}');
  }
}

Future<void> _waitForScanner(String baseUrl) async {
  print('Waiting for scanner to be ready...');
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(const Duration(seconds: 1));
    try {
      final response = await _getText('$baseUrl/public_key');
      if (response.statusCode == 200) {
        print('Scanner ready.\n');
        return;
      }
    } catch (_) {}
  }
  _die('Scanner did not become healthy within 30 s');
}

String _homeserverFromEnvOrPrompt() {
  final fromEnv = Platform.environment['CONTENT_SCANNER_HOMESERVER']?.trim();
  final input = fromEnv != null && fromEnv.isNotEmpty
      ? fromEnv
      : _prompt('Homeserver URL');
  return _normalizeHomeserver(input);
}

String _userIdFromEnvOrPrompt() {
  final fromEnv = Platform.environment['MATRIX_USER_ID']?.trim();
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  return _prompt('User ID or localpart');
}

String _passwordFromEnvOrPrompt() {
  final fromEnv = Platform.environment['MATRIX_PASSWORD'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  return _promptPassword('Password');
}

String _prompt(String label) {
  if (!stdin.hasTerminal) {
    _die(
      '$label is required. Provide it via environment variable in '
      'non-interactive mode.',
    );
  }

  stdout.write('$label: ');
  final input = stdin.readLineSync()?.trim() ?? '';
  if (input.isEmpty) _die('$label is required.');
  return input;
}

String _promptPassword(String label) {
  if (!stdin.hasTerminal) {
    _die(
      '$label is required. Provide MATRIX_PASSWORD in non-interactive mode.',
    );
  }

  stdout.write('$label: ');
  _setTerminalEcho(enabled: false);
  late final String input;
  try {
    input = stdin.readLineSync() ?? '';
  } finally {
    _setTerminalEcho(enabled: true);
    stdout.writeln();
  }
  if (input.isEmpty) _die('$label is required.');
  return input;
}

void _setTerminalEcho({required bool enabled}) {
  if (!stdin.hasTerminal) return;
  Process.runSync('stty', [enabled ? 'echo' : '-echo']);
}

String _normalizeHomeserver(String homeserver) {
  final trimmed = homeserver.trim();
  final withScheme =
      trimmed.startsWith('http://') || trimmed.startsWith('https://')
          ? trimmed
          : 'https://$trimmed';
  return withScheme.endsWith('/')
      ? withScheme.substring(0, withScheme.length - 1)
      : withScheme;
}

Future<_Response> _getText(String url) async {
  final httpClient = HttpClient();
  try {
    final request = await httpClient.getUrl(Uri.parse(url));
    final response = await request.close();
    return _Response(response.statusCode, await _readBody(response));
  } finally {
    httpClient.close();
  }
}

Future<List<int>> _readBody(HttpClientResponse response) async {
  final body = <int>[];
  await for (final chunk in response) {
    body.addAll(chunk);
  }
  return body;
}

List<String> _dockerDnsArgs() {
  final configured = Platform.environment['CONTENT_SCANNER_DOCKER_DNS'];
  if (configured == null || configured.trim().isEmpty) return const [];

  final args = <String>[];
  for (final dns in configured.split(',')) {
    final trimmed = dns.trim();
    if (trimmed.isEmpty) continue;
    args
      ..add('--dns')
      ..add(trimmed);
  }
  return args;
}

Future<void> _printScannerLogs(String containerName) async {
  if (!_verboseLogsEnabled()) return;

  final result = await Process.run('docker', [
    'logs',
    '--tail',
    '200',
    containerName,
  ]);
  if (result.exitCode != 0) {
    print('\nCould not read scanner logs:\n${result.stderr}');
    return;
  }

  final stdoutText = (result.stdout as String).trim();
  final stderrText = (result.stderr as String).trim();
  final logs = [
    if (stdoutText.isNotEmpty) stdoutText,
    if (stderrText.isNotEmpty) stderrText,
  ].join('\n');

  print('\n--- scanner container logs: $containerName ---');
  if (logs.isEmpty) {
    print('(no logs yet)');
  } else {
    print(logs);
  }
  print('--- end scanner container logs ---');
}

bool _verboseLogsEnabled() {
  final configured = Platform.environment['CONTENT_SCANNER_VERBOSE'];
  if (configured == null || configured.trim().isEmpty) return true;
  return !{'0', 'false', 'no', 'off'}.contains(configured.toLowerCase().trim());
}

Never _die(String message) => throw Exception(message);

class _Response {
  final int statusCode;
  final List<int> bodyBytes;

  const _Response(this.statusCode, this.bodyBytes);

  String get body => utf8.decode(bodyBytes, allowMalformed: true);
}
