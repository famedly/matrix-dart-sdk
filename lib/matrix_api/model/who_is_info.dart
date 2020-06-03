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

class WhoIsInfo {
  String userId;
  Map<String, DeviceInfo> devices;

  WhoIsInfo.fromJson(Map<String, dynamic> json) {
    userId = json['user_id'];
    devices = json['devices'] != null
        ? (json['devices'] as Map)
            .map((k, v) => MapEntry(k, DeviceInfo.fromJson(v)))
        : null;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['user_id'] = userId;
    if (devices != null) {
      data['devices'] = devices.map((k, v) => MapEntry(k, v.toJson()));
    }
    return data;
  }
}

class DeviceInfo {
  List<Sessions> sessions;

  DeviceInfo.fromJson(Map<String, dynamic> json) {
    if (json['sessions'] != null) {
      sessions = <Sessions>[];
      json['sessions'].forEach((v) {
        sessions.add(Sessions.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (sessions != null) {
      data['sessions'] = sessions.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Sessions {
  List<Connections> connections;

  Sessions.fromJson(Map<String, dynamic> json) {
    if (json['connections'] != null) {
      connections = <Connections>[];
      json['connections'].forEach((v) {
        connections.add(Connections.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (connections != null) {
      data['connections'] = connections.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Connections {
  String ip;
  int lastSeen;
  String userAgent;

  Connections.fromJson(Map<String, dynamic> json) {
    ip = json['ip'];
    lastSeen = json['last_seen'];
    userAgent = json['user_agent'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (ip != null) {
      data['ip'] = ip;
    }
    if (lastSeen != null) {
      data['last_seen'] = lastSeen;
    }
    if (userAgent != null) {
      data['user_agent'] = userAgent;
    }
    return data;
  }
}
