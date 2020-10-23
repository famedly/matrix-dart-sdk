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

import 'package:famedlysdk/matrix_api.dart';
import 'package:famedlysdk/src/client.dart';
import 'package:famedlysdk/src/event.dart';
import 'package:famedlysdk/src/room.dart';
import 'package:famedlysdk/src/user.dart';
import 'package:famedlysdk/src/utils/matrix_file.dart';
import 'package:famedlysdk/src/database/database.dart'
    show DbRoom, DbRoomState, DbRoomAccountData;
import 'package:test/test.dart';

import 'fake_client.dart';
import 'fake_matrix_api.dart';

import 'dart:convert';
import 'dart:typed_data';

void main() {
  Client matrix;
  Room room;

  /// All Tests related to the Event
  group('Room', () {
    test('Login', () async {
      matrix = await getClient();
    });

    test('Create from json', () async {
      final id = '!localpart:server.abc';
      final membership = Membership.join;
      final notificationCount = 2;
      final highlightCount = 1;
      final heroes = [
        '@alice:matrix.org',
        '@bob:example.com',
        '@charley:example.org'
      ];

      var dbRoom = DbRoom(
        clientId: 1,
        roomId: id,
        membership: membership.toString().split('.').last,
        highlightCount: highlightCount,
        notificationCount: notificationCount,
        prevBatch: '',
        joinedMemberCount: notificationCount,
        invitedMemberCount: notificationCount,
        newestSortOrder: 0.0,
        oldestSortOrder: 0.0,
        heroes: heroes.join(','),
      );

      var states = [
        DbRoomState(
          clientId: 1,
          eventId: '143273582443PhrSn:example.org',
          roomId: id,
          sortOrder: 0.0,
          originServerTs: 1432735824653,
          sender: '@example:example.org',
          type: 'm.room.join_rules',
          unsigned: '{"age": 1234}',
          content: '{"join_rule": "public"}',
          prevContent: '',
          stateKey: '',
        ),
      ];

      var roomAccountData = [
        DbRoomAccountData(
          clientId: 1,
          type: 'com.test.foo',
          roomId: id,
          content: '{"foo": "bar"}',
        ),
      ];

      room = await Room.getRoomFromTableRow(
        dbRoom,
        matrix,
        states: states,
        roomAccountData: roomAccountData,
      );

      expect(room.id, id);
      expect(room.membership, membership);
      expect(room.notificationCount, notificationCount);
      expect(room.highlightCount, highlightCount);
      expect(room.mJoinedMemberCount, notificationCount);
      expect(room.mInvitedMemberCount, notificationCount);
      expect(room.mHeroes, heroes);
      expect(room.displayname, 'Alice, Bob, Charley');
      expect(room.getState('m.room.join_rules').content['join_rule'], 'public');
      expect(room.roomAccountData['com.test.foo'].content['foo'], 'bar');

      room.states['m.room.canonical_alias'] = Event(
          senderId: '@test:example.com',
          type: 'm.room.canonical_alias',
          roomId: room.id,
          room: room,
          eventId: '123',
          content: {'alias': '#testalias:example.com'},
          stateKey: '');
      expect(room.displayname, 'testalias');
      expect(room.canonicalAlias, '#testalias:example.com');

      room.states['m.room.name'] = Event(
          senderId: '@test:example.com',
          type: 'm.room.name',
          roomId: room.id,
          room: room,
          eventId: '123',
          content: {'name': 'testname'},
          stateKey: '');
      expect(room.displayname, 'testname');

      expect(room.topic, '');
      room.states['m.room.topic'] = Event(
          senderId: '@test:example.com',
          type: 'm.room.topic',
          roomId: room.id,
          room: room,
          eventId: '123',
          content: {'topic': 'testtopic'},
          stateKey: '');
      expect(room.topic, 'testtopic');

      expect(room.avatar, null);
      room.states['m.room.avatar'] = Event(
          senderId: '@test:example.com',
          type: 'm.room.avatar',
          roomId: room.id,
          room: room,
          eventId: '123',
          content: {'url': 'mxc://testurl'},
          stateKey: '');
      expect(room.avatar.toString(), 'mxc://testurl');

      expect(room.pinnedEventIds, <String>[]);
      room.states['m.room.pinned_events'] = Event(
          senderId: '@test:example.com',
          type: 'm.room.pinned_events',
          roomId: room.id,
          room: room,
          eventId: '123',
          content: {
            'pinned': ['1234']
          },
          stateKey: '');
      expect(room.pinnedEventIds.first, '1234');
      room.states['m.room.message'] = Event(
          senderId: '@test:example.com',
          type: 'm.room.message',
          roomId: room.id,
          room: room,
          eventId: '12345',
          originServerTs: DateTime.now(),
          content: {'msgtype': 'm.text', 'body': 'test'},
          stateKey: '');
      expect(room.lastEvent.eventId, '12345');
      expect(room.lastMessage, 'test');
      expect(room.timeCreated, room.lastEvent.originServerTs);
    });

    test('multiple last event with same sort order', () {
      room.states['m.room.encrypted'] = Event(
          senderId: '@test:example.com',
          type: 'm.room.encrypted',
          roomId: room.id,
          room: room,
          eventId: '12345',
          originServerTs: DateTime.now(),
          content: {'msgtype': 'm.text', 'body': 'test'},
          stateKey: '',
          sortOrder: 42.0);
      expect(room.lastEvent.type, 'm.room.encrypted');
      room.states['m.room.messge'] = Event(
          senderId: '@test:example.com',
          type: 'm.room.messge',
          roomId: room.id,
          room: room,
          eventId: '12345',
          originServerTs: DateTime.now(),
          content: {'msgtype': 'm.text', 'body': 'test'},
          stateKey: '',
          sortOrder: 42.0);
      expect(room.lastEvent.type, 'm.room.encrypted');
    });

    test('sendReadReceipt', () async {
      await room.sendReadReceipt('§1234:fakeServer.notExisting');
    });

    test('requestParticipants', () async {
      final participants = await room.requestParticipants();
      expect(participants.length, 1);
      var user = participants[0];
      expect(user.id, '@alice:example.org');
      expect(user.displayName, 'Alice Margatroid');
      expect(user.membership, Membership.join);
      expect(user.avatarUrl.toString(), 'mxc://example.org/SEsfnsuifSDFSSEF');
      expect(user.room.id, '!localpart:server.abc');
    });

    test('getEventByID', () async {
      final event = await room.getEventById('1234');
      expect(event.eventId, '143273582443PhrSn:example.org');
    });

    test('setName', () async {
      final eventId = await room.setName('Testname');
      expect(eventId, '42');
    });

    test('setDescription', () async {
      final eventId = await room.setDescription('Testname');
      expect(eventId, '42');
    });

    test('kick', () async {
      await room.kick('Testname');
    });

    test('ban', () async {
      await room.ban('Testname');
    });

    test('unban', () async {
      await room.unban('Testname');
    });

    test('PowerLevels', () async {
      room.states['m.room.power_levels'] = Event(
          senderId: '@test:example.com',
          type: 'm.room.power_levels',
          roomId: room.id,
          room: room,
          eventId: '123',
          content: {
            'ban': 50,
            'events': {'m.room.name': 100, 'm.room.power_levels': 100},
            'events_default': 0,
            'invite': 50,
            'kick': 50,
            'notifications': {'room': 20},
            'redact': 50,
            'state_default': 50,
            'users': {'@test:fakeServer.notExisting': 100},
            'users_default': 10
          },
          stateKey: '');
      expect(room.ownPowerLevel, 100);
      expect(room.getPowerLevelByUserId(matrix.userID), room.ownPowerLevel);
      expect(room.getPowerLevelByUserId('@nouser:example.com'), 10);
      expect(room.ownPowerLevel, 100);
      expect(room.canBan, true);
      expect(room.canInvite, true);
      expect(room.canKick, true);
      expect(room.canRedact, true);
      expect(room.canSendDefaultMessages, true);
      expect(room.canSendDefaultStates, true);
      expect(room.canChangePowerLevel, true);
      expect(room.canSendEvent('m.room.name'), true);
      expect(room.canSendEvent('m.room.power_levels'), true);
      expect(room.canSendEvent('m.room.member'), true);
      expect(room.powerLevels,
          room.states['m.room.power_levels'].content['users']);

      room.states['m.room.power_levels'] = Event(
          senderId: '@test:example.com',
          type: 'm.room.power_levels',
          roomId: room.id,
          room: room,
          eventId: '123abc',
          content: {
            'ban': 50,
            'events': {'m.room.name': 0, 'm.room.power_levels': 100},
            'events_default': 0,
            'invite': 50,
            'kick': 50,
            'notifications': {'room': 20},
            'redact': 50,
            'state_default': 50,
            'users': {},
            'users_default': 0
          },
          stateKey: '');
      expect(room.ownPowerLevel, 0);
      expect(room.canBan, false);
      expect(room.canInvite, false);
      expect(room.canKick, false);
      expect(room.canRedact, false);
      expect(room.canSendDefaultMessages, true);
      expect(room.canSendDefaultStates, false);
      expect(room.canChangePowerLevel, false);
      expect(room.canSendEvent('m.room.name'), true);
      expect(room.canSendEvent('m.room.power_levels'), false);
      expect(room.canSendEvent('m.room.member'), false);
      expect(room.canSendEvent('m.room.message'), true);
      final resp = await room.setPower('@test:fakeServer.notExisting', 90);
      expect(resp, '42');
    });

    test('invite', () async {
      await room.invite('Testname');
    });

    test('getParticipants', () async {
      var userList = room.getParticipants();
      expect(userList.length, 4);
      // add new user
      room.setState(Event(
          senderId: '@alice:test.abc',
          type: 'm.room.member',
          roomId: room.id,
          room: room,
          eventId: '12345',
          originServerTs: DateTime.now(),
          content: {'displayname': 'alice'},
          stateKey: '@alice:test.abc'));
      userList = room.getParticipants();
      expect(userList.length, 5);
      expect(userList[4].displayName, 'alice');
    });

    test('addToDirectChat', () async {
      await room.addToDirectChat('Testname');
    });

    test('getTimeline', () async {
      final timeline = await room.getTimeline();
      expect(timeline.events.length, 0);
    });

    test('getUserByMXID', () async {
      User user;
      try {
        user = await room.getUserByMXID('@getme:example.com');
      } catch (_) {}
      expect(user.stateKey, '@getme:example.com');
      expect(user.calcDisplayname(), 'Getme');
    });

    test('setAvatar', () async {
      final testFile = MatrixFile(bytes: Uint8List(0), name: 'file.jpeg');
      final dynamic resp = await room.setAvatar(testFile);
      expect(resp, 'YUwRidLecu:example.com');
    });

    test('sendEvent', () async {
      final dynamic resp = await room.sendEvent(
          {'msgtype': 'm.text', 'body': 'hello world'},
          txid: 'testtxid');
      expect(resp.startsWith('\$event'), true);
    });

    test('sendEvent', () async {
      FakeMatrixApi.calledEndpoints.clear();
      final dynamic resp =
          await room.sendTextEvent('Hello world', txid: 'testtxid');
      expect(resp.startsWith('\$event'), true);
      final entry = FakeMatrixApi.calledEndpoints.entries
          .firstWhere((p) => p.key.contains('/send/m.room.message/'));
      final content = json.decode(entry.value.first);
      expect(content, {
        'body': 'Hello world',
        'msgtype': 'm.text',
      });
    });

    test('send edit', () async {
      FakeMatrixApi.calledEndpoints.clear();
      final dynamic resp = await room.sendTextEvent('Hello world',
          txid: 'testtxid', editEventId: '\$otherEvent');
      expect(resp.startsWith('\$event'), true);
      final entry = FakeMatrixApi.calledEndpoints.entries
          .firstWhere((p) => p.key.contains('/send/m.room.message/'));
      final content = json.decode(entry.value.first);
      expect(content, {
        'body': '* Hello world',
        'msgtype': 'm.text',
        'm.new_content': {
          'body': 'Hello world',
          'msgtype': 'm.text',
        },
        'm.relates_to': {
          'event_id': '\$otherEvent',
          'rel_type': 'm.replace',
        },
      });
    });

    test('send reply', () async {
      var event = Event.fromJson({
        'event_id': '\$replyEvent',
        'content': {
          'body': 'Blah',
          'msgtype': 'm.text',
        },
        'type': 'm.room.message',
        'sender': '@alice:example.org',
      }, room);
      FakeMatrixApi.calledEndpoints.clear();
      final dynamic resp = await room.sendTextEvent('Hello world',
          txid: 'testtxid', inReplyTo: event);
      expect(resp.startsWith('\$event'), true);
      final entry = FakeMatrixApi.calledEndpoints.entries
          .firstWhere((p) => p.key.contains('/send/m.room.message/'));
      final content = json.decode(entry.value.first);
      expect(content, {
        'body': '> <@alice:example.org> Blah\n\nHello world',
        'msgtype': 'm.text',
        'format': 'org.matrix.custom.html',
        'formatted_body':
            '<mx-reply><blockquote><a href="https://matrix.to/#/!localpart:server.abc/\$replyEvent">In reply to</a> <a href="https://matrix.to/#/@alice:example.org">@alice:example.org</a><br>Blah</blockquote></mx-reply>Hello world',
        'm.relates_to': {
          'm.in_reply_to': {
            'event_id': '\$replyEvent',
          },
        },
      });
    });

    test('send reaction', () async {
      FakeMatrixApi.calledEndpoints.clear();
      final dynamic resp =
          await room.sendReaction('\$otherEvent', '🦊', txid: 'testtxid');
      expect(resp.startsWith('\$event'), true);
      final entry = FakeMatrixApi.calledEndpoints.entries
          .firstWhere((p) => p.key.contains('/send/m.reaction/'));
      final content = json.decode(entry.value.first);
      expect(content, {
        'm.relates_to': {
          'event_id': '\$otherEvent',
          'rel_type': 'm.annotation',
          'key': '🦊',
        },
      });
    });

    test('send location', () async {
      FakeMatrixApi.calledEndpoints.clear();

      final body = 'Middle of the ocean';
      final geoUri = 'geo:0.0,0.0';
      final dynamic resp =
          await room.sendLocation(body, geoUri, txid: 'testtxid');
      expect(resp.startsWith('\$event'), true);

      final entry = FakeMatrixApi.calledEndpoints.entries
          .firstWhere((p) => p.key.contains('/send/m.room.message/'));
      final content = json.decode(entry.value.first);
      expect(content, {
        'msgtype': 'm.location',
        'body': body,
        'geo_uri': geoUri,
      });
    });

    // Not working because there is no real file to test it...
    /*test('sendImageEvent', () async {
      final File testFile = File.fromUri(Uri.parse("fake/path/file.jpeg"));
      final dynamic resp =
          await room.sendImageEvent(testFile, txid: "testtxid");
      expect(resp, "42");
    });*/

    test('sendFileEvent', () async {
      final testFile = MatrixFile(bytes: Uint8List(0), name: 'file.jpeg');
      final dynamic resp = await room.sendFileEvent(testFile, txid: 'testtxid');
      expect(resp, 'mxc://example.com/AQwafuaFswefuhsfAFAgsw');
    });

    test('pushRuleState', () async {
      expect(room.pushRuleState, PushRuleState.mentions_only);
      matrix.accountData['m.push_rules'].content['global']['override']
          .add(matrix.accountData['m.push_rules'].content['global']['room'][0]);
      expect(room.pushRuleState, PushRuleState.dont_notify);
    });

    test('Test call methods', () async {
      await room.inviteToCall('1234', 1234, 'sdp', txid: '1234');
      await room.answerCall('1234', 'sdp', txid: '1234');
      await room.hangupCall('1234', txid: '1234');
      await room.sendCallCandidates('1234', [], txid: '1234');
    });

    test('enableEncryption', () async {
      await room.enableEncryption();
    });

    test('Enable encryption', () async {
      room.setState(
        Event(
            senderId: '@alice:test.abc',
            type: 'm.room.encryption',
            roomId: room.id,
            room: room,
            eventId: '12345',
            originServerTs: DateTime.now(),
            content: {
              'algorithm': 'm.megolm.v1.aes-sha2',
              'rotation_period_ms': 604800000,
              'rotation_period_msgs': 100
            },
            stateKey: ''),
      );
      expect(room.encrypted, true);
      expect(room.encryptionAlgorithm, 'm.megolm.v1.aes-sha2');
    });

    test('setPushRuleState', () async {
      await room.setPushRuleState(PushRuleState.notify);
      await room.setPushRuleState(PushRuleState.dont_notify);
      await room.setPushRuleState(PushRuleState.mentions_only);
      await room.setPushRuleState(PushRuleState.notify);
    });

    test('Test tag methods', () async {
      await room.addTag(TagType.Favourite, order: 0.1);
      await room.removeTag(TagType.Favourite);
      expect(room.isFavourite, false);
      room.roomAccountData['m.tag'] = BasicRoomEvent.fromJson({
        'content': {
          'tags': {
            'm.favourite': {'order': 0.1},
            'm.wrong': {'order': 0.2},
          }
        },
        'type': 'm.tag'
      });
      expect(room.tags.length, 1);
      expect(room.tags[TagType.Favourite].order, 0.1);
      expect(room.isFavourite, true);
      await room.setFavourite(false);
    });

    test('joinRules', () async {
      expect(room.canChangeJoinRules, false);
      expect(room.joinRules, JoinRules.public);
      room.setState(Event.fromJson({
        'content': {'join_rule': 'invite'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '',
        'type': 'm.room.join_rules',
        'unsigned': {'age': 1234}
      }, room));
      expect(room.joinRules, JoinRules.invite);
      await room.setJoinRules(JoinRules.invite);
    });

    test('guestAccess', () async {
      expect(room.canChangeGuestAccess, false);
      expect(room.guestAccess, GuestAccess.forbidden);
      room.setState(Event.fromJson({
        'content': {'guest_access': 'can_join'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '',
        'type': 'm.room.guest_access',
        'unsigned': {'age': 1234}
      }, room));
      expect(room.guestAccess, GuestAccess.can_join);
      await room.setGuestAccess(GuestAccess.can_join);
    });

    test('historyVisibility', () async {
      expect(room.canChangeHistoryVisibility, false);
      expect(room.historyVisibility, null);
      room.setState(Event.fromJson({
        'content': {'history_visibility': 'shared'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '',
        'type': 'm.room.history_visibility',
        'unsigned': {'age': 1234}
      }, room));
      expect(room.historyVisibility, HistoryVisibility.shared);
      await room.setHistoryVisibility(HistoryVisibility.joined);
    });

    test('setState', () async {
      // not set non-state-events
      room.setState(Event.fromJson({
        'content': {'history_visibility': 'shared'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.custom',
        'unsigned': {'age': 1234}
      }, room));
      expect(room.getState('m.custom') != null, false);

      // set state events
      room.setState(Event.fromJson({
        'content': {'history_visibility': 'shared'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'state_key': '',
        'type': 'm.custom',
        'unsigned': {'age': 1234}
      }, room));
      expect(room.getState('m.custom') != null, true);

      // sets messages as state events
      room.setState(Event.fromJson({
        'content': {'history_visibility': 'shared'},
        'event_id': '\$143273582443PhrSn:example.org',
        'origin_server_ts': 1432735824653,
        'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
        'sender': '@example:example.org',
        'type': 'm.room.message',
        'unsigned': {'age': 1234}
      }, room));
      expect(room.getState('m.room.message') != null, true);
    });

    test('logout', () async {
      await matrix.logout();
    });
  });
}
