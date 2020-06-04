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

import 'fake_matrix_api.dart';

import 'dart:typed_data';

void main() {
  Client matrix;
  Room room;

  /// All Tests related to the Event
  group('Room', () {
    test('Login', () async {
      matrix = Client('testclient', debug: true, httpClient: FakeMatrixApi());

      final checkResp =
          await matrix.checkServer('https://fakeServer.notExisting');

      final loginResp = await matrix.login('test', '1234');

      expect(checkResp, true);
      expect(loginResp, true);
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
          originServerTs: DateTime.fromMillisecondsSinceEpoch(1432735824653),
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

    test('sendReadReceipt', () async {
      await room.sendReadReceipt('§1234:fakeServer.notExisting');
    });

    test('enableEncryption', () async {
      await room.enableEncryption();
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
      room.setState(Event(
          senderId: '@alice:test.abc',
          type: 'm.room.member',
          roomId: room.id,
          room: room,
          eventId: '12345',
          originServerTs: DateTime.now(),
          content: {'displayname': 'alice'},
          stateKey: '@alice:test.abc'));
      final userList = room.getParticipants();
      expect(userList.length, 4);
      expect(userList[3].displayName, 'alice');
    });

    test('addToDirectChat', () async {
      await room.addToDirectChat('Testname');
    });

    test('getTimeline', () async {
      final timeline = await room.getTimeline();
      expect(timeline.events.length, 1);
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
      final testFile =
          MatrixFile(bytes: Uint8List(0), path: 'fake/path/file.jpeg');
      final dynamic resp = await room.setAvatar(testFile);
      expect(resp, 'YUwRidLecu:example.com');
    });

    test('sendEvent', () async {
      final dynamic resp = await room.sendEvent(
          {'msgtype': 'm.text', 'body': 'hello world'},
          txid: 'testtxid');
      expect(resp, '42');
    });

    test('sendEvent', () async {
      final dynamic resp =
          await room.sendTextEvent('Hello world', txid: 'testtxid');
      expect(resp, '42');
    });

    // Not working because there is no real file to test it...
    /*test('sendImageEvent', () async {
      final File testFile = File.fromUri(Uri.parse("fake/path/file.jpeg"));
      final dynamic resp =
          await room.sendImageEvent(testFile, txid: "testtxid");
      expect(resp, "42");
    });*/

    test('sendFileEvent', () async {
      final testFile =
          MatrixFile(bytes: Uint8List(0), path: 'fake/path/file.jpeg');
      final dynamic resp = await room.sendFileEvent(testFile,
          msgType: 'm.file', txid: 'testtxid');
      expect(resp, 'mxc://example.com/AQwafuaFswefuhsfAFAgsw');
    });

    test('pushRuleState', () async {
      expect(room.pushRuleState, PushRuleState.mentions_only);
      matrix.accountData['m.push_rules'].content['global']['override']
          .add(matrix.accountData['m.push_rules'].content['global']['room'][0]);
      expect(room.pushRuleState, PushRuleState.dont_notify);
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

    test('Test call methods', () async {
      await room.inviteToCall('1234', 1234, 'sdp', txid: '1234');
      await room.answerCall('1234', 'sdp', txid: '1234');
      await room.hangupCall('1234', txid: '1234');
      await room.sendCallCandidates('1234', [], txid: '1234');
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

    test('logout', () async {
      await matrix.logout();
    });
  });
}
