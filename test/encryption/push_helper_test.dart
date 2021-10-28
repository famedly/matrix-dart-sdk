/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2021 Famedly GmbH
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
import 'package:test/test.dart';
import 'package:matrix/matrix.dart';
import 'package:olm/olm.dart' as olm;
import '../fake_client.dart';

final privateKey = 'ocE2RWd/yExYEk0JCAx3100//WQkmM3syidCVFsndS0=';

final wantPublicKey = 'odb+sBwaK0bZtaAqzcuFR3UVg5Wa1cW7ZMwJY1SnDng';

final rawJson =
    '{"ciphertext":"S7EYruu1f3Z1PkYnx/O3bw8OxCbWavLih10CpSm/msfPJ6ho4OcHa+6eYAPQCZp4MVuvadGfHVdTpdinzMUCJJvIkRbFU4rYN3HsfIhYni1pdknPQ+9AGXkxUIlmfmziZwObGOFfX1HwyTOykrZEIEQj0oKGK4psSi8BwRv+D2bvPkYBCeZiAKr5dSkOoZo4Lkoe7Q2a41nr2d23+ZTn7Q","devices":[{"app_id":"encrypted-push","data":{"algorithm":"com.famedly.curve25519-aes-sha2","format":"event_id_only"},"pushkey":"https://gotify.luckyskies.pet/UP?token=AqXZS.CM7VI0F2V","pushkey_ts":1635499243}],"ephemeral":"kxEHE2fYpCO9Go35MV7DmjIW22A1zCw32PeHEUuXkQs","mac":"8/sK41zVaPU"}';

void main() {
  group('Push Helper', () {
    Logs().level = Level.error;
    var olmEnabled = true;

    late Client client;

    test('setupClient', () async {
      if (!olmEnabled) return;
      try {
        await olm.init();
        olm.get_library_version();
      } catch (e) {
        olmEnabled = false;
        Logs().w('[LibOlm] Failed to load LibOlm', e);
      }
      Logs().i('[LibOlm] Enabled: $olmEnabled');
      if (!olmEnabled) return;

      client = await getClient();
    });
    test('decrypt an encrypted push payload', () async {
      if (!olmEnabled) return;
      await client.encryption!.pushHelper.init(privateKey);
      expect(client.encryption!.pushHelper.publicKey, wantPublicKey);
      final ret = await client.encryption!.pushHelper
          .processPushPayload(json.decode(rawJson));
      expect(ret, <String, dynamic>{
        'event_id': '\$0VwDWKcBsKnANLsgZyBiuUxpRfkj-Bj7fDTW2jpuwXY',
        'room_id': '!GQUqohCDwvpnSczitP:nheko.im',
        'counts': <String, dynamic>{'unread': 1},
        'prio': 'high'
      });
    });
    test('decrypt a top-level algorithm payload', () async {
      if (!olmEnabled) return;
      await client.encryption!.pushHelper.init(privateKey);
      expect(client.encryption!.pushHelper.publicKey, wantPublicKey);
      final j = json.decode(rawJson);
      j['algorithm'] = j['devices'].first['data']['algorithm'];
      j.remove('devices');
      final ret = await client.encryption!.pushHelper.processPushPayload(j);
      expect(ret, <String, dynamic>{
        'event_id': '\$0VwDWKcBsKnANLsgZyBiuUxpRfkj-Bj7fDTW2jpuwXY',
        'room_id': '!GQUqohCDwvpnSczitP:nheko.im',
        'counts': <String, dynamic>{'unread': 1},
        'prio': 'high'
      });
    });
    test('decrypt the plain payload format', () async {
      if (!olmEnabled) return;
      await client.encryption!.pushHelper.init(privateKey);
      expect(client.encryption!.pushHelper.publicKey, wantPublicKey);
      final j = json.decode(rawJson);
      final ret = await client.encryption!.pushHelper.processPushPayload(j);
      expect(ret, <String, dynamic>{
        'event_id': '\$0VwDWKcBsKnANLsgZyBiuUxpRfkj-Bj7fDTW2jpuwXY',
        'room_id': '!GQUqohCDwvpnSczitP:nheko.im',
        'counts': <String, dynamic>{'unread': 1},
        'prio': 'high'
      });
    });
    test('decrypt an fcm push payload', () async {
      if (!olmEnabled) return;
      await client.encryption!.pushHelper.init(privateKey);
      final j = json.decode(rawJson);
      j['devices'] = json.encode(j['devices']);
      final ret = await client.encryption!.pushHelper.processPushPayload(j);
      expect(ret, <String, dynamic>{
        'event_id': '\$0VwDWKcBsKnANLsgZyBiuUxpRfkj-Bj7fDTW2jpuwXY',
        'room_id': '!GQUqohCDwvpnSczitP:nheko.im',
        'counts': <String, dynamic>{'unread': 1},
        'prio': 'high'
      });
    });
    test('handle the plain algorithm', () async {
      if (!olmEnabled) return;
      await client.encryption!.pushHelper.init(privateKey);
      expect(client.encryption!.pushHelper.publicKey, wantPublicKey);
      final j = json.decode(rawJson);
      j['devices'].first['data']['algorithm'] = 'm.plain';
      final ret = await client.encryption!.pushHelper.processPushPayload(j);
      expect(ret['mac'], '8/sK41zVaPU');
    });
    test('handle the absense of an algorithm', () async {
      if (!olmEnabled) return;
      await client.encryption!.pushHelper.init(privateKey);
      expect(client.encryption!.pushHelper.publicKey, wantPublicKey);
      final j = json.decode(rawJson);
      j['devices'].first['data'].remove('algorithm');
      final ret = await client.encryption!.pushHelper.processPushPayload(j);
      expect(ret['mac'], '8/sK41zVaPU');
    });
    test('getPusher', () async {
      if (!olmEnabled) return;
      await client.encryption!.pushHelper.init();
      final oldPusher = Pusher.fromJson(<String, dynamic>{
        'app_display_name': 'Appy McAppface',
        'app_id': 'face.mcapp.appy.prod',
        'data': {'url': 'https://example.com/_matrix/push/v1/notify'},
        'device_display_name': 'Foxies',
        'kind': 'http',
        'lang': 'en-US',
        'profile_tag': 'xyz',
        'pushkey': 'Xp/MzCt8/9DcSNE9cuiaoT5Ac55job3TdLSSmtmYl4A='
      });
      final newPusher =
          await client.encryption!.pushHelper.getPusher(oldPusher);
      expect(newPusher.data.additionalProperties['public_key'] is String, true);
      expect(newPusher.data.additionalProperties['public_key'],
          client.encryption!.pushHelper.publicKey);
      expect(newPusher.data.additionalProperties['algorithm'],
          'com.famedly.curve25519-aes-sha2');
    });
    test('dispose client', () async {
      if (!olmEnabled) return;
      await client.dispose(closeDatabase: true);
    });
  });
}
