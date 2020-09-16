import 'package:canonical_json/canonical_json.dart';
import 'package:famedlysdk/src/utils/logs.dart';
import 'package:olm/olm.dart' as olm;

extension JsonSignatureCheckExtension on Map<String, dynamic> {
  /// Checks the signature of a signed json object.
  bool checkJsonSignature(String key, String userId, String deviceId) {
    final Map<String, dynamic> signatures = this['signatures'];
    if (signatures == null || !signatures.containsKey(userId)) return false;
    remove('unsigned');
    remove('signatures');
    if (!signatures[userId].containsKey('ed25519:$deviceId')) return false;
    final String signature = signatures[userId]['ed25519:$deviceId'];
    final canonical = canonicalJson.encode(this);
    final message = String.fromCharCodes(canonical);
    var isValid = false;
    final olmutil = olm.Utility();
    try {
      olmutil.ed25519_verify(key, message, signature);
      isValid = true;
    } catch (e, s) {
      isValid = false;
      Logs.error('[LibOlm] Signature check failed: ' + e.toString(), s);
    } finally {
      olmutil.free();
    }
    return isValid;
  }
}
