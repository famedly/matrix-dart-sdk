/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020, 2021 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:canonical_json/canonical_json.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:matrix/matrix.dart';

extension JsonSignatureCheckExtension on Map<String, dynamic> {
  /// Checks the signature of a signed json object.
  bool checkJsonSignature(String key, String userId, String deviceId) {
    final signatures = this['signatures'];
    if (signatures == null ||
        signatures is! Map<String, dynamic> ||
        !signatures.containsKey(userId)) {
      return false;
    }
    remove('unsigned');
    remove('signatures');
    if (!signatures[userId].containsKey('ed25519:$deviceId')) return false;
    final String signature = signatures[userId]['ed25519:$deviceId'];
    final canonical = canonicalJson.encode(this);
    final message = String.fromCharCodes(canonical);
    var isValid = false;
    try {
      vod.Ed25519PublicKey.fromBase64(key).verify(
        message: message,
        signature: vod.Ed25519Signature.fromBase64(signature),
      );
      isValid = true;
    } catch (e, s) {
      isValid = false;
      Logs().w('[LibOlm] Signature check failed', e, s);
    }
    return isValid;
  }
}
