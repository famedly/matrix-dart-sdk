/*
 *   Famedly Matrix SDK
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

import 'package:test/test.dart';

import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/models/timeline_chunk.dart';
import 'fake_client.dart';

void main() {
  /// All Tests related to the Event
  group('Event', () {
    Logs().level = Level.error;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final id = '!4fsdfjisjf:server.abc';
    final senderID = '@alice:server.abc';
    final type = 'm.room.message';
    final msgtype = 'm.text';
    final body = 'Hello World';
    final formatted_body = '<b>Hello</b> World';

    final contentJson =
        '{"msgtype":"$msgtype","body":"$body","formatted_body":"$formatted_body","m.relates_to":{"m.in_reply_to":{"event_id":"\$1234:example.com"}}}';

    final jsonObj = <String, dynamic>{
      'event_id': id,
      'sender': senderID,
      'origin_server_ts': timestamp,
      'type': type,
      'room_id': '!testroom:example.abc',
      'status': EventStatus.synced.intValue,
      'content': contentJson,
    };
    final client = Client('testclient', httpClient: FakeMatrixApi());
    final room = Room(id: '!testroom:example.abc', client: client);
    final event = Event.fromJson(
        jsonObj, Room(id: '!testroom:example.abc', client: client));

    test('Create from json', () async {
      jsonObj['content'] = json.decode(contentJson);
      expect(event.toJson(), jsonObj);
      jsonObj['content'] = contentJson;

      expect(event.eventId, id);
      expect(event.senderId, senderID);
      expect(event.status, EventStatus.synced);
      expect(event.text, body);
      expect(event.formattedText, formatted_body);
      expect(event.body, body);
      expect(event.type, EventTypes.Message);
      expect(event.relationshipType, RelationshipTypes.reply);
      jsonObj['state_key'] = '';
      final state = Event.fromJson(jsonObj, room);
      expect(state.eventId, id);
      expect(state.stateKey, '');
      expect(state.status, EventStatus.synced);
    });
    test('Test all EventTypes', () async {
      Event event;

      jsonObj['type'] = 'm.room.avatar';
      event = Event.fromJson(jsonObj, room);
      expect(event.type, EventTypes.RoomAvatar);

      jsonObj['type'] = 'm.room.name';
      event = Event.fromJson(jsonObj, room);
      expect(event.type, EventTypes.RoomName);

      jsonObj['type'] = 'm.room.topic';
      event = Event.fromJson(jsonObj, room);
      expect(event.type, EventTypes.RoomTopic);

      jsonObj['type'] = 'm.room.aliases';
      event = Event.fromJson(jsonObj, room);
      expect(event.type, EventTypes.RoomAliases);

      jsonObj['type'] = 'm.room.canonical_alias';
      event = Event.fromJson(jsonObj, room);
      expect(event.type, EventTypes.RoomCanonicalAlias);

      jsonObj['type'] = 'm.room.create';
      event = Event.fromJson(jsonObj, room);
      expect(event.type, EventTypes.RoomCreate);

      jsonObj['type'] = 'm.room.join_rules';
      event = Event.fromJson(jsonObj, room);
      expect(event.type, EventTypes.RoomJoinRules);

      jsonObj['type'] = 'm.room.member';
      event = Event.fromJson(jsonObj, room);
      expect(event.type, EventTypes.RoomMember);

      jsonObj['type'] = 'm.room.power_levels';
      event = Event.fromJson(jsonObj, room);
      expect(event.type, EventTypes.RoomPowerLevels);

      jsonObj['type'] = 'm.room.guest_access';
      event = Event.fromJson(jsonObj, room);
      expect(event.type, EventTypes.GuestAccess);

      jsonObj['type'] = 'm.room.history_visibility';
      event = Event.fromJson(jsonObj, room);
      expect(event.type, EventTypes.HistoryVisibility);

      jsonObj['type'] = 'm.room.message';
      jsonObj['content'] = json.decode(jsonObj['content']);

      jsonObj['content'].remove('m.relates_to');
      jsonObj['content']['msgtype'] = 'm.notice';
      event = Event.fromJson(jsonObj, room);
      expect(event.messageType, MessageTypes.Notice);

      jsonObj['content']['msgtype'] = 'm.emote';
      event = Event.fromJson(jsonObj, room);
      expect(event.messageType, MessageTypes.Emote);

      jsonObj['content']['msgtype'] = 'm.image';
      event = Event.fromJson(jsonObj, room);
      expect(event.messageType, MessageTypes.Image);

      jsonObj['content']['msgtype'] = 'm.video';
      event = Event.fromJson(jsonObj, room);
      expect(event.messageType, MessageTypes.Video);

      jsonObj['content']['msgtype'] = 'm.audio';
      event = Event.fromJson(jsonObj, room);
      expect(event.messageType, MessageTypes.Audio);

      jsonObj['content']['msgtype'] = 'm.file';
      event = Event.fromJson(jsonObj, room);
      expect(event.messageType, MessageTypes.File);

      jsonObj['content']['msgtype'] = 'm.location';
      event = Event.fromJson(jsonObj, room);
      expect(event.messageType, MessageTypes.Location);

      jsonObj['type'] = 'm.sticker';
      jsonObj['content']['msgtype'] = null;
      event = Event.fromJson(jsonObj, room);
      expect(event.messageType, MessageTypes.Sticker);

      jsonObj['type'] = 'm.room.message';
      jsonObj['content']['msgtype'] = 'm.text';
      jsonObj['content']['m.relates_to'] = <String, dynamic>{};
      jsonObj['content']['m.relates_to']['m.in_reply_to'] = {
        'event_id': '1234',
      };
      event = Event.fromJson(jsonObj, room);
      expect(event.messageType, MessageTypes.Text);
      expect(event.relationshipType, RelationshipTypes.reply);
      expect(event.relationshipEventId, '1234');
    });

    test('relationship types', () async {
      Event event;

      jsonObj['content'] = <String, dynamic>{
        'msgtype': 'm.text',
        'text': 'beep',
      };
      event = Event.fromJson(jsonObj, room);
      expect(event.relationshipType, null);
      expect(event.relationshipEventId, null);

      jsonObj['content']['m.relates_to'] = <String, dynamic>{
        'rel_type': 'm.replace',
        'event_id': 'abc',
      };
      event = Event.fromJson(jsonObj, room);
      expect(event.relationshipType, RelationshipTypes.edit);
      expect(event.relationshipEventId, 'abc');

      jsonObj['content']['m.relates_to']['rel_type'] = 'm.annotation';
      event = Event.fromJson(jsonObj, room);
      expect(event.relationshipType, RelationshipTypes.reaction);
      expect(event.relationshipEventId, 'abc');

      jsonObj['content']['m.relates_to'] = {
        'm.in_reply_to': {
          'event_id': 'def',
        },
      };
      event = Event.fromJson(jsonObj, room);
      expect(event.relationshipType, RelationshipTypes.reply);
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
          'unsigned': {'age': 1234},
          'status': 1,
        };
        final redactedBecause = Event.fromJson(redactionEventJson, room);
        final event = Event.fromJson(redactJsonObj, room);
        event.setRedactionEvent(redactedBecause);
        expect(event.redacted, true);
        expect(event.redactedBecause?.toJson(), redactedBecause.toJson());
        expect(event.content.isEmpty, true);
        redactionEventJson.remove('redacts');
        expect(event.unsigned?['redacted_because'], redactionEventJson);
      }
    });

    test('remove', () async {
      final event = Event.fromJson(
        jsonObj,
        Room(id: '1234', client: Client('testclient')),
      );
      expect(() async => await event.cancelSend(), throwsException);
      event.status = EventStatus.sending;
      await event.cancelSend();
    });

    test('sendAgain', () async {
      final matrix = Client('testclient', httpClient: FakeMatrixApi());
      await matrix.checkHomeserver(Uri.parse('https://fakeserver.notexisting'),
          checkWellKnown: false);
      await matrix.login(LoginType.mLoginPassword,
          identifier: AuthenticationUserIdentifier(user: 'test'),
          password: '1234');

      final event = Event.fromJson(
          jsonObj, Room(id: '!1234:example.com', client: matrix));
      final resp1 = await event.sendAgain();
      event.status = EventStatus.error;
      final resp2 = await event.sendAgain(txid: '1234');
      expect(resp1, null);
      expect(resp2?.startsWith('\$event'), true);

      await matrix.dispose(closeDatabase: true);
    });

    test('requestKey', tags: 'olm', () async {
      final matrix = Client('testclient', httpClient: FakeMatrixApi());
      await matrix.checkHomeserver(Uri.parse('https://fakeserver.notexisting'),
          checkWellKnown: false);
      await matrix.login(LoginType.mLoginPassword,
          identifier: AuthenticationUserIdentifier(user: 'test'),
          password: '1234');

      final event = Event.fromJson(
          jsonObj, Room(id: '!1234:example.com', client: matrix));
      String? exception;
      try {
        await event.requestKey();
      } catch (e) {
        exception = e.toString();
      }
      expect(exception, 'Session key not requestable');

      final event2 = Event.fromJson({
        'event_id': id,
        'sender': senderID,
        'origin_server_ts': timestamp,
        'type': 'm.room.encrypted',
        'room_id': '1234',
        'status': EventStatus.synced.intValue,
        'content': json.encode({
          'msgtype': 'm.bad.encrypted',
          'body': DecryptException.unknownSession,
          'can_request_session': true,
          'algorithm': AlgorithmTypes.megolmV1AesSha2,
          'ciphertext': 'AwgAEnACgAkLmt6qF84IK++J7UDH2Za1YVchHyprqTqsg...',
          'device_id': 'RJYKSTBOIE',
          'sender_key': 'IlRMeOPX2e0MurIyfWEucYBRVOEEUMrOHqn/8mLqMjA',
          'session_id': 'X3lUlvLELLYxeTx4yOVu6UDpasGEVO0Jbu+QFnm0cKQ'
        }),
      }, Room(id: '!1234:example.com', client: matrix));

      await event2.requestKey();

      await matrix.dispose(closeDatabase: true);
    });
    test('requestKey', tags: 'olm', () async {
      jsonObj['state_key'] = '@alice:example.com';
      final event = Event.fromJson(
          jsonObj, Room(id: '!localpart:server.abc', client: client));
      expect(event.stateKeyUser?.id, '@alice:example.com');
    });
    test('canRedact', () async {
      final client = await getClient();
      jsonObj['sender'] = client.userID!;
      final event = Event.fromJson(
        jsonObj,
        Room(
          id: '!localpart:server.abc',
          client: client,
        ),
      );
      expect(event.canRedact, true);
    });
    test('getLocalizedBody, isEventKnown', () async {
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
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Removed by Example');
      expect(event.isEventTypeKnown, true);

      event = Event.fromJson({
        'content': {
          'avatar_url':
              'mxc://pixelthefox.net/bmGuC44Eeb3BomfkZTP02DVnGaRp4dek',
          'displayname': [
            [
              [[]]
            ]
          ],
          'membership': 'join'
        },
        'origin_server_ts': 1636487843183,
        'room_id': '!watercooler-v9:maunium.net',
        'sender': '@nyaaori:pixelthefox.net',
        'state_key': '@nyaaori:pixelthefox.net',
        'type': 'm.room.member',
        'unsigned': {
          'prev_content': {
            'avatar_url':
                'mxc://pixelthefox.net/bmGuC44Eeb3BomfkZTP02DVnGaRp4dek',
            'displayname': 1,
            'membership': 'join'
          },
          'prev_sender': '@nyaaori:pixelthefox.net',
          'replaces_state': '\$kcqn2k6kXQKOM45t_p8OA03PQRR3KB2N_PN4HUq1GiY'
        },
        'event_id': '\$21DJjleMGcviLoT4L9wvxawMlOXSQ9yW6R8mrhlbhfU',
        'user_id': '@nyaaori:pixelthefox.net',
        'replaces_state': '\$kcqn2k6kXQKOM45t_p8OA03PQRR3KB2N_PN4HUq1GiY',
        'prev_content': {
          'avatar_url':
              'mxc://pixelthefox.net/bmGuC44Eeb3BomfkZTP02DVnGaRp4dek',
          'displayname': 1,
          'membership': 'join'
        }
      }, room);
      expect(event.isEventTypeKnown, true);

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
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Example sent a sticker');
      expect(event.isEventTypeKnown, true);

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
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Example redacted an event');
      expect(event.isEventTypeKnown, true);

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
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Example changed the room aliases');
      expect(event.isEventTypeKnown, true);

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
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Example changed the room aliases');
      expect(event.isEventTypeKnown, true);

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
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Example changed the room invitation link');
      expect(event.isEventTypeKnown, true);

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
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Example created the chat');
      expect(event.isEventTypeKnown, true);

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
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Room has been upgraded');
      expect(event.isEventTypeKnown, true);

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
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Example changed the join rules to Anyone can join');
      expect(event.isEventTypeKnown, true);

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
      expect(event.roomMemberChangeType, RoomMemberChangeType.join);
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Alice joined the chat');
      expect(event.isEventTypeKnown, true);

      event = Event.fromJson({
        'content': {'membership': 'invite'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '@alice:example.org',
        'type': 'm.room.member'
      }, room);
      expect(event.roomMemberChangeType, RoomMemberChangeType.invite);
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Example has invited Alice');
      expect(event.isEventTypeKnown, true);

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
      expect(event.roomMemberChangeType, RoomMemberChangeType.kick);
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Example kicked Alice');
      expect(event.isEventTypeKnown, true);

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
      expect(event.roomMemberChangeType, RoomMemberChangeType.ban);
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Example banned Alice');
      expect(event.isEventTypeKnown, true);

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
      expect(event.roomMemberChangeType, RoomMemberChangeType.acceptInvite);
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Alice accepted the invitation');
      expect(event.isEventTypeKnown, true);

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
      expect(event.roomMemberChangeType, RoomMemberChangeType.invite);
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Example has invited Alice');
      expect(event.isEventTypeKnown, true);

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
      expect(
          event.roomMemberChangeType, RoomMemberChangeType.withdrawInvitation);
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Example has withdrawn the invitation for Alice');
      expect(event.isEventTypeKnown, true);

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
      expect(event.roomMemberChangeType, RoomMemberChangeType.rejectInvite);
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Alice rejected the invitation');
      expect(event.isEventTypeKnown, true);

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
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Example changed the chat permissions');
      expect(event.isEventTypeKnown, true);

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
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Example changed the chat name to The room name');
      expect(event.isEventTypeKnown, true);

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
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Example changed the chat description to A room topic');
      expect(event.isEventTypeKnown, true);

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
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Example changed the chat avatar');
      expect(event.isEventTypeKnown, true);

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
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Example changed the history visibility to Visible for all participants');
      expect(event.isEventTypeKnown, true);

      event = Event.fromJson({
        'content': {
          'algorithm': AlgorithmTypes.megolmV1AesSha2,
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
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Example activated end to end encryption. Need pantalaimon');
      expect(event.isEventTypeKnown, true);

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
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'This is an example text message');
      expect(event.isEventTypeKnown, true);

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
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          '* thinks this is an example emote');
      expect(event.isEventTypeKnown, true);

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
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'This is an example notice');
      expect(event.isEventTypeKnown, true);

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
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Example sent a picture');
      expect(event.isEventTypeKnown, true);

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
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Example sent a file');
      expect(event.isEventTypeKnown, true);

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
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Example sent an audio');
      expect(event.isEventTypeKnown, true);

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
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Example shared the location');
      expect(event.isEventTypeKnown, true);

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
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Example sent a video');
      expect(event.isEventTypeKnown, true);

      event = Event.fromJson({
        'content': {'beep': 'boop'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'unknown.event.type',
        'unsigned': {'age': 1234}
      }, room);
      expect(await event.calcLocalizedBody(MatrixDefaultLocalizations()),
          'Unknown event unknown.event.type');
      expect(event.isEventTypeKnown, false);
    });

    test('getLocalizedBody, parameters', () async {
      final matrix = Client('testclient', httpClient: FakeMatrixApi());
      final room = Room(id: '!1234:example.com', client: matrix);
      var event = Event.fromJson({
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
      expect(
          await event.calcLocalizedBody(MatrixDefaultLocalizations(),
              plaintextBody: true),
          '**This is an example text message**');

      event = Event.fromJson({
        'content': {
          'body': '* This is an example text message',
          'format': 'org.matrix.custom.html',
          'formatted_body': '* <b>This is an example text message</b>',
          'msgtype': 'm.text',
          'm.relates_to': <String, dynamic>{
            'rel_type': 'm.replace',
            'event_id': '\$some_event',
          },
          'm.new_content': <String, dynamic>{
            'body': 'This is an example text message',
            'format': 'org.matrix.custom.html',
            'formatted_body': '<b>This is an example text message</b>',
            'msgtype': 'm.text'
          },
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.room.message',
        'unsigned': {'age': 1234}
      }, room);
      expect(
          await event.calcLocalizedBody(MatrixDefaultLocalizations(),
              hideEdit: true),
          'This is an example text message');
      expect(
          await event.calcLocalizedBody(MatrixDefaultLocalizations(),
              hideEdit: true, plaintextBody: true),
          '**This is an example text message**');

      event = Event.fromJson({
        'content': {
          'body': '> <@user:example.org> beep\n\nhmm, fox',
          'format': 'org.matrix.custom.html',
          'formatted_body': '<mx-reply>beep</mx-reply>hmm, <em>fox</em>',
          'msgtype': 'm.text'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.room.message',
        'unsigned': {'age': 1234}
      }, room);
      expect(
          await event.calcLocalizedBody(MatrixDefaultLocalizations(),
              hideReply: true),
          'hmm, fox');
      expect(
          await event.calcLocalizedBody(MatrixDefaultLocalizations(),
              hideReply: true, plaintextBody: true),
          'hmm, *fox*');

      event = Event.fromJson({
        'content': {
          'body':
              '# Title\nsome text and [link](https://example.com)\nokay and this is **important**',
          'format': 'org.matrix.custom.html',
          'formatted_body':
              '<h1>Title</h1>\n<p>some text and <a href="https://example.com">link</a><br>okay and this is <strong>important</strong></p>\n',
          'msgtype': 'm.text'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.room.message',
        'unsigned': {'age': 1234}
      }, room);
      expect(
          await event.calcLocalizedBody(MatrixDefaultLocalizations(),
              removeMarkdown: true),
          'Title\nsome text and link\nokay and this is important');
      expect(
          await event.calcLocalizedBody(MatrixDefaultLocalizations(),
              removeMarkdown: true, plaintextBody: true),
          'Title\nsome text and 🔗link\nokay and this is important');
      expect(
          await event.calcLocalizedBody(MatrixDefaultLocalizations(),
              removeMarkdown: true, withSenderNamePrefix: true),
          'Example: Title\nsome text and link\nokay and this is important');
      expect(
          await event.calcLocalizedBody(MatrixDefaultLocalizations(),
              removeMarkdown: true,
              plaintextBody: true,
              withSenderNamePrefix: true),
          'Example: Title\nsome text and 🔗link\nokay and this is important');

      event = Event.fromJson({
        'content': {
          'body':
              'Alice is requesting to verify your device, but your client does not support verification, so you may need to use a different verification method.',
          'from_device': 'AliceDevice2',
          'methods': ['m.sas.v1'],
          'msgtype': 'm.key.verification.request',
          'to': '@bob:example.org'
        },
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.room.message',
        'unsigned': {'age': 1234}
      }, room);
      expect(
        await event.calcLocalizedBody(MatrixDefaultLocalizations()),
        'Example requested key verification',
      );

      event.content['msgtype'] = 'm.key.verification.ready';
      expect(
        await event.calcLocalizedBody(MatrixDefaultLocalizations()),
        'Example is ready for key verification',
      );

      event.content['msgtype'] = 'm.key.verification.start';
      expect(
        await event.calcLocalizedBody(MatrixDefaultLocalizations()),
        'Example started key verification',
      );

      event.content['msgtype'] = 'm.key.verification.cancel';
      expect(
        await event.calcLocalizedBody(MatrixDefaultLocalizations()),
        'Example canceled key verification',
      );

      event.content['msgtype'] = 'm.key.verification.done';
      expect(
        await event.calcLocalizedBody(MatrixDefaultLocalizations()),
        'Example completed key verification',
      );

      event.content['msgtype'] = 'm.key.verification.accept';
      expect(
        await event.calcLocalizedBody(MatrixDefaultLocalizations()),
        'Example accepted key verification request',
      );
    });

    test('aggregations', () {
      final room = Room(id: '!1234', client: client);
      final event = Event.fromJson({
        'content': {
          'body': 'blah',
          'msgtype': 'm.text',
        },
        'type': 'm.room.message',
        'sender': '@example:example.org',
        'event_id': '\$source',
      }, room);
      final edit1 = Event.fromJson({
        'content': {
          'body': 'blah',
          'msgtype': 'm.text',
          'm.relates_to': {
            'event_id': '\$source',
            'rel_type': RelationshipTypes.edit,
          },
        },
        'type': 'm.room.message',
        'sender': '@example:example.org',
        'event_id': '\$edit1',
      }, room);
      final edit2 = Event.fromJson({
        'content': {
          'body': 'blah',
          'msgtype': 'm.text',
          'm.relates_to': {
            'event_id': '\$source',
            'rel_type': RelationshipTypes.edit,
          },
        },
        'type': 'm.room.message',
        'sender': '@example:example.org',
        'event_id': '\$edit2',
      }, room);
      final timeline = Timeline(
          chunk: TimelineChunk(events: <Event>[event, edit1, edit2]),
          room: room);
      expect(event.hasAggregatedEvents(timeline, RelationshipTypes.edit), true);
      expect(event.aggregatedEvents(timeline, RelationshipTypes.edit),
          {edit1, edit2});
      expect(event.aggregatedEvents(timeline, RelationshipTypes.reaction),
          <Event>{});
      expect(event.hasAggregatedEvents(timeline, RelationshipTypes.reaction),
          false);

      timeline.removeAggregatedEvent(edit2);
      expect(event.aggregatedEvents(timeline, RelationshipTypes.edit), {edit1});
      timeline.addAggregatedEvent(edit2);
      expect(event.aggregatedEvents(timeline, RelationshipTypes.edit),
          {edit1, edit2});

      timeline.removeAggregatedEvent(event);
      expect(
          event.aggregatedEvents(timeline, RelationshipTypes.edit), <Event>{});
    });
    test('plaintextBody', () {
      final event = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'body': 'blah',
          'msgtype': 'm.text',
          'format': 'org.matrix.custom.html',
          'formatted_body': '<b>blah</b>',
        },
        'event_id': '\$source',
        'sender': '@alice:example.org',
      }, room);
      expect(event.plaintextBody, '**blah**');
    });

    test('body', () {
      final event = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'body': 'blah',
          'msgtype': 'm.text',
          'format': 'org.matrix.custom.html',
          'formatted_body': '<b>blub</b>',
        },
        'event_id': '\$source',
        'sender': '@alice:example.org',
      }, room);
      expect(event.body, 'blah');

      final event2 = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'body': '',
          'msgtype': 'm.text',
          'format': 'org.matrix.custom.html',
          'formatted_body': '<b>blub</b>',
        },
        'event_id': '\$source',
        'sender': '@alice:example.org',
      }, room);
      expect(event2.body, 'm.room.message');
    });

    group('unlocalized body reply stripping', () {
      int i = 0;

      void testUnlocalizedBody({
        required Object? body,
        required Object? formattedBody,
        required bool html,
        Object? editBody,
        Object? editFormattedBody,
        bool editHtml = false,
        bool isEdit = false,
        required String expectation,
        required bool plaintextBody,
      }) {
        i += 1;
        test('$i', () {
          final event = Event.fromJson({
            'type': EventTypes.Message,
            'content': {
              'msgtype': 'm.text',
              if (body != null) 'body': body,
              if (formattedBody != null) 'formatted_body': formattedBody,
              if (html) 'format': 'org.matrix.custom.html',
              if (isEdit) ...{
                'm.new_content': {
                  if (editBody != null) 'body': editBody,
                  if (editFormattedBody != null)
                    'formatted_body': editFormattedBody,
                  if (editHtml) 'format': 'org.matrix.custom.html',
                },
                'm.relates_to': {
                  'event_id': '\$source2',
                  'rel_type': RelationshipTypes.edit,
                },
              },
            },
            'event_id': '\$source',
            'sender': '@alice:example.org',
          }, room);

          expect(
            event.calcUnlocalizedBody(
                hideReply: true, hideEdit: true, plaintextBody: plaintextBody),
            expectation,
            reason:
                'event was ${event.toJson()} and plaintextBody ${plaintextBody ? "was" : "was not"} set',
          );
        });
      }

      // everything where we expect the body to be returned
      testUnlocalizedBody(
        expectation: 'body',
        plaintextBody: false,
        body: 'body',
        formattedBody: '<b>formatted body</b>',
        html: false,
        isEdit: false,
        editBody: null,
        editFormattedBody: null,
        editHtml: false,
      );
      testUnlocalizedBody(
        // not sure we actually want m.room.message here and not an empty string
        expectation: 'm.room.message',
        plaintextBody: false,
        body: '',
        formattedBody: '<b>formatted body</b>',
        html: false,
        isEdit: false,
        editBody: null,
        editFormattedBody: null,
        editHtml: false,
      );
      testUnlocalizedBody(
        expectation: 'm.room.message',
        plaintextBody: false,
        body: null,
        formattedBody: '<b>formatted body</b>',
        html: false,
        isEdit: false,
        editBody: null,
        editFormattedBody: null,
        editHtml: false,
      );
      testUnlocalizedBody(
        expectation: 'm.room.message',
        plaintextBody: false,
        body: 5,
        formattedBody: '<b>formatted body</b>',
        html: false,
        isEdit: false,
        editBody: null,
        editFormattedBody: null,
        editHtml: false,
      );
      testUnlocalizedBody(
        expectation: 'body',
        plaintextBody: false,
        body: 'body',
        formattedBody: '<b>formatted body</b>',
        html: false,
        isEdit: true,
        editBody: null,
        editFormattedBody: null,
        editHtml: false,
      );
      testUnlocalizedBody(
        expectation: 'body',
        plaintextBody: false,
        body: 'body',
        formattedBody: null,
        html: true,
        isEdit: false,
        editBody: null,
        editFormattedBody: null,
        editHtml: false,
      );
      testUnlocalizedBody(
        expectation: 'body',
        plaintextBody: true,
        body: 'body',
        formattedBody: '<b>formatted body</b>',
        html: false,
        isEdit: false,
        editBody: null,
        editFormattedBody: null,
        editHtml: false,
      );
      testUnlocalizedBody(
        expectation: 'body',
        plaintextBody: true,
        body: 'body',
        formattedBody: null,
        html: true,
        isEdit: false,
        editBody: null,
        editFormattedBody: null,
        editHtml: false,
      );
      testUnlocalizedBody(
        expectation: 'body',
        plaintextBody: true,
        body: 'body',
        // do we actually expect this to then use the body?
        formattedBody: '',
        html: true,
        isEdit: false,
        editBody: null,
        editFormattedBody: null,
        editHtml: false,
      );
      testUnlocalizedBody(
        expectation: 'body',
        plaintextBody: true,
        body: 'body',
        formattedBody: 5,
        html: true,
        isEdit: false,
        editBody: null,
        editFormattedBody: null,
        editHtml: false,
      );
      testUnlocalizedBody(
        expectation: 'body',
        plaintextBody: false,
        body: 'body',
        formattedBody: '<b>formatted body</b>',
        html: true,
        isEdit: true,
        editBody: null,
        editFormattedBody: null,
        editHtml: false,
      );
      testUnlocalizedBody(
        expectation: 'body',
        plaintextBody: false,
        body: 'body',
        formattedBody: '<b>formatted body</b>',
        html: true,
        isEdit: true,
        editBody: null,
        editFormattedBody: null,
        editHtml: true,
      );
      testUnlocalizedBody(
        expectation: '**formatted body**',
        plaintextBody: true,
        body: 'body',
        formattedBody: '<b>formatted body</b>',
        html: true,
        isEdit: true,
        editBody: null,
        editFormattedBody: null,
        editHtml: false,
      );
      testUnlocalizedBody(
        expectation: '**formatted body**',
        plaintextBody: true,
        body: 'body',
        formattedBody: '<b>formatted body</b>',
        html: true,
        isEdit: true,
        editBody: null,
        editFormattedBody: null,
        editHtml: true,
      );

      // everything where we expect the formatted body to be returned
      testUnlocalizedBody(
        expectation: '**formatted body**',
        plaintextBody: true,
        body: 'body',
        formattedBody: '<b>formatted body</b>',
        html: true,
        isEdit: false,
        editBody: null,
        editFormattedBody: null,
        editHtml: false,
      );
      testUnlocalizedBody(
        expectation: '**formatted body**',
        plaintextBody: true,
        body: 5,
        formattedBody: '<b>formatted body</b>',
        html: true,
        isEdit: false,
        editBody: null,
        editFormattedBody: null,
        editHtml: false,
      );

      // everything where we expect the edit body to be returned
      testUnlocalizedBody(
        expectation: 'edit body',
        plaintextBody: false,
        body: 'body',
        formattedBody: '<b>formatted body</b>',
        html: false,
        isEdit: true,
        editBody: 'edit body',
        editFormattedBody: null,
        editHtml: false,
      );
      testUnlocalizedBody(
        expectation: 'edit body',
        plaintextBody: false,
        body: 'body',
        formattedBody: '<b>formatted body</b>',
        html: false,
        isEdit: true,
        editBody: 'edit body',
        editFormattedBody: '<b>edit formatted body</b>',
        editHtml: true,
      );
      testUnlocalizedBody(
        expectation: 'edit body',
        plaintextBody: false,
        body: 'body',
        formattedBody: '<b>formatted body</b>',
        html: true,
        isEdit: true,
        editBody: 'edit body',
        editFormattedBody: '<b>edit formatted body</b>',
        editHtml: true,
      );
      testUnlocalizedBody(
        expectation: 'edit body',
        plaintextBody: false,
        body: 'body',
        formattedBody: '<b>formatted body</b>',
        html: false,
        isEdit: true,
        editBody: 'edit body',
        editFormattedBody: '<b>edit formatted body</b>',
        editHtml: false,
      );
      testUnlocalizedBody(
        expectation: 'edit body',
        plaintextBody: false,
        body: 'body',
        formattedBody: '<b>formatted body</b>',
        html: false,
        isEdit: true,
        editBody: 'edit body',
        editFormattedBody: null,
        editHtml: true,
      );
      testUnlocalizedBody(
        expectation: 'edit body',
        plaintextBody: false,
        body: 'body',
        formattedBody: '<b>formatted body</b>',
        html: true,
        isEdit: true,
        editBody: 'edit body',
        editFormattedBody: 5,
        editHtml: true,
      );
      testUnlocalizedBody(
        expectation: 'edit body',
        plaintextBody: false,
        body: 'body',
        formattedBody: '<b>formatted body</b>',
        html: true,
        isEdit: true,
        editBody: 'edit body',
        editFormattedBody: null,
        editHtml: false,
      );
      testUnlocalizedBody(
        expectation: 'edit body',
        plaintextBody: false,
        body: 'body',
        formattedBody: '<b>formatted body</b>',
        html: true,
        isEdit: true,
        editBody: 'edit body',
        editFormattedBody: '<b>edit formatted body</b>',
        editHtml: false,
      );

      testUnlocalizedBody(
        expectation: 'edit body',
        plaintextBody: true,
        body: 'body',
        formattedBody: '<b>formatted body</b>',
        html: false,
        isEdit: true,
        editBody: 'edit body',
        editFormattedBody: null,
        editHtml: false,
      );
      testUnlocalizedBody(
        expectation: 'edit body',
        plaintextBody: true,
        body: 'body',
        formattedBody: '<b>formatted body</b>',
        html: false,
        isEdit: true,
        editBody: 'edit body',
        editFormattedBody: '<b>edit formatted body</b>',
        editHtml: false,
      );
      testUnlocalizedBody(
        expectation: 'edit body',
        plaintextBody: true,
        body: 'body',
        formattedBody: '<b>formatted body</b>',
        html: false,
        isEdit: true,
        editBody: 'edit body',
        editFormattedBody: null,
        editHtml: true,
      );
      testUnlocalizedBody(
        expectation: 'edit body',
        plaintextBody: true,
        body: 'body',
        formattedBody: '<b>formatted body</b>',
        html: true,
        isEdit: true,
        editBody: 'edit body',
        editFormattedBody: null,
        editHtml: false,
      );
      testUnlocalizedBody(
        expectation: 'edit body',
        plaintextBody: true,
        body: 'body',
        formattedBody: '<b>formatted body</b>',
        html: true,
        isEdit: true,
        editBody: 'edit body',
        editFormattedBody: '<b>edit formatted body</b>',
        editHtml: false,
      );
      testUnlocalizedBody(
        expectation: 'edit body',
        plaintextBody: true,
        body: 'body',
        formattedBody: '<b>formatted body</b>',
        html: true,
        isEdit: true,
        editBody: 'edit body',
        editFormattedBody: null,
        editHtml: true,
      );
      testUnlocalizedBody(
        expectation: 'edit body',
        plaintextBody: true,
        body: 'body',
        formattedBody: '<b>formatted body</b>',
        html: true,
        isEdit: true,
        editBody: 'edit body',
        editFormattedBody: null,
        editHtml: false,
      );

      // everything where we expect the edit formatted body to be returned
      testUnlocalizedBody(
        expectation: '**edit formatted body**',
        plaintextBody: true,
        body: 'body',
        formattedBody: '<b>formatted body</b>',
        html: true,
        isEdit: true,
        editBody: null,
        editFormattedBody: '<b>edit formatted body</b>',
        editHtml: true,
      );
      testUnlocalizedBody(
        expectation: '**edit formatted body**',
        plaintextBody: true,
        body: 'body',
        formattedBody: '<b>formatted body</b>',
        html: true,
        isEdit: true,
        editBody: 'edit body',
        editFormattedBody: '<b>edit formatted body</b>',
        editHtml: true,
      );
      testUnlocalizedBody(
        expectation: '**edit formatted body**',
        plaintextBody: true,
        body: null,
        formattedBody: '<b>formatted body</b>',
        html: true,
        isEdit: true,
        editBody: 'edit body',
        editFormattedBody: '<b>edit formatted body</b>',
        editHtml: true,
      );
      testUnlocalizedBody(
        expectation: '**edit formatted body**',
        plaintextBody: true,
        body: 'body',
        formattedBody: null,
        html: true,
        isEdit: true,
        editBody: 'edit body',
        editFormattedBody: '<b>edit formatted body</b>',
        editHtml: true,
      );
    });

    test('getDisplayEvent', () {
      final room = Room(id: '!1234', client: client);
      var event = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'body': 'blah',
          'msgtype': 'm.text',
        },
        'event_id': '\$source',
        'sender': '@alice:example.org',
      }, room);
      final edit1 = Event.fromJson({
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
            'rel_type': RelationshipTypes.edit,
          },
        },
        'event_id': '\$edit1',
        'sender': '@alice:example.org',
      }, room);
      final edit2 = Event.fromJson({
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
            'rel_type': RelationshipTypes.edit,
          },
        },
        'event_id': '\$edit2',
        'sender': '@alice:example.org',
      }, room);
      final edit3 = Event.fromJson({
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
            'rel_type': RelationshipTypes.edit,
          },
        },
        'event_id': '\$edit3',
        'sender': '@bob:example.org',
      }, room);
      // no edits
      var displayEvent = event.getDisplayEvent(
          Timeline(chunk: TimelineChunk(events: <Event>[event]), room: room));
      expect(displayEvent.body, 'blah');
      // one edit
      displayEvent = event.getDisplayEvent(Timeline(
          chunk: TimelineChunk(events: <Event>[event, edit1]), room: room));
      expect(displayEvent.body, 'edit 1');
      // two edits
      displayEvent = event.getDisplayEvent(Timeline(
          chunk: TimelineChunk(events: <Event>[event, edit1, edit2]),
          room: room));
      expect(displayEvent.body, 'edit 2');
      // foreign edit
      displayEvent = event.getDisplayEvent(Timeline(
          chunk: TimelineChunk(events: <Event>[event, edit3]), room: room));
      expect(displayEvent.body, 'blah');
      // mixed foreign and non-foreign
      displayEvent = event.getDisplayEvent(Timeline(
          chunk: TimelineChunk(events: <Event>[event, edit1, edit2, edit3]),
          room: room));
      expect(displayEvent.body, 'edit 2');
      event = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'body': 'blah',
          'msgtype': 'm.text',
        },
        'event_id': '\$source',
        'sender': '@alice:example.org',
        'unsigned': {
          'redacted_because': {
            'event_id': '\$redact',
            'sender': '@alice:example.org',
            'type': 'm.room.redaction',
          },
        },
      }, room);
      displayEvent = event.getDisplayEvent(Timeline(
          chunk: TimelineChunk(events: <Event>[event, edit1, edit2, edit3]),
          room: room));
      expect(displayEvent.body, 'Redacted');
    });
    test('attachments', () async {
      final FILE_BUFF = Uint8List.fromList([0]);
      final THUMBNAIL_BUFF = Uint8List.fromList([2]);
      Future<Uint8List> downloadCallback(Uri uri) async {
        return {
          '/_matrix/client/v1/media/download/example.org/file': FILE_BUFF,
          '/_matrix/client/v1/media/download/example.org/thumb': THUMBNAIL_BUFF,
        }[uri.path]!;
      }

      await client.checkHomeserver(Uri.parse('https://fakeserver.notexisting'),
          checkWellKnown: false);
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
      expect(event.attachmentOrThumbnailMxcUrl().toString(),
          'mxc://example.org/file');
      expect(event.attachmentOrThumbnailMxcUrl(getThumbnail: true).toString(),
          'mxc://example.org/file');

      event = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'body': 'image',
          'msgtype': 'm.image',
          'url': 'mxc://example.org/file',
          'info': {
            'size': 8000000,
            'thumbnail_url': 'mxc://example.org/thumb',
            'thumbnail_info': {
              'mimetype': 'thumbnail/mimetype',
            },
            'mimetype': 'application/octet-stream',
          },
        },
        'event_id': '\$edit2',
        'sender': '@alice:example.org',
      }, room);
      expect(event.hasAttachment, true);
      expect(event.hasThumbnail, true);
      expect(event.isAttachmentEncrypted, false);
      expect(event.isThumbnailEncrypted, false);
      expect(event.attachmentMimetype, 'application/octet-stream');
      expect(event.thumbnailMimetype, 'thumbnail/mimetype');
      expect(event.attachmentMxcUrl.toString(), 'mxc://example.org/file');
      expect(event.thumbnailMxcUrl.toString(), 'mxc://example.org/thumb');
      expect(event.attachmentOrThumbnailMxcUrl().toString(),
          'mxc://example.org/file');
      expect(event.attachmentOrThumbnailMxcUrl(getThumbnail: true).toString(),
          'mxc://example.org/thumb');
      expect((await event.getAttachmentUri()).toString(),
          'https://fakeserver.notexisting/_matrix/client/v1/media/download/example.org/file');
      expect((await event.getAttachmentUri(getThumbnail: true)).toString(),
          'https://fakeserver.notexisting/_matrix/client/v1/media/thumbnail/example.org/file?width=800&height=800&method=scale&animated=false');
      expect(
          (await event.getAttachmentUri(useThumbnailMxcUrl: true)).toString(),
          'https://fakeserver.notexisting/_matrix/client/v1/media/download/example.org/thumb');
      expect(
          (await event.getAttachmentUri(
                  getThumbnail: true, useThumbnailMxcUrl: true))
              .toString(),
          'https://fakeserver.notexisting/_matrix/client/v1/media/thumbnail/example.org/thumb?width=800&height=800&method=scale&animated=false');
      expect(
          (await event.getAttachmentUri(
                  getThumbnail: true, minNoThumbSize: 9000000))
              .toString(),
          'https://fakeserver.notexisting/_matrix/client/v1/media/download/example.org/file');

      buffer = await event.downloadAndDecryptAttachment(
          downloadCallback: downloadCallback);
      expect(buffer.bytes, FILE_BUFF);

      buffer = await event.downloadAndDecryptAttachment(
          getThumbnail: true, downloadCallback: downloadCallback);
      expect(buffer.bytes, THUMBNAIL_BUFF);
    });
    test(
      'encrypted attachments',
      tags: 'olm',
      () async {
        final FILE_BUFF_ENC =
            Uint8List.fromList([0x3B, 0x6B, 0xB2, 0x8C, 0xAF]);
        final FILE_BUFF_DEC =
            Uint8List.fromList([0x74, 0x65, 0x73, 0x74, 0x0A]);
        final THUMB_BUFF_ENC =
            Uint8List.fromList([0x55, 0xD7, 0xEB, 0x72, 0x05, 0x13]);
        final THUMB_BUFF_DEC =
            Uint8List.fromList([0x74, 0x68, 0x75, 0x6D, 0x62, 0x0A]);
        Future<Uint8List> downloadCallback(Uri uri) async {
          return {
            '/_matrix/client/v1/media/download/example.com/file': FILE_BUFF_ENC,
            '/_matrix/client/v1/media/download/example.com/thumb':
                THUMB_BUFF_ENC,
          }[uri.path]!;
        }

        final room =
            Room(id: '!localpart:server.abc', client: await getClient());
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
              'hashes': {
                'sha256': 'WgC7fw2alBC5t+xDx+PFlZxfFJXtIstQCg+j0WDaXxE'
              },
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
              'hashes': {
                'sha256': 'WgC7fw2alBC5t+xDx+PFlZxfFJXtIstQCg+j0WDaXxE'
              },
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
        expect(event.hasAttachment, true);
        expect(event.hasThumbnail, true);
        expect(event.isAttachmentEncrypted, true);
        expect(event.isThumbnailEncrypted, true);
        expect(event.attachmentMimetype, 'text/plain');
        expect(event.thumbnailMimetype, 'text/plain');
        expect(event.attachmentMxcUrl.toString(), 'mxc://example.com/file');
        expect(event.thumbnailMxcUrl.toString(), 'mxc://example.com/thumb');
        buffer = await event.downloadAndDecryptAttachment(
            downloadCallback: downloadCallback);
        expect(buffer.bytes, FILE_BUFF_DEC);

        buffer = await event.downloadAndDecryptAttachment(
            getThumbnail: true, downloadCallback: downloadCallback);
        expect(buffer.bytes, THUMB_BUFF_DEC);

        await room.client.dispose(closeDatabase: true);
      },
    );
    test('downloadAndDecryptAttachment store', tags: 'olm', () async {
      final FILE_BUFF = Uint8List.fromList([0]);
      var serverHits = 0;
      Future<Uint8List> downloadCallback(Uri uri) async {
        serverHits++;
        return {
          '/_matrix/client/v1/media/download/example.org/newfile': FILE_BUFF,
        }[uri.path]!;
      }

      await client.checkHomeserver(Uri.parse('https://fakeserver.notexisting'),
          checkWellKnown: false);
      final room = Room(id: '!localpart:server.abc', client: await getClient());
      final event = Event.fromJson({
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
      expect(await event.isAttachmentInLocalStore(), false);
      var buffer = await event.downloadAndDecryptAttachment(
          downloadCallback: downloadCallback);
      expect(await event.isAttachmentInLocalStore(),
          event.room.client.database?.supportsFileStoring);
      expect(buffer.bytes, FILE_BUFF);
      expect(serverHits, 1);
      buffer = await event.downloadAndDecryptAttachment(
          downloadCallback: downloadCallback);
      expect(buffer.bytes, FILE_BUFF);
      expect(
          serverHits, event.room.client.database!.supportsFileStoring ? 1 : 2);

      await room.client.dispose(closeDatabase: true);
    });

    test('downloadAndDecryptAttachment store only', tags: 'olm', () async {
      final FILE_BUFF = Uint8List.fromList([0]);
      var serverHits = 0;
      Future<Uint8List> downloadCallback(Uri uri) async {
        serverHits++;
        return {
          '/_matrix/client/v1/media/download/example.org/newfile': FILE_BUFF,
        }[uri.path]!;
      }

      await client.checkHomeserver(Uri.parse('https://fakeserver.notexisting'),
          checkWellKnown: false);
      final room = Room(id: '!localpart:server.abc', client: await getClient());
      final event = Event.fromJson({
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
      expect(await event.isAttachmentInLocalStore(),
          event.room.client.database?.supportsFileStoring);
      expect(buffer.bytes, FILE_BUFF);
      expect(serverHits, 1);

      if (event.room.client.database?.supportsFileStoring == true) {
        buffer = await event.downloadAndDecryptAttachment(
            downloadCallback: downloadCallback, fromLocalStoreOnly: true);
        expect(buffer.bytes, FILE_BUFF);
      } else {
        expect(
            () async => await event.downloadAndDecryptAttachment(
                downloadCallback: downloadCallback, fromLocalStoreOnly: true),
            throwsA(anything));
      }
      expect(serverHits, 1);

      await room.client.dispose(closeDatabase: true);
    });

    test('downloadAndDecryptAttachment store only without file', tags: 'olm',
        () async {
      final FILE_BUFF = Uint8List.fromList([0]);
      var serverHits = 0;
      Future<Uint8List> downloadCallback(Uri uri) async {
        serverHits++;
        return {
          '/_matrix/client/v1/media/download/example.org/newfile': FILE_BUFF,
        }[uri.path]!;
      }

      await client.checkHomeserver(Uri.parse('https://fakeserver.notexisting'),
          checkWellKnown: false);
      final room = Room(id: '!localpart:server.abc', client: await getClient());
      final event = Event.fromJson({
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

      expect(
          () async => await event.downloadAndDecryptAttachment(
              downloadCallback: downloadCallback, fromLocalStoreOnly: true),
          throwsA(anything));

      expect(serverHits, 0);

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
      }, room);
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
      }, room);
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
      }, room);
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
      }, room);
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
      }, room);
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
      }, room);
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
      }, room);
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
      }, room);
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
      }, room);
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
      }, room);
      expect(event.onlyEmotes, true);
      expect(event.numberEmotes, 1);
      event = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'msgtype': 'm.text',
          'body': '''> <@alice:example.org> 😒😒

          ❤❤❤''',
          'format': 'org.matrix.custom.html',
          'formatted_body':
              '<mx-reply><blockquote><a href="https://fakeserver.notexisting/\$jEsUZKDJdhlrceRyVU">In reply to</a> <a href="https://fakeserver.notexisting/@alice:example.org">@alice:example.org</a><br>😒😒</blockquote></mx-reply>❤❤❤'
        },
        'event_id': '\$edit2',
        'sender': '@alice:example.org',
      }, room);
      expect(event.onlyEmotes, true);
      expect(event.numberEmotes, 3);
      event = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'msgtype': 'm.text',
          'body': '''> <@alice:example.org> A 😒

          ❤❤''',
          'format': 'org.matrix.custom.html',
          'formatted_body':
              '<mx-reply><blockquote><a href="https://fakeserver.notexisting/\$jEsUZKDJdhlrceRyVU">In reply to</a> <a href="https://fakeserver.notexisting/@alice:example.org">@alice:example.org</a><br>A 😒</blockquote></mx-reply>❤❤'
        },
        'event_id': '\$edit2',
        'sender': '@alice:example.org',
      }, room);
      expect(event.onlyEmotes, true);
      expect(event.numberEmotes, 2);
      event = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'msgtype': 'm.text',
          'body': '''> <@alice:example.org> 😒😒😒

          ❤A❤''',
          'format': 'org.matrix.custom.html',
          'formatted_body':
              '<mx-reply><blockquote><a href="https://fakeserver.notexisting/\$jEsUZKDJdhlrceRyVU">In reply to</a> <a href="https://fakeserver.notexisting/@alice:example.org">@alice:example.org</a><br>😒😒😒</blockquote></mx-reply>❤A❤'
        },
        'event_id': '\$edit2',
        'sender': '@alice:example.org',
      }, room);
      expect(event.onlyEmotes, false);
      expect(event.numberEmotes, 2);
      event = Event.fromJson({
        'type': EventTypes.Message,
        'content': {
          'msgtype': 'm.text',
          'body': '''> <@alice:example.org> A😒

          ❤A❤''',
          'format': 'org.matrix.custom.html',
          'formatted_body':
              '<mx-reply><blockquote><a href="https://fakeserver.notexisting/\$jEsUZKDJdhlrceRyVU">In reply to</a> <a href="https://fakeserver.notexisting/@alice:example.org">@alice:example.org</a><br>A😒</blockquote></mx-reply>❤A❤'
        },
        'event_id': '\$edit2',
        'sender': '@alice:example.org',
      }, room);
      expect(event.onlyEmotes, false);
      expect(event.numberEmotes, 2);
    });
  });
}
