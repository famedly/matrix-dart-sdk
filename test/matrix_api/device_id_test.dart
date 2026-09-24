// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:matrix/matrix.dart';
import 'package:test/test.dart';

void main() {
  group('DeviceId', () {
    test('constructors and parsing', () {
      final d1 = DeviceId('DEVICE_ABC_123');
      final d2 = DeviceId.parse('DEVICE_ABC_123');
      final d3 = DeviceId.tryParse('DEVICE_ABC_123');

      expect(d1, equals(d2));
      expect(d1, equals(d3));
      expect(d1.value, 'DEVICE_ABC_123');
      expect(d1.toString(), 'DEVICE_ABC_123');
      expect(d1.toJson(), 'DEVICE_ABC_123');
    });

    test('case sensitivity and equality', () {
      final lower = DeviceId('device');
      final upper = DeviceId('DEVICE');

      expect(lower, isNot(equals(upper)));
      expect({lower: 'found'}[DeviceId('device')], 'found');
      expect({lower: 'found'}[upper], isNull);
      expect({lower, upper}, hasLength(2));
      expect((lower as Object) == 'device', isFalse);
    });

    test('JSON serialization round trips as String', () {
      final id = DeviceId('MY_PHONE_CLIENT');
      expect(jsonEncode({'device_id': id}), '{"device_id":"MY_PHONE_CLIENT"}');
      final decoded = jsonDecode(jsonEncode({'device_id': id}));
      expect(decoded['device_id'], 'MY_PHONE_CLIENT');
    });

    test('rejects empty device IDs', () {
      expect(() => DeviceId(''), throwsFormatException);
      expect(() => DeviceId.parse(''), throwsFormatException);
      expect(DeviceId.tryParse(''), isNull);
    });

    test('rejects NUL characters', () {
      expect(() => DeviceId('DEV\x00ICE'), throwsFormatException);
      expect(DeviceId.tryParse('DEV\x00ICE'), isNull);
    });

    test('rejects unpaired surrogates', () {
      expect(() => DeviceId('\uD800DEVICE'), throwsFormatException);
      expect(DeviceId.tryParse('\uD800DEVICE'), isNull);
    });

    test('accepts opaque device IDs including long IDs up to homeserver limits', () {
      final len255 = 'a' * 255;
      expect(() => DeviceId(len255), returnsNormally);

      // Synapse DB schema supports VARCHAR(512) for device IDs
      final synapse512 = 'a' * 512;
      expect(() => DeviceId(synapse512), returnsNormally);
      expect(DeviceId(synapse512).value, synapse512);

      // Multi-byte Unicode opaque strings
      final unicodeId = '€' * 100;
      expect(() => DeviceId(unicodeId), returnsNormally);

      // Bridge-style namespaced device IDs
      const bridgeDeviceId =
          'bridge_slack_T01234567_U09876543_long_opaque_identifier_session_token';
      expect(() => DeviceId(bridgeDeviceId), returnsNormally);
    });

    test('String extension asDeviceId', () {
      expect('MY_LAPTOP'.asDeviceId, equals(DeviceId('MY_LAPTOP')));
      expect(''.asDeviceId, isNull);
      expect('INVALID\x00DEVICE'.asDeviceId, isNull);
    });
  });
}
