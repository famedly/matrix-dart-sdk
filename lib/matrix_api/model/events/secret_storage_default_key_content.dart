import 'package:famedlysdk/matrix_api/model/basic_event.dart';
import '../../utils/try_get_map_extension.dart';

extension SecretStorageDefaultKeyContentBasicEventExtension on BasicEvent {
  SecretStorageDefaultKeyContent get parsedSecretStorageDefaultKeyContent =>
      SecretStorageDefaultKeyContent.fromJson(content);
}

class SecretStorageDefaultKeyContent {
  String key;

  SecretStorageDefaultKeyContent();

  SecretStorageDefaultKeyContent.fromJson(Map<String, dynamic> json)
      : key = json.tryGet<String>('key');

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (key != null) data['key'] = key;
    return data;
  }
}
