/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020 Famedly GmbH
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

import 'dart:convert';
import 'dart:async';

import 'package:pedantic/pedantic.dart';

import '../famedlysdk.dart';
import '../matrix_api.dart';
import '../src/utils/run_in_root.dart';
import '../src/utils/logs.dart';
import 'cross_signing.dart';
import 'key_manager.dart';
import 'key_verification_manager.dart';
import 'olm_manager.dart';
import 'ssss.dart';

class Encryption {
  final Client client;
  final bool debug;
  final bool enableE2eeRecovery;

  bool get enabled => olmManager.enabled;

  /// Returns the base64 encoded keys to store them in a store.
  /// This String should **never** leave the device!
  String get pickledOlmAccount => olmManager.pickledOlmAccount;

  String get fingerprintKey => olmManager.fingerprintKey;
  String get identityKey => olmManager.identityKey;

  KeyManager keyManager;
  OlmManager olmManager;
  KeyVerificationManager keyVerificationManager;
  CrossSigning crossSigning;
  SSSS ssss;

  Encryption({
    this.client,
    this.debug,
    this.enableE2eeRecovery,
  }) {
    ssss = SSSS(this);
    keyManager = KeyManager(this);
    olmManager = OlmManager(this);
    keyVerificationManager = KeyVerificationManager(this);
    crossSigning = CrossSigning(this);
  }

  Future<void> init(String olmAccount) async {
    await olmManager.init(olmAccount);
    _backgroundTasksRunning = true;
    _backgroundTasks(); // start the background tasks
  }

  void handleDeviceOneTimeKeysCount(Map<String, int> countJson) {
    runInRoot(() => olmManager.handleDeviceOneTimeKeysCount(countJson));
  }

  void onSync() {
    keyVerificationManager.cleanup();
  }

  Future<void> handleToDeviceEvent(ToDeviceEvent event) async {
    if (event.type == 'm.room_key') {
      // a new room key. We need to handle this asap, before other
      // events in /sync are handled
      await keyManager.handleToDeviceEvent(event);
    }
    if (['m.room_key_request', 'm.forwarded_room_key'].contains(event.type)) {
      // "just" room key request things. We don't need these asap, so we handle
      // them in the background
      unawaited(runInRoot(() => keyManager.handleToDeviceEvent(event)));
    }
    if (event.type.startsWith('m.key.verification.')) {
      // some key verification event. No need to handle it now, we can easily
      // do this in the background
      unawaited(
          runInRoot(() => keyVerificationManager.handleToDeviceEvent(event)));
    }
    if (event.type.startsWith('m.secret.')) {
      // some ssss thing. We can do this in the background
      unawaited(runInRoot(() => ssss.handleToDeviceEvent(event)));
    }
    if (event.sender == client.userID) {
      // maybe we need to re-try SSSS secrets
      unawaited(runInRoot(() => ssss.periodicallyRequestMissingCache()));
    }
  }

  Future<void> handleEventUpdate(EventUpdate update) async {
    if (update.type == 'ephemeral') {
      return;
    }
    if (update.eventType.startsWith('m.key.verification.') ||
        (update.eventType == 'm.room.message' &&
            (update.content['content']['msgtype'] is String) &&
            update.content['content']['msgtype']
                .startsWith('m.key.verification.'))) {
      // "just" key verification, no need to do this in sync
      unawaited(
          runInRoot(() => keyVerificationManager.handleEventUpdate(update)));
    }
    if (update.content['sender'] == client.userID &&
        !update.content['unsigned'].containsKey('transaction_id')) {
      // maybe we need to re-try SSSS secrets
      unawaited(runInRoot(() => ssss.periodicallyRequestMissingCache()));
    }
  }

  Future<ToDeviceEvent> decryptToDeviceEvent(ToDeviceEvent event) async {
    return await olmManager.decryptToDeviceEvent(event);
  }

  Event decryptRoomEventSync(String roomId, Event event) {
    if (event.type != EventTypes.Encrypted ||
        event.content['ciphertext'] == null) return event;
    Map<String, dynamic> decryptedPayload;
    var canRequestSession = false;
    try {
      if (event.content['algorithm'] != 'm.megolm.v1.aes-sha2') {
        throw (DecryptError.UNKNOWN_ALGORITHM);
      }
      final String sessionId = event.content['session_id'];
      final String senderKey = event.content['sender_key'];
      final inboundGroupSession =
          keyManager.getInboundGroupSession(roomId, sessionId, senderKey);
      if (inboundGroupSession == null) {
        canRequestSession = true;
        throw (DecryptError.UNKNOWN_SESSION);
      }
      // decrypt errors here may mean we have a bad session key - others might have a better one
      canRequestSession = true;
      final decryptResult = inboundGroupSession.inboundGroupSession
          .decrypt(event.content['ciphertext']);
      canRequestSession = false;
      // we can't have the key be an int, else json-serializing will fail, thus we need it to be a string
      final messageIndexKey = 'key-' + decryptResult.message_index.toString();
      final messageIndexValue = event.eventId +
          '|' +
          event.originServerTs.millisecondsSinceEpoch.toString();
      var haveIndex = inboundGroupSession.indexes.containsKey(messageIndexKey);
      if (haveIndex &&
          inboundGroupSession.indexes[messageIndexKey] != messageIndexValue) {
        // TODO: maybe clear outbound session, if it is ours
        // TODO: Make it so that we can't re-request the session keys, this is just for debugging
        Logs.error('[Decrypt] Could not decrypt due to a corrupted session.');
        Logs.error('[Decrypt] Want session: $roomId $sessionId $senderKey');
        Logs.error(
            '[Decrypt] Have sessoin: ${inboundGroupSession.roomId} ${inboundGroupSession.sessionId} ${inboundGroupSession.senderKey}');
        Logs.error(
            '[Decrypt] Want indexes: $messageIndexKey $messageIndexValue');
        Logs.error(
            '[Decrypt] Have indexes: $messageIndexKey ${inboundGroupSession.indexes[messageIndexKey]}');
        canRequestSession = true;
        throw (DecryptError.CHANNEL_CORRUPTED);
      }
      inboundGroupSession.indexes[messageIndexKey] = messageIndexValue;
      if (!haveIndex) {
        // now we persist the udpated indexes into the database.
        // the entry should always exist. In the case it doesn't, the following
        // line *could* throw an error. As that is a future, though, and we call
        // it un-awaited here, nothing happens, which is exactly the result we want
        client.database?.updateInboundGroupSessionIndexes(
            json.encode(inboundGroupSession.indexes),
            client.id,
            roomId,
            sessionId);
      }
      decryptedPayload = json.decode(decryptResult.plaintext);
    } catch (exception) {
      // alright, if this was actually by our own outbound group session, we might as well clear it
      if (client.enableE2eeRecovery &&
          (keyManager
                      .getOutboundGroupSession(roomId)
                      ?.outboundGroupSession
                      ?.session_id() ??
                  '') ==
              event.content['session_id']) {
        keyManager.clearOutboundGroupSession(roomId, wipe: true);
      }
      if (canRequestSession) {
        decryptedPayload = {
          'content': event.content,
          'type': EventTypes.Encrypted,
        };
        decryptedPayload['content']['body'] = exception.toString();
        decryptedPayload['content']['msgtype'] = 'm.bad.encrypted';
        decryptedPayload['content']['can_request_session'] = true;
      } else {
        decryptedPayload = {
          'content': <String, dynamic>{
            'msgtype': 'm.bad.encrypted',
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
      roomId: event.roomId,
      room: event.room,
      originServerTs: event.originServerTs,
      unsigned: event.unsigned,
      stateKey: event.stateKey,
      prevContent: event.prevContent,
      status: event.status,
      sortOrder: event.sortOrder,
    );
  }

  Future<Event> decryptRoomEvent(String roomId, Event event,
      {bool store = false, String updateType = 'timeline'}) async {
    final doStore = () async {
      await client.database?.storeEventUpdate(
        client.id,
        EventUpdate(
          eventType: event.type,
          content: event.toJson(),
          roomID: event.roomId,
          type: updateType,
          sortOrder: event.sortOrder,
        ),
      );
      if (updateType != 'history') {
        event.room?.setState(event);
      }
    };
    if (event.type != EventTypes.Encrypted) {
      return event;
    }
    event = decryptRoomEventSync(roomId, event);
    if (event.type != EventTypes.Encrypted) {
      if (store) {
        await doStore();
      }
      return event;
    }
    if (client.database == null) {
      return event;
    }
    await keyManager.loadInboundGroupSession(
        roomId, event.content['session_id'], event.content['sender_key']);
    event = decryptRoomEventSync(roomId, event);
    if (event.type != EventTypes.Encrypted && store) {
      await doStore();
    }
    return event;
  }

  /// Encrypts the given json payload and creates a send-ready m.room.encrypted
  /// payload. This will create a new outgoingGroupSession if necessary.
  Future<Map<String, dynamic>> encryptGroupMessagePayload(
      String roomId, Map<String, dynamic> payload,
      {String type = EventTypes.Message}) async {
    final room = client.getRoomById(roomId);
    if (room == null || !room.encrypted || !enabled) {
      return payload;
    }
    if (room.encryptionAlgorithm != 'm.megolm.v1.aes-sha2') {
      throw ('Unknown encryption algorithm');
    }
    if (keyManager.getOutboundGroupSession(roomId) == null) {
      await keyManager.loadOutboundGroupSession(roomId);
    }
    await keyManager.clearOutboundGroupSession(roomId);
    if (keyManager.getOutboundGroupSession(roomId) == null) {
      await keyManager.createOutboundGroupSession(roomId);
    }
    final sess = keyManager.getOutboundGroupSession(roomId);
    if (sess == null) {
      throw ('Unable to create new outbound group session');
    }
    // we clone the payload as we do not want to remove 'm.relates_to' from the
    // original payload passed into this function
    payload = Map<String, dynamic>.from(payload);
    final Map<String, dynamic> mRelatesTo = payload.remove('m.relates_to');
    final payloadContent = {
      'content': payload,
      'type': type,
      'room_id': roomId,
    };
    var encryptedPayload = <String, dynamic>{
      'algorithm': 'm.megolm.v1.aes-sha2',
      'ciphertext':
          sess.outboundGroupSession.encrypt(json.encode(payloadContent)),
      'device_id': client.deviceID,
      'sender_key': identityKey,
      'session_id': sess.outboundGroupSession.session_id(),
      if (mRelatesTo != null) 'm.relates_to': mRelatesTo,
    };
    sess.sentMessages++;
    await keyManager.storeOutboundGroupSession(roomId, sess);
    return encryptedPayload;
  }

  Future<Map<String, dynamic>> encryptToDeviceMessagePayload(
      DeviceKeys device, String type, Map<String, dynamic> payload) async {
    return await olmManager.encryptToDeviceMessagePayload(
        device, type, payload);
  }

  Future<Map<String, dynamic>> encryptToDeviceMessage(
      List<DeviceKeys> deviceKeys,
      String type,
      Map<String, dynamic> payload) async {
    return await olmManager.encryptToDeviceMessage(deviceKeys, type, payload);
  }

  Future<void> autovalidateMasterOwnKey() async {
    // check if we can set our own master key as verified, if it isn't yet
    if (client.database != null &&
        client.userDeviceKeys.containsKey(client.userID)) {
      final masterKey = client.userDeviceKeys[client.userID].masterKey;
      if (masterKey != null &&
          !masterKey.directVerified &&
          masterKey
              .hasValidSignatureChain(onlyValidateUserIds: {client.userID})) {
        await masterKey.setVerified(true);
      }
    }
  }

  // this method is responsible for all background tasks, such as uploading online key backups
  bool _backgroundTasksRunning = true;
  void _backgroundTasks() {
    if (!_backgroundTasksRunning) {
      return;
    }

    keyManager.backgroundTasks();

    autovalidateMasterOwnKey();

    if (_backgroundTasksRunning) {
      Timer(Duration(seconds: 10), _backgroundTasks);
    }
  }

  void dispose() {
    keyManager.dispose();
    olmManager.dispose();
    keyVerificationManager.dispose();
    _backgroundTasksRunning = false;
  }
}

abstract class DecryptError {
  static const String NOT_ENABLED = 'Encryption is not enabled in your client.';
  static const String UNKNOWN_ALGORITHM = 'Unknown encryption algorithm.';
  static const String UNKNOWN_SESSION =
      'The sender has not sent us the session key.';
  static const String CHANNEL_CORRUPTED =
      'The secure channel with the sender was corrupted.';
}
