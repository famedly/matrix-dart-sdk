// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite.dart';
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
        'initial_device_display_name': ?initialDeviceDisplayName,
        'device_data': ?deviceData,
        if (deviceKeys != null) 'device_keys': deviceKeys.toJson(),
        'one_time_keys': ?oneTimeKeys,
        if (fallbackKeys != null) ...{'fallback_keys': fallbackKeys},
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
  Future<DehydratedDeviceEvents> getDehydratedDeviceEvents(
    String deviceId, {
    String? nextBatch,
    int limit = 100,
  }) async {
    final response = await request(
      RequestType.POST,
      '/client/unstable/org.matrix.msc3814.v1/dehydrated_device/$deviceId/events',
      query: {'limit': limit.toString()},
      data: {'next_batch': ?nextBatch},
    );
    return DehydratedDeviceEvents.fromJson(response);
  }
}
