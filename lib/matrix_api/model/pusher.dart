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

class Pusher {
  String pushkey;
  String kind;
  String appId;
  String appDisplayName;
  String deviceDisplayName;
  String profileTag;
  String lang;
  PusherData data;

  Pusher(
    this.pushkey,
    this.appId,
    this.appDisplayName,
    this.deviceDisplayName,
    this.lang,
    this.data, {
    this.profileTag,
    this.kind,
  });

  Pusher.fromJson(Map<String, dynamic> json) {
    pushkey = json['pushkey'];
    kind = json['kind'];
    appId = json['app_id'];
    appDisplayName = json['app_display_name'];
    deviceDisplayName = json['device_display_name'];
    profileTag = json['profile_tag'];
    lang = json['lang'];
    data = PusherData.fromJson(json['data']);
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['pushkey'] = pushkey;
    data['kind'] = kind;
    data['app_id'] = appId;
    data['app_display_name'] = appDisplayName;
    data['device_display_name'] = deviceDisplayName;
    if (profileTag != null) {
      data['profile_tag'] = profileTag;
    }
    data['lang'] = lang;
    data['data'] = this.data.toJson();
    return data;
  }
}

class PusherData {
  Uri url;
  String format;

  PusherData({
    this.url,
    this.format,
  });

  PusherData.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('url')) {
      url = Uri.parse(json['url']);
    }
    format = json['format'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (url != null) {
      data['url'] = url.toString();
    }
    if (format != null) {
      data['format'] = format;
    }
    return data;
  }
}
