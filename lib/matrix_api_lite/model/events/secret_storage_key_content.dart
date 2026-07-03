// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix_api_lite/model/basic_event.dart';
import 'package:matrix/matrix_api_lite/utils/try_get_map_extension.dart';

extension SecretStorageKeyContentBasicEventExtension on BasicEvent {
  SecretStorageKeyContent get parsedSecretStorageKeyContent =>
      SecretStorageKeyContent.fromJson(content);
}

class SecretStorageKeyContent {
  PassphraseInfo? passphrase;
  String? iv;
  String? mac;
  String? algorithm;
  String? name;

  SecretStorageKeyContent();

  SecretStorageKeyContent.fromJson(Map<String, Object?> json)
    : passphrase = ((Map<String, Object?>? x) => x != null
          ? PassphraseInfo.fromJson(x)
          : null)(json.tryGet('passphrase')),
      iv = json.tryGet('iv'),
      mac = json.tryGet('mac'),
      algorithm = json.tryGet('algorithm'),
      name = json.tryGet('name');

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    if (passphrase != null) data['passphrase'] = passphrase!.toJson();
    if (iv != null) data['iv'] = iv;
    if (mac != null) data['mac'] = mac;
    if (algorithm != null) data['algorithm'] = algorithm;
    if (name != null) data['name'] = name;
    return data;
  }
}

class PassphraseInfo {
  //TODO: algorithm, salt, iterations are required by spec,
  //TODO: we should require it here and make sure to catch it everywhere
  String? algorithm;
  String? salt;
  int? iterations;
  int? bits;

  PassphraseInfo({
    required this.algorithm,
    required this.salt,
    required this.iterations,
    this.bits,
  });

  PassphraseInfo.fromJson(Map<String, Object?> json)
    : algorithm = json.tryGet('algorithm', TryGet.required),
      salt = json.tryGet('salt', TryGet.required),
      iterations = json.tryGet('iterations', TryGet.required),
      bits = json.tryGet('bits');

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    data['algorithm'] = algorithm;
    data['salt'] = salt;
    data['iterations'] = iterations;
    if (bits != null) data['bits'] = bits;
    return data;
  }
}
