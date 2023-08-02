// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'encrypted_file_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EncryptedFileInfo _$EncryptedFileInfoFromJson(Map<String, dynamic> json) =>
    EncryptedFileInfo(
      url: json['url'] as String?,
      key: EncryptedFileKey.fromJson(json['key'] as Map<String, dynamic>),
      version: json['v'] as String,
      initialVector: json['iv'] as String,
      hashes: Map<String, String>.from(json['hashes'] as Map),
    );

Map<String, dynamic> _$EncryptedFileInfoToJson(EncryptedFileInfo instance) =>
    <String, dynamic>{
      'url': instance.url,
      'key': instance.key.toJson(),
      'v': instance.version,
      'iv': instance.initialVector,
      'hashes': instance.hashes,
    };
