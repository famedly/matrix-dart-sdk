/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'well_known_informations.dart';

class LoginResponse {
  String userId;
  String accessToken;
  String deviceId;
  WellKnownInformations wellKnownInformations;

  LoginResponse.fromJson(Map<String, dynamic> json) {
    userId = json['user_id'];
    accessToken = json['access_token'];
    deviceId = json['device_id'];
    if (json['well_known'] is Map) {
      wellKnownInformations =
          WellKnownInformations.fromJson(json['well_known']);
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (userId != null) data['user_id'] = userId;
    if (accessToken != null) data['access_token'] = accessToken;
    if (deviceId != null) data['device_id'] = deviceId;
    if (wellKnownInformations != null) {
      data['well_known'] = wellKnownInformations.toJson();
    }
    return data;
  }
}
