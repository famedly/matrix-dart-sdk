// SPDX-FileCopyrightText: 2019-2022 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite.dart';

class DehydratedDevice {
  String deviceId;
  Map<String, dynamic>? deviceData;

  DehydratedDevice({
    required this.deviceId,
    this.deviceData,
  });

  DehydratedDevice.fromJson(Map<String, dynamic> json)
      : deviceId = json['device_id'] as String,
        deviceData = (json['device_data'] as Map<String, dynamic>?)?.copy();

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      if (deviceData != null) 'device_data': deviceData,
    };
  }
}
