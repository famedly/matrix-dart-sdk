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

import '../../utils/try_get_map_extension.dart';
import '../basic_event.dart';

extension SecretStorageKeyContentBasicEventExtension on BasicEvent {
  SecretStorageKeyContent get parsedSecretStorageKeyContent =>
      SecretStorageKeyContent.fromJson(content);
}

class SecretStorageKeyContent {
  PassphraseInfo? passphrase;
  String? iv;
  String? mac;
  String? algorithm;

  SecretStorageKeyContent();

  SecretStorageKeyContent.fromJson(Map<String, Object?> json)
      : passphrase = ((Map<String, Object?>? x) => x != null
            ? PassphraseInfo.fromJson(x)
            : null)(json.tryGet('passphrase')),
        iv = json.tryGet('iv'),
        mac = json.tryGet('mac'),
        algorithm = json.tryGet('algorithm');

  Map<String, Object?> toJson() {
    final data = <String, Object?>{};
    if (passphrase != null) data['passphrase'] = passphrase!.toJson();
    if (iv != null) data['iv'] = iv;
    if (mac != null) data['mac'] = mac;
    if (algorithm != null) data['algorithm'] = algorithm;
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

  PassphraseInfo(
      {required this.algorithm,
      required this.salt,
      required this.iterations,
      this.bits});

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
