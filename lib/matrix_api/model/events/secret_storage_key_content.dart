import 'package:famedlysdk/matrix_api/model/basic_event.dart';
import '../../utils/try_get_map_extension.dart';

extension SecretStorageKeyContentBasicEventExtension on BasicEvent {
  SecretStorageKeyContent get parsedSecretStorageKeyContent =>
      SecretStorageKeyContent.fromJson(content);
}

class SecretStorageKeyContent {
  PassphraseInfo passphrase;
  String iv;
  String mac;
  String algorithm;

  SecretStorageKeyContent();

  SecretStorageKeyContent.fromJson(Map<String, dynamic> json)
      : passphrase = json['passphrase'] is Map<String, dynamic>
            ? PassphraseInfo.fromJson(json['passphrase'])
            : null,
        iv = json.tryGet<String>('iv'),
        mac = json.tryGet<String>('mac'),
        algorithm = json.tryGet<String>('algorithm');

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (passphrase != null) data['passphrase'] = passphrase.toJson();
    if (iv != null) data['iv'] = iv;
    if (mac != null) data['mac'] = mac;
    if (algorithm != null) data['algorithm'] = algorithm;
    return data;
  }
}

class PassphraseInfo {
  String algorithm;
  String salt;
  int iterations;
  int bits;

  PassphraseInfo();

  PassphraseInfo.fromJson(Map<String, dynamic> json)
      : algorithm = json.tryGet<String>('algorithm'),
        salt = json.tryGet<String>('salt'),
        iterations = json.tryGet<int>('iterations'),
        bits = json.tryGet<int>('bits');

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (algorithm != null) data['algorithm'] = algorithm;
    if (salt != null) data['salt'] = salt;
    if (iterations != null) data['iterations'] = iterations;
    if (bits != null) data['bits'] = bits;
    return data;
  }
}
