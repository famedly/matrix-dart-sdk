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
    for (final entry in _requests.entries) {
      var dispose = entry.value.canceled ||
          entry.value.state == KeyVerificationState.done ||
          entry.value.state == KeyVerificationState.error;
      if (!dispose) {
        dispose = !(await entry.value.verifyActivity());
      }
      if (dispose) {
        entry.value.dispose();
        _requests.remove(entry.key);
      }
    }
  }

  void addRequest(KeyVerification request) {
    if (request.transactionId == null) {
      return;
    }
    _requests[request.transactionId] = request;
  }

  Future<void> handleToDeviceEvent(ToDeviceEvent event) async {
    if (!event.type.startsWith('m.key.verification')) {
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

  void dispose() {
    for (final req in _requests.values) {
      req.dispose();
    }
  }
}
