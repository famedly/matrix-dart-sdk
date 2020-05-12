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
      {this.pushkey,
      this.kind,
      this.appId,
      this.appDisplayName,
      this.deviceDisplayName,
      this.profileTag,
      this.lang,
      this.data});

  Pusher.fromJson(Map<String, dynamic> json) {
    pushkey = json['pushkey'];
    kind = json['kind'];
    appId = json['app_id'];
    appDisplayName = json['app_display_name'];
    deviceDisplayName = json['device_display_name'];
    profileTag = json['profile_tag'];
    lang = json['lang'];
    data = json['data'] != null ? PusherData.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['pushkey'] = pushkey;
    data['kind'] = kind;
    data['app_id'] = appId;
    data['app_display_name'] = appDisplayName;
    data['device_display_name'] = deviceDisplayName;
    data['profile_tag'] = profileTag;
    data['lang'] = lang;
    if (this.data != null) {
      data['data'] = this.data.toJson();
    }
    return data;
  }
}

class PusherData {
  String url;

  PusherData({this.url});

  PusherData.fromJson(Map<String, dynamic> json) {
    url = json['url'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['url'] = url;
    return data;
  }
}
