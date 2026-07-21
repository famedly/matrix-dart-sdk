// SPDX-FileCopyrightText: 2019-Present, 2020, 2021 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:canonical_json/canonical_json.dart';
import 'package:matrix/matrix.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

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
      Logs().w('[Vodozemac] Signature check failed', e, s);
    }
    return isValid;
  }
}
