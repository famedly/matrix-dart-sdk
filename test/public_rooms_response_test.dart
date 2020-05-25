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
import 'package:famedlysdk/famedlysdk.dart';
import 'package:test/test.dart';

import 'fake_matrix_api.dart';

void main() {
  /// All Tests related to device keys
  group('Public Rooms Response', () {
    Client client;
    test('Public Rooms Response', () async {
      client = Client('testclient', debug: true);
      client.httpClient = FakeMatrixApi();

      await client.checkServer('https://fakeServer.notExisting');
      final responseMap = {
        'chunk': [
          {
            'aliases': ['#murrays:cheese.bar'],
            'avatar_url': 'mxc://bleeker.street/CHEDDARandBRIE',
            'guest_can_join': false,
            'name': 'CHEESE',
            'num_joined_members': 37,
            'room_id': '1234',
            'topic': 'Tasty tasty cheese',
            'world_readable': true
          }
        ],
        'next_batch': 'p190q',
        'prev_batch': 'p1902',
        'total_room_count_estimate': 115
      };
      final publicRoomsResponse =
          PublicRoomsResponse.fromJson(responseMap, client);
      await publicRoomsResponse.publicRooms.first.join();
    });
  });
}
