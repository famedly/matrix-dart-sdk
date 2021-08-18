// @dart=2.9
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

import 'package:test/test.dart';
import 'package:matrix/matrix.dart';
import 'fake_client.dart';
import 'fake_matrix_api.dart';

void main() {
  group('Commands', () {
    Client client;
    Room room;

    final getLastMessagePayload =
        ([String type = 'm.room.message', String stateKey]) {
      final state = stateKey != null;
      return json.decode(FakeMatrixApi.calledEndpoints.entries
          .firstWhere((e) => e.key.startsWith(
              '/client/r0/rooms/${Uri.encodeComponent(room.id)}/${state ? 'state' : 'send'}/${Uri.encodeComponent(type)}${state && stateKey.isNotEmpty ? '/' + Uri.encodeComponent(stateKey) : ''}'))
          .value
          .first);
    };

    test('setupClient', () async {
      client = await getClient();
      room = Room(id: '!1234:fakeServer.notExisting', client: client);
      room.setState(Event(
        type: 'm.room.power_levels',
        content: {},
        room: room,
        stateKey: '',
      ));
      room.setState(Event(
        type: 'm.room.member',
        content: {'membership': 'join'},
        room: room,
        stateKey: client.userID,
      ));
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
      await room.sendTextEvent('/react 🦊',
          inReplyTo: Event(eventId: '\$event'));
      final sent = getLastMessagePayload('m.reaction');
      expect(sent, {
        'm.relates_to': {
          'rel_type': 'm.annotation',
          'event_id': '\$event',
          'key': '🦊',
        },
      });
    });

    test('join', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/join !newroom:example.com');
      expect(
          FakeMatrixApi
                  .calledEndpoints['/client/r0/join/!newroom%3Aexample.com']
                  .first !=
              null,
          true);
    });

    test('leave', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/leave');
      expect(
          FakeMatrixApi
                  .calledEndpoints[
                      '/client/r0/rooms/!1234%3AfakeServer.notExisting/leave']
                  .first !=
              null,
          true);
    });

    test('op', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/op @user:example.org');
      var sent = getLastMessagePayload('m.room.power_levels', '');
      expect(sent, {
        'users': {'@user:example.org': 50}
      });

      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/op @user:example.org 100');
      sent = getLastMessagePayload('m.room.power_levels', '');
      expect(sent, {
        'users': {'@user:example.org': 100}
      });
    });

    test('kick', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/kick @baduser:example.org');
      expect(
          json.decode(FakeMatrixApi
              .calledEndpoints[
                  '/client/r0/rooms/!1234%3AfakeServer.notExisting/kick']
              .first),
          {
            'user_id': '@baduser:example.org',
          });
    });

    test('ban', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/ban @baduser:example.org');
      expect(
          json.decode(FakeMatrixApi
              .calledEndpoints[
                  '/client/r0/rooms/!1234%3AfakeServer.notExisting/ban']
              .first),
          {
            'user_id': '@baduser:example.org',
          });
    });

    test('unban', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/unban @baduser:example.org');
      expect(
          json.decode(FakeMatrixApi
              .calledEndpoints[
                  '/client/r0/rooms/!1234%3AfakeServer.notExisting/unban']
              .first),
          {
            'user_id': '@baduser:example.org',
          });
    });

    test('invite', () async {
      FakeMatrixApi.calledEndpoints.clear();
      await room.sendTextEvent('/invite @baduser:example.org');
      expect(
          json.decode(FakeMatrixApi
              .calledEndpoints[
                  '/client/r0/rooms/!1234%3AfakeServer.notExisting/invite']
              .first),
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

    test('dispose client', () async {
      await client.dispose(closeDatabase: true);
    });
  });
}
