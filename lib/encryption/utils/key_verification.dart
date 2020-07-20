/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020 Famedly GmbH
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

import 'dart:async';
import 'dart:typed_data';
import 'package:canonical_json/canonical_json.dart';
import 'package:pedantic/pedantic.dart';
import 'package:olm/olm.dart' as olm;
import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/matrix_api.dart';

import '../encryption.dart';

/*
    +-------------+                    +-----------+
    | AliceDevice |                    | BobDevice |
    +-------------+                    +-----------+
          |                                 |
          | (m.key.verification.request)    |
          |-------------------------------->| (ASK FOR VERIFICATION REQUEST)
          |                                 |
          |      (m.key.verification.ready) |
          |<--------------------------------|
          |                                 |
          |      (m.key.verification.start) | we will probably not send this
          |<--------------------------------| for simplicities sake
          |                                 |
          | m.key.verification.start        |
          |-------------------------------->| (ASK FOR VERIFICATION REQUEST)
          |                                 |
          |       m.key.verification.accept |
          |<--------------------------------|
          |                                 |
          | m.key.verification.key          |
          |-------------------------------->|
          |                                 |
          |          m.key.verification.key |
          |<--------------------------------|
          |                                 |
          |     COMPARE EMOJI / NUMBERS     |
          |                                 |
          | m.key.verification.mac          |
          |-------------------------------->|  success
          |                                 |
          |          m.key.verification.mac |
 success  |<--------------------------------|
          |                                 |
*/

enum KeyVerificationState {
  askAccept,
  askSSSS,
  waitingAccept,
  askSas,
  waitingSas,
  done,
  error
}

enum KeyVerificationMethod { emoji, numbers }

List<String> _intersect(List<String> a, List<dynamic> b) {
  if (b == null || a == null) {
    return [];
  }
  final res = <String>[];
  for (final v in a) {
    if (b.contains(v)) {
      res.add(v);
    }
  }
  return res;
}

List<int> _bytesToInt(Uint8List bytes, int totalBits) {
  final ret = <int>[];
  var current = 0;
  var numBits = 0;
  for (final byte in bytes) {
    for (final bit in [7, 6, 5, 4, 3, 2, 1, 0]) {
      numBits++;
      if ((byte & (1 << bit)) > 0) {
        current += 1 << (totalBits - numBits);
      }
      if (numBits >= totalBits) {
        ret.add(current);
        current = 0;
        numBits = 0;
      }
    }
  }
  return ret;
}

_KeyVerificationMethod _makeVerificationMethod(
    String type, KeyVerification request) {
  if (type == 'm.sas.v1') {
    return _KeyVerificationMethodSas(request: request);
  }
  throw 'Unkown method type';
}

class KeyVerification {
  String transactionId;
  final Encryption encryption;
  Client get client => encryption.client;
  final Room room;
  final String userId;
  void Function() onUpdate;
  String get deviceId => _deviceId;
  String _deviceId;
  bool startedVerification = false;
  _KeyVerificationMethod method;
  List<String> possibleMethods;
  Map<String, dynamic> startPaylaod;
  String _nextAction;
  List<SignableKey> _verifiedDevices;

  DateTime lastActivity;
  String lastStep;

  KeyVerificationState state = KeyVerificationState.waitingAccept;
  bool canceled = false;
  String canceledCode;
  String canceledReason;

  KeyVerification(
      {this.encryption,
      this.room,
      this.userId,
      String deviceId,
      this.onUpdate}) {
    lastActivity = DateTime.now();
    _deviceId ??= deviceId;
  }

  void dispose() {
    print('[Key Verification] disposing object...');
    method?.dispose();
  }

  static String getTransactionId(Map<String, dynamic> payload) {
    return payload['transaction_id'] ??
        (payload['m.relates_to'] is Map
            ? payload['m.relates_to']['event_id']
            : null);
  }

  List<String> get knownVerificationMethods {
    final methods = <String>[];
    if (client.verificationMethods.contains(KeyVerificationMethod.numbers) ||
        client.verificationMethods.contains(KeyVerificationMethod.emoji)) {
      methods.add('m.sas.v1');
    }
    return methods;
  }

  Future<void> sendStart() async {
    await send('m.key.verification.request', {
      'methods': knownVerificationMethods,
      if (room == null) 'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    startedVerification = true;
    setState(KeyVerificationState.waitingAccept);
    lastActivity = DateTime.now();
  }

  Future<void> start() async {
    if (room == null) {
      transactionId = client.generateUniqueTransactionId();
    }
    if (encryption.crossSigning.enabled &&
        !(await encryption.crossSigning.isCached()) &&
        !client.isUnknownSession) {
      setState(KeyVerificationState.askSSSS);
      _nextAction = 'request';
    } else {
      await sendStart();
    }
  }

  bool _handlePayloadLock = false;

  Future<void> handlePayload(String type, Map<String, dynamic> payload,
      [String eventId]) async {
    while (_handlePayloadLock) {
      await Future.delayed(Duration(milliseconds: 50));
    }
    _handlePayloadLock = true;
    print('[Key Verification] Received type ${type}: ' + payload.toString());
    try {
      var thisLastStep = lastStep;
      switch (type) {
        case 'm.key.verification.request':
          _deviceId ??= payload['from_device'];
          transactionId ??= eventId ?? payload['transaction_id'];
          // verify the timestamp
          final now = DateTime.now();
          final verifyTime =
              DateTime.fromMillisecondsSinceEpoch(payload['timestamp']);
          if (now.subtract(Duration(minutes: 10)).isAfter(verifyTime) ||
              now.add(Duration(minutes: 5)).isBefore(verifyTime)) {
            await cancel('m.timeout');
            return;
          }
          // verify it has a method we can use
          possibleMethods =
              _intersect(knownVerificationMethods, payload['methods']);
          if (possibleMethods.isEmpty) {
            // reject it outright
            await cancel('m.unknown_method');
            return;
          }
          setState(KeyVerificationState.askAccept);
          break;
        case 'm.key.verification.ready':
          _deviceId ??= payload['from_device'];
          possibleMethods =
              _intersect(knownVerificationMethods, payload['methods']);
          if (possibleMethods.isEmpty) {
            // reject it outright
            await cancel('m.unknown_method');
            return;
          }
          // as both parties can send a start, the last step being "ready" is race-condition prone
          // as such, we better set it *before* we send our start
          lastStep = type;
          // TODO: Pick method?
          method = _makeVerificationMethod(possibleMethods.first, this);
          await method.sendStart();
          setState(KeyVerificationState.waitingAccept);
          break;
        case 'm.key.verification.start':
          _deviceId ??= payload['from_device'];
          transactionId ??= eventId ?? payload['transaction_id'];
          if (method != null) {
            // the other side sent us a start, even though we already sent one
            if (payload['method'] == method.type) {
              // same method. Determine priority
              final ourEntry = '${client.userID}|${client.deviceID}';
              final entries = [ourEntry, '${userId}|${deviceId}'];
              entries.sort();
              if (entries.first == ourEntry) {
                // our start won, nothing to do
                return;
              } else {
                // the other start won, let's hand off
                startedVerification = false; // it is now as if they started
                thisLastStep = lastStep =
                    'm.key.verification.request'; // we fake the last step
                method.dispose(); // in case anything got created already
              }
            } else {
              // methods don't match up, let's cancel this
              await cancel('m.unexpected_message');
              return;
            }
          }
          if (!(await verifyLastStep(['m.key.verification.request', null]))) {
            return; // abort
          }
          if (!knownVerificationMethods.contains(payload['method'])) {
            await cancel('m.unknown_method');
            return;
          }
          method = _makeVerificationMethod(payload['method'], this);
          if (lastStep == null) {
            if (!method.validateStart(payload)) {
              await cancel('m.unknown_method');
              return;
            }
            startPaylaod = payload;
            setState(KeyVerificationState.askAccept);
          } else {
            print('handling start in method.....');
            await method.handlePayload(type, payload);
          }
          break;
        case 'm.key.verification.done':
          // do nothing
          break;
        case 'm.key.verification.cancel':
          canceled = true;
          canceledCode = payload['code'];
          canceledReason = payload['reason'];
          setState(KeyVerificationState.error);
          break;
        default:
          await method.handlePayload(type, payload);
          break;
      }
      if (lastStep == thisLastStep) {
        lastStep = type;
      }
    } catch (err, stacktrace) {
      print('[Key Verification] An error occured: ' + err.toString());
      print(stacktrace);
      if (deviceId != null) {
        await cancel('m.invalid_message');
      }
    } finally {
      _handlePayloadLock = false;
    }
  }

  void otherDeviceAccepted() {
    canceled = true;
    canceledCode = 'm.accepted';
    canceledReason = 'm.accepted';
    setState(KeyVerificationState.error);
  }

  Future<void> openSSSS(
      {String passphrase, String recoveryKey, bool skip = false}) async {
    final next = () {
      if (_nextAction == 'request') {
        sendStart();
      } else if (_nextAction == 'done') {
        if (_verifiedDevices != null) {
          // and now let's sign them all in the background
          encryption.crossSigning.sign(_verifiedDevices);
        }
        setState(KeyVerificationState.done);
      }
    };
    if (skip) {
      next();
      return;
    }
    final handle = encryption.ssss.open('m.cross_signing.user_signing');
    await handle.unlock(passphrase: passphrase, recoveryKey: recoveryKey);
    await handle.maybeCacheAll();
    next();
  }

  /// called when the user accepts an incoming verification
  Future<void> acceptVerification() async {
    if (!(await verifyLastStep(
        ['m.key.verification.request', 'm.key.verification.start']))) {
      return;
    }
    setState(KeyVerificationState.waitingAccept);
    if (lastStep == 'm.key.verification.request') {
      // we need to send a ready event
      await send('m.key.verification.ready', {
        'methods': possibleMethods,
      });
    } else {
      // we need to send an accept event
      await method.handlePayload('m.key.verification.start', startPaylaod);
    }
  }

  /// called when the user rejects an incoming verification
  Future<void> rejectVerification() async {
    if (!(await verifyLastStep(
        ['m.key.verification.request', 'm.key.verification.start']))) {
      return;
    }
    await cancel('m.user');
  }

  Future<void> acceptSas() async {
    if (method is _KeyVerificationMethodSas) {
      await (method as _KeyVerificationMethodSas).acceptSas();
    }
  }

  Future<void> rejectSas() async {
    if (method is _KeyVerificationMethodSas) {
      await (method as _KeyVerificationMethodSas).rejectSas();
    }
  }

  List<int> get sasNumbers {
    if (method is _KeyVerificationMethodSas) {
      return _bytesToInt((method as _KeyVerificationMethodSas).makeSas(5), 13)
          .map((n) => n + 1000)
          .toList();
    }
    return [];
  }

  List<String> get sasTypes {
    if (method is _KeyVerificationMethodSas) {
      return (method as _KeyVerificationMethodSas).authenticationTypes;
    }
    return [];
  }

  List<KeyVerificationEmoji> get sasEmojis {
    if (method is _KeyVerificationMethodSas) {
      final numbers =
          _bytesToInt((method as _KeyVerificationMethodSas).makeSas(6), 6);
      return numbers.map((n) => KeyVerificationEmoji(n)).toList().sublist(0, 7);
    }
    return [];
  }

  Future<void> maybeRequestSSSSSecrets([int i = 0]) async {
    final requestInterval = <int>[10, 60];
    if ((!encryption.crossSigning.enabled ||
            (encryption.crossSigning.enabled &&
                (await encryption.crossSigning.isCached()))) &&
        (!encryption.keyManager.enabled ||
            (encryption.keyManager.enabled &&
                (await encryption.keyManager.isCached())))) {
      // no need to request cache, we already have it
      return;
    }
    unawaited(encryption.ssss
        .maybeRequestAll(_verifiedDevices.whereType<DeviceKeys>().toList()));
    if (requestInterval.length <= i) {
      return;
    }
    Timer(Duration(seconds: requestInterval[i]),
        () => maybeRequestSSSSSecrets(i + 1));
  }

  Future<void> verifyKeys(Map<String, String> keys,
      Future<bool> Function(String, SignableKey) verifier) async {
    _verifiedDevices = <SignableKey>[];

    if (!client.userDeviceKeys.containsKey(userId)) {
      await cancel('m.key_mismatch');
      return;
    }
    for (final entry in keys.entries) {
      final keyId = entry.key;
      final verifyDeviceId = keyId.substring('ed25519:'.length);
      final keyInfo = entry.value;
      final key = client.userDeviceKeys[userId].getKey(verifyDeviceId);
      if (key != null) {
        if (!(await verifier(keyInfo, key))) {
          await cancel('m.key_mismatch');
          return;
        }
        _verifiedDevices.add(key);
      }
    }
    // okay, we reached this far, so all the devices are verified!
    var verifiedMasterKey = false;
    final wasUnknownSession = client.isUnknownSession;
    for (final key in _verifiedDevices) {
      await key.setVerified(
          true, false); // we don't want to sign the keys juuuust yet
      if (key is CrossSigningKey && key.usage.contains('master')) {
        verifiedMasterKey = true;
      }
    }
    if (verifiedMasterKey && userId == client.userID) {
      // it was our own master key, let's request the cross signing keys
      // we do it in the background, thus no await needed here
      unawaited(maybeRequestSSSSSecrets());
    }
    await send('m.key.verification.done', {});

    var askingSSSS = false;
    if (encryption.crossSigning.enabled &&
        encryption.crossSigning.signable(_verifiedDevices)) {
      // these keys can be signed! Let's do so
      if (await encryption.crossSigning.isCached()) {
        // and now let's sign them all in the background
        unawaited(encryption.crossSigning.sign(_verifiedDevices));
      } else if (!wasUnknownSession) {
        askingSSSS = true;
      }
    }
    if (askingSSSS) {
      setState(KeyVerificationState.askSSSS);
      _nextAction = 'done';
    } else {
      setState(KeyVerificationState.done);
    }
  }

  Future<bool> verifyActivity() async {
    if (lastActivity != null &&
        lastActivity.add(Duration(minutes: 10)).isAfter(DateTime.now())) {
      lastActivity = DateTime.now();
      return true;
    }
    await cancel('m.timeout');
    return false;
  }

  Future<bool> verifyLastStep(List<String> checkLastStep) async {
    if (!(await verifyActivity())) {
      return false;
    }
    if (checkLastStep.contains(lastStep)) {
      return true;
    }
    await cancel('m.unexpected_message');
    return false;
  }

  Future<void> cancel([String code = 'm.unknown']) async {
    await send('m.key.verification.cancel', {
      'reason': code,
      'code': code,
    });
    canceled = true;
    canceledCode = code;
    setState(KeyVerificationState.error);
  }

  void makePayload(Map<String, dynamic> payload) {
    payload['from_device'] = client.deviceID;
    if (transactionId != null) {
      if (room != null) {
        payload['m.relates_to'] = {
          'rel_type': 'm.reference',
          'event_id': transactionId,
        };
      } else {
        payload['transaction_id'] = transactionId;
      }
    }
  }

  Future<void> send(String type, Map<String, dynamic> payload) async {
    makePayload(payload);
    print('[Key Verification] Sending type ${type}: ' + payload.toString());
    if (room != null) {
      print('[Key Verification] Sending to ${userId} in room ${room.id}');
      if (['m.key.verification.request'].contains(type)) {
        payload['msgtype'] = type;
        payload['to'] = userId;
        payload['body'] =
            'Attempting verification request. (${type}) Apparently your client doesn\'t support this';
        type = EventTypes.Message;
      }
      final newTransactionId = await room.sendEvent(payload, type: type);
      if (transactionId == null) {
        transactionId = newTransactionId;
        encryption.keyVerificationManager.addRequest(this);
      }
    } else {
      print('[Key Verification] Sending to ${userId} device ${deviceId}');
      await client.sendToDevice(
          [client.userDeviceKeys[userId].deviceKeys[deviceId]], type, payload);
    }
  }

  void setState(KeyVerificationState newState) {
    if (state != KeyVerificationState.error) {
      state = newState;
    }
    if (onUpdate != null) {
      onUpdate();
    }
  }
}

abstract class _KeyVerificationMethod {
  KeyVerification request;
  Encryption get encryption => request.encryption;
  Client get client => request.client;
  _KeyVerificationMethod({this.request});

  Future<void> handlePayload(String type, Map<String, dynamic> payload);
  bool validateStart(Map<String, dynamic> payload) {
    return false;
  }

  String _type;
  String get type => _type;

  Future<void> sendStart();
  void dispose() {}
}

const KNOWN_KEY_AGREEMENT_PROTOCOLS = ['curve25519-hkdf-sha256', 'curve25519'];
const KNOWN_HASHES = ['sha256'];
const KNOWN_MESSAGE_AUTHENTIFICATION_CODES = ['hkdf-hmac-sha256'];

class _KeyVerificationMethodSas extends _KeyVerificationMethod {
  _KeyVerificationMethodSas({KeyVerification request})
      : super(request: request);

  @override
  final _type = 'm.sas.v1';

  String keyAgreementProtocol;
  String hash;
  String messageAuthenticationCode;
  List<String> authenticationTypes;
  String startCanonicalJson;
  String commitment;
  String theirPublicKey;
  Map<String, dynamic> macPayload;
  olm.SAS sas;

  @override
  void dispose() {
    sas?.free();
  }

  List<String> get knownAuthentificationTypes {
    final types = <String>[];
    if (request.client.verificationMethods
        .contains(KeyVerificationMethod.emoji)) {
      types.add('emoji');
    }
    if (request.client.verificationMethods
        .contains(KeyVerificationMethod.numbers)) {
      types.add('decimal');
    }
    return types;
  }

  @override
  Future<void> handlePayload(String type, Map<String, dynamic> payload) async {
    try {
      switch (type) {
        case 'm.key.verification.start':
          if (!(await request.verifyLastStep(
              ['m.key.verification.request', 'm.key.verification.start']))) {
            return; // abort
          }
          if (!validateStart(payload)) {
            await request.cancel('m.unknown_method');
            return;
          }
          await _sendAccept();
          break;
        case 'm.key.verification.accept':
          if (!(await request.verifyLastStep(['m.key.verification.ready']))) {
            return;
          }
          if (!_handleAccept(payload)) {
            await request.cancel('m.unknown_method');
            return;
          }
          await _sendKey();
          break;
        case 'm.key.verification.key':
          if (!(await request.verifyLastStep(
              ['m.key.verification.accept', 'm.key.verification.start']))) {
            return;
          }
          _handleKey(payload);
          if (request.lastStep == 'm.key.verification.start') {
            // we need to send our key
            await _sendKey();
          } else {
            // we already sent our key, time to verify the commitment being valid
            if (!_validateCommitment()) {
              await request.cancel('m.mismatched_commitment');
              return;
            }
          }
          request.setState(KeyVerificationState.askSas);
          break;
        case 'm.key.verification.mac':
          if (!(await request.verifyLastStep(['m.key.verification.key']))) {
            return;
          }
          macPayload = payload;
          if (request.state == KeyVerificationState.waitingSas) {
            await _processMac();
          }
          break;
      }
    } catch (err, stacktrace) {
      print('[Key Verification SAS] An error occured: ' + err.toString());
      print(stacktrace);
      if (request.deviceId != null) {
        await request.cancel('m.invalid_message');
      }
    }
  }

  Future<void> acceptSas() async {
    await _sendMac();
    request.setState(KeyVerificationState.waitingSas);
    if (macPayload != null) {
      await _processMac();
    }
  }

  Future<void> rejectSas() async {
    await request.cancel('m.mismatched_sas');
  }

  @override
  Future<void> sendStart() async {
    final payload = <String, dynamic>{
      'method': type,
      'key_agreement_protocols': KNOWN_KEY_AGREEMENT_PROTOCOLS,
      'hashes': KNOWN_HASHES,
      'message_authentication_codes': KNOWN_MESSAGE_AUTHENTIFICATION_CODES,
      'short_authentication_string': knownAuthentificationTypes,
    };
    request.makePayload(payload);
    // We just store the canonical json in here for later verification
    startCanonicalJson = String.fromCharCodes(canonicalJson.encode(payload));
    await request.send('m.key.verification.start', payload);
  }

  @override
  bool validateStart(Map<String, dynamic> payload) {
    if (payload['method'] != type) {
      return false;
    }
    final possibleKeyAgreementProtocols = _intersect(
        KNOWN_KEY_AGREEMENT_PROTOCOLS, payload['key_agreement_protocols']);
    if (possibleKeyAgreementProtocols.isEmpty) {
      return false;
    }
    keyAgreementProtocol = possibleKeyAgreementProtocols.first;
    final possibleHashes = _intersect(KNOWN_HASHES, payload['hashes']);
    if (possibleHashes.isEmpty) {
      return false;
    }
    hash = possibleHashes.first;
    final possibleMessageAuthenticationCodes = _intersect(
        KNOWN_MESSAGE_AUTHENTIFICATION_CODES,
        payload['message_authentication_codes']);
    if (possibleMessageAuthenticationCodes.isEmpty) {
      return false;
    }
    messageAuthenticationCode = possibleMessageAuthenticationCodes.first;
    final possibleAuthenticationTypes = _intersect(
        knownAuthentificationTypes, payload['short_authentication_string']);
    if (possibleAuthenticationTypes.isEmpty) {
      return false;
    }
    authenticationTypes = possibleAuthenticationTypes;
    startCanonicalJson = String.fromCharCodes(canonicalJson.encode(payload));
    return true;
  }

  Future<void> _sendAccept() async {
    sas = olm.SAS();
    commitment = _makeCommitment(sas.get_pubkey(), startCanonicalJson);
    await request.send('m.key.verification.accept', {
      'method': type,
      'key_agreement_protocol': keyAgreementProtocol,
      'hash': hash,
      'message_authentication_code': messageAuthenticationCode,
      'short_authentication_string': authenticationTypes,
      'commitment': commitment,
    });
  }

  bool _handleAccept(Map<String, dynamic> payload) {
    if (!KNOWN_KEY_AGREEMENT_PROTOCOLS
        .contains(payload['key_agreement_protocol'])) {
      return false;
    }
    keyAgreementProtocol = payload['key_agreement_protocol'];
    if (!KNOWN_HASHES.contains(payload['hash'])) {
      return false;
    }
    hash = payload['hash'];
    if (!KNOWN_MESSAGE_AUTHENTIFICATION_CODES
        .contains(payload['message_authentication_code'])) {
      return false;
    }
    messageAuthenticationCode = payload['message_authentication_code'];
    final possibleAuthenticationTypes = _intersect(
        knownAuthentificationTypes, payload['short_authentication_string']);
    if (possibleAuthenticationTypes.isEmpty) {
      return false;
    }
    authenticationTypes = possibleAuthenticationTypes;
    commitment = payload['commitment'];
    sas = olm.SAS();
    return true;
  }

  Future<void> _sendKey() async {
    await request.send('m.key.verification.key', {
      'key': sas.get_pubkey(),
    });
  }

  void _handleKey(Map<String, dynamic> payload) {
    theirPublicKey = payload['key'];
    sas.set_their_key(payload['key']);
  }

  bool _validateCommitment() {
    final checkCommitment = _makeCommitment(theirPublicKey, startCanonicalJson);
    return commitment == checkCommitment;
  }

  Uint8List makeSas(int bytes) {
    var sasInfo = '';
    if (keyAgreementProtocol == 'curve25519-hkdf-sha256') {
      final ourInfo =
          '${client.userID}|${client.deviceID}|${sas.get_pubkey()}|';
      final theirInfo =
          '${request.userId}|${request.deviceId}|${theirPublicKey}|';
      sasInfo = 'MATRIX_KEY_VERIFICATION_SAS|' +
          (request.startedVerification
              ? ourInfo + theirInfo
              : theirInfo + ourInfo) +
          request.transactionId;
    } else if (keyAgreementProtocol == 'curve25519') {
      final ourInfo = client.userID + client.deviceID;
      final theirInfo = request.userId + request.deviceId;
      sasInfo = 'MATRIX_KEY_VERIFICATION_SAS' +
          (request.startedVerification
              ? ourInfo + theirInfo
              : theirInfo + ourInfo) +
          request.transactionId;
    } else {
      throw 'Unknown key agreement protocol';
    }
    return sas.generate_bytes(sasInfo, bytes);
  }

  Future<void> _sendMac() async {
    final baseInfo = 'MATRIX_KEY_VERIFICATION_MAC' +
        client.userID +
        client.deviceID +
        request.userId +
        request.deviceId +
        request.transactionId;
    final mac = <String, String>{};
    final keyList = <String>[];

    // now add all the keys we want the other to verify
    // for now it is just our device key, once we have cross-signing
    // we would also add the cross signing key here
    final deviceKeyId = 'ed25519:${client.deviceID}';
    mac[deviceKeyId] =
        _calculateMac(encryption.fingerprintKey, baseInfo + deviceKeyId);
    keyList.add(deviceKeyId);

    final masterKey = client.userDeviceKeys.containsKey(client.userID)
        ? client.userDeviceKeys[client.userID].masterKey
        : null;
    if (masterKey != null && masterKey.verified) {
      // we have our own master key verified, let's send it!
      final masterKeyId = 'ed25519:${masterKey.publicKey}';
      mac[masterKeyId] =
          _calculateMac(masterKey.publicKey, baseInfo + masterKeyId);
      keyList.add(masterKeyId);
    }

    keyList.sort();
    final keys = _calculateMac(keyList.join(','), baseInfo + 'KEY_IDS');
    await request.send('m.key.verification.mac', {
      'mac': mac,
      'keys': keys,
    });
  }

  Future<void> _processMac() async {
    final payload = macPayload;
    final baseInfo = 'MATRIX_KEY_VERIFICATION_MAC' +
        request.userId +
        request.deviceId +
        client.userID +
        client.deviceID +
        request.transactionId;

    final keyList = payload['mac'].keys.toList();
    keyList.sort();
    if (payload['keys'] !=
        _calculateMac(keyList.join(','), baseInfo + 'KEY_IDS')) {
      await request.cancel('m.key_mismatch');
      return;
    }

    if (!client.userDeviceKeys.containsKey(request.userId)) {
      await request.cancel('m.key_mismatch');
      return;
    }
    final mac = <String, String>{};
    for (final entry in payload['mac'].entries) {
      if (entry.value is String) {
        mac[entry.key] = entry.value;
      }
    }
    await request.verifyKeys(mac, (String mac, SignableKey key) async {
      return mac ==
          _calculateMac(key.ed25519Key, baseInfo + 'ed25519:' + key.identifier);
    });
  }

  String _makeCommitment(String pubKey, String canonicalJson) {
    if (hash == 'sha256') {
      final olmutil = olm.Utility();
      final ret = olmutil.sha256(pubKey + canonicalJson);
      olmutil.free();
      return ret;
    }
    throw 'Unknown hash method';
  }

  String _calculateMac(String input, String info) {
    if (messageAuthenticationCode == 'hkdf-hmac-sha256') {
      return sas.calculate_mac(input, info);
    } else {
      throw 'Unknown message authentification code';
    }
  }
}

const _emojiMap = [
  {
    'emoji': '\u{1F436}',
    'name': 'Dog',
  },
  {
    'emoji': '\u{1F431}',
    'name': 'Cat',
  },
  {
    'emoji': '\u{1F981}',
    'name': 'Lion',
  },
  {
    'emoji': '\u{1F40E}',
    'name': 'Horse',
  },
  {
    'emoji': '\u{1F984}',
    'name': 'Unicorn',
  },
  {
    'emoji': '\u{1F437}',
    'name': 'Pig',
  },
  {
    'emoji': '\u{1F418}',
    'name': 'Elephant',
  },
  {
    'emoji': '\u{1F430}',
    'name': 'Rabbit',
  },
  {
    'emoji': '\u{1F43C}',
    'name': 'Panda',
  },
  {
    'emoji': '\u{1F413}',
    'name': 'Rooster',
  },
  {
    'emoji': '\u{1F427}',
    'name': 'Penguin',
  },
  {
    'emoji': '\u{1F422}',
    'name': 'Turtle',
  },
  {
    'emoji': '\u{1F41F}',
    'name': 'Fish',
  },
  {
    'emoji': '\u{1F419}',
    'name': 'Octopus',
  },
  {
    'emoji': '\u{1F98B}',
    'name': 'Butterfly',
  },
  {
    'emoji': '\u{1F337}',
    'name': 'Flower',
  },
  {
    'emoji': '\u{1F333}',
    'name': 'Tree',
  },
  {
    'emoji': '\u{1F335}',
    'name': 'Cactus',
  },
  {
    'emoji': '\u{1F344}',
    'name': 'Mushroom',
  },
  {
    'emoji': '\u{1F30F}',
    'name': 'Globe',
  },
  {
    'emoji': '\u{1F319}',
    'name': 'Moon',
  },
  {
    'emoji': '\u{2601}\u{FE0F}',
    'name': 'Cloud',
  },
  {
    'emoji': '\u{1F525}',
    'name': 'Fire',
  },
  {
    'emoji': '\u{1F34C}',
    'name': 'Banana',
  },
  {
    'emoji': '\u{1F34E}',
    'name': 'Apple',
  },
  {
    'emoji': '\u{1F353}',
    'name': 'Strawberry',
  },
  {
    'emoji': '\u{1F33D}',
    'name': 'Corn',
  },
  {
    'emoji': '\u{1F355}',
    'name': 'Pizza',
  },
  {
    'emoji': '\u{1F382}',
    'name': 'Cake',
  },
  {
    'emoji': '\u{2764}\u{FE0F}',
    'name': 'Heart',
  },
  {
    'emoji': '\u{1F600}',
    'name': 'Smiley',
  },
  {
    'emoji': '\u{1F916}',
    'name': 'Robot',
  },
  {
    'emoji': '\u{1F3A9}',
    'name': 'Hat',
  },
  {
    'emoji': '\u{1F453}',
    'name': 'Glasses',
  },
  {
    'emoji': '\u{1F527}',
    'name': 'Spanner',
  },
  {
    'emoji': '\u{1F385}',
    'name': 'Santa',
  },
  {
    'emoji': '\u{1F44D}',
    'name': 'Thumbs Up',
  },
  {
    'emoji': '\u{2602}\u{FE0F}',
    'name': 'Umbrella',
  },
  {
    'emoji': '\u{231B}',
    'name': 'Hourglass',
  },
  {
    'emoji': '\u{23F0}',
    'name': 'Clock',
  },
  {
    'emoji': '\u{1F381}',
    'name': 'Gift',
  },
  {
    'emoji': '\u{1F4A1}',
    'name': 'Light Bulb',
  },
  {
    'emoji': '\u{1F4D5}',
    'name': 'Book',
  },
  {
    'emoji': '\u{270F}\u{FE0F}',
    'name': 'Pencil',
  },
  {
    'emoji': '\u{1F4CE}',
    'name': 'Paperclip',
  },
  {
    'emoji': '\u{2702}\u{FE0F}',
    'name': 'Scissors',
  },
  {
    'emoji': '\u{1F512}',
    'name': 'Lock',
  },
  {
    'emoji': '\u{1F511}',
    'name': 'Key',
  },
  {
    'emoji': '\u{1F528}',
    'name': 'Hammer',
  },
  {
    'emoji': '\u{260E}\u{FE0F}',
    'name': 'Telephone',
  },
  {
    'emoji': '\u{1F3C1}',
    'name': 'Flag',
  },
  {
    'emoji': '\u{1F682}',
    'name': 'Train',
  },
  {
    'emoji': '\u{1F6B2}',
    'name': 'Bicycle',
  },
  {
    'emoji': '\u{2708}\u{FE0F}',
    'name': 'Aeroplane',
  },
  {
    'emoji': '\u{1F680}',
    'name': 'Rocket',
  },
  {
    'emoji': '\u{1F3C6}',
    'name': 'Trophy',
  },
  {
    'emoji': '\u{26BD}',
    'name': 'Ball',
  },
  {
    'emoji': '\u{1F3B8}',
    'name': 'Guitar',
  },
  {
    'emoji': '\u{1F3BA}',
    'name': 'Trumpet',
  },
  {
    'emoji': '\u{1F514}',
    'name': 'Bell',
  },
  {
    'emoji': '\u{2693}',
    'name': 'Anchor',
  },
  {
    'emoji': '\u{1F3A7}',
    'name': 'Headphones',
  },
  {
    'emoji': '\u{1F4C1}',
    'name': 'Folder',
  },
  {
    'emoji': '\u{1F4CC}',
    'name': 'Pin',
  },
];

class KeyVerificationEmoji {
  final int number;
  KeyVerificationEmoji(this.number);

  String get emoji => _emojiMap[number]['emoji'];
  String get name => _emojiMap[number]['name'];
}
