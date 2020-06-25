/*
 *   Ansible inventory script used at Famedly GmbH for managing many hosts
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
import 'package:test/test.dart';
import 'package:olm/olm.dart' as olm;

import '../fake_client.dart';

void main() {
  group('Online Key Backup', () {
    var olmEnabled = true;
    try {
      olm.init();
      olm.Account();
    } catch (_) {
      olmEnabled = false;
      print('[LibOlm] Failed to load LibOlm: ' + _.toString());
    }
    print('[LibOlm] Enabled: $olmEnabled');

    if (!olmEnabled) return;

    Client client;

    final roomId = '!726s6s6q:example.com';
    final sessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
    final senderKey = 'JBG7ZaPn54OBC7TuIEiylW3BZ+7WcGQhFBPB9pogbAg';

    test('setupClient', () async {
      client = await getClient();
    });

    test('basic things', () async {
      expect(client.encryption.keyManager.enabled, true);
      expect(await client.encryption.keyManager.isCached(), false);
      final handle = client.encryption.ssss.open();
      handle.unlock(recoveryKey: SSSS_KEY);
      await handle.maybeCacheAll();
      expect(await client.encryption.keyManager.isCached(), true);
    });

    test('load key', () async {
      client.encryption.keyManager.clearInboundGroupSessions();
      await client.encryption.keyManager
          .request(client.getRoomById(roomId), sessionId, senderKey);
      expect(
          client.encryption.keyManager
                  .getInboundGroupSession(roomId, sessionId, senderKey) !=
              null,
          true);
    });

    test('dispose client', () async {
      await client.dispose(closeDatabase: true);
    });
  });
}
