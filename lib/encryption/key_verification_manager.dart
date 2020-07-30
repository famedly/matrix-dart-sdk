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

import 'package:famedlysdk/famedlysdk.dart';
import './encryption.dart';
import './utils/key_verification.dart';

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
    for (final k in entriesToDispose) {
      _requests.remove(k);
    }
  }

  void addRequest(KeyVerification request) {
    if (request.transactionId == null) {
      return;
    }
    _requests[request.transactionId] = request;
  }

  Future<void> handleToDeviceEvent(ToDeviceEvent event) async {
    if (!event.type.startsWith('m.key.verification') ||
        client.verificationMethods.isEmpty) {
      return;
    }
    // we have key verification going on!
    final transactionId = KeyVerification.getTransactionId(event.content);
    if (transactionId == null) {
      return; // TODO: send cancel with unknown transaction id
    }
    if (_requests.containsKey(transactionId)) {
      await _requests[transactionId].handlePayload(event.type, event.content);
    } else {
      if (!['m.key.verification.request', 'm.key.verification.start']
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

  Future<void> handleEventUpdate(EventUpdate update) async {
    final event = update.content;
    final type = event['type'].startsWith('m.key.verification.')
        ? event['type']
        : event['content']['msgtype'];
    if (type == null ||
        !type.startsWith('m.key.verification.') ||
        client.verificationMethods.isEmpty) {
      return;
    }
    if (type == 'm.key.verification.request') {
      event['content']['timestamp'] = event['origin_server_ts'];
    }

    final transactionId =
        KeyVerification.getTransactionId(event['content']) ?? event['event_id'];

    if (_requests.containsKey(transactionId)) {
      final req = _requests[transactionId];
      final otherDeviceId = event['content']['from_device'];
      if (event['sender'] != client.userID) {
        await req.handlePayload(type, event['content'], event['event_id']);
      } else if (event['sender'] == client.userID &&
          otherDeviceId != null &&
          otherDeviceId != client.deviceID) {
        // okay, another of our devices answered
        req.otherDeviceAccepted();
        req.dispose();
        _requests.remove(transactionId);
      }
    } else if (event['sender'] != client.userID) {
      if (!['m.key.verification.request', 'm.key.verification.start']
          .contains(type)) {
        return; // we can only start on these
      }
      final room = client.getRoomById(update.roomID) ??
          Room(id: update.roomID, client: client);
      final newKeyRequest = KeyVerification(
          encryption: encryption, userId: event['sender'], room: room);
      await newKeyRequest.handlePayload(
          type, event['content'], event['event_id']);
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
