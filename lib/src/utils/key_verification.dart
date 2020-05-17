import 'dart:typed_data';
import 'package:random_string/random_string.dart';
import 'package:canonical_json/canonical_json.dart';
import 'package:olm/olm.dart' as olm;
import 'device_keys_list.dart';
import '../client.dart';
import '../room.dart';

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

final KNOWN_KEY_AGREEMENT_PROTOCOLS = ['curve25519-hkdf-sha256', 'curve25519'];
final KNOWN_HASHES = ['sha256'];
final KNOWN_MESSAGE_AUTHENTIFICATION_CODES = ['hkdf-hmac-sha256'];
final KNOWN_AUTHENTICATION_TYPES = ['emoji', 'decimal'];

enum KeyVerificationState { askAccept, waitingAccept, askSas, waitingSas, done, error }

class KeyVerification {
  String transactionId;
  final Client client;
  final Room room;
  final String userId;
  void Function() onUpdate;
  String  get deviceId => _deviceId;
  String _deviceId;
  olm.SAS sas;
  bool startedVerification = false;

  String keyAgreementProtocol;
  String hash;
  String messageAuthenticationCode;
  List<String> authenticationTypes;
  String startCanonicalJson;
  String commitment;
  String theirPublicKey;

  DateTime lastActivity;
  String lastStep;

  KeyVerificationState state = KeyVerificationState.waitingAccept;
  bool canceled = false;
  String canceledCode;
  String canceledReason;

  Map<String, dynamic> macPayload;

  KeyVerification({this.client, this.room, this.userId, String deviceId, this.onUpdate}) {
    lastActivity = DateTime.now();
    _deviceId ??= deviceId;
  }

  void dispose() {
    print('[Key Verification] disposing object...');
    sas?.free();
  }

  static String getTransactionId(Map<String, dynamic> payload) {
    return payload['transaction_id'] ?? (
      payload['m.relates_to'] is Map ? payload['m.relates_to']['event_id'] : null
    );
  }

  Future<void> start() async {
    if (room == null) {
      transactionId = randomString(512);
    }
    await send('m.key.verification.request', {
      'methods': ['m.sas.v1'],
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    startedVerification = true;
    _setState(KeyVerificationState.waitingAccept);
  }

  Future<void> handlePayload(String type, Map<String, dynamic> payload, [String eventId]) async {
    print('[Key Verification] Received type ${type}: ' + payload.toString());
    try {
      switch (type) {
        case 'm.key.verification.request':
          _deviceId ??= payload['from_device'];
          transactionId ??= eventId ?? payload['transaction_id'];
          // verify it has a method we can use
          if (!(payload['methods'] is List && payload['methods'].contains('m.sas.v1'))) {
            // reject it outright
            await cancel('m.unknown_method');
            return;
          }
          // verify the timestamp
          final now = DateTime.now();
          final verifyTime = DateTime.fromMillisecondsSinceEpoch(payload['timestamp']);
          if (now.subtract(Duration(minutes: 10)).isAfter(verifyTime) || now.add(Duration(minutes: 5)).isBefore(verifyTime)) {
            await cancel('m.timeout');
            return;
          }
          _setState(KeyVerificationState.askAccept);
          break;
        case 'm.key.verification.ready':
          await _sendStart();
          _setState(KeyVerificationState.waitingAccept);
          break;
        case 'm.key.verification.start':
          _deviceId ??= payload['from_device'];
          transactionId ??= eventId ?? payload['transaction_id'];
          if (!(await verifyLastStep(['m.key.verification.request', null]))) {
            return; // abort
          }
          if (!_validateStart(payload)) {
            await cancel('m.unknown_method');
            return;
          }
          if (lastStep == null) {
            // we need to ask the user for verification
            _setState(KeyVerificationState.askAccept);
          } else {
            await _sendAccept();
          }
          break;
        case 'm.key.verification.accept':
          if (!(await verifyLastStep(['m.key.verification.ready', null]))) {
            return;
          }
          if (!_handleAccept(payload)) {
            await cancel('m.unknown_method');
            return;
          }
          await _sendKey();
          break;
        case 'm.key.verification.key':
          if (!(await verifyLastStep(['m.key.verification.accept', 'm.key.verification.start']))) {
            return;
          }
          _handleKey(payload);
          if (lastStep == 'm.key.verification.start') {
            // we need to send our key
            await _sendKey();
          } else {
            // we already sent our key, time to verify the commitment being valid
            if (!_validateCommitment()) {
              await cancel('m.mismatched_commitment');
              return;
            }
          }
          _setState(KeyVerificationState.askSas);
          break;
        case 'm.key.verification.mac':
          if (!(await verifyLastStep(['m.key.verification.key']))) {
            return;
          }
          macPayload = payload;
          if (state == KeyVerificationState.waitingSas) {
            await _processMac();
          }
          break;
        case 'm.key.verification.done':
          // do nothing
          break;
        case 'm.key.verification.cancel':
          canceled = true;
          canceledCode = payload['code'];
          canceledReason = payload['reason'];
          _setState(KeyVerificationState.error);
          break;
        default:
          return;
      }
      lastStep = type;
    } catch (err, stacktrace) {
      print('[Key Verification] An error occured: ' + err.toString());
      print(stacktrace);
      if (deviceId != null) {
        await cancel('m.invalid_message');
      }
    }
  }

  /// called when the user accepts an incoming verification
  Future<void> acceptVerification() async {
    if (!(await verifyLastStep(['m.key.verification.request', 'm.key.verification.start']))) {
      return;
    }
    _setState(KeyVerificationState.waitingAccept);
    if (lastStep == 'm.key.verification.request') {
      // we need to send a ready event
      await send('m.key.verification.ready', {
        'methods': ['m.sas.v1'],
      });
    } else {
      // we need to send an accept event
      await _sendAccept();
    }
  }

  /// called when the user rejects an incoming verification
  Future<void> rejectVerification() async {
    if (!(await verifyLastStep(['m.key.verification.request', 'm.key.verification.start']))) {
      return;
    }
    await cancel('m.user');
  }

  Future<void> acceptSas() async {
    await _sendMac();
    _setState(KeyVerificationState.waitingSas);
    if (macPayload != null) {
      await _processMac();
    }
  }

  Future<void> rejectSas() async {
    await cancel('m.mismatched_sas');
  }

  List<int> get sasNumbers {
    return _bytesToInt(_makeSas(5), 13).map((n) => n + 1000).toList();
  }

  List<KeyVerificationEmoji> get sasEmojis {
    final numbers = _bytesToInt(_makeSas(6), 6);
    return numbers.map((n) => KeyVerificationEmoji(n)).toList().sublist(0, 7);
  }

  Future<void> _sendStart() async {
    final payload = <String, dynamic>{
      'method': 'm.sas.v1',
      'key_agreement_protocols': KNOWN_KEY_AGREEMENT_PROTOCOLS,
      'hashes': KNOWN_HASHES,
      'message_authentication_codes': KNOWN_MESSAGE_AUTHENTIFICATION_CODES,
      'short_authentication_string': KNOWN_AUTHENTICATION_TYPES,
    };
    _makePayload(payload);
    // We just store the canonical json in here for later verification
    startCanonicalJson = String.fromCharCodes(canonicalJson.encode(payload));
    await send('m.key.verification.start', payload);
  }

  bool _validateStart(Map<String, dynamic> payload) {
    if (payload['method'] != 'm.sas.v1') {
      return false;
    }
    final possibleKeyAgreementProtocols = _intersect(KNOWN_KEY_AGREEMENT_PROTOCOLS, payload['key_agreement_protocols']);
    if (possibleKeyAgreementProtocols.isEmpty) {
      return false;
    }
    keyAgreementProtocol = possibleKeyAgreementProtocols.first;
    final possibleHashes = _intersect(KNOWN_HASHES, payload['hashes']);
    if (possibleHashes.isEmpty) {
      return false;
    }
    hash = possibleHashes.first;
    final possibleMessageAuthenticationCodes = _intersect(KNOWN_MESSAGE_AUTHENTIFICATION_CODES, payload['message_authentication_codes']);
    if (possibleMessageAuthenticationCodes.isEmpty) {
      return false;
    }
    messageAuthenticationCode = possibleMessageAuthenticationCodes.first;
    final possibleAuthenticationTypes = _intersect(KNOWN_AUTHENTICATION_TYPES, payload['short_authentication_string']);
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
    await send('m.key.verification.accept', {
      'method': 'm.sas.v1',
      'key_agreement_protocol': keyAgreementProtocol,
      'hash': hash,
      'message_authentication_code': messageAuthenticationCode,
      'short_authentication_string': authenticationTypes,
      'commitment': commitment,
    });
  }

  bool _handleAccept(Map<String, dynamic> payload) {
    if (!KNOWN_KEY_AGREEMENT_PROTOCOLS.contains(payload['key_agreement_protocol'])) {
      return false;
    }
    keyAgreementProtocol = payload['key_agreement_protocol'];
    if (!KNOWN_HASHES.contains(payload['hash'])) {
      return false;
    }
    hash = payload['hash'];
    if (!KNOWN_MESSAGE_AUTHENTIFICATION_CODES.contains(payload['message_authentication_code'])) {
      return false;
    }
    messageAuthenticationCode = payload['message_authentication_code'];
    final possibleAuthenticationTypes = _intersect(KNOWN_AUTHENTICATION_TYPES, payload['short_authentication_string']);
    if (possibleAuthenticationTypes.isEmpty) {
      return false;
    }
    authenticationTypes = possibleAuthenticationTypes;
    commitment = payload['commitment'];
    sas = olm.SAS();
    return true;
  }

  Future<void> _sendKey() async {
    await send('m.key.verification.key', {
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

  Uint8List _makeSas(int bytes) {
    var sasInfo = '';
    if (keyAgreementProtocol == 'curve25519-hkdf-sha256') {
      final ourInfo = '${client.userID}|${client.deviceID}|${sas.get_pubkey()}|';
      final theirInfo = '${userId}|${deviceId}|${theirPublicKey}|';
      sasInfo = 'MATRIX_KEY_VERIFICATION_SAS|' + (startedVerification ? ourInfo + theirInfo : theirInfo + ourInfo) + transactionId;
    } else if (keyAgreementProtocol == 'curve25519') {
      final ourInfo = client.userID + client.deviceID;
      final theirInfo = userId + deviceId;
      sasInfo = 'MATRIX_KEY_VERIFICATION_SAS' + (startedVerification ? ourInfo + theirInfo : theirInfo + ourInfo) + transactionId;
    } else {
      throw 'Unknown key agreement protocol';
    }
    print('++++++++++++++++');
    print(keyAgreementProtocol);
    print(sasInfo);
    return sas.generate_bytes(sasInfo, bytes);
  }

  Future<void> _sendMac() async {
    final baseInfo = 'MATRIX_KEY_VERIFICATION_MAC' +
      client.userID + client.deviceID +
      userId + deviceId +
      transactionId;
    final mac = <String, String>{};
    final keyList = <String>[];

    // now add all the keys we want the other to verify
    // for now it is just our device key, once we have cross-signing
    // we would also add the cross signing key here
    final deviceKeyId = 'ed25519:${client.deviceID}';
    mac[deviceKeyId] = _calculateMac(client.fingerprintKey, baseInfo + deviceKeyId);
    keyList.add(deviceKeyId);

    keyList.sort();
    final keys = _calculateMac(keyList.join(','), baseInfo + 'KEY_IDS');
    await send('m.key.verification.mac', {
      'mac': mac,
      'keys': keys,
    });
  }

  Future<void> _processMac() async {
    final payload = macPayload;
    final baseInfo = 'MATRIX_KEY_VERIFICATION_MAC' +
      userId + deviceId +
      client.userID + client.deviceID +
      transactionId;

    final keyList = payload['mac'].keys.toList();
    keyList.sort();
    if (payload['keys'] != _calculateMac(keyList.join(','), baseInfo + 'KEY_IDS')) {
      await cancel('m.key_mismatch');
      return;
    }

    if (!client.userDeviceKeys.containsKey(userId)) {
      await cancel('m.key_mismatch');
      return;
    }
    final mac = <String, String>{};
    for (final entry in payload['mac'].entries) {
      if (entry.value is String) {
        mac[entry.key] = entry.value;
      }
    }
    await _verifyKeys(mac, (String mac, DeviceKeys device) async {
      return mac == _calculateMac(device.ed25519Key, baseInfo + 'ed25519:' + device.deviceId);
    });
    await send('m.key.verification.done', {});
    if (state != KeyVerificationState.error) {
      _setState(KeyVerificationState.done);
    }
  }

  Future<void> _verifyKeys(Map<String, String> keys, Future<bool> Function(String, DeviceKeys) verifier) async {
    final verifiedDevices = <String>[];

    if (!client.userDeviceKeys.containsKey(userId)) {
      await cancel('m.key_mismatch');
      return;
    }
    for (final entry in keys.entries) {
      final keyId = entry.key;
      final verifyDeviceId = keyId.substring('ed25519:'.length);
      final keyInfo = entry.value;
      if (client.userDeviceKeys[userId].deviceKeys.containsKey(verifyDeviceId)) {
        if (!(await verifier(keyInfo, client.userDeviceKeys[userId].deviceKeys[verifyDeviceId]))) {
          await cancel('m.key_mismatch');
          return;
        }
        verifiedDevices.add(verifyDeviceId);
      } else {
        // TODO: we would check here if what we are verifying is actually a
        // cross-signing key and not a "normal" device key
      }
    }
    // okay, we reached this far, so all the devices are verified!
    for (final verifyDeviceId in verifiedDevices) {
      await client.userDeviceKeys[userId].deviceKeys[verifyDeviceId].setVerified(true, client);
    }
  }

  String _calculateMac(String input, String info) {
    if (messageAuthenticationCode == 'hkdf-hmac-sha256') {
      return sas.calculate_mac(input, info);
    } else {
      throw 'Unknown message authentification code';
    }
  }

  Future<bool> verifyActivity() async {
    if (lastActivity != null && lastActivity.add(Duration(minutes: 10)).isAfter(DateTime.now())) {
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
    _setState(KeyVerificationState.error);
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

  void _makePayload(Map<String, dynamic> payload) {
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
    _makePayload(payload);
    print('[Key Verification] Sending type ${type}: ' + payload.toString());
    print('[Key Verification] Sending to ${userId} device ${deviceId}');
    if (room != null) {
      if (['m.key.verification.request'].contains(type)) {
        payload['msgtype'] = type;
        payload['to'] = userId;
        payload['body'] = 'Attempting verification request. (${type}) Apparently your client doesn\'t support this';
        type = 'm.room.message';
      }
      final newTransactionId = await room.sendEvent(payload, type: type);
      if (transactionId == null) {
        transactionId = newTransactionId;
        client.addKeyVerificationRequest(this);
      }
    } else {
      await client.sendToDevice([client.userDeviceKeys[userId].deviceKeys[deviceId]], type, payload);
    }
  }

  void _setState(KeyVerificationState newState) {
    if (state != KeyVerificationState.error) {
      state = newState;
    }
    if (onUpdate != null) {
      onUpdate();
    }
  }

  List<String> _intersect(List<String> a, List<dynamic> b) {
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
