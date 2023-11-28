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

import 'package:matrix_api_lite/matrix_api_lite.dart';

import 'package:matrix/msc_extensions/msc_3814_dehydrated_devices/model/dehydrated_device.dart';
import 'package:matrix/msc_extensions/msc_3814_dehydrated_devices/model/dehydrated_device_events.dart';

/// Endpoints related to MSC3814, dehydrated devices v2 aka shrivelled sessions
/// https://github.com/matrix-org/matrix-spec-proposals/pull/3814
extension DehydratedDeviceMatrixApi on MatrixApi {
  /// uploads a dehydrated device.
  /// https://github.com/matrix-org/matrix-spec-proposals/pull/3814
  Future<String> uploadDehydratedDevice({
    required String deviceId,
    String? initialDeviceDisplayName,
    Map<String, dynamic>? deviceData,
    MatrixDeviceKeys? deviceKeys,
    Map<String, dynamic>? oneTimeKeys,
    Map<String, dynamic>? fallbackKeys,
  }) async {
    final response = await request(
      RequestType.PUT,
      '/client/unstable/org.matrix.msc3814.v1/dehydrated_device',
      data: {
        'device_id': deviceId,
        if (initialDeviceDisplayName != null)
          'initial_device_display_name': initialDeviceDisplayName,
        if (deviceData != null) 'device_data': deviceData,
        if (deviceKeys != null) 'device_keys': deviceKeys.toJson(),
        if (oneTimeKeys != null) 'one_time_keys': oneTimeKeys,
        if (fallbackKeys != null) ...{
          'fallback_keys': fallbackKeys,
        },
      },
    );
    return response['device_id'] as String;
  }

  /// fetch a dehydrated device.
  /// https://github.com/matrix-org/matrix-spec-proposals/pull/3814
  Future<DehydratedDevice> getDehydratedDevice() async {
    final response = await request(
      RequestType.GET,
      '/client/unstable/org.matrix.msc3814.v1/dehydrated_device',
    );
    return DehydratedDevice.fromJson(response);
  }

  /// fetch events sent to a dehydrated device.
  /// https://github.com/matrix-org/matrix-spec-proposals/pull/3814
  Future<DehydratedDeviceEvents> getDehydratedDeviceEvents(String deviceId,
      {String? nextBatch, int limit = 100}) async {
    final response = await request(RequestType.POST,
        '/client/unstable/org.matrix.msc3814.v1/dehydrated_device/$deviceId/events',
        query: {
          'limit': limit.toString(),
        },
        data: {
          if (nextBatch != null) 'next_batch': nextBatch,
        });
    return DehydratedDeviceEvents.fromJson(response);
  }
}
