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

import 'dart:convert';

import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/src/event.dart';
import 'package:test/test.dart';

import 'fake_matrix_api.dart';

void main() {
  /// All Tests related to the Event
  group('Event', () {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final id = '!4fsdfjisjf:server.abc';
    final senderID = '@alice:server.abc';
    final type = 'm.room.message';
    final msgtype = 'm.text';
    final body = 'Hello World';
    final formatted_body = '<b>Hello</b> World';

    final contentJson =
        '{"msgtype":"$msgtype","body":"$body","formatted_body":"$formatted_body","m.relates_to":{"m.in_reply_to":{"event_id":"\$1234:example.com"}}}';

    var jsonObj = <String, dynamic>{
      'event_id': id,
      'sender': senderID,
      'origin_server_ts': timestamp,
      'type': type,
      'room_id': '1234',
      'status': 2,
      'content': contentJson,
    };

    test('Create from json', () async {
      var event = Event.fromJson(jsonObj, null);
      jsonObj.remove('status');
      jsonObj['content'] = json.decode(contentJson);
      expect(event.toJson(), jsonObj);
      jsonObj['content'] = contentJson;

      expect(event.eventId, id);
      expect(event.senderId, senderID);
      expect(event.status, 2);
      expect(event.text, body);
      expect(event.formattedText, formatted_body);
      expect(event.body, body);
      expect(event.type, EventTypes.Message);
      expect(event.isReply, true);
      jsonObj['state_key'] = '';
      var state = Event.fromJson(jsonObj, null);
      expect(state.eventId, id);
      expect(state.stateKey, '');
      expect(state.status, 2);
    });
    test('Test all EventTypes', () async {
      Event event;

      jsonObj['type'] = 'm.room.avatar';
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomAvatar);

      jsonObj['type'] = 'm.room.name';
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomName);

      jsonObj['type'] = 'm.room.topic';
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomTopic);

      jsonObj['type'] = 'm.room.aliases';
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomAliases);

      jsonObj['type'] = 'm.room.canonical_alias';
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomCanonicalAlias);

      jsonObj['type'] = 'm.room.create';
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomCreate);

      jsonObj['type'] = 'm.room.join_rules';
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomJoinRules);

      jsonObj['type'] = 'm.room.member';
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomMember);

      jsonObj['type'] = 'm.room.power_levels';
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.RoomPowerLevels);

      jsonObj['type'] = 'm.room.guest_access';
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.GuestAccess);

      jsonObj['type'] = 'm.room.history_visibility';
      event = Event.fromJson(jsonObj, null);
      expect(event.type, EventTypes.HistoryVisibility);

      jsonObj['type'] = 'm.room.message';
      jsonObj['content'] = json.decode(jsonObj['content']);

      jsonObj['content']['msgtype'] = 'm.notice';
      event = Event.fromJson(jsonObj, null);
      expect(event.messageType, MessageTypes.Notice);

      jsonObj['content']['msgtype'] = 'm.emote';
      event = Event.fromJson(jsonObj, null);
      expect(event.messageType, MessageTypes.Emote);

      jsonObj['content']['msgtype'] = 'm.image';
      event = Event.fromJson(jsonObj, null);
      expect(event.messageType, MessageTypes.Image);

      jsonObj['content']['msgtype'] = 'm.video';
      event = Event.fromJson(jsonObj, null);
      expect(event.messageType, MessageTypes.Video);

      jsonObj['content']['msgtype'] = 'm.audio';
      event = Event.fromJson(jsonObj, null);
      expect(event.messageType, MessageTypes.Audio);

      jsonObj['content']['msgtype'] = 'm.file';
      event = Event.fromJson(jsonObj, null);
      expect(event.messageType, MessageTypes.File);

      jsonObj['content']['msgtype'] = 'm.location';
      event = Event.fromJson(jsonObj, null);
      expect(event.messageType, MessageTypes.Location);

      jsonObj['type'] = 'm.room.message';
      jsonObj['content']['msgtype'] = 'm.text';
      jsonObj['content']['m.relates_to'] = {};
      jsonObj['content']['m.relates_to']['m.in_reply_to'] = {
        'event_id': '1234',
      };
      event = Event.fromJson(jsonObj, null);
      expect(event.messageType, MessageTypes.Reply);
    });

    test('redact', () async {
      final room = Room(id: '1234', client: Client('testclient', debug: true));
      final redactionEventJson = {
        'content': {'reason': 'Spamming'},
        'event_id': '143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'redacts': id,
        'room_id': '1234',
        'sender': '@example:example.org',
        'type': 'm.room.redaction',
        'unsigned': {'age': 1234}
      };
      var redactedBecause = Event.fromJson(redactionEventJson, room);
      var event = Event.fromJson(jsonObj, room);
      event.setRedactionEvent(redactedBecause);
      expect(event.redacted, true);
      expect(event.redactedBecause.toJson(), redactedBecause.toJson());
      expect(event.content.isEmpty, true);
      redactionEventJson.remove('redacts');
      expect(event.unsigned['redacted_because'], redactionEventJson);
    });

    test('remove', () async {
      var event = Event.fromJson(
          jsonObj, Room(id: '1234', client: Client('testclient', debug: true)));
      final removed1 = await event.remove();
      event.status = 0;
      final removed2 = await event.remove();
      expect(removed1, false);
      expect(removed2, true);
    });

    test('sendAgain', () async {
      var matrix = Client('testclient', debug: true);
      matrix.httpClient = FakeMatrixApi();
      await matrix.checkServer('https://fakeServer.notExisting');
      await matrix.login('test', '1234');

      var event = Event.fromJson(
          jsonObj, Room(id: '!1234:example.com', client: matrix));
      final resp1 = await event.sendAgain();
      event.status = -1;
      final resp2 = await event.sendAgain(txid: '1234');
      expect(resp1, null);
      expect(resp2, '42');

      await matrix.dispose(closeDatabase: true);
    });

    test('requestKey', () async {
      var matrix = Client('testclient', debug: true);
      matrix.httpClient = FakeMatrixApi();
      await matrix.checkServer('https://fakeServer.notExisting');
      await matrix.login('test', '1234');

      var event = Event.fromJson(
          jsonObj, Room(id: '!1234:example.com', client: matrix));
      String exception;
      try {
        await event.requestKey();
      } catch (e) {
        exception = e;
      }
      expect(exception, 'Session key not unknown');

      event = Event.fromJson({
        'event_id': id,
        'sender': senderID,
        'origin_server_ts': timestamp,
        'type': 'm.room.encrypted',
        'room_id': '1234',
        'status': 2,
        'content': json.encode({
          'msgtype': 'm.bad.encrypted',
          'body': DecryptError.UNKNOWN_SESSION,
          'algorithm': 'm.megolm.v1.aes-sha2',
          'ciphertext': 'AwgAEnACgAkLmt6qF84IK++J7UDH2Za1YVchHyprqTqsg...',
          'device_id': 'RJYKSTBOIE',
          'sender_key': 'IlRMeOPX2e0MurIyfWEucYBRVOEEUMrOHqn/8mLqMjA',
          'session_id': 'X3lUlvLELLYxeTx4yOVu6UDpasGEVO0Jbu+QFnm0cKQ'
        }),
      }, Room(id: '!1234:example.com', client: matrix));

      await event.requestKey();

      await matrix.dispose(closeDatabase: true);
    });
  });
}
