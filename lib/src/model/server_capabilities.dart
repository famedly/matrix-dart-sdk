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

enum RoomVersionStability { stable, unstable }

class ServerCapabilities {
  MChangePassword mChangePassword;
  MRoomVersions mRoomVersions;
  Map<String, dynamic> customCapabilities;

  ServerCapabilities.fromJson(Map<String, dynamic> json) {
    mChangePassword = json['m.change_password'] != null
        ? MChangePassword.fromJson(json['m.change_password'])
        : null;
    mRoomVersions = json['m.room_versions'] != null
        ? MRoomVersions.fromJson(json['m.room_versions'])
        : null;
    customCapabilities = Map<String, dynamic>.from(json);
    customCapabilities.remove('m.change_password');
    customCapabilities.remove('m.room_versions');
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (mChangePassword != null) {
      data['m.change_password'] = mChangePassword.toJson();
    }
    if (mRoomVersions != null) {
      data['m.room_versions'] = mRoomVersions.toJson();
    }
    for (final entry in customCapabilities.entries) {
      data[entry.key] = entry.value;
    }
    return data;
  }
}

class MChangePassword {
  bool enabled;

  MChangePassword.fromJson(Map<String, dynamic> json) {
    enabled = json['enabled'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['enabled'] = enabled;
    return data;
  }
}

class MRoomVersions {
  String defaultVersion;
  Map<String, RoomVersionStability> available;

  MRoomVersions.fromJson(Map<String, dynamic> json) {
    defaultVersion = json['default'];
    available = (json['available'] as Map).map<String, RoomVersionStability>(
      (k, v) => MapEntry(
        k,
        RoomVersionStability.values
            .firstWhere((r) => r.toString().split('.').last == v),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['default'] = defaultVersion;
    data['available'] = available.map<String, dynamic>(
        (k, v) => MapEntry(k, v.toString().split('.').last));
    return data;
  }
}
