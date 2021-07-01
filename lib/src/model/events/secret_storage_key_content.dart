
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

import '../basic_event.dart';
import '../../utils/try_get_map_extension.dart';

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

  SecretStorageKeyContent.fromJson(Map<String, dynamic> json)
      : passphrase = json['passphrase'] is Map<String, dynamic>
            ? PassphraseInfo.fromJson(json['passphrase'])
            : null,
        iv = json.tryGet<String?>('iv'),
        mac = json.tryGet<String?>('mac'),
        algorithm = json.tryGet<String?>('algorithm');

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (passphrase != null) data['passphrase'] = passphrase!.toJson();
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
  int? bits;

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
