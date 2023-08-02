import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'encrypted_file_key.g.dart';

@JsonSerializable()
class EncryptedFileKey with EquatableMixin {

  @JsonKey(name: 'alg')
  final String algorithrm;

  @JsonKey(name: 'ext')
  final bool extractable;

  @JsonKey(name: 'k')
  final String key;

  @JsonKey(name: 'key_ops')
  final List<KeyOperation> keyOperations;

  @JsonKey(name: 'kty')
  final String keyType;

  EncryptedFileKey({
    required this.algorithrm,
    required this.extractable,
    required this.key,
    required this.keyOperations,
    required this.keyType,
  });

  factory EncryptedFileKey.fromJson(Map<String, dynamic> json) 
    => _$EncryptedFileKeyFromJson(json);

  Map<String, dynamic> toJson() => _$EncryptedFileKeyToJson(this);

  @override
  List<Object?> get props => [algorithrm, extractable, key, keyOperations, keyType];
}

enum KeyOperation {
  encrypt,
  decrypt
}