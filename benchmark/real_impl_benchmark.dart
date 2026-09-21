// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

/// Benchmarks the real `MatrixSdkDatabase` through its public API, so the
/// numbers reflect the shipped code rather than a hand-rolled model of it.
/// Uses only the surface both candidate branches share, so the same file runs
/// unchanged on either.
///
/// Run with: dart run benchmark/real_impl_benchmark.dart
library;

import 'dart:io';

import 'package:canonical_json/canonical_json.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:matrix/matrix.dart';

class UserFixture {
  final String userId;
  final Map<String, Map<String, Object?>> devices;
  final Map<String, Map<String, Object?>> crossSigning;
  UserFixture(this.userId, this.devices, this.crossSigning);
}

Map<String, Object?> _selfSign(
  vod.Account account,
  Map<String, Object?> payload,
  String userId,
  String keyId,
) {
  final signature = account
      .sign(String.fromCharCodes(canonicalJson.encode(payload)))
      .toBase64();
  return {
    ...payload,
    'signatures': {
      userId: {'ed25519:$keyId': signature},
    },
  };
}

List<UserFixture> buildFixtures({
  required int userCount,
  required int devicesPerUser,
}) {
  final pool = List.generate(8, (_) => vod.Account());
  return List.generate(userCount, (u) {
    final userId = '@user$u:example.com';
    final devices = <String, Map<String, Object?>>{};
    for (var d = 0; d < devicesPerUser; d++) {
      final account = pool[(u + d) % pool.length];
      final identity = account.identityKeys;
      final deviceId = 'DEVICE${u}_$d';
      devices[deviceId] = _selfSign(account, {
        'user_id': userId,
        'device_id': deviceId,
        'algorithms': [
          AlgorithmTypes.olmV1Curve25519AesSha2,
          AlgorithmTypes.megolmV1AesSha2,
        ],
        'keys': {
          'curve25519:$deviceId': identity.curve25519.toBase64(),
          'ed25519:$deviceId': identity.ed25519.toBase64(),
        },
      }, userId, deviceId);
    }
    final crossSigning = <String, Map<String, Object?>>{};
    for (final usage in ['master', 'self_signing', 'user_signing']) {
      final pub =
          '${pool[(u + usage.length) % pool.length].identityKeys.ed25519.toBase64()}${usage[0]}';
      crossSigning[pub] = {
        'user_id': userId,
        'usage': [usage],
        'keys': {'ed25519:$pub': pub},
        'signatures': <String, Object?>{},
      };
    }
    return UserFixture(userId, devices, crossSigning);
  });
}

/// Hydrates the fixtures into the in-memory shape the SDK keeps on the client,
/// which is what every write path actually persists from.
Map<String, DeviceKeysList> buildLists(
  List<UserFixture> fixtures,
  Client client,
) {
  final lists = <String, DeviceKeysList>{};
  for (final user in fixtures) {
    final list = DeviceKeysList(user.userId, client);
    list.outdated = false;
    for (final entry in user.devices.entries) {
      list.deviceKeys[entry.key] = DeviceKeys.fromJson(
        Map<String, dynamic>.from(entry.value),
        client,
      );
    }
    for (final entry in user.crossSigning.entries) {
      list.crossSigningKeys[entry.key] = CrossSigningKey.fromJson(
        Map<String, dynamic>.from(entry.value),
        client,
      );
    }
    // _updateUserDeviceKeys checks isValid before accepting a key from the
    // server, so by the time anything is persisted the self-signature verdict
    // is already computed. Mirror that here, outside the measured region.
    for (final key in list.deviceKeys.values) {
      key.isValid;
    }
    lists[user.userId] = list;
  }
  return lists;
}

Future<int> measure(Future<void> Function() body) async {
  final sw = Stopwatch()..start();
  await body();
  sw.stop();
  return sw.elapsedMicroseconds;
}

String fmt(int micros) => micros >= 1000
    ? '${(micros / 1000).toStringAsFixed(1)} ms'
    : '$micros us';

Future<void> runDataset({
  required String label,
  required int userCount,
  required int devicesPerUser,
}) async {
  final dir = await Directory.systemTemp.createTemp('realbench');
  final path = '${dir.path}/db.sqlite';
  final database = await MatrixSdkDatabase.init(
    'realbench',
    database: await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(singleInstance: false),
    ),
    sqfliteFactory: databaseFactoryFfi,
  );
  final client = Client('bench', database: database);

  final fixtures = buildFixtures(
    userCount: userCount,
    devicesPerUser: devicesPerUser,
  );
  final lists = buildLists(fixtures, client);
  // Write paths reach back through the client, so mirror what init() does.
  client.userDeviceKeys.addAll(lists);

  stdout.writeln('\n${'=' * 72}');
  stdout.writeln(
    '$label: $userCount users x $devicesPerUser devices '
    '(${userCount * devicesPerUser} devices, ${userCount * 3} cross-signing)',
  );
  stdout.writeln('=' * 72);

  // Mirrors _updateUserDeviceKeys: every tracked user persisted inside one
  // transaction after a fresh login.
  final keysQueryAll = await measure(
    () => database.transaction(() async {
      for (final user in fixtures) {
        await database.storeDeviceKeysList(user.userId, lists[user.userId]!);
      }
    }),
  );
  stdout.writeln('  keysQuery ALL      ${fmt(keysQueryAll).padLeft(10)}');

  late Map<String, DeviceKeysList> loaded;
  final coldRead = await measure(() async {
    loaded = await database.getUserDeviceKeys(client);
  });
  stdout.writeln('  cold read          ${fmt(coldRead).padLeft(10)}');

  // Isolates signature verification from the storage layout: main validates
  // every key on load, so a read that looks fast may simply have skipped it.
  var validated = 0;
  final validate = await measure(() async {
    for (final list in loaded.values) {
      for (final key in list.deviceKeys.values) {
        if (key.isValid) validated++;
      }
    }
  });
  stdout.writeln(
    '  validate $validated keys'.padRight(21) + fmt(validate).padLeft(10),
  );

  final hot = fixtures[fixtures.length ~/ 2];
  final hotDevice = hot.devices.keys.first;

  final lastActive = await measure(() async {
    for (var i = 0; i < 1000; i++) {
      await database.setLastActiveUserDeviceKey(
        1700000000000 + i,
        hot.userId,
        hotDevice,
      );
    }
  });
  stdout.writeln('  lastActive x1000   ${fmt(lastActive).padLeft(10)}');

  final lastSent = await measure(() async {
    for (var i = 0; i < 1000; i++) {
      await database.setLastSentMessageUserDeviceKey(
        '{"type":"m.room.encrypted","content":{"i":$i}}',
        hot.userId,
        hotDevice,
      );
    }
  });
  stdout.writeln('  lastSent x1000     ${fmt(lastSent).padLeft(10)}');

  // The real verification path, via SignableKey.setVerified.
  final setVerified = await measure(() async {
    for (var i = 0; i < 200; i++) {
      final user = fixtures[i % fixtures.length];
      final key = lists[user.userId]!.deviceKeys[user.devices.keys.first]!;
      await key.setVerified(i.isEven, false);
    }
  });
  stdout.writeln('  setVerified x200   ${fmt(setVerified).padLeft(10)}');

  await database.close();
  final size = File(path).lengthSync();
  stdout.writeln(
    '  db size            ${(size / 1024 / 1024).toStringAsFixed(2)} MB',
  );
  await dir.delete(recursive: true);
}

Future<void> main() async {
  sqfliteFfiInit();
  await vod.init(wasmPath: './pkg/', libraryPath: './rust/target/debug/');
  Logs().level = Level.error;

  await runDataset(label: 'typical', userCount: 200, devicesPerUser: 4);
  await runDataset(label: 'stress', userCount: 1000, devicesPerUser: 8);
}
