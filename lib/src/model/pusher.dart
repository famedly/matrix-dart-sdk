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

  Pusher.fromJson(Map<String, dynamic> json)
      : pushkey = json['pushkey'],
        kind = json['kind'],
        appId = json['app_id'],
        appDisplayName = json['app_display_name'],
        deviceDisplayName = json['device_display_name'],
        profileTag = json['profile_tag'],
        lang = json['lang'],
        data = PusherData.fromJson(json['data']);

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

  PusherData.fromJson(Map<String, dynamic> json)
      : format = json['format'],
        url = json.containsKey('url') ? Uri.parse(json['url']) : null;

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
