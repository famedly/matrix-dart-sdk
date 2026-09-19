// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

/// Compares device-key storage layouts against each other.
///
/// The SDK reads device keys from disk exactly once per session (see
/// `Client.init`), so the interesting axis is write cost, which differs by
/// four orders of magnitude between `/keys/query` and per-olm-message
/// bookkeeping. Each layout below is measured on the same fixtures through the
/// same serialisation code.
///
/// Run with: dart run benchmark/device_keys_storage_benchmark.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:canonical_json/canonical_json.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:matrix/matrix.dart';
import 'package:matrix/src/database/sqflite_box.dart';
import 'package:matrix/src/utils/copy_map.dart';

// ---------------------------------------------------------------------------
// Byte accounting
// ---------------------------------------------------------------------------

int _bytes = 0;
void _resetBytes() => _bytes = 0;

Future<void> putMap(Box<Map> box, String key, Map<String, Object?> value) {
  _bytes += jsonEncode(value).length;
  return box.put(key, value);
}

Future<void> putString(Box<String> box, String key, String value) {
  _bytes += value.length;
  return box.put(key, value);
}

Future<void> putInt(Box<int> box, String key, int value) {
  _bytes += value.toString().length;
  return box.put(key, value);
}

Future<void> putBool(Box<bool> box, String key, bool value) {
  _bytes += value.toString().length;
  return box.put(key, value);
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

class UserFixture {
  final String userId;

  /// deviceId -> validly self-signed device key json
  final Map<String, Map<String, Object?>> devices;

  /// publicKey -> cross signing key json
  final Map<String, Map<String, Object?>> crossSigning;

  UserFixture(this.userId, this.devices, this.crossSigning);
}

/// Signs [payload] the way [SignableKey.signingContent] expects, so that
/// `DeviceKeys.isValid` actually passes. Without this every read path would
/// short-circuit on invalid keys and the comparison would be meaningless.
Map<String, Object?> _selfSign(
  vod.Account account,
  Map<String, Object?> payload,
  String userId,
  String keyId,
) {
  final canonical = canonicalJson.encode(payload);
  final signature = account.sign(String.fromCharCodes(canonical)).toBase64();
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
  // Creating a vodozemac account is the expensive part, signing is cheap, so
  // rotate through a small pool instead of one account per device.
  final pool = List.generate(8, (_) => vod.Account());
  final fixtures = <UserFixture>[];

  for (var u = 0; u < userCount; u++) {
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
      final account = pool[(u + usage.length) % pool.length];
      final pub = account.identityKeys.ed25519.toBase64();
      // Cross signing keys are keyed by their own public key; a distinct
      // suffix keeps the three usages apart within a user.
      final publicKey = '$pub${usage[0]}';
      crossSigning[publicKey] = {
        'user_id': userId,
        'usage': [usage],
        'keys': {'ed25519:$publicKey': publicKey},
        'signatures': <String, Object?>{},
      };
    }

    fixtures.add(UserFixture(userId, devices, crossSigning));
  }
  return fixtures;
}

// ---------------------------------------------------------------------------
// Layouts
// ---------------------------------------------------------------------------

abstract class Layout {
  String get name;
  Set<String> get boxNames;
  void open(BoxCollection collection);
  void clearCaches();

  Future<void> seed(List<UserFixture> fixtures);
  Future<Map<String, DeviceKeysList>> readAll(Client client);

  Future<void> setLastActive(int ms, String userId, String deviceId);
  Future<void> setLastSent(String message, String userId, String deviceId);

  /// A single trust flag flip, e.g. the user verifying one device.
  Future<void> setVerified(UserFixture user, String deviceId, bool verified);

  /// `device_lists.changed` marking a user's keys stale.
  Future<void> setOutdated(UserFixture user, bool outdated);

  /// Persisting a fresh `/keys/query` response for one user.
  Future<void> persistUser(UserFixture user);
}

/// Shared helpers for the flat-row shapes (`main` and variant B).
mixin _RowSerialisation {
  Map<String, Object?> deviceRow(
    String userId,
    String deviceId,
    Map<String, Object?> content, {
    required bool legacyHotFields,
  }) => {
    'user_id': userId,
    'device_id': deviceId,
    'content': jsonEncode(content),
    'verified': false,
    'blocked': false,
    if (legacyHotFields) ...{'last_active': 0, 'last_sent_message': ''},
  };

  Map<String, Object?> crossRow(
    String userId,
    String publicKey,
    Map<String, Object?> content,
  ) => {
    'user_id': userId,
    'public_key': publicKey,
    'content': jsonEncode(content),
    'verified': false,
    'blocked': false,
  };
}

// --- main -------------------------------------------------------------------

/// Verbatim port of the layout on `main`: three boxes, hot fields inlined into
/// the device row, and a read that rescans every device tuple once per user.
class MainLayout extends Layout with _RowSerialisation {
  @override
  String get name => 'main (3 boxes, nested scan)';

  static const _devices = 'box_user_device_keys';
  static const _cross = 'box_cross_signing_keys';
  static const _outdated = 'box_user_device_keys_outdated';

  @override
  Set<String> get boxNames => {_devices, _cross, _outdated};

  late Box<Map> devicesBox;
  late Box<Map> crossBox;
  late Box<bool> outdatedBox;

  @override
  void open(BoxCollection c) {
    devicesBox = c.openBox<Map>(_devices);
    crossBox = c.openBox<Map>(_cross);
    outdatedBox = c.openBox<bool>(_outdated);
  }

  @override
  void clearCaches() {
    devicesBox.clearQuickAccessCache();
    crossBox.clearQuickAccessCache();
    outdatedBox.clearQuickAccessCache();
  }

  @override
  Future<void> seed(List<UserFixture> fixtures) async {
    for (final user in fixtures) {
      for (final entry in user.devices.entries) {
        await putMap(
          devicesBox,
          TupleKey(user.userId, entry.key).toString(),
          deviceRow(
            user.userId,
            entry.key,
            entry.value,
            legacyHotFields: true,
          ),
        );
      }
      for (final entry in user.crossSigning.entries) {
        await putMap(
          crossBox,
          TupleKey(user.userId, entry.key).toString(),
          crossRow(user.userId, entry.key, entry.value),
        );
      }
      await putBool(outdatedBox, user.userId, false);
    }
  }

  @override
  Future<Map<String, DeviceKeysList>> readAll(Client client) async {
    final deviceKeysOutdated = await outdatedBox.getAllValues();
    if (deviceKeysOutdated.isEmpty) return {};
    final res = <String, DeviceKeysList>{};
    final userDeviceKeys = await devicesBox.getAllValues();
    final userCrossSigningKeys = await crossBox.getAllValues();
    for (final userId in deviceKeysOutdated.keys) {
      final deviceKeysBoxKeys = userDeviceKeys.keys.where((tuple) {
        final tupleKey = TupleKey.fromString(tuple);
        return tupleKey.parts.first == userId;
      });
      final crossSigningKeysBoxKeys = userCrossSigningKeys.keys.where((tuple) {
        final tupleKey = TupleKey.fromString(tuple);
        return tupleKey.parts.first == userId;
      });
      final childEntries = deviceKeysBoxKeys.map(
        (key) => copyMap(userDeviceKeys[key]!),
      );
      final crossSigningEntries = crossSigningKeysBoxKeys.map(
        (key) => copyMap(userCrossSigningKeys[key]!),
      );
      res[userId] = DeviceKeysList.fromDbJson(
        {
          'client_id': client.id,
          'user_id': userId,
          'outdated': deviceKeysOutdated[userId],
        },
        childEntries.toList().cast<Map<String, dynamic>>(),
        crossSigningEntries.toList().cast<Map<String, dynamic>>(),
        client,
      );
    }
    return res;
  }

  @override
  Future<void> setLastActive(int ms, String userId, String deviceId) async {
    final key = TupleKey(userId, deviceId).toString();
    final raw = copyMap(await devicesBox.get(key) ?? {});
    raw['last_active'] = ms;
    await putMap(devicesBox, key, raw);
  }

  @override
  Future<void> setLastSent(String message, String userId, String deviceId) async {
    final key = TupleKey(userId, deviceId).toString();
    final raw = copyMap(await devicesBox.get(key) ?? {});
    raw['last_sent_message'] = message;
    await putMap(devicesBox, key, raw);
  }

  @override
  Future<void> setVerified(
    UserFixture user,
    String deviceId,
    bool verified,
  ) async {
    final key = TupleKey(user.userId, deviceId).toString();
    final raw = copyMap(await devicesBox.get(key) ?? {});
    raw['verified'] = verified;
    await putMap(devicesBox, key, raw);
  }

  @override
  Future<void> setOutdated(UserFixture user, bool outdated) =>
      putBool(outdatedBox, user.userId, outdated);

  @override
  Future<void> persistUser(UserFixture user) async {
    for (final entry in user.devices.entries) {
      await putMap(
        devicesBox,
        TupleKey(user.userId, entry.key).toString(),
        deviceRow(user.userId, entry.key, entry.value, legacyHotFields: true),
      );
    }
    for (final entry in user.crossSigning.entries) {
      await putMap(
        crossBox,
        TupleKey(user.userId, entry.key).toString(),
        crossRow(user.userId, entry.key, entry.value),
      );
    }
    await putBool(outdatedBox, user.userId, false);
  }
}

/// Serialisation shared by the per-user blob shapes (Krille and variant A).
mixin _BlobSerialisation {
  Map<String, Object?> blob(
    UserFixture user, {
    required bool outdated,
    required bool encodeContent,
    required bool includeLastActive,
    Set<String> verifiedDevices = const {},
  }) => {
    'user_id': user.userId,
    'outdated': outdated,
    'device_keys': user.devices.map(
      (id, content) => MapEntry(id, {
        'user_id': user.userId,
        'device_id': id,
        'content': encodeContent ? jsonEncode(content) : content,
        'verified': verifiedDevices.contains(id),
        'blocked': false,
        if (includeLastActive) 'last_active': 0,
      }),
    ),
    'cross_signing_keys': user.crossSigning.map(
      (pub, content) => MapEntry(pub, {
        'user_id': user.userId,
        'public_key': pub,
        'content': encodeContent ? jsonEncode(content) : content,
        'verified': false,
        'blocked': false,
      }),
    ),
  };

  DeviceKeysList hydrate(Map<String, Object?> json, Client client) {
    final list = DeviceKeysList(json['user_id'] as String, client);
    list.outdated = json['outdated'] as bool? ?? true;
    for (final entry
        in (json['device_keys'] as Map? ?? {}).entries) {
      try {
        final key = DeviceKeys.fromDb(
          Map<String, dynamic>.from(entry.value as Map),
          client,
        );
        if (!key.isValid) throw Exception('Invalid device keys');
        list.deviceKeys[entry.key as String] = key;
      } catch (_) {
        list.outdated = true;
      }
    }
    for (final entry
        in (json['cross_signing_keys'] as Map? ?? {}).entries) {
      try {
        final key = CrossSigningKey.fromDbJson(
          Map<String, dynamic>.from(entry.value as Map),
          client,
        );
        if (!key.isValid) throw Exception('Invalid cross signing key');
        list.crossSigningKeys[entry.key as String] = key;
      } catch (_) {
        list.outdated = true;
      }
    }
    return list;
  }
}

// --- krille -----------------------------------------------------------------

/// The proposed branch: everything for a user in one row, `lastSentMessage`
/// split out, `lastActive` still inside the blob, `content` double-encoded.
class KrilleLayout extends Layout with _BlobSerialisation {
  @override
  String get name => 'krille (1 blob, lastActive inside)';

  static const _lists = 'box_device_keys_list';
  static const _lastSent = 'box_last_sent_olm_messages';

  @override
  Set<String> get boxNames => {_lists, _lastSent};

  late Box<Map> listsBox;
  late Box<String> lastSentBox;

  final Map<String, Map<String, Object?>> _mem = {};

  @override
  void open(BoxCollection c) {
    listsBox = c.openBox<Map>(_lists);
    lastSentBox = c.openBox<String>(_lastSent);
  }

  @override
  void clearCaches() {
    listsBox.clearQuickAccessCache();
    lastSentBox.clearQuickAccessCache();
  }

  @override
  Future<void> seed(List<UserFixture> fixtures) async {
    for (final user in fixtures) {
      final value = blob(
        user,
        outdated: false,
        encodeContent: true,
        includeLastActive: true,
      );
      _mem[user.userId] = value;
      await putMap(listsBox, user.userId, value);
    }
  }

  @override
  Future<Map<String, DeviceKeysList>> readAll(Client client) async {
    final raw = await listsBox.getAllValues();
    return raw.map((k, v) => MapEntry(k, hydrate(copyMap(v), client)));
  }

  /// Read-modify-write of the whole user blob, as on the branch.
  @override
  Future<void> setLastActive(int ms, String userId, String deviceId) async {
    final raw = copyMap(await listsBox.get(userId) ?? {});
    final devices = raw['device_keys'] as Map?;
    (devices?[deviceId] as Map?)?['last_active'] = ms;
    await putMap(listsBox, userId, raw);
  }

  @override
  Future<void> setLastSent(String message, String userId, String deviceId) =>
      putString(lastSentBox, TupleKey(userId, deviceId).toString(), message);

  @override
  Future<void> setVerified(
    UserFixture user,
    String deviceId,
    bool verified,
  ) async {
    final raw = _mem[user.userId]!;
    ((raw['device_keys'] as Map)[deviceId] as Map)['verified'] = verified;
    await putMap(listsBox, user.userId, raw);
  }

  @override
  Future<void> setOutdated(UserFixture user, bool outdated) async {
    final raw = _mem[user.userId]!;
    raw['outdated'] = outdated;
    await putMap(listsBox, user.userId, raw);
  }

  @override
  Future<void> persistUser(UserFixture user) => putMap(
    listsBox,
    user.userId,
    blob(
      user,
      outdated: false,
      encodeContent: true,
      includeLastActive: true,
    ),
  );
}

// --- variant A --------------------------------------------------------------

/// Blob for cold data, dedicated boxes for the two per-message fields, and
/// `content` stored nested rather than double-encoded.
class VariantALayout extends Layout with _BlobSerialisation {
  @override
  String get name => 'A (blob cold + hot boxes)';

  static const _lists = 'box_device_keys_list';
  static const _lastSent = 'box_last_sent_olm_messages';
  static const _lastActive = 'box_last_active_devices';

  @override
  Set<String> get boxNames => {_lists, _lastSent, _lastActive};

  late Box<Map> listsBox;
  late Box<String> lastSentBox;
  late Box<int> lastActiveBox;

  final Map<String, Map<String, Object?>> _mem = {};

  @override
  void open(BoxCollection c) {
    listsBox = c.openBox<Map>(_lists);
    lastSentBox = c.openBox<String>(_lastSent);
    lastActiveBox = c.openBox<int>(_lastActive);
  }

  @override
  void clearCaches() {
    listsBox.clearQuickAccessCache();
    lastSentBox.clearQuickAccessCache();
    lastActiveBox.clearQuickAccessCache();
  }

  @override
  Future<void> seed(List<UserFixture> fixtures) async {
    for (final user in fixtures) {
      final value = blob(
        user,
        outdated: false,
        encodeContent: false,
        includeLastActive: false,
      );
      _mem[user.userId] = value;
      await putMap(listsBox, user.userId, value);
    }
  }

  @override
  Future<Map<String, DeviceKeysList>> readAll(Client client) async {
    final raw = await listsBox.getAllValues();
    final lists = raw.map((k, v) => MapEntry(k, hydrate(copyMap(v), client)));
    final lastActive = await lastActiveBox.getAllValues();
    for (final entry in lastActive.entries) {
      final parts = TupleKey.fromString(entry.key).parts;
      if (parts.length < 2) continue;
      lists[parts[0]]?.deviceKeys[parts[1]]?.lastActive =
          DateTime.fromMillisecondsSinceEpoch(entry.value);
    }
    return lists;
  }

  @override
  Future<void> setLastActive(int ms, String userId, String deviceId) =>
      putInt(lastActiveBox, TupleKey(userId, deviceId).toString(), ms);

  @override
  Future<void> setLastSent(String message, String userId, String deviceId) =>
      putString(lastSentBox, TupleKey(userId, deviceId).toString(), message);

  @override
  Future<void> setVerified(
    UserFixture user,
    String deviceId,
    bool verified,
  ) async {
    final raw = _mem[user.userId]!;
    ((raw['device_keys'] as Map)[deviceId] as Map)['verified'] = verified;
    await putMap(listsBox, user.userId, raw);
  }

  @override
  Future<void> setOutdated(UserFixture user, bool outdated) async {
    final raw = _mem[user.userId]!;
    raw['outdated'] = outdated;
    await putMap(listsBox, user.userId, raw);
  }

  @override
  Future<void> persistUser(UserFixture user) => putMap(
    listsBox,
    user.userId,
    blob(
      user,
      outdated: false,
      encodeContent: false,
      includeLastActive: false,
    ),
  );
}

// --- variant B --------------------------------------------------------------

/// Main's flat rows, but the read is a single O(rows) bucketing pass and the
/// two per-message fields live in their own boxes.
class VariantBLayout extends Layout with _RowSerialisation {
  @override
  String get name => 'B (flat rows, single-pass read)';

  static const _devices = 'box_user_device_keys';
  static const _cross = 'box_cross_signing_keys';
  static const _outdated = 'box_user_device_keys_outdated';
  static const _lastSent = 'box_last_sent_olm_messages';
  static const _lastActive = 'box_last_active_devices';

  @override
  Set<String> get boxNames => {
    _devices,
    _cross,
    _outdated,
    _lastSent,
    _lastActive,
  };

  late Box<Map> devicesBox;
  late Box<Map> crossBox;
  late Box<bool> outdatedBox;
  late Box<String> lastSentBox;
  late Box<int> lastActiveBox;

  @override
  void open(BoxCollection c) {
    devicesBox = c.openBox<Map>(_devices);
    crossBox = c.openBox<Map>(_cross);
    outdatedBox = c.openBox<bool>(_outdated);
    lastSentBox = c.openBox<String>(_lastSent);
    lastActiveBox = c.openBox<int>(_lastActive);
  }

  @override
  void clearCaches() {
    devicesBox.clearQuickAccessCache();
    crossBox.clearQuickAccessCache();
    outdatedBox.clearQuickAccessCache();
    lastSentBox.clearQuickAccessCache();
    lastActiveBox.clearQuickAccessCache();
  }

  @override
  Future<void> seed(List<UserFixture> fixtures) async {
    for (final user in fixtures) {
      for (final entry in user.devices.entries) {
        await putMap(
          devicesBox,
          TupleKey(user.userId, entry.key).toString(),
          deviceRow(
            user.userId,
            entry.key,
            entry.value,
            legacyHotFields: false,
          ),
        );
      }
      for (final entry in user.crossSigning.entries) {
        await putMap(
          crossBox,
          TupleKey(user.userId, entry.key).toString(),
          crossRow(user.userId, entry.key, entry.value),
        );
      }
      await putBool(outdatedBox, user.userId, false);
    }
  }

  @override
  Future<Map<String, DeviceKeysList>> readAll(Client client) async {
    final outdated = await outdatedBox.getAllValues();
    final deviceRows = await devicesBox.getAllValues();
    final crossRows = await crossBox.getAllValues();

    // Single pass: bucket rows by user instead of rescanning per user.
    final devicesByUser = <String, List<Map<String, dynamic>>>{};
    for (final entry in deviceRows.entries) {
      final userId = TupleKey.fromString(entry.key).parts.first;
      (devicesByUser[userId] ??= []).add(
        copyMap(entry.value).cast<String, dynamic>(),
      );
    }
    final crossByUser = <String, List<Map<String, dynamic>>>{};
    for (final entry in crossRows.entries) {
      final userId = TupleKey.fromString(entry.key).parts.first;
      (crossByUser[userId] ??= []).add(
        copyMap(entry.value).cast<String, dynamic>(),
      );
    }

    final res = <String, DeviceKeysList>{};
    for (final userId in outdated.keys) {
      res[userId] = DeviceKeysList.fromDbJson(
        {'user_id': userId, 'outdated': outdated[userId]},
        devicesByUser[userId] ?? [],
        crossByUser[userId] ?? [],
        client,
      );
    }

    final lastActive = await lastActiveBox.getAllValues();
    for (final entry in lastActive.entries) {
      final parts = TupleKey.fromString(entry.key).parts;
      if (parts.length < 2) continue;
      res[parts[0]]?.deviceKeys[parts[1]]?.lastActive =
          DateTime.fromMillisecondsSinceEpoch(entry.value);
    }
    return res;
  }

  @override
  Future<void> setLastActive(int ms, String userId, String deviceId) =>
      putInt(lastActiveBox, TupleKey(userId, deviceId).toString(), ms);

  @override
  Future<void> setLastSent(String message, String userId, String deviceId) =>
      putString(lastSentBox, TupleKey(userId, deviceId).toString(), message);

  @override
  Future<void> setVerified(
    UserFixture user,
    String deviceId,
    bool verified,
  ) async {
    final key = TupleKey(user.userId, deviceId).toString();
    final raw = copyMap(await devicesBox.get(key) ?? {});
    raw['verified'] = verified;
    await putMap(devicesBox, key, raw);
  }

  @override
  Future<void> setOutdated(UserFixture user, bool outdated) =>
      putBool(outdatedBox, user.userId, outdated);

  @override
  Future<void> persistUser(UserFixture user) async {
    for (final entry in user.devices.entries) {
      await putMap(
        devicesBox,
        TupleKey(user.userId, entry.key).toString(),
        deviceRow(user.userId, entry.key, entry.value, legacyHotFields: false),
      );
    }
    for (final entry in user.crossSigning.entries) {
      await putMap(
        crossBox,
        TupleKey(user.userId, entry.key).toString(),
        crossRow(user.userId, entry.key, entry.value),
      );
    }
    await putBool(outdatedBox, user.userId, false);
  }
}

// --- variant C --------------------------------------------------------------

/// Strict split by mutability: the blob holds only server-signed material, so
/// it is written solely on `/keys/query`. Everything the client mutates lives
/// in its own small row.
class VariantCLayout extends Layout {
  @override
  String get name => 'C (material blob + trust rows)';

  static const _material = 'box_device_keys_material';
  static const _trust = 'box_device_trust';
  static const _outdated = 'box_device_keys_outdated';
  static const _lastSent = 'box_last_sent_olm_messages';
  static const _lastActive = 'box_last_active_devices';

  @override
  Set<String> get boxNames => {
    _material,
    _trust,
    _outdated,
    _lastSent,
    _lastActive,
  };

  late Box<Map> materialBox;
  late Box<Map> trustBox;
  late Box<bool> outdatedBox;
  late Box<String> lastSentBox;
  late Box<int> lastActiveBox;

  @override
  void open(BoxCollection c) {
    materialBox = c.openBox<Map>(_material);
    trustBox = c.openBox<Map>(_trust);
    outdatedBox = c.openBox<bool>(_outdated);
    lastSentBox = c.openBox<String>(_lastSent);
    lastActiveBox = c.openBox<int>(_lastActive);
  }

  @override
  void clearCaches() {
    materialBox.clearQuickAccessCache();
    trustBox.clearQuickAccessCache();
    outdatedBox.clearQuickAccessCache();
    lastSentBox.clearQuickAccessCache();
    lastActiveBox.clearQuickAccessCache();
  }

  Map<String, Object?> _materialRow(UserFixture user) => {
    'device_keys': user.devices,
    'cross_signing_keys': user.crossSigning,
  };

  @override
  Future<void> seed(List<UserFixture> fixtures) async {
    for (final user in fixtures) {
      await putMap(materialBox, user.userId, _materialRow(user));
      await putBool(outdatedBox, user.userId, false);
    }
  }

  @override
  Future<Map<String, DeviceKeysList>> readAll(Client client) async {
    final material = await materialBox.getAllValues();
    final trust = await trustBox.getAllValues();
    final outdated = await outdatedBox.getAllValues();
    final lastActive = await lastActiveBox.getAllValues();

    final res = <String, DeviceKeysList>{};
    for (final entry in material.entries) {
      final userId = entry.key;
      final raw = copyMap(entry.value);
      final list = DeviceKeysList(userId, client);
      list.outdated = outdated[userId] ?? true;

      for (final device
          in (raw['device_keys'] as Map? ?? {}).entries) {
        final deviceId = device.key as String;
        final tuple = TupleKey(userId, deviceId).toString();
        final flags = trust[tuple];
        try {
          final key = DeviceKeys.fromDb({
            'user_id': userId,
            'device_id': deviceId,
            'content': device.value,
            'verified': flags?['verified'] ?? false,
            'blocked': flags?['blocked'] ?? false,
            'last_active': lastActive[tuple] ?? 0,
          }, client);
          if (!key.isValid) throw Exception('Invalid device keys');
          list.deviceKeys[deviceId] = key;
        } catch (_) {
          list.outdated = true;
        }
      }

      for (final cross
          in (raw['cross_signing_keys'] as Map? ?? {}).entries) {
        final publicKey = cross.key as String;
        final flags = trust[TupleKey(userId, publicKey).toString()];
        try {
          final key = CrossSigningKey.fromDbJson({
            'user_id': userId,
            'public_key': publicKey,
            'content': cross.value,
            'verified': flags?['verified'] ?? false,
            'blocked': flags?['blocked'] ?? false,
            'tofu': flags?['tofu'],
          }, client);
          if (!key.isValid) throw Exception('Invalid cross signing key');
          list.crossSigningKeys[publicKey] = key;
        } catch (_) {
          list.outdated = true;
        }
      }
      res[userId] = list;
    }
    return res;
  }

  @override
  Future<void> setLastActive(int ms, String userId, String deviceId) =>
      putInt(lastActiveBox, TupleKey(userId, deviceId).toString(), ms);

  @override
  Future<void> setLastSent(String message, String userId, String deviceId) =>
      putString(lastSentBox, TupleKey(userId, deviceId).toString(), message);

  @override
  Future<void> setVerified(
    UserFixture user,
    String deviceId,
    bool verified,
  ) => putMap(trustBox, TupleKey(user.userId, deviceId).toString(), {
    'verified': verified,
    'blocked': false,
  });

  @override
  Future<void> setOutdated(UserFixture user, bool outdated) =>
      putBool(outdatedBox, user.userId, outdated);

  @override
  Future<void> persistUser(UserFixture user) async {
    await putMap(materialBox, user.userId, _materialRow(user));
    await putBool(outdatedBox, user.userId, false);
  }
}

// ---------------------------------------------------------------------------
// Runner
// ---------------------------------------------------------------------------

class Measurement {
  final String scenario;
  final int micros;
  final int bytes;
  Measurement(this.scenario, this.micros, this.bytes);
}

Future<Measurement> measure(
  String scenario,
  Future<void> Function() body,
) async {
  _resetBytes();
  final sw = Stopwatch()..start();
  await body();
  sw.stop();
  return Measurement(scenario, sw.elapsedMicroseconds, _bytes);
}

Future<Map<String, Measurement>> runLayout(
  Layout layout,
  List<UserFixture> fixtures,
  Client client,
  Directory dir,
) async {
  final path = '${dir.path}/${layout.runtimeType}.sqlite';
  final db = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(singleInstance: false),
  );
  final collection = await BoxCollection.open(
    'bench',
    layout.boxNames,
    sqfliteDatabase: db,
    sqfliteFactory: databaseFactoryFfi,
  );
  layout.open(collection);

  final results = <String, Measurement>{};

  results['seed'] = await measure('seed', () => layout.seed(fixtures));

  layout.clearCaches();
  results['cold read'] = await measure(
    'cold read',
    () => layout.readAll(client),
  );

  // Hot paths: one write per incoming/outgoing olm message.
  final hotUser = fixtures[fixtures.length ~/ 2];
  final hotDevice = hotUser.devices.keys.first;
  results['lastActive x1000'] = await measure('lastActive x1000', () async {
    for (var i = 0; i < 1000; i++) {
      await layout.setLastActive(1700000000000 + i, hotUser.userId, hotDevice);
    }
  });
  results['lastSent x1000'] = await measure('lastSent x1000', () async {
    for (var i = 0; i < 1000; i++) {
      await layout.setLastSent(
        '{"type":"m.room.encrypted","content":{"i":$i}}',
        hotUser.userId,
        hotDevice,
      );
    }
  });

  results['setVerified x200'] = await measure('setVerified x200', () async {
    for (var i = 0; i < 200; i++) {
      final user = fixtures[i % fixtures.length];
      await layout.setVerified(user, user.devices.keys.first, i.isEven);
    }
  });

  results['outdated x100'] = await measure('outdated x100', () async {
    for (var i = 0; i < 100; i++) {
      await layout.setOutdated(fixtures[i % fixtures.length], true);
    }
  });

  results['keysQuery x50'] = await measure('keysQuery x50', () async {
    for (var i = 0; i < 50; i++) {
      await layout.persistUser(fixtures[i % fixtures.length]);
    }
  });

  await db.close();
  final size = File(path).existsSync() ? File(path).lengthSync() : 0;
  results['db size'] = Measurement('db size', 0, size);
  return results;
}

String _fmtMicros(int micros) => micros >= 1000
    ? '${(micros / 1000).toStringAsFixed(1)} ms'
    : '$micros us';

String _fmtBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}

Future<void> runDataset({
  required String label,
  required int userCount,
  required int devicesPerUser,
  required Client client,
}) async {
  stdout.writeln('\n${'=' * 96}');
  stdout.writeln(
    'DATASET: $label  ($userCount users x $devicesPerUser devices '
    '= ${userCount * devicesPerUser} devices, ${userCount * 3} cross-signing keys)',
  );
  stdout.writeln('=' * 96);

  final fixtures = buildFixtures(
    userCount: userCount,
    devicesPerUser: devicesPerUser,
  );

  final layouts = <Layout>[
    MainLayout(),
    KrilleLayout(),
    VariantALayout(),
    VariantBLayout(),
    VariantCLayout(),
  ];

  final all = <String, Map<String, Measurement>>{};
  for (final layout in layouts) {
    final dir = await Directory.systemTemp.createTemp('dkbench');
    all[layout.name] = await runLayout(layout, fixtures, client, dir);
    await dir.delete(recursive: true);
  }

  const scenarios = [
    'cold read',
    'lastActive x1000',
    'lastSent x1000',
    'setVerified x200',
    'outdated x100',
    'keysQuery x50',
    'db size',
  ];

  const nameWidth = 32;
  for (final scenario in scenarios) {
    stdout.writeln('\n$scenario');
    for (final layout in layouts) {
      final m = all[layout.name]![scenario]!;
      final time = scenario == 'db size' ? '' : _fmtMicros(m.micros).padLeft(10);
      stdout.writeln(
        '  ${layout.name.padRight(nameWidth)} $time   ${_fmtBytes(m.bytes).padLeft(10)}',
      );
    }
  }
}

Future<void> main() async {
  sqfliteFfiInit();
  await vod.init(
    wasmPath: './pkg/',
    libraryPath: './rust/target/debug/',
  );
  Logs().level = Level.error;

  final clientDb = await MatrixSdkDatabase.init(
    'bench_client',
    database: await databaseFactoryFfi.openDatabase(
      ':memory:',
      options: OpenDatabaseOptions(singleInstance: false),
    ),
    sqfliteFactory: databaseFactoryFfi,
  );
  final client = Client('bench', database: clientDb);

  await runDataset(
    label: 'typical',
    userCount: 200,
    devicesPerUser: 4,
    client: client,
  );
  await runDataset(
    label: 'stress',
    userCount: 1000,
    devicesPerUser: 8,
    client: client,
  );

  await clientDb.close();
}
