// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'encrypted_file_key.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EncryptedFileKey _$EncryptedFileKeyFromJson(Map<String, dynamic> json) =>
    EncryptedFileKey(
      algorithrm: json['alg'] as String,
      extractable: json['ext'] as bool,
      key: json['k'] as String,
      keyOperations: (json['key_ops'] as List<dynamic>)
          .map((e) => $enumDecode(_$KeyOperationEnumMap, e))
          .toList(),
      keyType: json['kty'] as String,
    );

Map<String, dynamic> _$EncryptedFileKeyToJson(EncryptedFileKey instance) =>
    <String, dynamic>{
      'alg': instance.algorithrm,
      'ext': instance.extractable,
      'k': instance.key,
      'key_ops':
          instance.keyOperations.map((e) => _$KeyOperationEnumMap[e]!).toList(),
      'kty': instance.keyType,
    };

const _$KeyOperationEnumMap = {
  KeyOperation.encrypt: 'encrypt',
  KeyOperation.decrypt: 'decrypt',
};
