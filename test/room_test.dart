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

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:matrix/matrix.dart';
import 'fake_client.dart';

Future<void> updateLastEvent(Event event) {
  if (event.room.client.getRoomById(event.room.id) == null) {
    event.room.client.rooms.add(event.room);
  }
  return event.room.client.handleSync(
    SyncUpdate(
      rooms: RoomsUpdate(
        join: {
          event.room.id: JoinedRoomUpdate(
            timeline: TimelineUpdate(
              events: [event],
            ),
          ),
        },
      ),
      nextBatch: '',
    ),
  );
}

void main() {
  late Client matrix;
  late Room room;

  /// All Tests related to the Event
  group('Room', () {
    Logs().level = Level.error;
    test('Login', () async {
      matrix = await getClient();
      await matrix.abortSync();
    });

    test('Create from json', () async {
      final id = '!localpart:server.abc';
      final membership = Membership.join;
      final notificationCount = 2;
      final highlightCount = 1;
      final heroes = [
        '@alice:matrix.org',
        '@bob:example.com',
        '@charley:example.org',
      ];

      room = Room(
        client: matrix,
        id: id,
        membership: membership,
        highlightCount: highlightCount,
        notificationCount: notificationCount,
        prev_batch: '',
        summary: RoomSummary.fromJson({
          'm.joined_member_count': 2,
          'm.invited_member_count': 2,
          'm.heroes': heroes,
        }),
        roomAccountData: {
          'com.test.foo': BasicRoomEvent(
            type: 'com.test.foo',
            content: {'foo': 'bar'},
          ),
          'm.fully_read': BasicRoomEvent(
            type: 'm.fully_read',
            content: {'event_id': '\$event_id:example.com'},
          ),
        },
      );

      room.setState(
        Event(
          room: room,
          eventId: '143273582443PhrSn:example.org',
          originServerTs: DateTime.fromMillisecondsSinceEpoch(1432735824653),
          senderId: '@example:example.org',
          type: 'm.room.join_rules',
          unsigned: {'age': 1234},
          content: {'join_rule': 'public'},
          stateKey: '',
        ),
      );
      room.setState(
        Event(
          room: room,
          eventId: '143273582443PhrSnY:example.org',
          originServerTs: DateTime.fromMillisecondsSinceEpoch(1432735824653),
          senderId: matrix.userID!,
          type: 'm.room.member',
          unsigned: {'age': 1234},
          content: {'membership': 'join', 'displayname': 'YOU'},
          stateKey: matrix.userID!,
        ),
      );
      room.setState(
        Event(
          room: room,
          eventId: '143273582443PhrSnA:example.org',
          originServerTs: DateTime.fromMillisecondsSinceEpoch(1432735824653),
          senderId: '@alice:matrix.org',
          type: 'm.room.member',
          unsigned: {'age': 1234},
          content: {'membership': 'join', 'displayname': 'Alice Margatroid'},
          stateKey: '@alice:matrix.org',
        ),
      );
      room.setState(
        Event(
          room: room,
          eventId: '143273582443PhrSnB:example.org',
          originServerTs: DateTime.fromMillisecondsSinceEpoch(1432735824653),
          senderId: '@bob:example.com',
          type: 'm.room.member',
          unsigned: {'age': 1234},
          content: {'membership': 'invite', 'displayname': 'Bob'},
          stateKey: '@bob:example.com',
        ),
      );
      room.setState(
        Event(
          room: room,
          eventId: '143273582443PhrSnC:example.org',
          originServerTs: DateTime.fromMillisecondsSinceEpoch(1432735824653),
          senderId: '@charley:example.org',
          type: 'm.room.member',
          unsigned: {'age': 1234},
          content: {'membership': 'invite', 'displayname': 'Charley'},
          stateKey: '@charley:example.org',
        ),
      );

      final heroUsers = await room.loadHeroUsers();
      expect(heroUsers.length, 3);

      expect(room.id, id);
      expect(room.membership, membership);
      expect(room.notificationCount, notificationCount);
      expect(room.highlightCount, highlightCount);
      expect(room.summary.mJoinedMemberCount, notificationCount);
      expect(room.summary.mInvitedMemberCount, 2);
      expect(room.summary.mHeroes, heroes);
      expect(
        room.getLocalizedDisplayname(),
        'Group with Alice Margatroid, Bob, Charley',
      );
      expect(
        room.getState('m.room.join_rules')?.content['join_rule'],
        'public',
      );
      expect(room.roomAccountData['com.test.foo']?.content['foo'], 'bar');
      expect(room.fullyRead, '\$event_id:example.com');

      room.setState(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.canonical_alias',
          room: room,
          eventId: '123',
          content: {'alias': '#testalias:example.com'},
          originServerTs: DateTime.now(),
          stateKey: '',
        ),
      );
      expect(room.getLocalizedDisplayname(), 'testalias');
      expect(room.canonicalAlias, '#testalias:example.com');

      room.setState(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.name',
          room: room,
          eventId: '123',
          content: {'name': 'testname'},
          originServerTs: DateTime.now(),
          stateKey: '',
        ),
      );
      expect(room.getLocalizedDisplayname(), 'testname');

      expect(room.topic, '');
      room.setState(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.topic',
          room: room,
          eventId: '123',
          content: {'topic': 'testtopic'},
          originServerTs: DateTime.now(),
          stateKey: '',
        ),
      );
      expect(room.topic, 'testtopic');

      expect(room.avatar, null);
      room.setState(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.avatar',
          room: room,
          eventId: '123',
          content: {'url': 'mxc://testurl'},
          originServerTs: DateTime.now(),
          stateKey: '',
        ),
      );
      expect(room.avatar.toString(), 'mxc://testurl');

      expect(room.pinnedEventIds, <String>[]);
      room.setState(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.pinned_events',
          room: room,
          eventId: '123',
          content: {
            'pinned': ['1234'],
          },
          originServerTs: DateTime.now(),
          stateKey: '',
        ),
      );
      expect(room.pinnedEventIds.first, '1234');
      await updateLastEvent(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.message',
          room: room,
          eventId: '12345',
          originServerTs: DateTime.now(),
          content: {'msgtype': 'm.text', 'body': 'abc'},
        ),
      );
      expect(room.lastEvent?.eventId, '12345');
      expect(room.lastEvent?.body, 'abc');
      expect(room.timeCreated, room.lastEvent?.originServerTs);
    });

    test('lastEvent is set properly', () async {
      await updateLastEvent(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.message',
          room: room,
          eventId: '0',
          originServerTs: DateTime.now(),
          content: {'msgtype': 'm.text', 'body': 'meow'},
        ),
      );
      expect(room.lastEvent?.body, 'meow');
      await updateLastEvent(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.encrypted',
          room: room,
          eventId: '1',
          originServerTs: DateTime.now(),
          content: {'msgtype': 'm.text', 'body': 'cd'},
        ),
      );
      expect(room.hasNewMessages, true);
      expect(room.isUnreadOrInvited, false);
      expect(room.lastEvent?.body, 'cd');
      await updateLastEvent(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.encrypted',
          room: room,
          eventId: '2',
          originServerTs: DateTime.now(),
          content: {'msgtype': 'm.text', 'body': 'cdc'},
        ),
      );
      expect(room.lastEvent?.body, 'cdc');
      await updateLastEvent(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.encrypted',
          room: room,
          eventId: '3',
          originServerTs: DateTime.now(),
          content: {
            'm.new_content': {'msgtype': 'm.text', 'body': 'test ok'},
            'm.relates_to': {'rel_type': 'm.replace', 'event_id': '1'},
            'msgtype': 'm.text',
            'body': '* test ok',
          },
        ),
      );
      expect(room.lastEvent?.body, 'cdc'); // because we edited the "cd" message

      // update even when status is sending
      // https://github.com/famedly/matrix-dart-sdk/pull/1852#issuecomment-2173019450
      await updateLastEvent(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.encrypted',
          room: room,
          eventId: '4',
          originServerTs: DateTime.now(),
          content: {
            'msgtype': 'm.text',
            'body': 'edited cdc',
            'm.new_content': {'msgtype': 'm.text', 'body': 'edited cdc'},
            'm.relates_to': {'rel_type': 'm.replace', 'event_id': '2'},
          },
          unsigned: {
            messageSendingStatusKey: EventStatus.sending.intValue,
            'transaction_id': 'messageID',
          },
          status: EventStatus.sending,
        ),
      );
      expect(room.lastEvent?.body, 'edited cdc');

      // change because sent
      await updateLastEvent(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.encrypted',
          room: room,
          eventId: '5',
          originServerTs: DateTime.now(),
          content: {
            'msgtype': 'm.text',
            'body': 'edited cdc just because',
            'm.new_content': {
              'msgtype': 'm.text',
              'body': 'edited cdc just because',
            },
            'm.relates_to': {'rel_type': 'm.replace', 'event_id': '2'},
          },
          unsigned: {
            messageSendingStatusKey: EventStatus.sent.intValue,
            'transaction_id': 'messageID',
          },
          status: EventStatus.sent,
        ),
      );
      expect(room.lastEvent?.body, 'edited cdc just because');
      expect(room.lastEvent?.status, EventStatus.sent);
      expect(room.lastEvent?.eventId, '5');

      // Status update on edits working?
      await updateLastEvent(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.encrypted',
          room: room,
          eventId: '6',
          unsigned: {
            'transaction_id': '4',
            messageSendingStatusKey: EventStatus.sent.intValue,
          },
          originServerTs: DateTime.now(),
          content: {
            'msgtype': 'm.text',
            'body': 'edited cdc is back!',
            'm.new_content': {
              'msgtype': 'm.text',
              'body': 'edited cdc is back!',
            },
            'm.relates_to': {'rel_type': 'm.replace', 'event_id': '2'},
          },
          stateKey: '',
          status: EventStatus.sent,
        ),
      );
      expect(room.lastEvent?.eventId, '6');
      expect(room.lastEvent?.body, 'edited cdc is back!');
      expect(room.lastEvent?.status, EventStatus.sent);

      // Are reactions coming through?
      await updateLastEvent(
        Event(
          senderId: '@test:example.com',
          type: EventTypes.Reaction,
          room: room,
          eventId: 'lastEvent_reactions_dont_matter',
          originServerTs: DateTime.now(),
          content: {
            'm.relates_to': {
              'rel_type': RelationshipTypes.reaction,
              'event_id': '1234',
              'key': ':-)',
            },
          },
        ),
      );
      expect(room.lastEvent?.eventId, '6');
      expect(room.lastEvent?.body, 'edited cdc is back!');
      expect(room.lastEvent?.status, EventStatus.sent);
    });

    test('lastEvent when edited and deleted', () async {
      await room.client.handleSync(
        SyncUpdate(
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    Event(
                      content: {
                        'body': 'A',
                        'm.mentions': {},
                        'msgtype': 'm.text',
                      },
                      type: 'm.room.message',
                      eventId: 'testLastEventBeforeEdit',
                      senderId: '@test:example.com',
                      originServerTs: DateTime.now(),
                      room: room,
                    ),
                  ],
                ),
              ),
            },
          ),
          nextBatch: '',
        ),
      );
      expect(room.lastEvent?.eventId, 'testLastEventBeforeEdit');
      expect(room.lastEvent?.body, 'A');

      await room.client.handleSync(
        SyncUpdate(
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    Event(
                      content: {
                        'body': ' * A-edited',
                        'm.mentions': {},
                        'm.new_content': {
                          'body': 'A-edited',
                          'm.mentions': {},
                          'msgtype': 'm.text',
                        },
                        'm.relates_to': {
                          'event_id': 'testLastEventBeforeEdit',
                          'rel_type': 'm.replace',
                        },
                        'msgtype': 'm.text',
                      },
                      type: 'm.room.message',
                      eventId: 'testLastEventAfterEdit',
                      senderId: '@test:example.com',
                      originServerTs: DateTime.now(),
                      room: room,
                    ),
                  ],
                ),
              ),
            },
          ),
          nextBatch: '',
        ),
      );
      expect(room.lastEvent?.eventId, 'testLastEventAfterEdit');
      expect(room.lastEvent?.body, ' * A-edited');

      await room.client.handleSync(
        SyncUpdate(
          rooms: RoomsUpdate(
            join: {
              room.id: JoinedRoomUpdate(
                timeline: TimelineUpdate(
                  events: [
                    Event(
                      content: {'redacts': 'testLastEventBeforeEdit'},
                      type: 'm.room.redaction',
                      eventId: 'testLastEventAfterEditAndDelete',
                      senderId: '@test:example.com',
                      originServerTs: DateTime.now(),
                      room: room,
                    ),
                  ],
                ),
              ),
            },
          ),
          nextBatch: '',
        ),
      );
      expect(room.lastEvent?.eventId, 'testLastEventAfterEdit');
      expect(room.lastEvent?.body, 'Redacted');
    });

    test('lastEvent when reply parent edited', () async {
      await updateLastEvent(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.encrypted',
          room: room,
          eventId: '5',
          originServerTs: DateTime.now(),
          content: {'msgtype': 'm.text', 'body': 'A'},
        ),
      );
      expect(room.lastEvent?.body, 'A');

      await updateLastEvent(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.encrypted',
          room: room,
          eventId: '6',
          originServerTs: DateTime.now(),
          content: {
            'msgtype': 'm.text',
            'body': 'B',
            'm.relates_to': {'rel_type': 'm.in_reply_to', 'event_id': '5'},
          },
        ),
      );
      expect(room.lastEvent?.body, 'B');
      await updateLastEvent(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.encrypted',
          room: room,
          eventId: '7',
          originServerTs: DateTime.now(),
          content: {
            'msgtype': 'm.text',
            'body': 'edited A',
            'm.new_content': {'msgtype': 'm.text', 'body': 'edited A'},
            'm.relates_to': {'rel_type': 'm.replace', 'event_id': '5'},
          },
        ),
      );
      expect(room.lastEvent?.body, 'B');
    });

    test('lastEvent with deleted message', () async {
      await updateLastEvent(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.encrypted',
          room: room,
          eventId: '8',
          originServerTs: DateTime.now(),
          content: {'msgtype': 'm.text', 'body': 'AA'},
          stateKey: '',
        ),
      );
      expect(room.lastEvent?.body, 'AA');

      await updateLastEvent(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.encrypted',
          room: room,
          eventId: '9',
          originServerTs: DateTime.now(),
          content: {
            'msgtype': 'm.text',
            'body': 'B',
            'm.relates_to': {'rel_type': 'm.in_reply_to', 'event_id': '8'},
          },
          stateKey: '',
        ),
      );
      expect(room.lastEvent?.body, 'B');

      await updateLastEvent(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.encrypted',
          room: room,
          eventId: '10',
          originServerTs: DateTime.now(),
          content: {
            'type': 'm.room.redaction',
            'content': {'reason': 'test'},
            'sender': '@test:example.com',
            'redacts': '9',
            'event_id': '10',
            'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
          },
          stateKey: '',
        ),
      );
      expect(room.lastEvent?.eventId, '10');
      await updateLastEvent(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.encrypted',
          room: room,
          eventId: '11',
          originServerTs: DateTime.now(),
          content: {'msgtype': 'm.text', 'body': 'BB'},
          stateKey: '',
        ),
      );
      expect(room.lastEvent?.body, 'BB');
      await updateLastEvent(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.encrypted',
          room: room,
          eventId: '12',
          originServerTs: DateTime.now(),
          content: {
            'm.new_content': {'msgtype': 'm.text', 'body': 'BBB'},
            'm.relates_to': {'rel_type': 'm.replace', 'event_id': '11'},
            'msgtype': 'm.text',
            'body': '* BBB',
          },
          stateKey: '',
        ),
      );
      expect(room.lastEvent?.body, '* BBB');
      room.setState(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.name',
          room: room,
          eventId: '12',
          originServerTs: DateTime.now(),
          content: {'body': 'brainfarts'},
          stateKey: '',
        ),
      );
      expect(room.lastEvent?.body, '* BBB');
    });

    test('sendReadMarker', () async {
      await room.setReadMarker('§1234:fakeServer.notExisting');
    });

    test('requestParticipants', () async {
      final participants = await room.requestParticipants();
      expect(participants.length, 4);
      final user = participants.singleWhere((u) => u.id == '@alice:matrix.org');
      expect(user.id, '@alice:matrix.org');
      expect(user.displayName, 'Alice Margatroid');
      expect(user.membership, Membership.join);
      //expect(user.avatarUrl.toString(), 'mxc://example.org/SEsfnsuifSDFSSEF');
      expect(user.room.id, '!localpart:server.abc');
    });

    test('calcEncryptionHealthState', () async {
      expect(
        await room.calcEncryptionHealthState(),
        EncryptionHealthState.unverifiedDevices,
      );
    });

    test('getEventByID', () async {
      final event = await room.getEventById('1234');
      expect(event?.eventId, '143273582443PhrSn:example.org');
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
      room.setState(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.power_levels',
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
            'users_default': 10,
          },
          originServerTs: DateTime.now(),
          stateKey: '',
        ),
      );
      expect(room.ownPowerLevel, 100);
      expect(room.getPowerLevelByUserId(matrix.userID!), room.ownPowerLevel);
      expect(room.getPowerLevelByUserId('@nouser:example.com'), 10);
      expect(room.ownPowerLevel, 100);
      expect(room.canBan, true);
      expect(room.canInvite, true);
      expect(room.canKick, true);
      expect(room.canRedact, true);
      expect(room.canSendDefaultMessages, true);
      expect(room.canChangePowerLevel, true);
      expect(room.canSendEvent('m.room.name'), true);
      expect(room.canSendEvent('m.room.power_levels'), true);
      expect(room.canSendEvent('m.room.member'), true);
      room.setState(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.power_levels',
          room: room,
          eventId: '123',
          content: {
            'ban': 50,
            'events': {
              'm.room.name': 'lannaForcedMeToTestThis',
              'm.room.power_levels': 100,
            },
            'events_default': 0,
            'invite': 50,
            'kick': 50,
            'notifications': {'room': 20},
            'redact': 50,
            'state_default': 60,
            'users': {'@test:fakeServer.notExisting': 100},
            'users_default': 10,
          },
          originServerTs: DateTime.now(),
          stateKey: '',
        ),
      );
      expect(room.powerForChangingStateEvent('m.room.name'), 60);
      expect(room.powerForChangingStateEvent('m.room.power_levels'), 100);
      expect(room.powerForChangingStateEvent('m.room.nonExisting'), 60);

      room.setState(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.power_levels',
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
            'users_default': 0,
          },
          originServerTs: DateTime.now(),
          stateKey: '',
        ),
      );
      expect(room.ownPowerLevel, 0);
      expect(room.canBan, false);
      expect(room.canInvite, false);
      expect(room.canKick, false);
      expect(room.canRedact, false);
      expect(room.canSendDefaultMessages, true);
      expect(room.canChangePowerLevel, false);
      expect(room.canChangeStateEvent('m.room.name'), true);
      expect(room.canChangeStateEvent('m.room.power_levels'), false);
      expect(room.canChangeStateEvent('m.room.member'), false);
      expect(room.canSendEvent('m.room.message'), true);
      final resp = await room.setPower('@test:fakeServer.notExisting', 0);
      expect(resp, '42');
    });

    test('invite', () async {
      await room.invite('Testname');
    });

    test('setPower', () async {
      final powerLevelMap =
          room.getState(EventTypes.RoomPowerLevels, '')!.content.copy();

      // Request to fake api does not update anything:
      await room.setPower('@bob:fakeServer.notExisting', 100);

      // Original power level map has not changed:
      expect(
        powerLevelMap,
        room.getState(EventTypes.RoomPowerLevels, '')!.content.copy(),
      );
    });

    test('getParticipants', () async {
      var userList = room.getParticipants();
      expect(userList.length, 4);
      // add new user
      room.setState(
        Event(
          senderId: '@alice:test.abc',
          type: 'm.room.member',
          room: room,
          eventId: '12345',
          originServerTs: DateTime.now(),
          content: {'displayname': 'alice'},
          stateKey: '@alice:test.abc',
        ),
      );
      userList = room.getParticipants();
      expect(userList.length, 5);
      expect(userList[4].displayName, 'alice');
    });

    test('addToDirectChat', () async {
      await room.addToDirectChat('Testname');
    });

    test('getTimeline', () async {
      final timeline = await room.getTimeline();
      expect(timeline.events.length, 17);
    });

    test('isFederated', () {
      expect(room.isFederated, true);
      room.setState(
        StrippedStateEvent(
          type: EventTypes.RoomCreate,
          content: {'m.federate': false},
          senderId: room.client.userID!,
          stateKey: '',
        ),
      );
      expect(room.isFederated, false);
    });

    test('getUserByMXID', () async {
      final List<String> called = [];
      final List<String> called2 = [];
      // ignore: deprecated_member_use_from_same_package
      final subscription = room.onUpdate.stream.listen((i) {
        called.add(i);
      });
      final subscription2 = room.client.onRoomState.stream.listen((i) {
        called2.add(i.roomId);
      });

      FakeMatrixApi.calledEndpoints.clear();
      final user = await room.requestUser('@getme:example.com');
      expect(FakeMatrixApi.calledEndpoints.keys, [
        '/client/v3/rooms/!localpart%3Aserver.abc/state/m.room.member/%40getme%3Aexample.com',
      ]);
      expect(user?.stateKey, '@getme:example.com');
      expect(user?.calcDisplayname(), 'You got me');
      expect(user?.membership, Membership.knock);

      // Yield for the onUpdate
      await Future.delayed(
        Duration(
          milliseconds: 1,
        ),
      );
      expect(called.length, 1);
      expect(called2.length, 1);

      FakeMatrixApi.calledEndpoints.clear();
      final user2 = await room.requestUser('@getmeprofile:example.com');
      expect(FakeMatrixApi.calledEndpoints.keys, [
        '/client/v3/rooms/!localpart%3Aserver.abc/state/m.room.member/%40getmeprofile%3Aexample.com',
        '/client/v3/profile/%40getmeprofile%3Aexample.com',
      ]);
      expect(user2?.stateKey, '@getmeprofile:example.com');
      expect(user2?.calcDisplayname(), 'You got me (profile)');
      expect(user2?.membership, Membership.leave);

      // Yield for the onUpdate
      await Future.delayed(
        Duration(
          milliseconds: 1,
        ),
      );
      expect(called.length, 2);
      expect(called2.length, 2);

      FakeMatrixApi.calledEndpoints.clear();
      final userAgain = await room.requestUser('@getme:example.com');
      expect(FakeMatrixApi.calledEndpoints.keys, []);
      expect(userAgain?.stateKey, '@getme:example.com');
      expect(userAgain?.calcDisplayname(), 'You got me');
      expect(userAgain?.membership, Membership.knock);

      // Yield for the onUpdate
      await Future.delayed(
        Duration(
          milliseconds: 1,
        ),
      );
      expect(called.length, 2, reason: 'onUpdate should not have been called.');
      expect(
        called2.length,
        2,
        reason: 'onRoomState should not have been called.',
      );

      FakeMatrixApi.calledEndpoints.clear();
      final user3 = await room.requestUser('@getmeempty:example.com');
      expect(FakeMatrixApi.calledEndpoints.keys, [
        '/client/v3/rooms/!localpart%3Aserver.abc/state/m.room.member/%40getmeempty%3Aexample.com',
        '/client/v3/profile/%40getmeempty%3Aexample.com',
      ]);
      expect(user3?.stateKey, '@getmeempty:example.com');
      expect(user3?.calcDisplayname(), 'You got me (empty)');
      expect(user3?.membership, Membership.leave);

      // Yield for the onUpdate
      await Future.delayed(
        Duration(
          milliseconds: 1,
        ),
      );
      expect(called.length, 3);
      expect(called2.length, 3);

      await subscription.cancel();
      await subscription2.cancel();
    });

    test('setAvatar', () async {
      final testFile = MatrixFile(bytes: Uint8List(0), name: 'file.jpeg');
      final dynamic resp = await room.setAvatar(testFile);
      expect(resp, 'YUwRidLecu:example.com');
    });

    test('sendEvent', () async {
      final dynamic resp = await room.sendEvent(
        {'msgtype': 'm.text', 'body': 'hello world'},
        txid: 'testtxid',
      );
      expect(resp?.startsWith('\$event'), true);
    });

    test('sendEvent', () async {
      FakeMatrixApi.calledEndpoints.clear();
      final dynamic resp =
          await room.sendTextEvent('Hello world', txid: 'testtxid');
      expect(resp?.startsWith('\$event'), true);
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
      final dynamic resp = await room.sendTextEvent(
        'Hello world',
        txid: 'testtxid',
        editEventId: '\$otherEvent',
      );
      expect(resp?.startsWith('\$event'), true);
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
      var event = Event.fromJson(
        {
          'event_id': '\$replyEvent',
          'content': {
            'body': 'Blah',
            'msgtype': 'm.text',
          },
          'type': 'm.room.message',
          'sender': '@alice:example.org',
        },
        room,
      );
      FakeMatrixApi.calledEndpoints.clear();
      var resp = await room.sendTextEvent(
        'Hello world',
        txid: 'testtxid',
        inReplyTo: event,
      );
      expect(resp?.startsWith('\$event'), true);
      var entry = FakeMatrixApi.calledEndpoints.entries
          .firstWhere((p) => p.key.contains('/send/m.room.message/'));
      var content = json.decode(entry.value.first);
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

      event = Event.fromJson(
        {
          'event_id': '\$replyEvent',
          'content': {
            'body': '<b>Blah</b>\nbeep',
            'msgtype': 'm.text',
          },
          'type': 'm.room.message',
          'sender': '@alice:example.org',
        },
        room,
      );
      FakeMatrixApi.calledEndpoints.clear();
      resp = await room.sendTextEvent(
        'Hello world\nfox',
        txid: 'testtxid',
        inReplyTo: event,
      );
      expect(resp?.startsWith('\$event'), true);
      entry = FakeMatrixApi.calledEndpoints.entries
          .firstWhere((p) => p.key.contains('/send/m.room.message/'));
      content = json.decode(entry.value.first);
      expect(content, {
        'body':
            '> <@alice:example.org> <b>Blah</b>\n> beep\n\nHello world\nfox',
        'msgtype': 'm.text',
        'format': 'org.matrix.custom.html',
        'formatted_body':
            '<mx-reply><blockquote><a href="https://matrix.to/#/!localpart:server.abc/\$replyEvent">In reply to</a> <a href="https://matrix.to/#/@alice:example.org">@alice:example.org</a><br>&lt;b&gt;Blah&lt;&#47;b&gt;<br>beep</blockquote></mx-reply>Hello world<br/>fox',
        'm.relates_to': {
          'm.in_reply_to': {
            'event_id': '\$replyEvent',
          },
        },
      });

      event = Event.fromJson(
        {
          'event_id': '\$replyEvent',
          'content': {
            'format': 'org.matrix.custom.html',
            'formatted_body': '<mx-reply>heya</mx-reply>meow',
            'body': 'plaintext meow',
            'msgtype': 'm.text',
          },
          'type': 'm.room.message',
          'sender': '@alice:example.org',
        },
        room,
      );
      FakeMatrixApi.calledEndpoints.clear();
      resp = await room.sendTextEvent(
        'Hello world',
        txid: 'testtxid',
        inReplyTo: event,
      );
      expect(resp?.startsWith('\$event'), true);
      entry = FakeMatrixApi.calledEndpoints.entries
          .firstWhere((p) => p.key.contains('/send/m.room.message/'));
      content = json.decode(entry.value.first);
      expect(content, {
        'body': '> <@alice:example.org> plaintext meow\n\nHello world',
        'msgtype': 'm.text',
        'format': 'org.matrix.custom.html',
        'formatted_body':
            '<mx-reply><blockquote><a href="https://matrix.to/#/!localpart:server.abc/\$replyEvent">In reply to</a> <a href="https://matrix.to/#/@alice:example.org">@alice:example.org</a><br>meow</blockquote></mx-reply>Hello world',
        'm.relates_to': {
          'm.in_reply_to': {
            'event_id': '\$replyEvent',
          },
        },
      });

      event = Event.fromJson(
        {
          'event_id': '\$replyEvent',
          'content': {
            'body': 'Hey @room',
            'msgtype': 'm.text',
          },
          'type': 'm.room.message',
          'sender': '@alice:example.org',
        },
        room,
      );
      FakeMatrixApi.calledEndpoints.clear();
      resp = await room.sendTextEvent(
        'Hello world',
        txid: 'testtxid',
        inReplyTo: event,
      );
      expect(resp?.startsWith('\$event'), true);
      entry = FakeMatrixApi.calledEndpoints.entries
          .firstWhere((p) => p.key.contains('/send/m.room.message/'));
      content = json.decode(entry.value.first);
      expect(content, {
        'body': '> <@alice:example.org> Hey @\u{200b}room\n\nHello world',
        'msgtype': 'm.text',
        'format': 'org.matrix.custom.html',
        'formatted_body':
            '<mx-reply><blockquote><a href="https://matrix.to/#/!localpart:server.abc/\$replyEvent">In reply to</a> <a href="https://matrix.to/#/@alice:example.org">@alice:example.org</a><br>Hey @room</blockquote></mx-reply>Hello world',
        'm.relates_to': {
          'm.in_reply_to': {
            'event_id': '\$replyEvent',
          },
        },
      });

      // Reply to a reply
      event = Event.fromJson(
        {
          'event_id': '\$replyEvent',
          'content': {
            'body': '> <@alice:example.org> Hey\n\nHello world',
            'msgtype': 'm.text',
            'format': 'org.matrix.custom.html',
            'formatted_body':
                '<mx-reply><blockquote><a href="https://matrix.to/#/!localpart:server.abc/\$replyEvent">In reply to</a> <a href="https://matrix.to/#/@alice:example.org">@alice:example.org</a><br>Hey</blockquote></mx-reply>Hello world',
            'm.relates_to': {
              'm.in_reply_to': {
                'event_id': '\$replyEvent',
              },
            },
          },
          'type': 'm.room.message',
          'sender': '@alice:example.org',
        },
        room,
      );
      FakeMatrixApi.calledEndpoints.clear();
      resp =
          await room.sendTextEvent('Fox', txid: 'testtxid', inReplyTo: event);
      expect(resp?.startsWith('\$event'), true);
      entry = FakeMatrixApi.calledEndpoints.entries
          .firstWhere((p) => p.key.contains('/send/m.room.message/'));
      content = json.decode(entry.value.first);
      expect(content, {
        'body': '> <@alice:example.org> Hello world\n\nFox',
        'msgtype': 'm.text',
        'format': 'org.matrix.custom.html',
        'formatted_body':
            '<mx-reply><blockquote><a href="https://matrix.to/#/!localpart:server.abc/\$replyEvent">In reply to</a> <a href="https://matrix.to/#/@alice:example.org">@alice:example.org</a><br>Hello world</blockquote></mx-reply>Fox',
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
      expect(resp?.startsWith('\$event'), true);
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
      expect(resp?.startsWith('\$event'), true);

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
      final resp = await room.sendFileEvent(testFile, txid: 'testtxid');
      expect(resp.toString(), '\$event10');
    });

    test('pushRuleState', () async {
      expect(room.pushRuleState, PushRuleState.mentionsOnly);
      ((matrix.accountData['m.push_rules']?.content['global']
              as Map<String, Object?>)['override'] as List)
          .add(
        ((matrix.accountData['m.push_rules']?.content['global']
            as Map<String, Object?>)['room'] as List)[0],
      );
      expect(room.pushRuleState, PushRuleState.dontNotify);
    });

    test('enableEncryption', () async {
      await room.enableEncryption();
    });

    test('Enable encryption', () async {
      room.setState(
        Event(
          senderId: '@alice:test.abc',
          type: 'm.room.encryption',
          room: room,
          eventId: '12345',
          originServerTs: DateTime.now(),
          content: {
            'algorithm': AlgorithmTypes.megolmV1AesSha2,
            'rotation_period_ms': 604800000,
            'rotation_period_msgs': 100,
          },
          stateKey: '',
        ),
      );
      expect(room.encrypted, true);
      expect(room.encryptionAlgorithm, AlgorithmTypes.megolmV1AesSha2);
    });

    test('setPushRuleState', () async {
      await room.setPushRuleState(PushRuleState.notify);
      await room.setPushRuleState(PushRuleState.dontNotify);
      await room.setPushRuleState(PushRuleState.mentionsOnly);
      await room.setPushRuleState(PushRuleState.notify);
    });

    test('Test tag methods', () async {
      await room.addTag(TagType.favourite, order: 0.1);
      await room.removeTag(TagType.favourite);
      expect(room.isFavourite, false);
      room.roomAccountData['m.tag'] = BasicRoomEvent.fromJson({
        'content': {
          'tags': {
            'm.favourite': {'order': 0.1},
            'm.wrong': {'order': 0.2},
          },
        },
        'type': 'm.tag',
      });
      expect(room.tags.length, 1);
      expect(room.tags[TagType.favourite]?.order, 0.1);
      expect(room.isFavourite, true);
      await room.setFavourite(false);
    });

    test('Test marked unread room', () async {
      await room.markUnread(true);
      await room.markUnread(false);
      expect(room.markedUnread, false);
      room.roomAccountData['m.marked_unread'] = BasicRoomEvent.fromJson({
        'content': {'unread': true},
        'type': 'm.marked_unread',
      });
      expect(room.markedUnread, true);
    });

    test('joinRules', () async {
      expect(room.canChangeJoinRules, false);
      expect(room.joinRules, JoinRules.public);
      room.setState(
        Event.fromJson(
          {
            'content': {'join_rule': 'invite'},
            'event_id': '\$143273582443PhrSn:example.org',
            'origin_server_ts': 1432735824653,
            'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
            'sender': '@example:example.org',
            'state_key': '',
            'type': 'm.room.join_rules',
            'unsigned': {'age': 1234},
          },
          room,
        ),
      );
      expect(room.joinRules, JoinRules.invite);
      await room.setJoinRules(JoinRules.invite);
    });

    test('guestAccess', () async {
      expect(room.canChangeGuestAccess, false);
      expect(room.guestAccess, GuestAccess.forbidden);
      room.setState(
        Event.fromJson(
          {
            'content': {'guest_access': 'can_join'},
            'event_id': '\$143273582443PhrSn:example.org',
            'origin_server_ts': 1432735824653,
            'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
            'sender': '@example:example.org',
            'state_key': '',
            'type': 'm.room.guest_access',
            'unsigned': {'age': 1234},
          },
          room,
        ),
      );
      expect(room.guestAccess, GuestAccess.canJoin);
      await room.setGuestAccess(GuestAccess.canJoin);
    });

    test('historyVisibility', () async {
      expect(room.canChangeHistoryVisibility, false);
      expect(room.historyVisibility, null);
      room.setState(
        Event.fromJson(
          {
            'content': {'history_visibility': 'shared'},
            'event_id': '\$143273582443PhrSn:example.org',
            'origin_server_ts': 1432735824653,
            'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
            'sender': '@example:example.org',
            'state_key': '',
            'type': 'm.room.history_visibility',
            'unsigned': {'age': 1234},
          },
          room,
        ),
      );
      expect(room.historyVisibility, HistoryVisibility.shared);
      await room.setHistoryVisibility(HistoryVisibility.joined);
    });

    test('setState', () async {
      // not set non-state-events
      try {
        room.setState(
          Event.fromJson(
            {
              'content': {'history_visibility': 'shared'},
              'event_id': '\$143273582443PhrSn:example.org',
              'origin_server_ts': 1432735824653,
              'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
              'sender': '@example:example.org',
              'type': 'm.custom',
              'unsigned': {'age': 1234},
            },
            room,
          ),
        );
      } catch (_) {}
      expect(room.getState('m.custom') != null, false);

      // set state events
      room.setState(
        Event.fromJson(
          {
            'content': {'history_visibility': 'shared'},
            'event_id': '\$143273582443PhrSn:example.org',
            'origin_server_ts': 1432735824653,
            'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
            'sender': '@example:example.org',
            'state_key': '',
            'type': 'm.custom',
            'unsigned': {'age': 1234},
          },
          room,
        ),
      );
      expect(room.getState('m.custom') != null, true);

      // sets messages as state events
      try {
        room.setState(
          Event.fromJson(
            {
              'content': {'history_visibility': 'shared'},
              'event_id': '\$143273582443PhrSn:example.org',
              'origin_server_ts': 1432735824653,
              'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
              'sender': '@example:example.org',
              'type': 'm.room.message',
              'unsigned': {'age': 1234},
            },
            room,
          ),
        );
      } catch (_) {}
      expect(room.getState('m.room.message') == null, true);
    });

    test('Widgets', () {
      expect(room.widgets.isEmpty, true);
      room.states['m.widget'] = {
        'test': Event.fromJson(
          {
            'content': {
              'creatorUserId': '@rxl881:matrix.org',
              'data': {'title': 'Bridges Dashboard', 'dateRange': '1y'},
              'id': 'grafana_@rxl881:matrix.org_1514573757015',
              'name': 'Grafana',
              'type': 'm.grafana',
              'url': 'https://matrix.org/grafana/whatever',
              'waitForIframeLoad': true,
            },
            'room_id': '!foo:bar',
            'event_id': '\$15104760642668662QICBu:matrix.org',
            'sender': '@rxl881:matrix.org',
            'state_key': 'test',
            'origin_server_ts': 1432735824653,
            'type': 'm.widget',
          },
          room,
        ),
      };
      expect(room.widgets.length, 1);
      room.states['m.widget'] = {
        'test2': Event.fromJson(
          {
            'content': {
              'creatorUserId': '@rxl881:matrix.org',
              'data': {'title': 'Bridges Dashboard', 'dateRange': '1y'},
              'id': 'grafana_@rxl881:matrix.org_1514573757016',
              'type': 'm.grafana',
              'url': 'https://matrix.org/grafana/whatever',
              'waitForIframeLoad': true,
            },
            'room_id': '!foo:bar',
            'event_id': '\$15104760642668663QICBu:matrix.org',
            'sender': '@rxl881:matrix.org',
            'state_key': 'test2',
            'origin_server_ts': 1432735824653,
            'type': 'm.widget',
          },
          room,
        ),
      };
      expect(room.widgets.length, 1);
      room.states['m.widget'] = {
        'test3': Event.fromJson(
          {
            'content': {
              'creatorUserId': '@rxl881:matrix.org',
              'data': {'title': 'Bridges Dashboard', 'dateRange': '1y'},
              'type': 'm.grafana',
              'waitForIframeLoad': true,
            },
            'room_id': '!foo:bar',
            'event_id': '\$15104760642668662QICBu:matrix.org',
            'sender': '@rxl881:matrix.org',
            'state_key': 'test3',
            'origin_server_ts': 1432735824655,
            'type': 'm.widget',
          },
          room,
        ),
      };
      expect(room.widgets.length, 0);
    });

    test('Spaces', () async {
      expect(room.isSpace, false);
      room.states['m.room.create'] = {
        '': Event.fromJson(
          {
            'content': {'type': 'm.space'},
            'event_id': '\$143273582443PhrSn:example.org',
            'origin_server_ts': 1432735824653,
            'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
            'sender': '@example:example.org',
            'type': 'm.room.create',
            'unsigned': {'age': 1234},
            'state_key': '',
          },
          room,
        ),
      };
      expect(room.isSpace, true);

      expect(room.spaceParents.isEmpty, true);
      room.states[EventTypes.SpaceParent] = {
        '!1234:example.invalid': Event.fromJson(
          {
            'content': {
              'via': ['example.invalid'],
            },
            'event_id': '\$143273582443PhrSn:example.org',
            'origin_server_ts': 1432735824653,
            'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
            'sender': '@example:example.org',
            'type': EventTypes.SpaceParent,
            'unsigned': {'age': 1234},
            'state_key': '!1234:example.invalid',
          },
          room,
        ),
      };
      expect(room.spaceParents.length, 1);

      expect(room.spaceChildren.isEmpty, true);
      room.states[EventTypes.SpaceChild] = {
        '!b:example.invalid': Event.fromJson(
          {
            'content': {
              'via': ['example.invalid'],
              'order': 'b',
            },
            'event_id': '\$143273582443PhrSn:example.org',
            'origin_server_ts': 1432735824653,
            'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
            'sender': '@example:example.org',
            'type': EventTypes.SpaceChild,
            'unsigned': {'age': 1234},
            'state_key': '!b:example.invalid',
          },
          room,
        ),
        '!c:example.invalid': Event.fromJson(
          {
            'content': {
              'via': ['example.invalid'],
              'order': 'c',
            },
            'event_id': '\$143273582443PhrSn:example.org',
            'origin_server_ts': 1432735824653,
            'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
            'sender': '@example:example.org',
            'type': EventTypes.SpaceChild,
            'unsigned': {'age': 1234},
            'state_key': '!c:example.invalid',
          },
          room,
        ),
        '!noorder:example.invalid': Event.fromJson(
          {
            'content': {
              'via': ['example.invalid'],
            },
            'event_id': '\$143273582443PhrSn:example.org',
            'origin_server_ts': 1432735824653,
            'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
            'sender': '@example:example.org',
            'type': EventTypes.SpaceChild,
            'unsigned': {'age': 1234},
            'state_key': '!noorder:example.invalid',
          },
          room,
        ),
        '!a:example.invalid': Event.fromJson(
          {
            'content': {
              'via': ['example.invalid'],
              'order': 'a',
            },
            'event_id': '\$143273582443PhrSn:example.org',
            'origin_server_ts': 1432735824653,
            'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
            'sender': '@example:example.org',
            'type': EventTypes.SpaceChild,
            'unsigned': {'age': 1234},
            'state_key': '!a:example.invalid',
          },
          room,
        ),
      };
      expect(room.spaceChildren.length, 4);

      expect(room.spaceChildren[0].roomId, '!a:example.invalid');
      expect(room.spaceChildren[1].roomId, '!b:example.invalid');
      expect(room.spaceChildren[2].roomId, '!c:example.invalid');
      expect(room.spaceChildren[3].roomId, '!noorder:example.invalid');

      // TODO: Implement a more generic fake api
      /*await room.setSpaceChild(
        '!jEsUZKDJdhlrceRyVU:example.org',
        via: ['example.invalid'],
        order: '5',
        suggested: true,
      );
      await room.removeSpaceChild('!1234:example.invalid');*/
    });

    test('getMention', () async {
      expect(room.getMention('@invalid'), null);
      expect(room.getMention('@[Alice Margatroid]'), '@alice:matrix.org');
      expect(room.getMention('@[Alice Margatroid]#1667'), '@alice:matrix.org');
    });
    test('inviteLink', () async {
      // ensure we don't rerequest members
      room.summary.mJoinedMemberCount = 3;

      var matrixToLink = await room.matrixToInviteLink();
      expect(
        matrixToLink.toString(),
        'https://matrix.to/#/%23testalias%3Aexample.com',
      );

      room.setState(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.canonical_alias',
          room: room,
          eventId: '123',
          content: {'alias': ''},
          originServerTs: DateTime.now(),
          stateKey: '',
        ),
      );

      matrixToLink = await room.matrixToInviteLink();
      expect(
        matrixToLink.toString(),
        'https://matrix.to/#/!localpart%3Aserver.abc?via=fakeServer.notExisting&via=matrix.org&via=test.abc',
      );
    });

    test('cancelSend because EventTooLarge in postLoaded room', () async {
      expect(room.partial, false);
      await room.sendTextEvent(
        'older_event',
        txid: 'older_event',
      );

      // check if persisted in db
      final sentEventFromDB =
          await matrix.database?.getEventById('older_event', room);
      expect(sentEventFromDB?.eventId, 'older_event');
      Room? roomFromDB;

      roomFromDB = await matrix.database?.getSingleRoom(matrix, room.id);
      expect(roomFromDB?.lastEvent?.eventId, 'older_event');

      expect(room.lastEvent?.body, 'older_event');
      // status will be error here because fakeapi
      // but enough for us to fallback after calling cancelSend below
      expect(room.lastEvent?.eventId, 'older_event');

      try {
        await room.sendTextEvent(
          txid: 'event_too_large',
          // data just bigger than maxBodySize
          base64Encode(
            List<int>.generate(60001, (i) => Random().nextInt(256)),
          ),
        );
      } catch (e) {
        expect(e.runtimeType, EventTooLarge);
        expect(room.lastEvent?.eventId, 'event_too_large');
        expect(room.lastEvent?.status, EventStatus.error);

        roomFromDB = await matrix.database?.getSingleRoom(matrix, room.id);
        expect(roomFromDB?.lastEvent?.eventId, 'event_too_large');

        // force null because except would have caught it anyway
        await room.lastEvent?.cancelSend();
      }

      // work in postLoaded room
      expect(room.lastEvent?.eventId, 'event_too_large');
      expect(
        await room.lastEvent?.calcLocalizedBody(MatrixDefaultLocalizations()),
        'Cancelled sending message',
      );

      // check if persisted in db
      final lastEventFromDB =
          await matrix.database?.getEventById('event_too_large', room);

      // null here because cancelSend removes event.
      expect(lastEventFromDB, null);

      roomFromDB = await matrix.database?.getSingleRoom(matrix, room.id);

      expect(roomFromDB?.partial, true);

      expect(roomFromDB?.lastEvent?.eventId, 'event_too_large');
      expect(
        await room.lastEvent?.calcLocalizedBody(MatrixDefaultLocalizations()),
        'Cancelled sending message',
      );

      roomFromDB = await matrix.database?.getSingleRoom(matrix, room.id);

      await roomFromDB?.postLoad();
      expect(roomFromDB?.partial, false);

      expect(roomFromDB?.lastEvent?.eventId, 'event_too_large');
      expect(
        await room.lastEvent?.calcLocalizedBody(MatrixDefaultLocalizations()),
        'Cancelled sending message',
      );
    });

    test('logout', () async {
      await matrix.logout();
    });
  });
}
