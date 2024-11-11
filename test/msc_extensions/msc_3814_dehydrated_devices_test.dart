/* MIT License
*
* Copyright (C) 2019, 2020, 2021, 2022 Famedly GmbH
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

import 'package:test/test.dart';

import 'package:matrix/fake_matrix_api.dart';
import 'package:matrix/msc_extensions/msc_3814_dehydrated_devices/api.dart';
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
