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
import 'fake_database.dart';

void main() {
  /// All Tests related to device keys
  group('Room Key Request', () {
    test('fromJson', () async {
      var rawJson = <String, dynamic>{
        'content': {
          'action': 'request',
          'body': {
            'algorithm': 'm.megolm.v1.aes-sha2',
            'room_id': '!726s6s6q:example.com',
            'sender_key': 'RF3s+E7RkTQTGF2d8Deol0FkQvgII2aJDf3/Jp5mxVU',
            'session_id': 'X3lUlvLELLYxeTx4yOVu6UDpasGEVO0Jbu+QFnm0cKQ'
          },
          'request_id': '1495474790150.19',
          'requesting_device_id': 'JLAFKJWSCS'
        },
        'type': 'm.room_key_request',
        'sender': '@alice:example.com'
      };
      var toDeviceEvent = ToDeviceEvent.fromJson(rawJson);
      expect(toDeviceEvent.content, rawJson['content']);
      expect(toDeviceEvent.sender, rawJson['sender']);
      expect(toDeviceEvent.type, rawJson['type']);

      var matrix = Client('testclient', debug: true);
      matrix.httpClient = FakeMatrixApi();
      matrix.database = getDatabase();
      await matrix.checkServer('https://fakeServer.notExisting');
      await matrix.login('test', '1234');
      var room = matrix.getRoomById('!726s6s6q:example.com');
      if (matrix.encryptionEnabled) {
        await room.createOutboundGroupSession();
        rawJson['content']['body']['session_id'] = room.inboundGroupSessions.keys.first;

        var roomKeyRequest = RoomKeyRequest.fromToDeviceEvent(
            ToDeviceEvent.fromJson(rawJson), matrix);
        await roomKeyRequest.forwardKey();
      }
    });
  });
}
