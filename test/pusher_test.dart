/*
 * Copyright (c) 2019 Zender & Kurtz GbR.
 *
 * Authors:
 *   Christian Pauly <krille@famedly.com>
 *   Marcel Radzio <mtrnord@famedly.com>
 *
 * This file is part of famedlysdk.
 *
 * famedlysdk is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * famedlysdk is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with famedlysdk.  If not, see <http://www.gnu.org/licenses/>.
 */
import 'package:famedlysdk/src/utils/pusher.dart';
import 'package:test/test.dart';

void main() {
  /// All Tests related to device keys
  group('Pusher', () {
    test('Pusher', () {
      final rawPusher = {
        'pushkey': 'Xp/MzCt8/9DcSNE9cuiaoT5Ac55job3TdLSSmtmYl4A=',
        'kind': 'http',
        'app_id': 'face.mcapp.appy.prod',
        'app_display_name': 'Appy McAppface',
        'device_display_name': "Alice's Phone",
        'profile_tag': 'xyz',
        'lang': 'en-US',
        'data': {'url': 'https://example.com/_matrix/push/v1/notify'}
      };

      final pusher = Pusher.fromJson(rawPusher);
      expect(pusher.toJson(), rawPusher);
    });
  });
}
