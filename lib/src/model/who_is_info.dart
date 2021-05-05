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
      sessions =
          (json['sessions'] as List).map((v) => Sessions.fromJson(v)).toList();
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
      connections = (json['connections'] as List)
          .map((v) => Connections.fromJson(v))
          .toList();
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
