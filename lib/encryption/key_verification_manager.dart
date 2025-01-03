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

import 'package:matrix/encryption/encryption.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';

class KeyVerificationManager {
  final Encryption encryption;
  Client get client => encryption.client;

  KeyVerificationManager(this.encryption);

  final Map<String, KeyVerification> _requests = {};

  Future<void> cleanup() async {
    final Set entriesToDispose = <String>{};
    for (final entry in _requests.entries) {
      var dispose = entry.value.canceled ||
          entry.value.state == KeyVerificationState.done ||
          entry.value.state == KeyVerificationState.error;
      if (!dispose) {
        dispose = !(await entry.value.verifyActivity());
      }
      if (dispose) {
        entry.value.dispose();
        entriesToDispose.add(entry.key);
      }
    }
    entriesToDispose.forEach(_requests.remove);
  }

  void addRequest(KeyVerification request) {
    if (request.transactionId == null) {
      return;
    }
    _requests[request.transactionId!] = request;
  }

  KeyVerification? getRequest(String requestId) => _requests[requestId];

  Future<void> handleToDeviceEvent(ToDeviceEvent event) async {
    if (!event.type.startsWith('m.key.verification.') ||
        client.verificationMethods.isEmpty) {
      return;
    }
    // we have key verification going on!
    final transactionId = KeyVerification.getTransactionId(event.content);
    if (transactionId == null) {
      return; // TODO: send cancel with unknown transaction id
    }
    final request = _requests[transactionId];
    if (request != null) {
      // make sure that new requests can't come from ourself
      if (!{EventTypes.KeyVerificationRequest}.contains(event.type)) {
        await request.handlePayload(event.type, event.content);
      }
    } else {
      if (!{EventTypes.KeyVerificationRequest, EventTypes.KeyVerificationStart}
          .contains(event.type)) {
        return; // we can only start on these
      }
      final newKeyRequest =
          KeyVerification(encryption: encryption, userId: event.sender);
      await newKeyRequest.handlePayload(event.type, event.content);
      if (newKeyRequest.state != KeyVerificationState.askAccept) {
        // okay, something went wrong (unknown transaction id?), just dispose it
        newKeyRequest.dispose();
      } else {
        _requests[transactionId] = newKeyRequest;
        client.onKeyVerificationRequest.add(newKeyRequest);
      }
    }
  }

  Future<void> handleEventUpdate(Event update) async {
    final type = update.type.startsWith('m.key.verification.')
        ? update.type
        : update.content.tryGet<String>('msgtype');
    if (type == null ||
        !type.startsWith('m.key.verification.') ||
        client.verificationMethods.isEmpty) {
      return;
    }
    if (type == EventTypes.KeyVerificationRequest) {
      update.content['timestamp'] =
          update.originServerTs.millisecondsSinceEpoch;
    }

    final transactionId =
        KeyVerification.getTransactionId(update.content) ?? update.eventId;

    final req = _requests[transactionId];
    if (req != null) {
      final otherDeviceId = update.content.tryGet<String>('from_device');
      if (update.senderId != client.userID) {
        await req.handlePayload(type, update.content, update.eventId);
      } else if (update.senderId == client.userID &&
          otherDeviceId != null &&
          otherDeviceId != client.deviceID) {
        // okay, another of our devices answered
        req.otherDeviceAccepted();
        req.dispose();
        _requests.remove(transactionId);
      }
    } else if (update.senderId != client.userID) {
      if (!{EventTypes.KeyVerificationRequest, EventTypes.KeyVerificationStart}
          .contains(type)) {
        return; // we can only start on these
      }
      final room = client.getRoomById(update.roomId!) ??
          Room(id: update.roomId!, client: client);
      final newKeyRequest = KeyVerification(
        encryption: encryption,
        userId: update.senderId,
        room: room,
      );
      await newKeyRequest.handlePayload(
        type,
        update.content,
        update.eventId,
      );
      if (newKeyRequest.state != KeyVerificationState.askAccept) {
        // something went wrong, let's just dispose the request
        newKeyRequest.dispose();
      } else {
        // new request! Let's notify it and stuff
        _requests[transactionId] = newKeyRequest;
        client.onKeyVerificationRequest.add(newKeyRequest);
      }
    }
  }

  void dispose() {
    for (final req in _requests.values) {
      req.dispose();
    }
  }
}
