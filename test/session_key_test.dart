/*
 *   Ansible inventory script used at Famedly GmbH for managing many hosts
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
import 'package:famedlysdk/src/utils/session_key.dart';
import 'package:olm/olm.dart' as olm;
import 'package:test/test.dart';

void main() {
  /// All Tests related to the ChatTime
  group('SessionKey', () {
    var olmEnabled = true;
    try {
      olm.init();
      olm.Account();
    } catch (_) {
      olmEnabled = false;
      print('[LibOlm] Failed to load LibOlm: ' + _.toString());
    }
    print('[LibOlm] Enabled: $olmEnabled');
    test('SessionKey test', () {
      if (olmEnabled) {
        final sessionKey = SessionKey(
          content: {
            'algorithm': 'm.megolm.v1.aes-sha2',
            'room_id': '!Cuyf34gef24t:localhost',
            'session_id': 'X3lUlvLELLYxeTx4yOVu6UDpasGEVO0Jbu+QFnm0cKQ',
            'session_key':
                'AgAAAADxKHa9uFxcXzwYoNueL5Xqi69IkD4sni8LlfJL7qNBEY...'
          },
          inboundGroupSession: olm.InboundGroupSession(),
          key: '1234',
          indexes: {},
        );
        expect(sessionKey.senderClaimedEd25519Key, '');
        expect(sessionKey.toJson(),
            SessionKey.fromJson(sessionKey.toJson(), '1234').toJson());
        expect(sessionKey.toString(), json.encode(sessionKey.toJson()));
      }
    });
  });
}
