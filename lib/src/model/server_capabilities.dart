/* MIT License
* 
* Copyright (C) 2019, 2020, 2021 Famedly GmbH
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

import '../utils/map_copy_extension.dart';

enum RoomVersionStability { stable, unstable }

class ServerCapabilities {
  MChangePassword mChangePassword;
  MRoomVersions mRoomVersions;
  Map<String, dynamic> customCapabilities;

  ServerCapabilities.fromJson(Map<String, dynamic> json)
      : mChangePassword = json['m.change_password'] != null
            ? MChangePassword.fromJson(json['m.change_password'])
            : null,
        mRoomVersions = json['m.room_versions'] != null
            ? MRoomVersions.fromJson(json['m.room_versions'])
            : null,
        customCapabilities = json.copy()
          ..remove('m.change_password')
          ..remove('m.room_versions');

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
