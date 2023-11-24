/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020, 2021 Famedly GmbH
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
import 'dart:convert';

import 'package:olm/olm.dart' as olm;

import 'package:matrix/encryption/cross_signing.dart';
import 'package:matrix/encryption/key_manager.dart';
import 'package:matrix/encryption/key_verification_manager.dart';
import 'package:matrix/encryption/olm_manager.dart';
import 'package:matrix/encryption/ssss.dart';
import 'package:matrix/encryption/utils/bootstrap.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/run_in_root.dart';

class Encryption {
  final Client client;
  final bool debug;

  bool get enabled => olmManager.enabled;

  /// Returns the base64 encoded keys to store them in a store.
  /// This String should **never** leave the device!
  String? get pickledOlmAccount => olmManager.pickledOlmAccount;

  String? get fingerprintKey => olmManager.fingerprintKey;
  String? get identityKey => olmManager.identityKey;

  /// Returns the database used to store olm sessions and the olm account.
  /// We don't want to store olm keys for dehydrated devices.
  DatabaseApi? get olmDatabase =>
      ourDeviceId == client.deviceID ? client.database : null;

  late final KeyManager keyManager;
  late final OlmManager olmManager;
  late final KeyVerificationManager keyVerificationManager;
  late final CrossSigning crossSigning;
  late SSSS ssss; // some tests mock this, which is why it isn't final

  late String ourDeviceId;

  Encryption({
    required this.client,
    this.debug = false,
  }) {
    ssss = SSSS(this);
    keyManager = KeyManager(this);
    olmManager = OlmManager(this);
    keyVerificationManager = KeyVerificationManager(this);
    crossSigning = CrossSigning(this);
  }

  // initial login passes null to init a new olm account
  Future<void> init(String? olmAccount,
      {String? deviceId,
      String? pickleKey,
      bool isDehydratedDevice = false}) async {
    ourDeviceId = deviceId ?? client.deviceID!;
    await olmManager.init(
        olmAccount: olmAccount,
        deviceId: isDehydratedDevice ? deviceId : ourDeviceId,
        pickleKey: pickleKey);

    if (!isDehydratedDevice) keyManager.startAutoUploadKeys();
  }

  bool isMinOlmVersion(int major, int minor, int patch) {
    try {
      final version = olm.get_library_version();
      return version[0] > major ||
          (version[0] == major &&
              (version[1] > minor ||
                  (version[1] == minor && version[2] >= patch)));
    } catch (_) {
      return false;
    }
  }

  Bootstrap bootstrap({void Function(Bootstrap)? onUpdate}) => Bootstrap(
        encryption: this,
        onUpdate: onUpdate,
      );

  void handleDeviceOneTimeKeysCount(
      Map<String, int>? countJson, List<String>? unusedFallbackKeyTypes) {
    runInRoot(() async => olmManager.handleDeviceOneTimeKeysCount(
        countJson, unusedFallbackKeyTypes));
  }

  void onSync() {
    // ignore: discarded_futures
    keyVerificationManager.cleanup();
  }

  Future<void> handleToDeviceEvent(ToDeviceEvent event) async {
    if (event.type == EventTypes.RoomKey) {
      // a new room key. We need to handle this asap, before other
      // events in /sync are handled
      await keyManager.handleToDeviceEvent(event);
    }
    if ([EventTypes.RoomKeyRequest, EventTypes.ForwardedRoomKey]
        .contains(event.type)) {
      // "just" room key request things. We don't need these asap, so we handle
      // them in the background
      runInRoot(() => keyManager.handleToDeviceEvent(event));
    }
    if (event.type == EventTypes.Dummy) {
      // the previous device just had to create a new olm session, due to olm session
      // corruption. We want to try to send it the last message we just sent it, if possible
      runInRoot(() => olmManager.handleToDeviceEvent(event));
    }
    if (event.type.startsWith('m.key.verification.')) {
      // some key verification event. No need to handle it now, we can easily
      // do this in the background

      runInRoot(() => keyVerificationManager.handleToDeviceEvent(event));
    }
    if (event.type.startsWith('m.secret.')) {
      // some ssss thing. We can do this in the background
      runInRoot(() => ssss.handleToDeviceEvent(event));
    }
    if (event.sender == client.userID) {
      // maybe we need to re-try SSSS secrets
      runInRoot(() => ssss.periodicallyRequestMissingCache());
    }
  }

  Future<void> handleEventUpdate(EventUpdate update) async {
    if (update.type == EventUpdateType.ephemeral ||
        update.type == EventUpdateType.history) {
      return;
    }
    if (update.content['type'].startsWith('m.key.verification.') ||
        (update.content['type'] == EventTypes.Message &&
            (update.content['content']['msgtype'] is String) &&
            update.content['content']['msgtype']
                .startsWith('m.key.verification.'))) {
      // "just" key verification, no need to do this in sync
      runInRoot(() => keyVerificationManager.handleEventUpdate(update));
    }
    if (update.content['sender'] == client.userID &&
        update.content['unsigned']?['transaction_id'] == null) {
      // maybe we need to re-try SSSS secrets
      runInRoot(() => ssss.periodicallyRequestMissingCache());
    }
  }

  Future<ToDeviceEvent> decryptToDeviceEvent(ToDeviceEvent event) async {
    try {
      return await olmManager.decryptToDeviceEvent(event);
    } catch (e, s) {
      Logs().w(
          '[LibOlm] Could not decrypt to device event from ${event.sender} with content: ${event.content}',
          e,
          s);
      client.onEncryptionError.add(
        SdkError(
          exception: e is Exception ? e : Exception(e),
          stackTrace: s,
        ),
      );
      return event;
    }
  }

  Event decryptRoomEventSync(String roomId, Event event) {
    if (event.type != EventTypes.Encrypted || event.redacted) {
      return event;
    }
    final content = event.parsedRoomEncryptedContent;
    if (event.type != EventTypes.Encrypted ||
        content.ciphertextMegolm == null) {
      return event;
    }
    Map<String, dynamic> decryptedPayload;
    var canRequestSession = false;
    try {
      if (content.algorithm != AlgorithmTypes.megolmV1AesSha2) {
        throw DecryptException(DecryptException.unknownAlgorithm);
      }
      final sessionId = content.sessionId;
      if (sessionId == null) {
        throw DecryptException(DecryptException.unknownSession);
      }

      final inboundGroupSession =
          keyManager.getInboundGroupSession(roomId, sessionId);
      if (!(inboundGroupSession?.isValid ?? false)) {
        canRequestSession = true;
        throw DecryptException(DecryptException.unknownSession);
      }

      // decrypt errors here may mean we have a bad session key - others might have a better one
      canRequestSession = true;

      final decryptResult = inboundGroupSession!.inboundGroupSession!
          .decrypt(content.ciphertextMegolm!);
      canRequestSession = false;

      // we can't have the key be an int, else json-serializing will fail, thus we need it to be a string
      final messageIndexKey = 'key-${decryptResult.message_index}';
      final messageIndexValue =
          '${event.eventId}|${event.originServerTs.millisecondsSinceEpoch}';
      final haveIndex =
          inboundGroupSession.indexes.containsKey(messageIndexKey);
      if (haveIndex &&
          inboundGroupSession.indexes[messageIndexKey] != messageIndexValue) {
        Logs().e('[Decrypt] Could not decrypt due to a corrupted session.');
        throw DecryptException(DecryptException.channelCorrupted);
      }

      inboundGroupSession.indexes[messageIndexKey] = messageIndexValue;
      if (!haveIndex) {
        // now we persist the udpated indexes into the database.
        // the entry should always exist. In the case it doesn't, the following
        // line *could* throw an error. As that is a future, though, and we call
        // it un-awaited here, nothing happens, which is exactly the result we want
        client.database
            // ignore: discarded_futures
            ?.updateInboundGroupSessionIndexes(
                json.encode(inboundGroupSession.indexes), roomId, sessionId)
            // ignore: discarded_futures
            .onError((e, _) => Logs().e('Ignoring error for updating indexes'));
      }
      decryptedPayload = json.decode(decryptResult.plaintext);
    } catch (exception) {
      // alright, if this was actually by our own outbound group session, we might as well clear it
      if (exception.toString() != DecryptException.unknownSession &&
          (keyManager
                      .getOutboundGroupSession(roomId)
                      ?.outboundGroupSession
                      ?.session_id() ??
                  '') ==
              content.sessionId) {
        runInRoot(() async =>
            keyManager.clearOrUseOutboundGroupSession(roomId, wipe: true));
      }
      if (canRequestSession) {
        decryptedPayload = {
          'content': event.content,
          'type': EventTypes.Encrypted,
        };
        decryptedPayload['content']['body'] = exception.toString();
        decryptedPayload['content']['msgtype'] = MessageTypes.BadEncrypted;
        decryptedPayload['content']['can_request_session'] = true;
      } else {
        decryptedPayload = {
          'content': <String, dynamic>{
            'msgtype': MessageTypes.BadEncrypted,
            'body': exception.toString(),
          },
          'type': EventTypes.Encrypted,
        };
      }
    }
    if (event.content['m.relates_to'] != null) {
      decryptedPayload['content']['m.relates_to'] =
          event.content['m.relates_to'];
    }
    return Event(
      content: decryptedPayload['content'],
      type: decryptedPayload['type'],
      senderId: event.senderId,
      eventId: event.eventId,
      room: event.room,
      originServerTs: event.originServerTs,
      unsigned: event.unsigned,
      stateKey: event.stateKey,
      prevContent: event.prevContent,
      status: event.status,
      originalSource: event,
    );
  }

  Future<Event> decryptRoomEvent(String roomId, Event event,
      {bool store = false,
      EventUpdateType updateType = EventUpdateType.timeline}) async {
    if (event.type != EventTypes.Encrypted || event.redacted) {
      return event;
    }
    final content = event.parsedRoomEncryptedContent;
    final sessionId = content.sessionId;
    try {
      if (client.database != null &&
          sessionId != null &&
          !(keyManager
                  .getInboundGroupSession(
                    roomId,
                    sessionId,
                  )
                  ?.isValid ??
              false)) {
        await keyManager.loadInboundGroupSession(
          roomId,
          sessionId,
        );
      }
      event = decryptRoomEventSync(roomId, event);
      if (event.type == EventTypes.Encrypted &&
          event.content['can_request_session'] == true &&
          sessionId != null) {
        keyManager.maybeAutoRequest(
          roomId,
          sessionId,
          content.senderKey,
        );
      }
      if (event.type != EventTypes.Encrypted && store) {
        if (updateType != EventUpdateType.history) {
          event.room.setState(event);
        }
        await client.database?.storeEventUpdate(
          EventUpdate(
            content: event.toJson(),
            roomID: roomId,
            type: updateType,
          ),
          client,
        );
      }
      return event;
    } catch (e, s) {
      Logs().e('[Decrypt] Could not decrpyt event', e, s);
      return event;
    }
  }

  /// Encrypts the given json payload and creates a send-ready m.room.encrypted
  /// payload. This will create a new outgoingGroupSession if necessary.
  Future<Map<String, dynamic>> encryptGroupMessagePayload(
      String roomId, Map<String, dynamic> payload,
      {String type = EventTypes.Message}) async {
    payload = copyMap(payload);
    final Map<String, dynamic>? mRelatesTo = payload.remove('m.relates_to');

    // Events which only contain a m.relates_to like reactions don't need to
    // be encrypted.
    if (payload.isEmpty && mRelatesTo != null) {
      return {'m.relates_to': mRelatesTo};
    }
    final room = client.getRoomById(roomId);
    if (room == null || !room.encrypted || !enabled) {
      return payload;
    }
    if (room.encryptionAlgorithm != AlgorithmTypes.megolmV1AesSha2) {
      throw ('Unknown encryption algorithm');
    }
    if (keyManager.getOutboundGroupSession(roomId)?.isValid != true) {
      await keyManager.loadOutboundGroupSession(roomId);
    }
    await keyManager.clearOrUseOutboundGroupSession(roomId);
    if (keyManager.getOutboundGroupSession(roomId)?.isValid != true) {
      await keyManager.createOutboundGroupSession(roomId);
    }
    final sess = keyManager.getOutboundGroupSession(roomId);
    if (sess?.isValid != true) {
      throw ('Unable to create new outbound group session');
    }
    // we clone the payload as we do not want to remove 'm.relates_to' from the
    // original payload passed into this function
    payload = payload.copy();
    final payloadContent = {
      'content': payload,
      'type': type,
      'room_id': roomId,
    };
    final encryptedPayload = <String, dynamic>{
      'algorithm': AlgorithmTypes.megolmV1AesSha2,
      'ciphertext':
          sess!.outboundGroupSession!.encrypt(json.encode(payloadContent)),
      // device_id + sender_key should be removed at some point in future since
      // they're deprecated. Just left here for compatibility
      'device_id': client.deviceID,
      'sender_key': identityKey,
      'session_id': sess.outboundGroupSession!.session_id(),
      if (mRelatesTo != null) 'm.relates_to': mRelatesTo,
    };
    await keyManager.storeOutboundGroupSession(roomId, sess);
    return encryptedPayload;
  }

  Future<Map<String, Map<String, Map<String, dynamic>>>> encryptToDeviceMessage(
      List<DeviceKeys> deviceKeys,
      String type,
      Map<String, dynamic> payload) async {
    return await olmManager.encryptToDeviceMessage(deviceKeys, type, payload);
  }

  Future<void> autovalidateMasterOwnKey() async {
    // check if we can set our own master key as verified, if it isn't yet
    final userId = client.userID;
    final masterKey = client.userDeviceKeys[userId]?.masterKey;
    if (client.database != null &&
        masterKey != null &&
        userId != null &&
        !masterKey.directVerified &&
        masterKey.hasValidSignatureChain(onlyValidateUserIds: {userId})) {
      await masterKey.setVerified(true);
    }
  }

  Future<void> dispose() async {
    keyManager.dispose();
    await olmManager.dispose();
    keyVerificationManager.dispose();
  }
}

class DecryptException implements Exception {
  String cause;
  String? libolmMessage;
  DecryptException(this.cause, [this.libolmMessage]);

  @override
  String toString() =>
      cause + (libolmMessage != null ? ': $libolmMessage' : '');

  static const String notEnabled = 'Encryption is not enabled in your client.';
  static const String unknownAlgorithm = 'Unknown encryption algorithm.';
  static const String unknownSession =
      'The sender has not sent us the session key.';
  static const String channelCorrupted =
      'The secure channel with the sender was corrupted.';
  static const String unableToDecryptWithAnyOlmSession =
      'Unable to decrypt with any existing OLM session';
  static const String senderDoesntMatch =
      "Message was decrypted but sender doesn't match";
  static const String recipientDoesntMatch =
      "Message was decrypted but recipient doesn't match";
  static const String ownFingerprintDoesntMatch =
      "Message was decrypted but own fingerprint Key doesn't match";
  static const String isntSentForThisDevice =
      "The message isn't sent for this device";
  static const String unknownMessageType = 'Unknown message type';
  static const String decryptionFailed = 'Decryption failed';
}
