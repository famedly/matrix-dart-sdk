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
import 'dart:typed_data';

import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/matrix_api.dart';
import 'package:famedlysdk/encryption.dart';
import 'package:famedlysdk/src/event.dart';
import 'package:famedlysdk/src/utils/logs.dart';
import 'package:test/test.dart';
import 'package:olm/olm.dart' as olm;

import 'fake_client.dart';
import 'fake_matrix_api.dart';
import 'fake_matrix_localizations.dart';

void main() {
  /// All Tests related to the Event
  group('Event', () {
    var olmEnabled = true;
    try {
      olm.init();
      olm.Account();
    } catch (_) {
      olmEnabled = false;
      Logs.warning('[LibOlm] Failed to load LibOlm: ' + _.toString());
    }
    Logs.success('[LibOlm] Enabled: $olmEnabled');

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
    var client = Client('testclient', httpClient: FakeMatrixApi());
    var event = Event.fromJson(
        jsonObj, Room(id: '!localpart:server.abc', client: client));

    test('Create from json', () async {
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
      expect(event.relationshipType, RelationshipTypes.Reply);
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

      jsonObj['content'].remove('m.relates_to');
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

      jsonObj['type'] = 'm.sticker';
      jsonObj['content']['msgtype'] = null;
      event = Event.fromJson(jsonObj, null);
      expect(event.messageType, MessageTypes.Sticker);

      jsonObj['type'] = 'm.room.message';
      jsonObj['content']['msgtype'] = 'm.text';
      jsonObj['content']['m.relates_to'] = {};
      jsonObj['content']['m.relates_to']['m.in_reply_to'] = {
        'event_id': '1234',
      };
      event = Event.fromJson(jsonObj, null);
      expect(event.messageType, MessageTypes.Text);
      expect(event.relationshipType, RelationshipTypes.Reply);
      expect(event.relationshipEventId, '1234');
    });

    test('relationship types', () async {
      Event event;

      jsonObj['content'] = <String, dynamic>{
        'msgtype': 'm.text',
        'text': 'beep',
      };
      event = Event.fromJson(jsonObj, null);
      expect(event.relationshipType, null);
      expect(event.relationshipEventId, null);

      jsonObj['content']['m.relates_to'] = <String, dynamic>{
        'rel_type': 'm.replace',
        'event_id': 'abc',
      };
      event = Event.fromJson(jsonObj, null);
      expect(event.relationshipType, RelationshipTypes.Edit);
      expect(event.relationshipEventId, 'abc');

      jsonObj['content']['m.relates_to']['rel_type'] = 'm.annotation';
      event = Event.fromJson(jsonObj, null);
      expect(event.relationshipType, RelationshipTypes.Reaction);
      expect(event.relationshipEventId, 'abc');

      jsonObj['content']['m.relates_to'] = {
        'm.in_reply_to': {
          'event_id': 'def',
        },
      };
      event = Event.fromJson(jsonObj, null);
      expect(event.relationshipType, RelationshipTypes.Reply);
      expect(event.relationshipEventId, 'def');
    });

    test('redact', () async {
      final redactJsonObj = Map<String, dynamic>.from(jsonObj);
      final testTypes = [
        EventTypes.RoomMember,
        EventTypes.RoomCreate,
        EventTypes.RoomJoinRules,
        EventTypes.RoomPowerLevels,
        EventTypes.RoomAliases,
        EventTypes.HistoryVisibility,
      ];
      for (final testType in testTypes) {
        redactJsonObj['type'] = testType;
        final room = Room(id: '1234', client: Client('testclient'));
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
        var event = Event.fromJson(redactJsonObj, room);
        event.setRedactionEvent(redactedBecause);
        expect(event.redacted, true);
        expect(event.redactedBecause.toJson(), redactedBecause.toJson());
        expect(event.content.isEmpty, true);
        redactionEventJson.remove('redacts');
        expect(event.unsigned['redacted_because'], redactionEventJson);
      }
    });

    test('remove', () async {
      var event = Event.fromJson(
          jsonObj, Room(id: '1234', client: Client('testclient')));
      final removed1 = await event.remove();
      event.status = 0;
      final removed2 = await event.remove();
      expect(removed1, false);
      expect(removed2, true);
    });

    test('sendAgain', () async {
      var matrix = Client('testclient', httpClient: FakeMatrixApi());
      await matrix.checkHomeserver('https://fakeServer.notExisting');
      await matrix.login(user: 'test', password: '1234');

      var event = Event.fromJson(
          jsonObj, Room(id: '!1234:example.com', client: matrix));
      final resp1 = await event.sendAgain();
      event.status = -1;
      final resp2 = await event.sendAgain(txid: '1234');
      expect(resp1, null);
      expect(resp2.startsWith('\$event'), true);

      await matrix.dispose(closeDatabase: true);
    });

    test('requestKey', () async {
      var matrix = Client('testclient', httpClient: FakeMatrixApi());
      await matrix.checkHomeserver('https://fakeServer.notExisting');
      await matrix.login(user: 'test', password: '1234');

      var event = Event.fromJson(
          jsonObj, Room(id: '!1234:example.com', client: matrix));
      String exception;
      try {
        await event.requestKey();
      } catch (e) {
        exception = e.toString();
      }
      expect(exception, 'Session key not requestable');

      var event2 = Event.fromJson({
        'event_id': id,
        'sender': senderID,
        'origin_server_ts': timestamp,
        'type': 'm.room.encrypted',
        'room_id': '1234',
        'status': 2,
        'content': json.encode({
          'msgtype': 'm.bad.encrypted',
          'body': DecryptError.UNKNOWN_SESSION,
          'can_request_session': true,
          'algorithm': 'm.megolm.v1.aes-sha2',
          'ciphertext': 'AwgAEnACgAkLmt6qF84IK++J7UDH2Za1YVchHyprqTqsg...',
          'device_id': 'RJYKSTBOIE',
          'sender_key': 'IlRMeOPX2e0MurIyfWEucYBRVOEEUMrOHqn/8mLqMjA',
          'session_id': 'X3lUlvLELLYxeTx4yOVu6UDpasGEVO0Jbu+QFnm0cKQ'
        }),
      }, Room(id: '!1234:example.com', client: matrix));

      await event2.requestKey();

      await matrix.dispose(closeDatabase: true);
    });
    test('requestKey', () async {
      jsonObj['state_key'] = '@alice:example.com';
      var event = Event.fromJson(
          jsonObj, Room(id: '!localpart:server.abc', client: client));
      expect(event.stateKeyUser.id, '@alice:example.com');
    });
    test('canRedact', () async {
      expect(event.canRedact, true);
    });
    test('getLocalizedBody', () async {
      final matrix = Client('testclient', httpClient: FakeMatrixApi());
      final room = Room(id: '!1234:example.com', client: matrix);
      var event = Event.fromJson({
        'content': {
          'avatar_url': 'mxc://example.org/SEsfnsuifSDFSSEF',
          'displayname': 'Alice Margatroid',
          'membership': 'join'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '@alice:example.org',
        'type': 'm.room.member',
        'unsigned': {
          'age': 1234,
          'redacted_because': {
            'content': {'reason': 'Spamming'},
            'event_id': '\$143273582443PhrSn:example.org',
            'origin_server_ts': 1432735824653,
            'redacts': '\$143273582443PhrSn:example.org',
            'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
            'sender': '@example:example.org',
            'type': 'm.room.redaction',
            'unsigned': {'age': 1234}
          }
        }
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'body': 'Landing',
          'info': {
            'h': 200,
            'mimetype': 'image/png',
            'size': 73602,
            'thumbnail_info': {
              'h': 200,
              'mimetype': 'image/png',
              'size': 73602,
              'w': 140
            },
            'thumbnail_url': 'mxc://matrix.org/sHhqkFCvSkFwtmvtETOtKnLP',
            'w': 140
          },
          'url': 'mxc://matrix.org/sHhqkFCvSkFwtmvtETOtKnLP'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.sticker',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'reason': 'Spamming'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'redacts': '\$143273582443PhrSn:example.org',
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.room.redaction',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'aliases': ['#somewhere:example.org', '#another:example.org']
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': 'example.org',
        'type': 'm.room.aliases',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'aliases': ['#somewhere:example.org', '#another:example.org']
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': 'example.org',
        'type': 'm.room.aliases',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'alias': '#somewhere:localhost'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '',
        'type': 'm.room.canonical_alias',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'creator': '@example:example.org',
          'm.federate': true,
          'predecessor': {
            'event_id': '\$something:example.org',
            'room_id': '!oldroom:example.org'
          },
          'room_version': '1'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '',
        'type': 'm.room.create',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'body': 'This room has been replaced',
          'replacement_room': '!newroom:example.org'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '',
        'type': 'm.room.tombstone',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'join_rule': 'public'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '',
        'type': 'm.room.join_rules',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'avatar_url': 'mxc://example.org/SEsfnsuifSDFSSEF',
          'displayname': 'Alice Margatroid',
          'membership': 'join'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '@alice:example.org',
        'type': 'm.room.member',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'membership': 'invite'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '@alice:example.org',
        'type': 'm.room.member'
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'membership': 'leave'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '@alice:example.org',
        'type': 'm.room.member',
        'unsigned': {
          'prev_content': {'membership': 'join'},
        }
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'membership': 'ban'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '@alice:example.org',
        'type': 'm.room.member',
        'unsigned': {
          'prev_content': {'membership': 'join'},
        }
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'membership': 'join'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '@alice:example.org',
        'type': 'm.room.member',
        'unsigned': {
          'prev_content': {'membership': 'invite'},
        }
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'membership': 'invite'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '@alice:example.org',
        'type': 'm.room.member',
        'unsigned': {
          'prev_content': {'membership': 'join'},
        }
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'membership': 'leave'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '@alice:example.org',
        'type': 'm.room.member',
        'unsigned': {
          'prev_content': {'membership': 'invite'},
        }
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'membership': 'leave'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@alice:example.org',
        'state_key': '@alice:example.org',
        'type': 'm.room.member',
        'unsigned': {
          'prev_content': {'membership': 'invite'},
        }
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'ban': 50,
          'events': {'m.room.name': 100, 'm.room.power_levels': 100},
          'events_default': 0,
          'invite': 50,
          'kick': 50,
          'notifications': {'room': 20},
          'redact': 50,
          'state_default': 50,
          'users': {'@example:localhost': 100},
          'users_default': 0
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '',
        'type': 'm.room.power_levels',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'name': 'The room name'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '',
        'type': 'm.room.name',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'topic': 'A room topic'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '',
        'type': 'm.room.topic',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'info': {'h': 398, 'mimetype': 'image/jpeg', 'size': 31037, 'w': 394},
          'url': 'mxc://example.org/JWEIFJgwEIhweiWJE'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '',
        'type': 'm.room.avatar',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {'history_visibility': 'shared'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '',
        'type': 'm.room.history_visibility',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'algorithm': 'm.megolm.v1.aes-sha2',
          'rotation_period_ms': 604800000,
          'rotation_period_msgs': 100
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '',
        'type': 'm.room.encryption',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()),
          'Example activatedEndToEndEncryption. needPantalaimonWarning');

      event = Event.fromJson({
        'content': {
          'body': 'This is an example text message',
          'format': 'org.matrix.custom.html',
          'formatted_body': '<b>This is an example text message</b>',
          'msgtype': 'm.text'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.room.message',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()),
          'This is an example text message');

      event = Event.fromJson({
        'content': {
          'body': 'thinks this is an example emote',
          'format': 'org.matrix.custom.html',
          'formatted_body': 'thinks <b>this</b> is an example emote',
          'msgtype': 'm.emote'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.room.message',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()),
          '* thinks this is an example emote');

      event = Event.fromJson({
        'content': {
          'body': 'This is an example notice',
          'format': 'org.matrix.custom.html',
          'formatted_body': 'This is an <strong>example</strong> notice',
          'msgtype': 'm.notice'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.room.message',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()),
          'This is an example notice');

      event = Event.fromJson({
        'content': {
          'body': 'filename.jpg',
          'info': {'h': 398, 'mimetype': 'image/jpeg', 'size': 31037, 'w': 394},
          'msgtype': 'm.image',
          'url': 'mxc://example.org/JWEIFJgwEIhweiWJE'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.room.message',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'body': 'something-important.doc',
          'filename': 'something-important.doc',
          'info': {'mimetype': 'application/msword', 'size': 46144},
          'msgtype': 'm.file',
          'url': 'mxc://example.org/FHyPlCeYUSFFxlgbQYZmoEoe'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.room.message',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'body': 'Bee Gees - Stayin Alive',
          'info': {
            'duration': 2140786,
            'mimetype': 'audio/mpeg',
            'size': 1563685
          },
          'msgtype': 'm.audio',
          'url': 'mxc://example.org/ffed755USFFxlgbQYZGtryd'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.room.message',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'body': 'Big Ben, London, UK',
          'geo_uri': 'geo:51.5008,0.1247',
          'info': {
            'thumbnail_info': {
              'h': 300,
              'mimetype': 'image/jpeg',
              'size': 46144,
              'w': 300
            },
            'thumbnail_url': 'mxc://example.org/FHyPlCeYUSFFxlgbQYZmoEoe'
          },
          'msgtype': 'm.location'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.room.message',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);

      event = Event.fromJson({
        'content': {
          'body': 'Gangnam Style',
          'info': {
            'duration': 2140786,
            'h': 320,
            'mimetype': 'video/mp4',
            'size': 1563685,
            'thumbnail_info': {
              'h': 300,
              'mimetype': 'image/jpeg',
              'size': 46144,
              'w': 300
            },
            'thumbnail_url': 'mxc://example.org/FHyPlCeYUSFFxlgbQYZmoEoe',
            'w': 480
          },
          'msgtype': 'm.video',
          'url': 'mxc://example.org/a526eYUSFFxlgbQYZmo442'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.room.message',
        'unsigned': {'age': 1234}
      }, room);
      expect(event.getLocalizedBody(FakeMatrixLocalizations()), null);
    });

    test('aggregations', () {
      var event = Event.fromJson({
        'content': {
          'body': 'blah',
          'msgtype': 'm.text',
        },
        'event_id': '\$source',
      }, null);
      var edit1 = Event.fromJson({
        'content': {
          'body': 'blah',
          'msgtype': 'm.text',
          'm.relates_to': {
            'event_id': '\$source',
            'rel_type': RelationshipTypes.Edit,
          },
        },
        'event_id': '\$edit1',
      }, null);
      var edit2 = Event.fromJson({
        'content': {
          'body': 'blah',
          'msgtype': 'm.text',
          'm.relates_to': {
            'event_id': '\$source',
            'rel_type': RelationshipTypes.Edit,
          },
        },
        'event_id': '\$edit2',
      }, null);
      var room = Room(client: client);
      var timeline = Timeline(events: <Event>[event, edit1, edit2], room: room);
      expect(event.hasAggregatedEvents(timeline, RelationshipTypes.Edit), true);
      expect(event.aggregatedEvents(timeline, RelationshipTypes.Edit),
          {edit1, edit2});
      expect(event.aggregatedEvents(timeline, RelationshipTypes.Reaction),
          <Event>{});
      expect(event.hasAggregatedEvents(timeline, RelationshipTypes.Reaction),
          false);

      timeline.removeAggregatedEvent(edit2);
      expect(event.aggregatedEvents(timeline, RelationshipTypes.Edit), {edit1});
      timeline.addAggregatedEvent(edit2);
      expect(event.aggregatedEvents(timeline, RelationshipTypes.Edit),
          {edit1, edit2});

      timeline.removeAggregatedEvent(event);
      expect(
          event.aggregatedEvents(timeline, RelationshipTypes.Edit), <Event>{});
    });
    test('getDisplayEvent', () {
      var event = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'body': 'blah',
          'msgtype': 'm.text',
        },
        'event_id': '\$source',
        'sender': '@alice:example.org',
      }, null);
      event.sortOrder = 0;
      var edit1 = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'body': '* edit 1',
          'msgtype': 'm.text',
          'm.new_content': {
            'body': 'edit 1',
            'msgtype': 'm.text',
          },
          'm.relates_to': {
            'event_id': '\$source',
            'rel_type': RelationshipTypes.Edit,
          },
        },
        'event_id': '\$edit1',
        'sender': '@alice:example.org',
      }, null);
      edit1.sortOrder = 1;
      var edit2 = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'body': '* edit 2',
          'msgtype': 'm.text',
          'm.new_content': {
            'body': 'edit 2',
            'msgtype': 'm.text',
          },
          'm.relates_to': {
            'event_id': '\$source',
            'rel_type': RelationshipTypes.Edit,
          },
        },
        'event_id': '\$edit2',
        'sender': '@alice:example.org',
      }, null);
      edit2.sortOrder = 2;
      var edit3 = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'body': '* edit 3',
          'msgtype': 'm.text',
          'm.new_content': {
            'body': 'edit 3',
            'msgtype': 'm.text',
          },
          'm.relates_to': {
            'event_id': '\$source',
            'rel_type': RelationshipTypes.Edit,
          },
        },
        'event_id': '\$edit3',
        'sender': '@bob:example.org',
      }, null);
      edit3.sortOrder = 3;
      var room = Room(client: client);
      // no edits
      var displayEvent =
          event.getDisplayEvent(Timeline(events: <Event>[event], room: room));
      expect(displayEvent.body, 'blah');
      // one edit
      displayEvent = event
          .getDisplayEvent(Timeline(events: <Event>[event, edit1], room: room));
      expect(displayEvent.body, 'edit 1');
      // two edits
      displayEvent = event.getDisplayEvent(
          Timeline(events: <Event>[event, edit1, edit2], room: room));
      expect(displayEvent.body, 'edit 2');
      // foreign edit
      displayEvent = event
          .getDisplayEvent(Timeline(events: <Event>[event, edit3], room: room));
      expect(displayEvent.body, 'blah');
      // mixed foreign and non-foreign
      displayEvent = event.getDisplayEvent(
          Timeline(events: <Event>[event, edit1, edit2, edit3], room: room));
      expect(displayEvent.body, 'edit 2');
    });
    test('downloadAndDecryptAttachment', () async {
      final FILE_BUFF = Uint8List.fromList([0]);
      final THUMBNAIL_BUFF = Uint8List.fromList([2]);
      final downloadCallback = (String url) async {
        return {
          'https://fakeserver.notexisting/_matrix/media/r0/download/example.org/file':
              FILE_BUFF,
          'https://fakeserver.notexisting/_matrix/media/r0/download/example.org/thumb':
              THUMBNAIL_BUFF,
        }[url];
      };
      await client.checkHomeserver('https://fakeServer.notExisting');
      final room = Room(id: '!localpart:server.abc', client: client);
      var event = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'body': 'image',
          'msgtype': 'm.image',
          'url': 'mxc://example.org/file',
        },
        'event_id': '\$edit2',
        'sender': '@alice:example.org',
      }, room);
      var buffer = await event.downloadAndDecryptAttachment(
          downloadCallback: downloadCallback);
      expect(buffer.bytes, FILE_BUFF);

      event = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'body': 'image',
          'msgtype': 'm.image',
          'url': 'mxc://example.org/file',
          'info': {
            'thumbnail_url': 'mxc://example.org/thumb',
          },
        },
        'event_id': '\$edit2',
        'sender': '@alice:example.org',
      }, room);
      buffer = await event.downloadAndDecryptAttachment(
          downloadCallback: downloadCallback);
      expect(buffer.bytes, FILE_BUFF);

      buffer = await event.downloadAndDecryptAttachment(
          getThumbnail: true, downloadCallback: downloadCallback);
      expect(buffer.bytes, THUMBNAIL_BUFF);
    });
    test('downloadAndDecryptAttachment encrypted', () async {
      if (!olmEnabled) return;

      final FILE_BUFF_ENC = Uint8List.fromList([0x3B, 0x6B, 0xB2, 0x8C, 0xAF]);
      final FILE_BUFF_DEC = Uint8List.fromList([0x74, 0x65, 0x73, 0x74, 0x0A]);
      final THUMB_BUFF_ENC =
          Uint8List.fromList([0x55, 0xD7, 0xEB, 0x72, 0x05, 0x13]);
      final THUMB_BUFF_DEC =
          Uint8List.fromList([0x74, 0x68, 0x75, 0x6D, 0x62, 0x0A]);
      final downloadCallback = (String url) async {
        return {
          'https://fakeserver.notexisting/_matrix/media/r0/download/example.com/file':
              FILE_BUFF_ENC,
          'https://fakeserver.notexisting/_matrix/media/r0/download/example.com/thumb':
              THUMB_BUFF_ENC,
        }[url];
      };
      final room = Room(id: '!localpart:server.abc', client: await getClient());
      var event = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'body': 'image',
          'msgtype': 'm.image',
          'file': {
            'v': 'v2',
            'key': {
              'alg': 'A256CTR',
              'ext': true,
              'k': '7aPRNIDPeUAUqD6SPR3vVX5W9liyMG98NexVJ9udnCc',
              'key_ops': ['encrypt', 'decrypt'],
              'kty': 'oct'
            },
            'iv': 'Wdsf+tnOHIoAAAAAAAAAAA',
            'hashes': {'sha256': 'WgC7fw2alBC5t+xDx+PFlZxfFJXtIstQCg+j0WDaXxE'},
            'url': 'mxc://example.com/file',
            'mimetype': 'text/plain'
          },
        },
        'event_id': '\$edit2',
        'sender': '@alice:example.org',
      }, room);
      var buffer = await event.downloadAndDecryptAttachment(
          downloadCallback: downloadCallback);
      expect(buffer.bytes, FILE_BUFF_DEC);

      event = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'body': 'image',
          'msgtype': 'm.image',
          'file': {
            'v': 'v2',
            'key': {
              'alg': 'A256CTR',
              'ext': true,
              'k': '7aPRNIDPeUAUqD6SPR3vVX5W9liyMG98NexVJ9udnCc',
              'key_ops': ['encrypt', 'decrypt'],
              'kty': 'oct'
            },
            'iv': 'Wdsf+tnOHIoAAAAAAAAAAA',
            'hashes': {'sha256': 'WgC7fw2alBC5t+xDx+PFlZxfFJXtIstQCg+j0WDaXxE'},
            'url': 'mxc://example.com/file',
            'mimetype': 'text/plain'
          },
          'info': {
            'thumbnail_file': {
              'v': 'v2',
              'key': {
                'alg': 'A256CTR',
                'ext': true,
                'k': 'TmF-rZYetZbxpL5yjDPE21UALQJcpEE6X-nvUDD5rA0',
                'key_ops': ['encrypt', 'decrypt'],
                'kty': 'oct'
              },
              'iv': '41ZqNRZSLFUAAAAAAAAAAA',
              'hashes': {
                'sha256': 'zccOwXiOTAYhGXyk0Fra7CRreBF6itjiCKdd+ov8mO4'
              },
              'url': 'mxc://example.com/thumb',
              'mimetype': 'text/plain'
            }
          },
        },
        'event_id': '\$edit2',
        'sender': '@alice:example.org',
      }, room);
      buffer = await event.downloadAndDecryptAttachment(
          downloadCallback: downloadCallback);
      expect(buffer.bytes, FILE_BUFF_DEC);

      buffer = await event.downloadAndDecryptAttachment(
          getThumbnail: true, downloadCallback: downloadCallback);
      expect(buffer.bytes, THUMB_BUFF_DEC);

      await room.client.dispose(closeDatabase: true);
    });
    test('downloadAndDecryptAttachment store', () async {
      final FILE_BUFF = Uint8List.fromList([0]);
      var serverHits = 0;
      final downloadCallback = (String url) async {
        serverHits++;
        return {
          'https://fakeserver.notexisting/_matrix/media/r0/download/example.org/newfile':
              FILE_BUFF,
        }[url];
      };
      await client.checkHomeserver('https://fakeServer.notExisting');
      final room = Room(id: '!localpart:server.abc', client: await getClient());
      var event = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'body': 'image',
          'msgtype': 'm.image',
          'url': 'mxc://example.org/newfile',
          'info': {
            'size': 5,
          },
        },
        'event_id': '\$edit2',
        'sender': '@alice:example.org',
      }, room);
      var buffer = await event.downloadAndDecryptAttachment(
          downloadCallback: downloadCallback);
      expect(buffer.bytes, FILE_BUFF);
      expect(serverHits, 1);
      buffer = await event.downloadAndDecryptAttachment(
          downloadCallback: downloadCallback);
      expect(buffer.bytes, FILE_BUFF);
      expect(serverHits, 1);

      await room.client.dispose(closeDatabase: true);
    });
    test('emote detection', () async {
      var event = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'msgtype': 'm.text',
          'body': 'normal message',
        },
        'event_id': '\$edit2',
        'sender': '@alice:example.org',
      }, null);
      expect(event.onlyEmotes, false);
      expect(event.numberEmotes, 0);
      event = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'msgtype': 'm.text',
          'body': 'normal message\n\nvery normal',
        },
        'event_id': '\$edit2',
        'sender': '@alice:example.org',
      }, null);
      expect(event.onlyEmotes, false);
      expect(event.numberEmotes, 0);
      event = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'msgtype': 'm.text',
          'body': 'normal message with emoji 🦊',
        },
        'event_id': '\$edit2',
        'sender': '@alice:example.org',
      }, null);
      expect(event.onlyEmotes, false);
      expect(event.numberEmotes, 1);
      event = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'msgtype': 'm.text',
          'body': '🦊',
        },
        'event_id': '\$edit2',
        'sender': '@alice:example.org',
      }, null);
      expect(event.onlyEmotes, true);
      expect(event.numberEmotes, 1);
      event = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'msgtype': 'm.text',
          'body': '🦊🦊 🦊\n🦊🦊',
        },
        'event_id': '\$edit2',
        'sender': '@alice:example.org',
      }, null);
      expect(event.onlyEmotes, true);
      expect(event.numberEmotes, 5);
      event = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'msgtype': 'm.text',
          'body': 'rich message',
          'format': 'org.matrix.custom.html',
          'formatted_body': 'rich message'
        },
        'event_id': '\$edit2',
        'sender': '@alice:example.org',
      }, null);
      expect(event.onlyEmotes, false);
      expect(event.numberEmotes, 0);
      event = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'msgtype': 'm.text',
          'body': '🦊',
          'format': 'org.matrix.custom.html',
          'formatted_body': '🦊'
        },
        'event_id': '\$edit2',
        'sender': '@alice:example.org',
      }, null);
      expect(event.onlyEmotes, true);
      expect(event.numberEmotes, 1);
      event = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'msgtype': 'm.text',
          'body': ':blah:',
          'format': 'org.matrix.custom.html',
          'formatted_body': '<img data-mx-emoticon src="mxc://blah/blubb">'
        },
        'event_id': '\$edit2',
        'sender': '@alice:example.org',
      }, null);
      expect(event.onlyEmotes, true);
      expect(event.numberEmotes, 1);
      event = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'msgtype': 'm.text',
          'body': '🦊 :blah:',
          'format': 'org.matrix.custom.html',
          'formatted_body': '🦊 <img data-mx-emoticon src="mxc://blah/blubb">'
        },
        'event_id': '\$edit2',
        'sender': '@alice:example.org',
      }, null);
      expect(event.onlyEmotes, true);
      expect(event.numberEmotes, 2);
      // with variant selector
      event = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'msgtype': 'm.text',
          'body': '❤️',
        },
        'event_id': '\$edit2',
        'sender': '@alice:example.org',
      }, null);
      expect(event.onlyEmotes, true);
      expect(event.numberEmotes, 1);
    });
  });
}
