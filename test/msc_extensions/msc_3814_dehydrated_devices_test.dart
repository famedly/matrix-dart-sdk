// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/fake_matrix_api.dart';
import 'package:matrix/msc_extensions/msc_3814_dehydrated_devices/api.dart';
import 'package:test/test.dart';

import '../fake_client.dart';

void main() {
  /// All Tests related to device keys
  group('Dehydrated Devices', () {
    test('API calls', () async {
      final client = await getClient();

      final ret = await client.uploadDehydratedDevice(
        deviceId: 'DEHYDDEV',
        initialDeviceDisplayName: 'DehydratedDevice',
        deviceData: {'algorithm': 'some.famedly.proprietary.algorith'},
      );
      expect(
        FakeMatrixApi.calledEndpoints.containsKey(
          '/client/unstable/org.matrix.msc3814.v1/dehydrated_device',
        ),
        true,
      );
      expect(ret.isNotEmpty, true);
      final device = await client.getDehydratedDevice();
      expect(device.deviceId, 'DEHYDDEV');
      expect(
        device.deviceData?['algorithm'],
        'some.famedly.proprietary.algorithm',
      );

      final events = await client.getDehydratedDeviceEvents(device.deviceId);
      expect(events.events?.length, 1);
      expect(events.nextBatch, 'd1');
    });
  });
}
