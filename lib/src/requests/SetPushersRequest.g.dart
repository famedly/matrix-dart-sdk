// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'SetPushersRequest.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SetPushersRequest _$SetPushersRequestFromJson(Map<String, dynamic> json) {
  return SetPushersRequest(
      lang: json['lang'] as String,
      device_display_name: json['device_display_name'] as String,
      app_display_name: json['app_display_name'] as String,
      app_id: json['app_id'] as String,
      kind: json['kind'] as String,
      pushkey: json['pushkey'] as String,
      data: PusherData.fromJson(json['data'] as Map<String, dynamic>),
      profile_tag: json['profile_tag'] as String,
      append: json['append'] as bool);
}

Map<String, dynamic> _$SetPushersRequestToJson(SetPushersRequest instance) =>
    <String, dynamic>{
      'lang': instance.lang,
      'device_display_name': instance.device_display_name,
      'app_display_name': instance.app_display_name,
      'app_id': instance.app_id,
      'kind': instance.kind,
      'pushkey': instance.pushkey,
      'data': instance.data.toJson(),
      'profile_tag': instance.profile_tag,
      'append': instance.append
    };

PusherData _$PusherDataFromJson(Map<String, dynamic> json) {
  return PusherData(
      url: json['url'] as String, format: json['format'] as String);
}

Map<String, dynamic> _$PusherDataToJson(PusherData instance) =>
    <String, dynamic>{'url': instance.url, 'format': instance.format};
