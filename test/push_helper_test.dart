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
import 'fake_client.dart';
import 'fake_matrix_api.dart';
import 'package:olm/olm.dart' as olm;

final privateKey = 'ocE2RWd/yExYEk0JCAx3100//WQkmM3syidCVFsndS0=';
final rawJson =
    '{"notification":{"ciphertext":"S7EYruu1f3Z1PkYnx/O3bw8OxCbWavLih10CpSm/msfPJ6ho4OcHa+6eYAPQCZp4MVuvadGfHVdTpdinzMUCJJvIkRbFU4rYN3HsfIhYni1pdknPQ+9AGXkxUIlmfmziZwObGOFfX1HwyTOykrZEIEQj0oKGK4psSi8BwRv+D2bvPkYBCeZiAKr5dSkOoZo4Lkoe7Q2a41nr2d23+ZTn7Q","devices":[{"app_id":"encrypted-push","data":{"algorithm":"com.famedly.curve25519-aes-sha2","format":"event_id_only"},"pushkey":"https://gotify.luckyskies.pet/UP?token=AqXZS.CM7VI0F2V","pushkey_ts":1635499243}],"ephemeral":"kxEHE2fYpCO9Go35MV7DmjIW22A1zCw32PeHEUuXkQs","mac":"8/sK41zVaPU"}}';

void main() {
  group('Push Helper', () {
    Logs().level = Level.error;
    var olmEnabled = true;

    late Client client;
    test('setupClient', () async {
      try {
        await olm.init();
        olm.get_library_version();
      } catch (e) {
        olmEnabled = false;
        Logs().w('[LibOlm] Failed to load LibOlm', e);
      }
      Logs().i('[LibOlm] Enabled: $olmEnabled');
      client = await getClient();
    });
    test('setupPusher sets a new pusher', () async {
      final pusher = Pusher.fromJson({
        'pushkey': 'newpusher',
        'kind': 'http',
        'app_id': 'fox.floof',
        'app_display_name': 'Floofer',
        'device_display_name': 'Fox Phone',
        'profile_tag': 'xyz',
        'lang': 'en-US',
        'data': {
          'url': 'https://fox.floof/_matrix/push/v1/notify',
          'format': 'event_id_only',
        },
      });
      FakeMatrixApi.calledEndpoints.clear();
      await client.setupPusher(pusher: pusher);
      expect(
          FakeMatrixApi.calledEndpoints['/client/r0/pushers/set']!.length, 1);
      final sentJson = json.decode(
          FakeMatrixApi.calledEndpoints['/client/r0/pushers/set']!.first);
      if (olmEnabled) {
        expect(sentJson['data']['public_key'] is String, true);
        expect(
            sentJson['data']['algorithm'], 'com.famedly.curve25519-aes-sha2');
        sentJson['data'].remove('public_key');
        sentJson['data'].remove('algorithm');
      }
      expect(sentJson, {
        ...pusher.toJson(),
        'append': false,
      });
    });
    test('setupPusher does nothing if the pusher already exists', () async {
      final encryption = client.encryption;
      client.encryption = null;

      final pusher = Pusher.fromJson({
        'pushkey': 'Xp/MzCt8/9DcSNE9cuiaoT5Ac55job3TdLSSmtmYl4A=',
        'kind': 'http',
        'app_id': 'face.mcapp.appy.prod',
        'app_display_name': 'Appy McAppface',
        'device_display_name': 'Alices Phone',
        'profile_tag': 'xyz',
        'lang': 'en-US',
        'data': {
          'url': 'https://example.com/_matrix/push/v1/notify',
          'format': 'event_id_only',
        },
      });
      FakeMatrixApi.calledEndpoints.clear();
      await client.setupPusher(pusher: pusher);
      expect(FakeMatrixApi.calledEndpoints['/client/r0/pushers/set'], null);

      client.encryption = encryption;
    });
    test('setupPusher deletes old push keys provided', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await client.setupPusher(
          oldTokens: {'Xp/MzCt8/9DcSNE9cuiaoT5Ac55job3TdLSSmtmYl4A='});
      expect(
          FakeMatrixApi.calledEndpoints['/client/r0/pushers/set']!.length, 1);
      final sentJson = json.decode(
          FakeMatrixApi.calledEndpoints['/client/r0/pushers/set']!.first);
      expect(sentJson['kind'], null);
    });
    test('setupPusher auto-updates a pusher, if it already exists', () async {
      final encryption = client.encryption;
      client.encryption = null;

      final pusher = Pusher.fromJson({
        'pushkey': 'Xp/MzCt8/9DcSNE9cuiaoT5Ac55job3TdLSSmtmYl4A=',
        'kind': 'http',
        'app_id': 'face.mcapp.appy.prod',
        'app_display_name': 'Appy McAppface Flooftacular',
        'device_display_name': 'Alices Phone',
        'profile_tag': 'xyz',
        'lang': 'en-US',
        'data': {
          'url': 'https://example.com/_matrix/push/v1/notify',
          'format': 'event_id_only',
        },
      });
      FakeMatrixApi.calledEndpoints.clear();
      await client.setupPusher(pusher: pusher);
      expect(
          FakeMatrixApi.calledEndpoints['/client/r0/pushers/set']!.length, 2);
      var sentJson = json.decode(
          FakeMatrixApi.calledEndpoints['/client/r0/pushers/set']!.first);
      expect(sentJson['kind'], null);
      sentJson = json
          .decode(FakeMatrixApi.calledEndpoints['/client/r0/pushers/set']![1]);
      expect(sentJson, {
        ...pusher.toJson(),
        'append': false,
      });

      client.encryption = encryption;
    });
    test('processPushPayload no libolm', () async {
      final encryption = client.encryption;
      client.encryption = null;
      var ret = await client.processPushPayload(<String, dynamic>{
        'notification': <String, dynamic>{'fox': 'floof'}
      });
      expect(ret, {'fox': 'floof'});
      ret = await client.processPushPayload(<String, dynamic>{
        'data': <String, dynamic>{'fox': 'floof'}
      });
      expect(ret, {'fox': 'floof'});
      ret = await client.processPushPayload(<String, dynamic>{'fox': 'floof'});
      expect(ret, {'fox': 'floof'});
      client.encryption = encryption;
    });
    test('processPushPayload with libolm', () async {
      if (!olmEnabled) return;
      await client.encryption!.pushHelper.init(privateKey);
      final ret = await client.encryption!.pushHelper
          .processPushPayload(json.decode(rawJson)['notification']);
      expect(ret, <String, dynamic>{
        'event_id': '\$0VwDWKcBsKnANLsgZyBiuUxpRfkj-Bj7fDTW2jpuwXY',
        'room_id': '!GQUqohCDwvpnSczitP:nheko.im',
        'counts': <String, dynamic>{'unread': 1},
        'prio': 'high'
      });
    });
    test('dispose client', () async {
      await client.dispose(closeDatabase: true);
    });
  });
}
