import 'dart:typed_data';
import 'dart:convert';

import 'package:olm/olm.dart' as olm;

import 'client.dart';
import 'utils/device_keys_list.dart';

const SELF_SIGNING_KEY = 'm.cross_signing.self_signing';
const USER_SIGNING_KEY = 'm.cross_signing.user_signing';
const MASTER_KEY = 'm.cross_signing.master';

class CrossSigning {
  final Client client;
  CrossSigning(this.client);

  bool get enabled =>
      client.accountData[SELF_SIGNING_KEY] != null &&
      client.accountData[USER_SIGNING_KEY] != null &&
      client.accountData[MASTER_KEY] != null;

  Future<bool> isCached() async {
    if (!enabled) {
      return false;
    }
    return (await client.ssss.getCached(SELF_SIGNING_KEY)) != null &&
        (await client.ssss.getCached(USER_SIGNING_KEY)) != null;
  }

  bool signable(List<SignedKey> keys) {
    for (final key in keys) {
      if (key is CrossSigningKey && key.usage.contains('master')) {
        return true;
      }
      if (key.userId == client.userID &&
          (key is DeviceKeys) &&
          key.identifier != client.deviceID) {
        return true;
      }
    }
    return false;
  }

  Future<void> sign(List<SignedKey> keys) async {
    Uint8List selfSigningKey;
    Uint8List userSigningKey;
    final signatures = <String, dynamic>{};
    var signedKey = false;
    final addSignature =
        (SignedKey key, SignedKey signedWith, String signature) {
      if (key == null || signedWith == null || signature == null) {
        return;
      }
      if (!signatures.containsKey(key.userId)) {
        signatures[key.userId] = <String, dynamic>{};
      }
      if (!signatures[key.userId].containsKey(key.identifier)) {
        signatures[key.userId][key.identifier] = key.toJson();
      }
      if (!signatures[key.userId][key.identifier].containsKey('signatures')) {
        signatures[key.userId][key.identifier]
            ['signatures'] = <String, dynamic>{};
      }
      if (!signatures[key.userId][key.identifier]['signatures']
          .containsKey(signedWith.userId)) {
        signatures[key.userId][key.identifier]['signatures']
            [signedWith.userId] = <String, dynamic>{};
      }
      signatures[key.userId][key.identifier]['signatures'][signedWith.userId]
          ['ed25519:${signedWith.identifier}'] = signature;
      signedKey = true;
    };
    for (final key in keys) {
      if (key.userId == client.userID) {
        // we are singing a key of ourself
        if (key is CrossSigningKey) {
          if (key.usage.contains('master')) {
            // okay, we'll sign our own master key
            final signature = client.signString(key.signingContent);
            addSignature(
                key,
                client.userDeviceKeys[client.userID].deviceKeys[client.deviceID],
                signature);
          }
          // we don't care about signing other cross-signing keys
        } else if (key.identifier != client.deviceID) {
          // okay, we'll sign a device key with our self signing key
          selfSigningKey ??=
              base64.decode(await client.ssss.getCached(SELF_SIGNING_KEY) ?? '');
          if (selfSigningKey != null) {
            final signature = _sign(key.signingContent, selfSigningKey);
            addSignature(key, client.userDeviceKeys[client.userID].selfSigningKey,
                signature);
          }
        }
      } else if (key is CrossSigningKey && key.usage.contains('master')) {
        // we are signing someone elses master key
        userSigningKey ??=
            base64.decode(await client.ssss.getCached(USER_SIGNING_KEY) ?? '');
        if (userSigningKey != null) {
          final signature = _sign(key.signingContent, userSigningKey);
          addSignature(
              key, client.userDeviceKeys[client.userID].userSigningKey, signature);
        }
      }
    }
    if (signedKey) {
      // post our new keys!
      await client.jsonRequest(
        type: HTTPType.POST,
        action: '/client/r0/keys/signatures/upload',
        data: signatures,
      );
    }
  }

  String _sign(String canonicalJson, Uint8List key) {
    final keyObj = olm.PkSigning();
    keyObj.init_with_seed(key);
    try {
      return keyObj.sign(canonicalJson);
    } finally {
      keyObj.free();
    }
  }
}
