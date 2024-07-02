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

      room.setState(Event(
        room: room,
        eventId: '143273582443PhrSn:example.org',
        originServerTs: DateTime.fromMillisecondsSinceEpoch(1432735824653),
        senderId: '@example:example.org',
        type: 'm.room.join_rules',
        unsigned: {'age': 1234},
        content: {'join_rule': 'public'},
        stateKey: '',
      ));
      room.setState(Event(
        room: room,
        eventId: '143273582443PhrSnY:example.org',
        originServerTs: DateTime.fromMillisecondsSinceEpoch(1432735824653),
        senderId: matrix.userID!,
        type: 'm.room.member',
        unsigned: {'age': 1234},
        content: {'membership': 'join', 'displayname': 'YOU'},
        stateKey: matrix.userID!,
      ));
      room.setState(Event(
        room: room,
        eventId: '143273582443PhrSnA:example.org',
        originServerTs: DateTime.fromMillisecondsSinceEpoch(1432735824653),
        senderId: '@alice:matrix.org',
        type: 'm.room.member',
        unsigned: {'age': 1234},
        content: {'membership': 'join', 'displayname': 'Alice Margatroid'},
        stateKey: '@alice:matrix.org',
      ));
      room.setState(Event(
        room: room,
        eventId: '143273582443PhrSnB:example.org',
        originServerTs: DateTime.fromMillisecondsSinceEpoch(1432735824653),
        senderId: '@bob:example.com',
        type: 'm.room.member',
        unsigned: {'age': 1234},
        content: {'membership': 'invite', 'displayname': 'Bob'},
        stateKey: '@bob:example.com',
      ));
      room.setState(Event(
        room: room,
        eventId: '143273582443PhrSnC:example.org',
        originServerTs: DateTime.fromMillisecondsSinceEpoch(1432735824653),
        senderId: '@charley:example.org',
        type: 'm.room.member',
        unsigned: {'age': 1234},
        content: {'membership': 'invite', 'displayname': 'Charley'},
        stateKey: '@charley:example.org',
      ));

      final heroUsers = await room.loadHeroUsers();
      expect(heroUsers.length, 3);

      expect(room.id, id);
      expect(room.membership, membership);
      expect(room.notificationCount, notificationCount);
      expect(room.highlightCount, highlightCount);
      expect(room.summary.mJoinedMemberCount, notificationCount);
      expect(room.summary.mInvitedMemberCount, 2);
      expect(room.summary.mHeroes, heroes);
      expect(room.getLocalizedDisplayname(),
          'Group with Alice Margatroid, Bob, Charley');
      expect(
          room.getState('m.room.join_rules')?.content['join_rule'], 'public');
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
            stateKey: ''),
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
            stateKey: ''),
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
            stateKey: ''),
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
            stateKey: ''),
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
            'pinned': ['1234']
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
      expect(room.lastEvent?.status, EventStatus.sending);
      expect(room.lastEvent?.eventId, '4');

      // Status update on edits working?
      await updateLastEvent(
        Event(
          senderId: '@test:example.com',
          type: 'm.room.encrypted',
          room: room,
          eventId: '5',
          unsigned: {
            'transaction_id': '4',
            messageSendingStatusKey: EventStatus.sent.intValue,
          },
          originServerTs: DateTime.now(),
          content: {
            'msgtype': 'm.text',
            'body': 'edited cdc',
            'm.new_content': {'msgtype': 'm.text', 'body': 'edited cdc'},
            'm.relates_to': {'rel_type': 'm.replace', 'event_id': '2'},
          },
          stateKey: '',
          status: EventStatus.sent,
        ),
      );
      expect(room.lastEvent?.eventId, '5');
      expect(room.lastEvent?.body, 'edited cdc');
      expect(room.lastEvent?.status, EventStatus.sent);
      // Are reactions coming through?
      await updateLastEvent(
        Event(
          senderId: '@test:example.com',
          type: EventTypes.Reaction,
          room: room,
          eventId: '123456',
          originServerTs: DateTime.now(),
          content: {
            'm.relates_to': {
              'rel_type': RelationshipTypes.reaction,
              'event_id': '1234',
              'key': ':-)',
            }
          },
        ),
      );
      expect(room.lastEvent?.eventId, '5');
      expect(room.lastEvent?.body, 'edited cdc');
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
                        'msgtype': 'm.text'
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
                          'msgtype': 'm.text'
                        },
                        'm.relates_to': {
                          'event_id': 'testLastEventBeforeEdit',
                          'rel_type': 'm.replace'
                        },
                        'msgtype': 'm.text'
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
            'm.relates_to': {'rel_type': 'm.in_reply_to', 'event_id': '5'}
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
            'm.relates_to': {'rel_type': 'm.in_reply_to', 'event_id': '8'}
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
              'users_default': 10
            },
            originServerTs: DateTime.now(),
            stateKey: ''),
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
              'users_default': 10
            },
            originServerTs: DateTime.now(),
            stateKey: ''),
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
            'users_default': 0
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

    test('getParticipants', () async {
      var userList = room.getParticipants();
      expect(userList.length, 4);
      // add new user
      room.setState(Event(
          senderId: '@alice:test.abc',
          type: 'm.room.member',
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
      expect(timeline.events.length, 17);
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
        '/client/v3/rooms/!localpart%3Aserver.abc/state/m.room.member/%40getme%3Aexample.com'
      ]);
      expect(user?.stateKey, '@getme:example.com');
      expect(user?.calcDisplayname(), 'You got me');
      expect(user?.membership, Membership.knock);

      // Yield for the onUpdate
      await Future.delayed(Duration(
        milliseconds: 1,
      ));
      expect(called.length, 1);
      expect(called2.length, 1);

      FakeMatrixApi.calledEndpoints.clear();
      final user2 = await room.requestUser('@getmeprofile:example.com');
      expect(FakeMatrixApi.calledEndpoints.keys, [
        '/client/v3/rooms/!localpart%3Aserver.abc/state/m.room.member/%40getmeprofile%3Aexample.com',
        '/client/v3/profile/%40getmeprofile%3Aexample.com'
      ]);
      expect(user2?.stateKey, '@getmeprofile:example.com');
      expect(user2?.calcDisplayname(), 'You got me (profile)');
      expect(user2?.membership, Membership.leave);

      // Yield for the onUpdate
      await Future.delayed(Duration(
        milliseconds: 1,
      ));
      expect(called.length, 2);
      expect(called2.length, 2);

      FakeMatrixApi.calledEndpoints.clear();
      final userAgain = await room.requestUser('@getme:example.com');
      expect(FakeMatrixApi.calledEndpoints.keys, []);
      expect(userAgain?.stateKey, '@getme:example.com');
      expect(userAgain?.calcDisplayname(), 'You got me');
      expect(userAgain?.membership, Membership.knock);

      // Yield for the onUpdate
      await Future.delayed(Duration(
        milliseconds: 1,
      ));
      expect(called.length, 2, reason: 'onUpdate should not have been called.');
      expect(called2.length, 2,
          reason: 'onRoomState should not have been called.');

      FakeMatrixApi.calledEndpoints.clear();
      final user3 = await room.requestUser('@getmeempty:example.com');
      expect(FakeMatrixApi.calledEndpoints.keys, [
        '/client/v3/rooms/!localpart%3Aserver.abc/state/m.room.member/%40getmeempty%3Aexample.com',
        '/client/v3/profile/%40getmeempty%3Aexample.com'
      ]);
      expect(user3?.stateKey, '@getmeempty:example.com');
      expect(user3?.calcDisplayname(), 'You got me (empty)');
      expect(user3?.membership, Membership.leave);

      // Yield for the onUpdate
      await Future.delayed(Duration(
        milliseconds: 1,
      ));
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
          txid: 'testtxid');
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
      final dynamic resp = await room.sendTextEvent('Hello world',
          txid: 'testtxid', editEventId: '\$otherEvent');
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
      var resp = await room.sendTextEvent('Hello world',
          txid: 'testtxid', inReplyTo: event);
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

      event = Event.fromJson({
        'event_id': '\$replyEvent',
        'content': {
          'body': '<b>Blah</b>\nbeep',
          'msgtype': 'm.text',
        },
        'type': 'm.room.message',
        'sender': '@alice:example.org',
      }, room);
      FakeMatrixApi.calledEndpoints.clear();
      resp = await room.sendTextEvent('Hello world\nfox',
          txid: 'testtxid', inReplyTo: event);
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

      event = Event.fromJson({
        'event_id': '\$replyEvent',
        'content': {
          'format': 'org.matrix.custom.html',
          'formatted_body': '<mx-reply>heya</mx-reply>meow',
          'body': 'plaintext meow',
          'msgtype': 'm.text',
        },
        'type': 'm.room.message',
        'sender': '@alice:example.org',
      }, room);
      FakeMatrixApi.calledEndpoints.clear();
      resp = await room.sendTextEvent('Hello world',
          txid: 'testtxid', inReplyTo: event);
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

      event = Event.fromJson({
        'event_id': '\$replyEvent',
        'content': {
          'body': 'Hey @room',
          'msgtype': 'm.text',
        },
        'type': 'm.room.message',
        'sender': '@alice:example.org',
      }, room);
      FakeMatrixApi.calledEndpoints.clear();
      resp = await room.sendTextEvent('Hello world',
          txid: 'testtxid', inReplyTo: event);
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
      event = Event.fromJson({
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
      }, room);
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
          .add(((matrix.accountData['m.push_rules']?.content['global']
              as Map<String, Object?>)['room'] as List)[0]);
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
              'rotation_period_msgs': 100
            },
            stateKey: ''),
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
          }
        },
        'type': 'm.tag'
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
      room.roomAccountData['com.famedly.marked_unread'] =
          BasicRoomEvent.fromJson({
        'content': {'unread': true},
        'type': 'com.famedly.marked_unread'
      });
      expect(room.markedUnread, true);
    });

    test('joinRules', () async {
      expect(room.canChangeJoinRules, false);
      expect(room.joinRules, JoinRules.public);
      room.setState(Event.fromJson(
        {
          'content': {'join_rule': 'invite'},
          'event_id': '\$143273582443PhrSn:example.org',
          'origin_server_ts': 1432735824653,
          'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
          'sender': '@example:example.org',
          'state_key': '',
          'type': 'm.room.join_rules',
          'unsigned': {'age': 1234}
        },
        room,
      ));
      expect(room.joinRules, JoinRules.invite);
      await room.setJoinRules(JoinRules.invite);
    });

    test('guestAccess', () async {
      expect(room.canChangeGuestAccess, false);
      expect(room.guestAccess, GuestAccess.forbidden);
      room.setState(Event.fromJson(
        {
          'content': {'guest_access': 'can_join'},
          'event_id': '\$143273582443PhrSn:example.org',
          'origin_server_ts': 1432735824653,
          'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
          'sender': '@example:example.org',
          'state_key': '',
          'type': 'm.room.guest_access',
          'unsigned': {'age': 1234}
        },
        room,
      ));
      expect(room.guestAccess, GuestAccess.canJoin);
      await room.setGuestAccess(GuestAccess.canJoin);
    });

    test('historyVisibility', () async {
      expect(room.canChangeHistoryVisibility, false);
      expect(room.historyVisibility, null);
      room.setState(Event.fromJson(
        {
          'content': {'history_visibility': 'shared'},
          'event_id': '\$143273582443PhrSn:example.org',
          'origin_server_ts': 1432735824653,
          'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
          'sender': '@example:example.org',
          'state_key': '',
          'type': 'm.room.history_visibility',
          'unsigned': {'age': 1234}
        },
        room,
      ));
      expect(room.historyVisibility, HistoryVisibility.shared);
      await room.setHistoryVisibility(HistoryVisibility.joined);
    });

    test('setState', () async {
      // not set non-state-events
      try {
        room.setState(Event.fromJson(
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
        ));
      } catch (_) {}
      expect(room.getState('m.custom') != null, false);

      // set state events
      room.setState(Event.fromJson(
        {
          'content': {'history_visibility': 'shared'},
          'event_id': '\$143273582443PhrSn:example.org',
          'origin_server_ts': 1432735824653,
          'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
          'sender': '@example:example.org',
          'state_key': '',
          'type': 'm.custom',
          'unsigned': {'age': 1234}
        },
        room,
      ));
      expect(room.getState('m.custom') != null, true);

      // sets messages as state events
      try {
        room.setState(Event.fromJson(
          {
            'content': {'history_visibility': 'shared'},
            'event_id': '\$143273582443PhrSn:example.org',
            'origin_server_ts': 1432735824653,
            'room_id': '!jEsUZKDJdhlrceRyVU:example.org',
            'sender': '@example:example.org',
            'type': 'm.room.message',
            'unsigned': {'age': 1234}
          },
          room,
        ));
      } catch (_) {}
      expect(room.getState('m.room.message') == null, true);
    });

    test('Widgets', () {
      expect(room.widgets.isEmpty, true);
      room.states['m.widget'] = {
        'test': Event.fromJson({
          'content': {
            'creatorUserId': '@rxl881:matrix.org',
            'data': {'title': 'Bridges Dashboard', 'dateRange': '1y'},
            'id': 'grafana_@rxl881:matrix.org_1514573757015',
            'name': 'Grafana',
            'type': 'm.grafana',
            'url': 'https://matrix.org/grafana/whatever',
            'waitForIframeLoad': true
          },
          'room_id': '!foo:bar',
          'event_id': '\$15104760642668662QICBu:matrix.org',
          'sender': '@rxl881:matrix.org',
          'state_key': 'test',
          'origin_server_ts': 1432735824653,
          'type': 'm.widget'
        }, room),
      };
      expect(room.widgets.length, 1);
      room.states['m.widget'] = {
        'test2': Event.fromJson({
          'content': {
            'creatorUserId': '@rxl881:matrix.org',
            'data': {'title': 'Bridges Dashboard', 'dateRange': '1y'},
            'id': 'grafana_@rxl881:matrix.org_1514573757016',
            'type': 'm.grafana',
            'url': 'https://matrix.org/grafana/whatever',
            'waitForIframeLoad': true
          },
          'room_id': '!foo:bar',
          'event_id': '\$15104760642668663QICBu:matrix.org',
          'sender': '@rxl881:matrix.org',
          'state_key': 'test2',
          'origin_server_ts': 1432735824653,
          'type': 'm.widget'
        }, room),
      };
      expect(room.widgets.length, 1);
      room.states['m.widget'] = {
        'test3': Event.fromJson({
          'content': {
            'creatorUserId': '@rxl881:matrix.org',
            'data': {'title': 'Bridges Dashboard', 'dateRange': '1y'},
            'type': 'm.grafana',
            'waitForIframeLoad': true
          },
          'room_id': '!foo:bar',
          'event_id': '\$15104760642668662QICBu:matrix.org',
          'sender': '@rxl881:matrix.org',
          'state_key': 'test3',
          'origin_server_ts': 1432735824655,
          'type': 'm.widget'
        }, room),
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
              'via': ['example.invalid']
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
      expect(matrixToLink.toString(),
          'https://matrix.to/#/%23testalias%3Aexample.com');

      room.setState(
        Event(
            senderId: '@test:example.com',
            type: 'm.room.canonical_alias',
            room: room,
            eventId: '123',
            content: {'alias': ''},
            originServerTs: DateTime.now(),
            stateKey: ''),
      );

      matrixToLink = await room.matrixToInviteLink();
      expect(matrixToLink.toString(),
          'https://matrix.to/#/!localpart%3Aserver.abc?via=fakeServer.notExisting&via=matrix.org&via=test.abc');
    });

    test('EventTooLarge on exceeding max PDU size', () async {
      try {
        await room.sendTextEvent('''

Հայերեն Shqip  Български Català 中文简体 Hrvatski Česky Dansk Nederlands English Eesti Filipino Suomi Français ქართული Deutsch हिन्दी Magyar Indonesia Italiano Latviski Lietuviškai македонски Melayu Norsk Polski Português Româna Pyccкий Српски Slovenčina Slovenščina Español Svenska ไทย Türkçe Українська Tiếng Việt
Lorem Ipsum
"Neque porro quisquam est qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit..."
"There is no one who loves pain itself, who seeks after it and wants to have it, simply because it is pain..."

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Fusce laoreet imperdiet molestie. Nulla facilisi. Duis pulvinar in dui in congue. Proin at odio eget urna facilisis ultricies et ac ipsum. Nam aliquam augue nunc, eget porta est aliquam a. Maecenas convallis sit amet justo vitae mollis. Duis luctus eleifend lacinia. Sed dictum nulla quis erat dapibus, at sollicitudin felis bibendum. Aenean ultricies, sem ac sollicitudin lobortis, nunc lectus aliquet arcu, in consequat lectus purus non quam. Suspendisse efficitur sagittis est a malesuada. Duis dictum mollis sem. Duis erat quam, malesuada non quam ac, rutrum varius mi.

Fusce eleifend id arcu eu efficitur. Sed eu nisl ullamcorper, laoreet erat eget, tempor dui. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Fusce congue faucibus enim, vitae aliquam magna. Quisque pharetra ut diam eget elementum. Etiam eget sapien velit. Pellentesque interdum, urna id laoreet commodo, tortor orci mollis orci, in sodales magna justo vel lectus. Interdum et malesuada fames ac ante ipsum primis in faucibus. Praesent semper, diam quis condimentum sagittis, felis arcu euismod quam, et vulputate tellus nibh quis libero. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus.

Phasellus nec elit erat. Phasellus vitae mi tempor, gravida orci sed, efficitur purus. Quisque a malesuada nunc. Phasellus varius convallis turpis non porttitor. Nulla venenatis feugiat convallis. Fusce eu pharetra erat. Aliquam in scelerisque eros, aliquam efficitur dolor. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos.

Nunc vehicula libero libero, in tempus quam hendrerit at. Maecenas mattis, ligula sit amet placerat fringilla, diam erat viverra sapien, sit amet vehicula augue tellus sed nunc. Aliquam condimentum tristique tortor vel tincidunt. Nam iaculis tellus enim, vel finibus nulla pharetra eu. Quisque eu tristique enim. Morbi urna neque, tincidunt at malesuada non, fringilla ac arcu. Aliquam sed massa in odio consectetur volutpat. Donec ultrices, elit sed rhoncus blandit, ex tellus molestie magna, id iaculis elit libero ut augue. In fringilla ipsum a ante blandit, nec ornare ante dignissim. Mauris fermentum nisl in turpis gravida pellentesque.

Sed fermentum sapien vitae laoreet tempor. Donec dapibus pulvinar lectus. Phasellus odio ipsum, fringilla quis ultrices ut, posuere egestas arcu. Donec ac pulvinar tellus. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae; Aenean vitae mi a est ornare maximus at nec tortor. Quisque sit amet velit lacus.

Nunc eget mollis nisl, et interdum ex. Nam ac augue laoreet orci ullamcorper condimentum. Donec luctus nisl at dui tristique, et viverra dui maximus. Quisque ut ex augue. Nullam venenatis id nunc quis pulvinar. Fusce nulla augue, lacinia nec vehicula a, suscipit suscipit magna. In et consectetur felis.

Pellentesque suscipit augue in ipsum bibendum, et pretium arcu sagittis. Morbi quis purus nec tellus luctus imperdiet. Nullam porta, tellus at malesuada auctor, neque odio posuere magna, in auctor turpis lorem eu sapien. Vivamus tortor mauris, pellentesque ac aliquam id, tincidunt vel metus. Aliquam pharetra augue sapien, quis maximus nisi ullamcorper sit amet. Donec finibus velit nec massa imperdiet consequat. In nec neque justo. Vestibulum tristique placerat felis, quis ornare lacus maximus ut.

Donec in sapien lectus. Nunc condimentum risus quis enim accumsan, quis consequat arcu auctor. In vel odio egestas, sollicitudin quam et, rutrum lectus. Mauris hendrerit rutrum cursus. Mauris sem ante, pretium sit amet risus in, semper auctor ligula. Integer ac urna leo. Aenean nec faucibus ipsum. Nam porttitor, felis quis vehicula vestibulum, mi metus malesuada purus, sed blandit ipsum libero molestie leo. Nam lacinia justo diam, convallis hendrerit eros maximus in. Phasellus fringilla consequat tempor. Sed nec arcu imperdiet, ullamcorper mi nec, faucibus libero.

Curabitur vestibulum pretium sem sit amet eleifend. Ut lectus enim, faucibus at fermentum dapibus, viverra ac mauris. Ut eu ex pretium, egestas eros sodales, imperdiet risus. Etiam vitae tincidunt urna, et varius lectus. Aliquam erat volutpat. Pellentesque consectetur ex at dolor aliquet dapibus. Quisque vestibulum rhoncus tortor at semper. Nulla pharetra condimentum diam ac porta. Cras at interdum mi. Curabitur mattis lacus id neque euismod dignissim. Nullam nibh arcu, commodo nec blandit nec, placerat quis dolor. Cras finibus, arcu eu tempus pulvinar, turpis mi dapibus nibh, a vestibulum dui nulla id nulla. Sed dictum dolor at tempor imperdiet. Praesent vel lacus arcu. Mauris aliquam lacus in eros tincidunt iaculis. Sed vitae aliquam tortor, ut sodales diam.

Aenean eu erat consequat, fermentum ex id, scelerisque tortor. Vestibulum eros nibh, consectetur quis maximus non, mattis non urna. Nullam at ligula ut nibh molestie elementum. Fusce accumsan arcu mattis arcu ultrices, sodales gravida nunc malesuada. Nam nec tincidunt mi. Cras sed tempor lacus. Donec maximus nunc id est hendrerit aliquet. Nulla elementum malesuada felis rutrum bibendum. Pellentesque non nisi vitae tellus consectetur tincidunt. Vestibulum ac magna pulvinar, semper velit et, eleifend dui. Fusce efficitur nulla dui, eget placerat risus vestibulum vitae. Praesent augue nisl, tempor sit amet arcu ac, rhoncus mattis magna. Sed pulvinar turpis a magna condimentum, a egestas turpis commodo.

Phasellus id ante et purus tincidunt fermentum. Duis augue ante, laoreet eget tincidunt in, auctor at risus. Sed lacinia libero nisi, ac fringilla nisi sollicitudin ut. Integer auctor tristique placerat. In hac habitasse platea dictumst. Maecenas at rutrum neque. In scelerisque id lectus ut vulputate. Nullam aliquet pretium nulla ut bibendum. Aenean at tellus eget purus pulvinar vulputate. Mauris scelerisque porta elit sed rhoncus. Phasellus mollis nibh et elit fringilla, eget pharetra elit ornare. Proin malesuada ultrices enim sed egestas. Cras eu rhoncus nibh, nec aliquet velit. Pellentesque mattis placerat lorem sed pretium.

Vivamus quis ultricies magna, sed pellentesque erat. Praesent non volutpat odio. Sed nisl metus, dignissim sed gravida sit amet, ultricies vel urna. Integer semper ex sed felis ullamcorper suscipit. Quisque et molestie velit, a pellentesque nulla. Nam iaculis tristique ipsum, a facilisis orci tristique et. Suspendisse pellentesque magna ut ligula accumsan, sit amet convallis sapien fermentum. Nulla mattis nunc justo. Vivamus semper sapien non turpis gravida, sed pellentesque leo imperdiet. Aenean eget justo quis ipsum aliquam faucibus sed eget orci. Nulla in bibendum tortor, eu lobortis lacus. Morbi tincidunt auctor purus, sit amet viverra metus condimentum aliquet. Aenean nec urna mollis, egestas elit non, lacinia eros. Curabitur mi odio, sodales vel ipsum id, hendrerit condimentum dui.

Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Donec nunc odio, cursus quis sodales ac, porta eget purus. Mauris non est sit amet velit accumsan dignissim. Nam quis ultricies magna. Nulla facilisi. Pellentesque malesuada est a fringilla consectetur. Pellentesque ipsum eros, ultrices id viverra nec, tempus ut eros. Suspendisse commodo elit vel nisl commodo, non auctor justo dignissim. In sed pharetra ligula, sed lacinia felis. Nulla sodales elit sed erat dignissim faucibus. Etiam a augue ut tortor consectetur pellentesque et in mauris. Pellentesque convallis ligula eget arcu ornare, a tincidunt eros rutrum. Donec eu tellus sollicitudin, rhoncus turpis in, interdum odio. Vestibulum interdum orci convallis nisl ornare dignissim.

Vivamus sagittis nunc eget ipsum dapibus euismod. Nunc sollicitudin elementum cursus. Vivamus ac sollicitudin leo, eget pretium libero. Vestibulum aliquet, turpis eget aliquet egestas, turpis dui ornare velit, et volutpat nisi felis vitae libero. Proin ut sapien urna. Ut eget nibh et mi maximus scelerisque. Nulla facilisis augue sem, sed auctor dolor bibendum at. Fusce eu volutpat magna.

Aliquam ac ante porta, molestie magna tempus, dictum eros. Praesent consectetur interdum nulla, non rutrum libero egestas id. Phasellus sapien nulla, malesuada eu massa vehicula, tincidunt laoreet ipsum. Morbi eu luctus metus. Curabitur at tellus est. Cras blandit sed turpis sit amet fermentum. Morbi vitae enim lectus.

Nulla dignissim dictum maximus. Pellentesque varius tincidunt justo, non dignissim erat egestas id. Cras vitae elit sed dui consectetur finibus vitae eu nunc. Vivamus mattis posuere neque viverra dapibus. Donec congue nunc at massa rutrum, a tristique mi rutrum. Sed accumsan malesuada sagittis. Vivamus nunc leo, aliquet eget mattis vitae, fermentum quis mi. Donec fermentum metus nec risus ultricies, sed dapibus orci dapibus. In nibh felis, feugiat vitae felis vel, dignissim molestie lorem. Fusce tincidunt, lorem et feugiat euismod, quam odio feugiat purus, at sagittis arcu nisi sed diam. Maecenas vestibulum sapien libero, sit amet feugiat nibh pellentesque in. Morbi velit lectus, varius vitae euismod id, mollis in est. Vestibulum vel risus pellentesque, placerat metus eget, cursus dolor.

Duis eu finibus dui. In hac habitasse platea dictumst. Mauris ut elit ut ex malesuada dignissim a tristique dui. Fusce et fringilla dui. Praesent a pretium nulla, elementum tempor lacus. Aliquam maximus elit at orci pellentesque consequat. Interdum et malesuada fames ac ante ipsum primis in faucibus. Donec venenatis consequat lectus, in cursus nisi ullamcorper eget. Nam tincidunt velit quis lorem eleifend sodales. Fusce ac lectus non lectus vehicula convallis. Maecenas tristique nisi mi, sed accumsan diam luctus nec. Praesent non vehicula purus. Fusce ac erat in leo mattis pharetra. Sed et sapien eget ipsum convallis congue.

Fusce convallis, lorem ut luctus venenatis, tortor eros ultricies mi, eu ultricies elit elit at nunc. Mauris semper sagittis condimentum. Fusce consequat porta augue, nec aliquet lacus vestibulum vel. Nam mollis ultricies dui, non maximus urna semper in. Curabitur in lacus pharetra libero blandit mollis. Morbi bibendum at nulla in suscipit. Cras sit amet eros fermentum, interdum erat id, sagittis lorem. Aliquam augue felis, laoreet nec tempus nec, porttitor a augue. Praesent placerat et velit sed maximus. Sed malesuada, purus in porttitor congue, nisi magna pulvinar turpis, et viverra sem nunc eu velit. Fusce augue enim, pulvinar eu leo eget, eleifend blandit metus. Etiam feugiat erat eget efficitur viverra. Vestibulum elit ligula, aliquet sed malesuada a, auctor ut odio. Aenean tincidunt tristique velit nec finibus. Suspendisse eu consequat quam, ac faucibus risus.

Maecenas fermentum tristique velit eget convallis. Proin elementum risus nibh, sed mattis risus mattis bibendum. Nullam id pulvinar arcu. Pellentesque lobortis, arcu et vulputate placerat, quam justo congue nunc, ut pharetra eros nibh eget massa. Nam vel lorem risus. Aliquam egestas volutpat sem malesuada fermentum. Sed justo tellus, mattis nec sapien varius, imperdiet iaculis eros. Maecenas eu congue elit. Nam finibus nisi sit amet sagittis tincidunt. Proin vitae pretium ante. Cras nulla dui, condimentum eget massa eu, ullamcorper posuere justo. Maecenas lobortis vestibulum ligula, eget consequat nibh vulputate sed. Aenean lorem ligula, suscipit sed placerat ut, mattis quis nulla.

Cras diam sem, egestas sed tempor vel, placerat eget orci. Cras et sem a sapien ullamcorper imperdiet. Cras vulputate rutrum posuere. Morbi elementum lorem eget mi mattis aliquet. Nullam gravida eros metus, pharetra hendrerit felis sollicitudin vitae. Donec ultricies arcu nec semper lobortis. Vivamus sollicitudin ex diam, vitae egestas nulla ullamcorper ut.

Aenean pretium sem id justo feugiat, porta fermentum nibh auctor. Quisque et venenatis est, vel semper urna. Suspendisse aliquet sit amet nisi non pretium. Nam sit amet ipsum feugiat, lacinia diam et, lobortis magna. Praesent luctus egestas nisl, quis euismod mi mollis ac. Aenean consequat lobortis mollis. Vestibulum diam tortor, laoreet a nunc vulputate, imperdiet luctus libero. Integer id nisi eu lorem commodo lobortis. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. In elit augue, feugiat at feugiat in, fermentum eu justo. Ut ut neque nisi. Maecenas tristique vestibulum quam, vel blandit erat ornare eget. Quisque ullamcorper tellus sit amet justo dictum laoreet. Praesent at elit condimentum, accumsan tortor vitae, ultrices justo. Cras in cursus justo, sit amet malesuada turpis. Suspendisse porta, turpis quis porttitor pharetra, ante erat ornare libero, nec pulvinar felis ex sed magna.

Maecenas ac nisi quis nulla fringilla faucibus. Sed non lorem consectetur, tempor sem at, maximus libero. Sed aliquam facilisis varius. Curabitur quis molestie ante, sed finibus enim. Duis mattis arcu vitae viverra elementum. Suspendisse efficitur orci et justo ultrices porttitor. Donec scelerisque accumsan iaculis. Integer quis porttitor odio. Mauris in nisi quis ipsum dignissim condimentum. Phasellus ante lacus, porta pretium magna ac, tincidunt ornare urna. Curabitur semper ornare consequat. Maecenas commodo posuere nunc quis dapibus. Proin tincidunt malesuada arcu, nec consectetur magna tempor nec.

Pellentesque neque risus, tempor a blandit non, tempor non lorem. Proin vitae turpis erat. Donec non ante non lacus elementum mollis nec at elit. Nunc facilisis eu sem sed commodo. Sed tristique euismod cursus. Maecenas sit amet ipsum laoreet dui faucibus pellentesque. In a porttitor nibh, a semper justo. Pellentesque vulputate commodo dolor eget sagittis. Nullam venenatis congue facilisis. Nam aliquam, nisl et vulputate sollicitudin, risus dolor iaculis magna, et suscipit nulla enim ut risus. Etiam vehicula sed leo ut volutpat.

Maecenas condimentum lobortis eros, vehicula egestas augue pharetra sed. Pellentesque ac augue vel quam convallis imperdiet nec a orci. Mauris hendrerit hendrerit elit, sed sodales arcu feugiat ut. Fusce sit amet augue pulvinar, vehicula mauris non, posuere elit. In sed ante vel neque efficitur malesuada sed eu est. Etiam accumsan dapibus placerat. Aenean aliquet porta lacus, et dictum ipsum tincidunt id. Sed ut lacinia eros, vel maximus ligula. Maecenas scelerisque, nibh id porta semper, purus quam feugiat massa, vitae convallis tortor augue quis nisi. In in enim sagittis, dapibus enim at, gravida velit. Etiam sodales libero eget lectus posuere aliquam. Proin fermentum, justo eu tempor luctus, lacus nisi bibendum eros, et vulputate nunc sem porta neque.

Fusce eu ipsum tellus. Sed et vulputate sem. Sed nec ipsum dictum, molestie lorem ut, pretium dolor. Vestibulum iaculis dignissim mi, vel lacinia sem consectetur a. Quisque in tortor eget enim viverra rhoncus eget eu magna. Sed ut sollicitudin lorem, in semper justo. Maecenas congue dui vitae sapien molestie interdum quis quis velit. Quisque nec sem in erat tempor sodales in quis nunc.

Maecenas eleifend libero sed enim iaculis, vitae vestibulum elit auctor. Mauris nunc ligula, gravida sodales sagittis a, molestie a dui. Proin faucibus id sem imperdiet facilisis. Aenean aliquet ac diam eu facilisis. Maecenas interdum pellentesque augue quis aliquet. Sed iaculis mattis luctus. Pellentesque porttitor nisi eu sapien dictum, rhoncus laoreet neque vehicula. Vivamus in nisi justo. Aenean est leo, aliquet nec eros ut, hendrerit fermentum arcu. Praesent eget mi ultrices, semper mi ut, porta dui. Fusce vestibulum lacus augue, quis viverra lacus elementum euismod. Nullam tempus tincidunt blandit. Quisque ultricies mauris feugiat, pretium justo consectetur, lacinia metus. Maecenas condimentum augue arcu, vitae congue purus fringilla volutpat.

Ut molestie massa libero, tempus finibus magna ultrices ut. Nunc consectetur arcu ultrices pharetra rutrum. Mauris fringilla hendrerit blandit. Phasellus ultrices consectetur purus, id bibendum velit elementum non. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nulla eu urna non felis facilisis finibus sed ac purus. Vivamus vestibulum, turpis ut tincidunt cursus, libero lectus ultricies quam, at vulputate arcu sem at nisi. Quisque ac mi sit amet nisi vestibulum faucibus ut a arcu.

Suspendisse ornare auctor gravida. Donec vitae pellentesque risus. In placerat commodo sapien in laoreet. Quisque tempus ipsum nulla, a rhoncus nunc tincidunt id. In non luctus odio. Suspendisse non pretium nisi. Morbi orci eros, porttitor quis augue sit amet, rhoncus sodales erat. Phasellus at aliquet orci.

Aliquam condimentum, ipsum quis consectetur posuere, magna justo posuere tortor, nec aliquet massa libero in orci. Cras quam lacus, dapibus a elit eu, maximus eleifend velit. Donec erat quam, egestas at viverra et, posuere sed neque. Praesent mattis nibh eget augue convallis, sit amet mattis purus rutrum. Nam nec ligula auctor, bibendum purus non, vestibulum mi. Curabitur fringilla consectetur dapibus. Donec dapibus blandit ultrices. Nulla sed sollicitudin arcu, vitae rhoncus risus. Vestibulum fermentum, libero vel aliquam hendrerit, orci felis vehicula diam, condimentum gravida sem arcu ut felis. Quisque id neque accumsan eros viverra tincidunt nec sit amet velit. Donec urna dui, pulvinar ut nisl a, luctus rutrum mi. Nulla erat odio, vulputate luctus consequat vulputate, venenatis a enim. Maecenas at suscipit justo, ac gravida odio.

Duis elementum velit ac mauris elementum, sed eleifend tellus pharetra. Praesent eu consectetur ipsum. Proin vel bibendum ex. Nulla feugiat felis magna, et pharetra risus tempor vitae. Donec quis metus dui. Nunc egestas porttitor massa, id lacinia velit fermentum eu. Sed porttitor ligula nulla, eu auctor ex eleifend nec. Morbi viverra luctus ligula, eu facilisis nisi interdum ut. Phasellus auctor mauris ac ipsum eleifend, vitae ultrices est fermentum. Fusce fermentum maximus vehicula. Integer ullamcorper lectus non magna tempor venenatis. Donec non accumsan massa. Integer eu justo in velit mattis facilisis.

In venenatis felis vel mi congue, a pulvinar velit volutpat. In nec justo sed dolor egestas tincidunt non et augue. Curabitur consectetur sem sed fringilla gravida. Duis porta mi arcu, vitae sodales ex scelerisque non. Duis a ante a orci ultricies molestie sed ac erat. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Duis auctor odio ut feugiat fermentum. Nunc maximus metus in finibus rutrum. Nulla suscipit metus sit amet neque pulvinar bibendum aliquam sed ipsum. Nunc purus neque, lobortis vitae hendrerit non, imperdiet a ipsum. Praesent ultricies justo ut aliquam laoreet. Etiam vel varius eros. Aliquam at consequat massa.

Nulla ultrices arcu in vehicula eleifend. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Nam volutpat eleifend ultricies. Nunc fringilla turpis malesuada mi porttitor, a interdum mauris vestibulum. Ut eu orci quis ipsum finibus molestie vel vitae orci. Proin sollicitudin erat sapien, ac rutrum tortor fermentum in. In iaculis placerat neque ut rutrum. Donec enim felis, efficitur imperdiet viverra vel, sagittis eget ligula.

Aliquam a purus aliquam, rhoncus diam sed, egestas odio. Etiam tincidunt lacus non magna blandit sagittis. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aliquam erat volutpat. Quisque ex est, lacinia ut auctor a, posuere vel sapien. Vivamus urna diam, condimentum et feugiat sed, ornare et nisi. Cras ac quam at velit iaculis luctus non sed ante. Donec bibendum quam metus, sit amet facilisis ligula euismod commodo. Proin rhoncus sodales enim at vestibulum. Quisque in ligula elementum eros luctus dapibus ut eget felis. Morbi in turpis diam. Etiam eleifend, lacus vitae condimentum rutrum, eros odio condimentum nisi, ut pulvinar tellus elit et orci. Phasellus sit amet laoreet diam. Etiam bibendum arcu odio, non tempor diam ultricies vel.

Duis vestibulum iaculis lacus sed dapibus. Maecenas tincidunt nec eros quis semper. Pellentesque eget mauris ipsum. Ut sodales eros lacus, in lobortis neque facilisis ac. Pellentesque vestibulum quam ante, in posuere sapien tristique ut. Integer varius in libero eu varius. Donec varius lorem quis augue interdum convallis.

Nullam faucibus arcu sed quam lobortis, quis mattis tellus viverra. Vivamus in metus dolor. Nam at auctor nisi, pellentesque varius justo. Maecenas viverra, erat eget pharetra rhoncus, nibh libero cursus nisi, quis lobortis felis odio quis ipsum. Aenean eget porta tellus, nec aliquam ipsum. Cras elementum lacinia ex, nec feugiat nibh mollis in. Pellentesque eget lectus ipsum. Fusce maximus velit a urna lobortis ultricies sit amet in lectus. In pharetra diam ut enim auctor, congue auctor nulla rhoncus.

Vestibulum id eros tempus, fermentum elit sit amet, feugiat nisi. Cras sollicitudin lectus molestie diam feugiat dapibus. Sed dapibus congue venenatis. Sed quis interdum elit, aliquet luctus turpis. Donec sit amet eros et nunc porttitor accumsan vitae vel enim. Nunc ultricies rutrum dolor, ac ornare dui. Praesent quis interdum tortor. In dictum eleifend diam sed auctor. Cras vel massa nec turpis aliquam tempus sed a odio. Curabitur quis eleifend turpis, sed egestas ipsum. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Aliquam laoreet tempus lobortis. Mauris scelerisque dui lectus, eu pharetra tellus faucibus a. Fusce ut nibh sed libero auctor fringilla. Aliquam tristique tristique turpis, quis egestas mi. Aliquam scelerisque lacus vel orci fringilla, eu tincidunt lectus tincidunt.

Vivamus pulvinar aliquam purus in tempus. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae; Sed eget sollicitudin urna. Vestibulum suscipit ut lacus hendrerit lobortis. Ut at elit turpis. Aliquam condimentum tellus vitae ante dignissim interdum. Aliquam gravida neque eu sem pulvinar, sed malesuada massa malesuada. Pellentesque nec posuere dolor. Etiam scelerisque velit dolor, ut fringilla elit cursus vitae. Nulla fermentum risus nunc, ullamcorper ultricies eros tristique lobortis. Duis sit amet aliquam enim. Sed maximus fermentum diam, at venenatis dolor bibendum sollicitudin.

Mauris vestibulum eros id enim rhoncus ullamcorper nec eu nisi. Aenean placerat nulla eu dolor tempor dapibus. Donec porttitor velit vitae velit porttitor dictum. Nam sed laoreet leo. Integer id cursus risus. Nulla in nibh aliquet, sagittis sapien et, posuere risus. Pellentesque malesuada tristique eleifend. Proin nec sagittis enim. Curabitur eget ex at enim fermentum egestas. Integer hendrerit accumsan augue, posuere fermentum erat pharetra vel. Etiam faucibus vestibulum ipsum, eu pellentesque mi. Donec nec tortor et ex volutpat consectetur. Aliquam erat volutpat. Integer non enim justo. Quisque augue ante, fermentum eu ipsum tempus, maximus vulputate leo. Cras imperdiet pulvinar nisl, eget aliquet elit.

Praesent nec nunc quis est pharetra efficitur. Nunc rutrum quis erat et dignissim. Proin ultricies sagittis tortor, quis finibus sapien interdum non. Vestibulum ex nulla, dictum ut enim ac, finibus pretium leo. Maecenas porta ex hendrerit justo rutrum lobortis. Nullam felis arcu, gravida ac tellus in, bibendum suscipit elit. Duis iaculis blandit metus nec fringilla. Maecenas a sapien non est consequat fringilla at tempor justo. Etiam turpis quam, vulputate eu elit at, lacinia scelerisque urna. Mauris massa lorem, auctor non scelerisque nec, vestibulum iaculis nisi. Duis at sapien mattis, placerat lacus a, tristique massa. Maecenas molestie justo vitae tellus euismod, ac dictum risus auctor. Cras sagittis dui risus, vitae hendrerit libero aliquam ornare. Nulla quis felis ac libero maximus feugiat quis vitae enim. Donec quam leo, egestas a congue vitae, tempus hendrerit est. In pulvinar turpis faucibus mi maximus cursus.

In lacus velit, facilisis a erat et, blandit finibus eros. Vivamus nec laoreet est. Vivamus eu sapien consectetur, iaculis mi vel, condimentum justo. Vivamus tincidunt purus eu leo suscipit tempor. Etiam commodo porttitor ex id pellentesque. Vivamus ac erat et purus porttitor tristique. Maecenas quis nulla libero.

Integer finibus libero ex, ac malesuada neque aliquet a. Etiam elementum a lacus sed rhoncus. Proin semper neque ac nulla interdum pretium. Nam porta convallis urna. Cras vel tempus nunc. Praesent eget suscipit elit, faucibus sollicitudin ex. Nulla vel eros a libero mollis varius quis eu justo.

Nullam sed pulvinar magna. Mauris at mauris nec lorem lobortis condimentum. Morbi vestibulum malesuada lacus id molestie. Sed eu auctor mi, in laoreet ligula. Sed fringilla, diam et bibendum sagittis, nisi odio rutrum sem, et interdum dolor felis vitae enim. Donec id mollis enim. Nullam ut gravida dolor.

Duis eget eros mollis, ullamcorper turpis eu, rhoncus felis. In semper quam nec dignissim dignissim. Praesent quis bibendum tellus, id tincidunt dolor. Morbi congue interdum odio non interdum. Proin at sem et ligula venenatis bibendum id id odio. Proin sit amet rutrum libero, eu dictum sapien. Aenean interdum felis quis sollicitudin tristique. Proin hendrerit ipsum vel enim mattis sollicitudin.

Sed id auctor lorem, non auctor libero. Cras non augue tellus. Fusce scelerisque, nulla in imperdiet convallis, urna lorem consectetur urna, non hendrerit ipsum turpis ut ante. Sed justo leo, placerat vel bibendum sit amet, sollicitudin ornare ligula. Praesent laoreet dignissim accumsan. Proin cursus dui nisl, et interdum lacus dapibus malesuada. Nunc condimentum, dolor et tempor rhoncus, velit nisl accumsan elit, non imperdiet nulla sem a eros.

Donec eu tortor porta mi semper pulvinar. Integer porttitor, tortor vitae malesuada facilisis, est metus bibendum erat, nec molestie nunc mi eu arcu. Aliquam sit amet vulputate nisi. Sed ullamcorper purus et odio facilisis, non pharetra odio suscipit. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Sed semper tellus augue, facilisis placerat risus pulvinar eget. In in magna ut sapien pharetra bibendum porta ut leo. Ut varius est ac placerat pharetra. Integer eu feugiat quam, at porta lectus. Curabitur in interdum mi, sed scelerisque neque. Nullam pellentesque ex eu accumsan congue. Curabitur auctor blandit gravida.

Nulla at lobortis felis. Quisque ante dui, aliquam non hendrerit vel, eleifend a massa. Maecenas eget massa ac lectus auctor molestie. Nullam at sagittis elit, ut aliquet augue. Integer eget augue ut mi vehicula pharetra euismod ut felis. Mauris mauris tellus, facilisis et vestibulum a, tincidunt sit amet elit. Maecenas consequat felis at enim congue, vitae eleifend nisi blandit. Suspendisse potenti. Donec at suscipit metus. Nam a sem at lacus maximus laoreet. Cras lacinia hendrerit ornare. Phasellus rhoncus imperdiet urna, sed malesuada eros laoreet at. Vivamus vel euismod urna. Donec sapien risus, tincidunt quis felis in, gravida tempor diam.

Ut a lectus molestie enim sodales condimentum faucibus in diam. Suspendisse ultricies tincidunt felis, a venenatis est interdum in. Nulla a sem ac ligula fermentum sodales vitae id justo. Donec facilisis placerat est, sed tempor sapien condimentum vel. Fusce consectetur nulla accumsan quam consequat, vitae tempus elit maximus. Praesent egestas augue quis tortor porta bibendum. In ultricies urna ac bibendum suscipit. Morbi et arcu tempor, faucibus est quis, ullamcorper neque. Aenean accumsan urna mattis nulla rhoncus, a volutpat neque efficitur. Pellentesque quis risus facilisis, dignissim arcu in, venenatis diam. Phasellus lobortis massa et finibus lacinia. Praesent blandit eros in ex blandit, quis tincidunt orci dapibus. Pellentesque auctor orci ac lorem scelerisque porta. Aliquam ultricies dapibus consectetur. Vestibulum consequat, magna varius tempor posuere, lacus turpis gravida nulla, eu vestibulum est libero vitae magna. Aenean rutrum dolor sit amet rhoncus egestas.

Ut eleifend hendrerit augue, eget bibendum orci porttitor eget. Donec pulvinar ligula massa, sed lobortis nunc condimentum et. Etiam sapien augue, faucibus varius gravida nec, aliquet id risus. Mauris in lacus lectus. Curabitur efficitur, sem lacinia posuere suscipit, augue quam consectetur leo, quis accumsan ante felis ac nisi. Vivamus condimentum at mauris sed sodales. In id quam mauris. Integer bibendum lacinia mauris ac consectetur. Integer vitae volutpat sapien, eu vestibulum libero. Suspendisse vel ante tortor.

Curabitur tempus odio nunc, et rhoncus est laoreet vitae. Vestibulum a ipsum efficitur, ullamcorper nulla sit amet, consectetur lorem. Donec in accumsan ex. Mauris ac scelerisque velit, a rhoncus purus. Pellentesque aliquet, erat nec malesuada sollicitudin, massa nibh pretium orci, vel blandit orci mi nec nunc. Morbi luctus placerat sem, et ornare eros feugiat nec. Fusce aliquam justo eu ipsum ullamcorper, vitae vestibulum tellus mattis.

Praesent iaculis congue venenatis. Aenean placerat pellentesque tempus. Praesent ornare, odio id feugiat dapibus, metus tortor pulvinar augue, nec ultrices lectus nulla at risus. Suspendisse condimentum feugiat nibh. Mauris eget neque ac eros porttitor mollis ut non nisl. Fusce dictum magna pretium, hendrerit magna tempus, rutrum elit. Vestibulum gravida vulputate leo, in consequat quam sagittis id.
Generated 50 paragraphs, 4331 words, 29263 bytes of Lorem Ipsum
help@lipsum.com
Privacy Policy ·
''');
      } catch (e) {
        expect(e.runtimeType, EventTooLarge);
      }
    });

    test('logout', () async {
      await matrix.logout();
    });
  });
}
