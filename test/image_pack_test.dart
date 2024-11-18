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

import 'package:test/test.dart';

import 'package:matrix/matrix.dart';
import 'fake_client.dart';

void main() {
  group('Image Pack', () {
    late Client client;
    late Room room;
    late Room room2;

    test('setupClient', () async {
      client = await getClient();
      room = Room(id: '!1234:fakeServer.notExisting', client: client);
      room2 = Room(id: '!abcd:fakeServer.notExisting', client: client);
      room.setState(
        Event(
          type: 'm.room.power_levels',
          content: {},
          room: room,
          stateKey: '',
          senderId: client.userID!,
          eventId: '\$fakeid1:fakeServer.notExisting',
          originServerTs: DateTime.now(),
        ),
      );
      room.setState(
        Event(
          type: 'm.room.member',
          content: {'membership': 'join'},
          room: room,
          stateKey: client.userID,
          senderId: '@fakeuser:fakeServer.notExisting',
          eventId: '\$fakeid2:fakeServer.notExisting',
          originServerTs: DateTime.now(),
        ),
      );
      room2.setState(
        Event(
          type: 'm.room.power_levels',
          content: {},
          room: room2,
          stateKey: '',
          senderId: client.userID!,
          eventId: '\$fakeid3:fakeServer.notExisting',
          originServerTs: DateTime.now(),
        ),
      );
      room2.setState(
        Event(
          type: 'm.room.member',
          content: {'membership': 'join'},
          room: room2,
          stateKey: client.userID,
          senderId: '@fakeuser:fakeServer.notExisting',
          eventId: '\$fakeid4:fakeServer.notExisting',
          originServerTs: DateTime.now(),
        ),
      );
      client.rooms.add(room);
      client.rooms.add(room2);
    });

    test('Single room', () async {
      room.setState(
        Event(
          type: 'im.ponies.room_emotes',
          content: {
            'images': {
              'room_plain': {'url': 'mxc://room_plain'},
            },
          },
          room: room,
          stateKey: '',
          senderId: '@fakeuser:fakeServer.notExisting',
          eventId: '\$fakeid5:fakeServer.notExisting',
          originServerTs: DateTime.now(),
        ),
      );
      final packs = room.getImagePacks();
      expect(packs.length, 1);
      expect(packs['room']?.images.length, 1);
      expect(
        packs['room']?.images['room_plain']?.url.toString(),
        'mxc://room_plain',
      );
      var packsFlat = room.getImagePacksFlat();
      expect(packsFlat, {
        'room': {'room_plain': 'mxc://room_plain'},
      });
      room.setState(
        Event(
          type: 'im.ponies.room_emotes',
          content: {
            'images': {
              'emote': {
                'url': 'mxc://emote',
                'usage': ['emoticon'],
              },
              'sticker': {
                'url': 'mxc://sticker',
                'usage': ['sticker'],
              },
            },
          },
          room: room,
          stateKey: '',
          senderId: '@fakeuser:fakeServer.notExisting',
          eventId: '\$fakeid6:fakeServer.notExisting',
          originServerTs: DateTime.now(),
        ),
      );
      packsFlat = room.getImagePacksFlat(ImagePackUsage.emoticon);
      expect(packsFlat, {
        'room': {'emote': 'mxc://emote'},
      });
      packsFlat = room.getImagePacksFlat(ImagePackUsage.sticker);
      expect(packsFlat, {
        'room': {'sticker': 'mxc://sticker'},
      });
      room.setState(
        Event(
          type: 'im.ponies.room_emotes',
          content: {
            'images': {
              'emote': {'url': 'mxc://emote'},
              'sticker': {'url': 'mxc://sticker'},
            },
            'pack': {
              'usage': ['emoticon'],
            },
          },
          room: room,
          stateKey: '',
          senderId: '@fakeuser:fakeServer.notExisting',
          eventId: '\$fakeid7:fakeServer.notExisting',
          originServerTs: DateTime.now(),
        ),
      );
      packsFlat = room.getImagePacksFlat(ImagePackUsage.emoticon);
      expect(packsFlat, {
        'room': {'emote': 'mxc://emote', 'sticker': 'mxc://sticker'},
      });
      packsFlat = room.getImagePacksFlat(ImagePackUsage.sticker);
      expect(packsFlat, {});

      room.setState(
        Event(
          type: 'im.ponies.room_emotes',
          content: {
            'images': {
              'fox': {'url': 'mxc://fox'},
            },
            'pack': {
              'usage': ['emoticon'],
            },
          },
          room: room,
          stateKey: 'fox',
          senderId: '@fakeuser:fakeServer.notExisting',
          eventId: '\$fakeid8:fakeServer.notExisting',
          originServerTs: DateTime.now(),
        ),
      );
      packsFlat = room.getImagePacksFlat(ImagePackUsage.emoticon);
      expect(packsFlat, {
        'room': {'emote': 'mxc://emote', 'sticker': 'mxc://sticker'},
        'fox': {'fox': 'mxc://fox'},
      });
    });

    test('user pack', () async {
      client.accountData['im.ponies.user_emotes'] = BasicEvent.fromJson({
        'type': 'im.ponies.user_emotes',
        'content': {
          'images': {
            'user': {
              'url': 'mxc://user',
            },
          },
        },
      });
      final packsFlat = room.getImagePacksFlat(ImagePackUsage.emoticon);
      expect(packsFlat, {
        'room': {'emote': 'mxc://emote', 'sticker': 'mxc://sticker'},
        'fox': {'fox': 'mxc://fox'},
        'user': {'user': 'mxc://user'},
      });
    });

    test('other rooms', () async {
      room2.setState(
        Event(
          type: 'im.ponies.room_emotes',
          content: {
            'images': {
              'other_room_emote': {'url': 'mxc://other_room_emote'},
            },
            'pack': {
              'usage': ['emoticon'],
            },
          },
          room: room2,
          stateKey: '',
          senderId: '@fakeuser:fakeServer.notExisting',
          eventId: '\$fakeid9:fakeServer.notExisting',
          originServerTs: DateTime.now(),
        ),
      );
      client.accountData['im.ponies.emote_rooms'] = BasicEvent.fromJson({
        'type': 'im.ponies.emote_rooms',
        'content': {
          'rooms': {
            '!abcd:fakeServer.notExisting': {'': {}},
          },
        },
      });
      var packsFlat = room.getImagePacksFlat(ImagePackUsage.emoticon);
      expect(packsFlat, {
        'room': {'emote': 'mxc://emote', 'sticker': 'mxc://sticker'},
        'fox': {'fox': 'mxc://fox'},
        'user': {'user': 'mxc://user'},
        'empty-chat-abcdfakeservernotexisting': {
          'other_room_emote': 'mxc://other_room_emote',
        },
      });
      room2.setState(
        Event(
          type: 'im.ponies.room_emotes',
          content: {
            'images': {
              'other_fox': {'url': 'mxc://other_fox'},
            },
            'pack': {
              'usage': ['emoticon'],
            },
          },
          room: room2,
          stateKey: 'fox',
          senderId: '@fakeuser:fakeServer.notExisting',
          eventId: '\$fakeid10:fakeServer.notExisting',
          originServerTs: DateTime.now(),
        ),
      );
      client.accountData['im.ponies.emote_rooms'] = BasicEvent.fromJson({
        'type': 'im.ponies.emote_rooms',
        'content': {
          'rooms': {
            '!abcd:fakeServer.notExisting': {'': {}, 'fox': {}},
          },
        },
      });
      packsFlat = room.getImagePacksFlat(ImagePackUsage.emoticon);
      expect(packsFlat, {
        'room': {'emote': 'mxc://emote', 'sticker': 'mxc://sticker'},
        'fox': {'fox': 'mxc://fox'},
        'user': {'user': 'mxc://user'},
        'empty-chat-abcdfakeservernotexisting': {
          'other_room_emote': 'mxc://other_room_emote',
        },
        'empty-chat-fox-abcdfakeservernotexisting': {
          'other_fox': 'mxc://other_fox',
        },
      });
    });

    test('dispose client', () async {
      await client.dispose(closeDatabase: true);
    });
  });
}
