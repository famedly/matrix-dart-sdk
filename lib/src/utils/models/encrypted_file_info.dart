import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:matrix/src/utils/models/encrypted_file_key.dart';

part 'encrypted_file_info.g.dart';

@JsonSerializable()
class EncryptedFileInfo with EquatableMixin {

  final String? url;

  final EncryptedFileKey key;

  @JsonKey(name: 'v')
  final String version;

  @JsonKey(name: 'iv')
  final String initialVector;

  final Map<String, String> hashes;

  EncryptedFileInfo({
    this.url,
    required this.key,
    required this.version,
    required this.initialVector,
    required this.hashes,
  });

  factory EncryptedFileInfo.fromJson(Map<String, dynamic> json) 
    => _$EncryptedFileInfoFromJson(json);

  Map<String, dynamic> toJson() => _$EncryptedFileInfoToJson(this);

  @override
  List<Object?> get props => [url, key, version, initialVector, hashes];
}