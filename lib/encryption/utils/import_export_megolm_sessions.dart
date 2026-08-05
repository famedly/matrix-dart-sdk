import 'dart:convert';
import 'dart:typed_data';

import 'package:matrix/encryption/utils/session_key.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/crypto/crypto.dart' as uc;
import 'package:vodozemac/vodozemac.dart';

extension ImportExportMegolmSessions on Client {
  /// Exports all megolm sessions and encrypts them with the given passphrase.
  /// The key will be derived from the passphrase via PBKDF2 as specified in
  /// https://spec.matrix.org/v1.18/client-server-api/#key-exports with a
  /// 128 long salt and 100.000 iterations. This can take some time so it is
  /// recommended to run this method in a different isolate.
  /// Please make sure that you have all desired keys downloaded before.
  /// You can download all keys with
  /// `Client.encryption!.keyManager.loadAllKeys()`.
  Future<Uint8List> exportMegolmSessions(
    String passphrase, {
    int iterations = 100000,
    int saltLength = 16,
    int ivLength = 16,
  }) async {
    final salt = base64.encode(uc.secureRandomBytes(saltLength));
    // TODO: We need 512 bits, not 256 but 256 is right now hardcoded in dart-vodozemac
    // TODO: We need HMAC
    final key = CryptoUtils.pbkdf2(
      passphrase: Uint8List.fromList(utf8.encode(passphrase)),
      salt: Uint8List.fromList(utf8.encode(salt)),
      iterations: iterations,
    );

    final megolmSessions = await database.getAllInboundGroupSessions();
    final exportedSessionDatas = megolmSessions
        .map((session) {
          final key = SessionKey.fromDb(session, userID!);
          return ExportedSessionData(
            senderKey: session.senderKey,
            sessionId: session.sessionId,
            sessionKey: key.inboundGroupSession!.exportAtFirstKnownIndex(),
            roomId: session.roomId,
            algorithm: 'm.megolm.v1.aes-sha2',
            forwardingCurve25519KeyChain: key.forwardingCurve25519KeyChain,
            senderClaimedKeys: key.senderClaimedKeys,
          );
        })
        .map((data) => data.toJson())
        .toList();

    final exportString = jsonEncode(exportedSessionDatas);
    final input = utf8.encode(exportString);

    final iv = uc.secureRandomBytes(ivLength);
    // Setting bit 63 to zero in IV is needed to work around differences in implementations of AES-CTR.
    iv[7] &= 0x7F;

    final encryptedExport = CryptoUtils.aesCtr(input: input, key: key, iv: iv);
    return encryptedExport; // TODO: Implement concatenating as String
  }
}

Future<void> importMegolmSessions(String passphrase, String fileContent) async {
  throw UnimplementedError(); // TODO: Implement me
}

class ExportedSessionData {
  final String senderKey, sessionId, sessionKey, roomId, algorithm;
  final List<String> forwardingCurve25519KeyChain;
  final Map<String, String> senderClaimedKeys;

  ExportedSessionData({
    required this.senderKey,
    required this.sessionId,
    required this.sessionKey,
    required this.roomId,
    required this.algorithm,
    required this.forwardingCurve25519KeyChain,
    required this.senderClaimedKeys,
  });

  factory ExportedSessionData.fromJson(Map<String, Object?> json) =>
      ExportedSessionData(
        senderKey: json['sender_key'] as String,
        sessionId: json['session_id'] as String,
        sessionKey: json['session_key'] as String,
        roomId: json['room_id'] as String,
        algorithm: json['algorithm'] as String,
        forwardingCurve25519KeyChain: List<String>.from(
          json['forwarding_curve25519_key_chain'] as List,
        ),
        senderClaimedKeys: Map<String, String>.from(
          json['sender_claimed_keys'] as Map,
        ),
      );

  Map<String, Object?> toJson() => {
    'sender_key': senderKey,
    'session_id': sessionId,
    'session_key': sessionKey,
    'room_id': roomId,
    'algorithm': algorithm,
    'forwarding_curve25519_key_chain': forwardingCurve25519KeyChain,
    'sender_claimed_keys': senderClaimedKeys,
  };
}
