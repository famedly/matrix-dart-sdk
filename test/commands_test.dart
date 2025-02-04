/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2021 Famedly GmbH
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

import 'package:matrix/matrix.dart';
import 'fake_client.dart';

void main() {
  group('Commands', tags: 'olm', () {
    late Client client;
    late Room room;

    Map<String, dynamic> getLastMessagePayload([
      String type = 'm.room.message',
      String? stateKey,
    ]) {
      final state = stateKey != null;
      return json.decode(
        FakeMatrixApi.calledEndpoints.entries
            .firstWhere(
              (e) => e.key.startsWith(
                '/client/v3/rooms/${Uri.encodeComponent(room.id)}/${state ? 'state' : 'send'}/${Uri.encodeComponent(type)}${state && stateKey.isNotEmpty == true ? '/${Uri.encodeComponent(stateKey)}' : ''}',
              ),
            )
            .value
            .first,
      );
    }

    test('setupClient', () async {
      client = await getClient();
      room = Room(id: '!1234:fakeServer.notExisting', client: client);
      room.setState(
        Event(
          type: 'm.room.power_levels',
          content: {},
          room: room,
          stateKey: '',
          eventId: '\$fakeeventid',
          originServerTs: DateTime.now(),
          senderId: '@fakeuser:fakeServer.notExisting',
        ),
      );
      room.setState(
        Event(
          type: 'm.room.member',
          content: {'membership': 'join'},
          room: room,
          stateKey: client.userID,
          eventId: '\$fakeeventid',
          originServerTs: DateTime.now(),
          senderId: '@fakeuser:fakeServer.notExisting',
        ),
      );
    });

    test('send', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/send Hello World');
      var sent = getLastMessagePayload();
      expect(sent, {
        'msgtype': 'm.text',
        'body': 'Hello World',
      });

      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('Beep Boop');
      sent = getLastMessagePayload();
      expect(sent, {
        'msgtype': 'm.text',
        'body': 'Beep Boop',
      });

      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('Beep *Boop*');
      sent = getLastMessagePayload();
      expect(sent, {
        'msgtype': 'm.text',
        'body': 'Beep *Boop*',
        'format': 'org.matrix.custom.html',
        'formatted_body': 'Beep <em>Boop</em>',
      });

      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('//send Hello World');
      sent = getLastMessagePayload();
      expect(sent, {
        'msgtype': 'm.text',
        'body': '/send Hello World',
      });
    });

    test('me', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/me heya');
      final sent = getLastMessagePayload();
      expect(sent, {
        'msgtype': 'm.emote',
        'body': 'heya',
      });
    });

    test('plain', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/plain *floof*');
      final sent = getLastMessagePayload();
      expect(sent, {
        'msgtype': 'm.text',
        'body': '*floof*',
      });
    });

    test('html', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/html <b>yay</b>');
      final sent = getLastMessagePayload();
      expect(sent, {
        'msgtype': 'm.text',
        'body': '<b>yay</b>',
        'format': 'org.matrix.custom.html',
        'formatted_body': '<b>yay</b>',
      });
    });

    test('react', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent(
        '/react 🦊',
        inReplyTo: Event(
          eventId: '\$event',
          type: 'm.room.message',
          content: {
            'msgtype': 'm.text',
            'body': '<b>yay</b>',
            'format': 'org.matrix.custom.html',
            'formatted_body': '<b>yay</b>',
          },
          originServerTs: DateTime.now(),
          senderId: client.userID!,
          room: room,
        ),
      );
      final sent = getLastMessagePayload('m.reaction');
      expect(sent, {
        'm.relates_to': {
          'rel_type': 'm.annotation',
          'event_id': '\$event',
          'key': '🦊',
        },
      });
    });

    test('thread', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent(
        'thread',
        threadRootEventId: '\$parent_event',
        threadLastEventId: '\$parent_event',
      );
      final sent = getLastMessagePayload();
      expect(sent, {
        'msgtype': 'm.text',
        'body': 'thread',
        'm.relates_to': {
          'rel_type': 'm.thread',
          'event_id': '\$parent_event',
          'is_falling_back': true,
          'm.in_reply_to': {'event_id': '\$parent_event'},
        },
      });
    });

    test('thread_image', () async {
      FakeMatrixApi.calledEndpoints.clear();
      final testImage = MatrixFile(bytes: Uint8List(0), name: 'file.jpeg');
      await room.sendFileEvent(
        testImage,
        threadRootEventId: '\$parent_event',
        threadLastEventId: '\$parent_event',
      );
      final sent = getLastMessagePayload();
      expect(sent, {
        'msgtype': 'm.image',
        'body': 'file.jpeg',
        'filename': 'file.jpeg',
        'url': 'mxc://example.com/AQwafuaFswefuhsfAFAgsw',
        'info': {
          'mimetype': 'image/jpeg',
          'size': 0,
        },
        'm.relates_to': {
          'rel_type': 'm.thread',
          'event_id': '\$parent_event',
          'is_falling_back': true,
          'm.in_reply_to': {'event_id': '\$parent_event'},
        },
      });
    });

    test('thread_reply', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent(
        'reply',
        inReplyTo: Event(
          eventId: '\$parent_event',
          type: 'm.room.message',
          content: {
            'msgtype': 'm.text',
            'body': 'reply',
          },
          originServerTs: DateTime.now(),
          senderId: client.userID!,
          room: room,
        ),
        threadRootEventId: '\$parent_event',
        threadLastEventId: '\$parent_event',
      );
      final sent = getLastMessagePayload();
      expect(sent, {
        'msgtype': 'm.text',
        'body': '> <@test:fakeServer.notExisting> reply\n\nreply',
        'format': 'org.matrix.custom.html',
        'formatted_body':
            '<mx-reply><blockquote><a href="https://matrix.to/#/!1234:fakeServer.notExisting/\$parent_event">In reply to</a> <a href="https://matrix.to/#/@test:fakeServer.notExisting">@test:fakeServer.notExisting</a><br>reply</blockquote></mx-reply>reply',
        'm.relates_to': {
          'rel_type': 'm.thread',
          'event_id': '\$parent_event',
          'is_falling_back': false,
          'm.in_reply_to': {'event_id': '\$parent_event'},
        },
      });
    });

    test('thread_different_event_ids', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent(
        'thread',
        threadRootEventId: '\$parent_event',
        threadLastEventId: '\$last_event',
      );
      final sent = getLastMessagePayload();
      expect(sent, {
        'msgtype': 'm.text',
        'body': 'thread',
        'm.relates_to': {
          'rel_type': 'm.thread',
          'event_id': '\$parent_event',
          'is_falling_back': true,
          'm.in_reply_to': {'event_id': '\$last_event'},
        },
      });
    });

    test('join', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/join !newroom:example.com');
      expect(
        FakeMatrixApi.calledEndpoints['/client/v3/join/!newroom%3Aexample.com']
                ?.first !=
            null,
        true,
      );
    });

    test('leave', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/leave');
      expect(
        FakeMatrixApi
                .calledEndpoints[
                    '/client/v3/rooms/!1234%3AfakeServer.notExisting/leave']
                ?.first !=
            null,
        true,
      );
    });

    test('op', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/op @user:example.org');
      var sent = getLastMessagePayload('m.room.power_levels', '');
      expect(sent, {
        'users': {'@user:example.org': 50},
      });

      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/op @user:example.org 100');
      sent = getLastMessagePayload('m.room.power_levels', '');
      expect(sent, {
        'users': {'@user:example.org': 100},
      });
    });

    test('kick', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/kick @baduser:example.org');
      expect(
          json.decode(
            FakeMatrixApi
                .calledEndpoints[
                    '/client/v3/rooms/!1234%3AfakeServer.notExisting/kick']
                ?.first,
          ),
          {
            'user_id': '@baduser:example.org',
          });
    });

    test('ban', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/ban @baduser:example.org');
      expect(
          json.decode(
            FakeMatrixApi
                .calledEndpoints[
                    '/client/v3/rooms/!1234%3AfakeServer.notExisting/ban']
                ?.first,
          ),
          {
            'user_id': '@baduser:example.org',
          });
    });

    test('unban', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/unban @baduser:example.org');
      expect(
          json.decode(
            FakeMatrixApi
                .calledEndpoints[
                    '/client/v3/rooms/!1234%3AfakeServer.notExisting/unban']
                ?.first,
          ),
          {
            'user_id': '@baduser:example.org',
          });
    });

    test('invite', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/invite @baduser:example.org');
      expect(
          json.decode(
            FakeMatrixApi
                .calledEndpoints[
                    '/client/v3/rooms/!1234%3AfakeServer.notExisting/invite']
                ?.first,
          ),
          {
            'user_id': '@baduser:example.org',
          });
    });

    test('myroomnick', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/myroomnick Foxies~');
      final sent = getLastMessagePayload('m.room.member', client.userID);
      expect(sent, {
        'displayname': 'Foxies~',
        'membership': 'join',
      });
    });

    test('myroomavatar', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/myroomavatar mxc://beep/boop');
      final sent = getLastMessagePayload('m.room.member', client.userID);
      expect(sent, {
        'avatar_url': 'mxc://beep/boop',
        'membership': 'join',
      });
    });

    test('dm', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/dm @alice:example.com --no-encryption');
      expect(
          json.decode(
            FakeMatrixApi.calledEndpoints['/client/v3/createRoom']?.last,
          ),
          {
            'invite': ['@alice:example.com'],
            'is_direct': true,
            'preset': 'trusted_private_chat',
          });
    });

    test('create', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/create New room --no-encryption');
      expect(
        json.decode(
          FakeMatrixApi.calledEndpoints['/client/v3/createRoom']?.last,
        ),
        {
          'name': 'New room',
          'preset': 'private_chat',
        },
      );
    });

    test('discardsession', () async {
      await client.encryption?.keyManager.createOutboundGroupSession(room.id);
      expect(
        client.encryption?.keyManager.getOutboundGroupSession(room.id) != null,
        true,
      );
      await room.sendTextEvent('/discardsession');
      expect(
        client.encryption?.keyManager.getOutboundGroupSession(room.id) != null,
        false,
      );
    });

    test('markasdm', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/markasdm @test:fakeServer.notExisting');
      expect(
        json.decode(
          FakeMatrixApi
              .calledEndpoints[
                  '/client/v3/user/%40test%3AfakeServer.notExisting/account_data/m.direct']
              ?.first,
        )?['@alice:example.com'],
        ['!1234:fakeServer.notExisting'],
      );
      expect(
        json.decode(
          FakeMatrixApi
              .calledEndpoints[
                  '/client/v3/user/%40test%3AfakeServer.notExisting/account_data/m.direct']
              ?.first,
        )?['@test:fakeServer.notExisting'],
        ['!1234:fakeServer.notExisting'],
      );
      expect(
        json
            .decode(
              FakeMatrixApi
                  .calledEndpoints[
                      '/client/v3/user/%40test%3AfakeServer.notExisting/account_data/m.direct']
                  ?.first,
            )
            .entries
            .any(
              (e) =>
                  e.key != '@test:fakeServer.notExisting' &&
                  e.key != '@alice:example.com' &&
                  e.value.contains('!1234:fakeServer.notExisting'),
            ),
        false,
      );

      FakeMatrixApi.calledEndpoints.clear();
    });

    test('markasgroup', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/markasgroup');
      expect(
        json
            .decode(
              FakeMatrixApi
                  .calledEndpoints[
                      '/client/v3/user/%40test%3AfakeServer.notExisting/account_data/m.direct']
                  ?.first,
            )
            ?.containsKey('@alice:example.com'),
        false,
      );
      expect(
        json
            .decode(
              FakeMatrixApi
                  .calledEndpoints[
                      '/client/v3/user/%40test%3AfakeServer.notExisting/account_data/m.direct']
                  ?.first,
            )
            .entries
            .any(
              (e) => (e.value as List<dynamic>)
                  .contains('!1234:fakeServer.notExisting'),
            ),
        false,
      );
    });

    test('clearcache', () async {
      await room.sendTextEvent('/clearcache');
      expect(room.client.prevBatch, null);
    });

    test('cute events - googly eyes', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/googly');
      final sent = getLastMessagePayload();
      expect(sent, CuteEventContent.googlyEyes);
    });

    test('cute events - hug', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/hug');
      final sent = getLastMessagePayload();
      expect(sent, CuteEventContent.hug);
    });

    test('cute events - hug', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/cuddle');
      final sent = getLastMessagePayload();
      expect(sent, CuteEventContent.cuddle);
    });

    test('client - clearcache', () async {
      await client.parseAndRunCommand(null, '/clearcache');
      expect(client.prevBatch, null);
    });

    test('client - missing room - discardsession', () async {
      Object? error;
      try {
        await client.parseAndRunCommand(null, '/discardsession');
      } catch (e) {
        error = e;
      }

      expect(error is RoomCommandException, isTrue);
    });

    test('dispose client', () async {
      await client.dispose(closeDatabase: true);
    });
  });
}
