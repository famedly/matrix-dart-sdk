// SPDX-FileCopyrightText: 2019-Present Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matrix/matrix.dart';
import 'package:test/test.dart';

import 'fake_database.dart';

void main() {
  final alias = RoomAlias('#General 🦊:example.org');
  final roomId = RoomId('!room:example.org');

  test('typed directory operations send strings on the wire', () async {
    final requests = <http.Request>[];
    final httpClient = MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode(
          request.method == 'GET'
              ? {
                  'room_id': roomId.value,
                  'servers': ['example.org'],
                }
              : <String, Object?>{},
        ),
        200,
      );
    });
    addTearDown(httpClient.close);
    final api = MatrixApi(
      homeserver: Uri.https('example.org'),
      accessToken: 'test-token',
      httpClient: httpClient,
    );
    await api.createRoomAlias(alias, roomId);
    final resolved = await api.resolveRoomAlias(alias);
    await api.removeRoomAlias(alias);

    expect(resolved.roomId, roomId.value);
    expect(resolved.parsedRoomId, roomId);
    expect(requests.map((request) => request.method), ['PUT', 'GET', 'DELETE']);
    for (final request in requests) {
      expect(request.url.pathSegments.last, alias.value);
    }
    expect(jsonDecode(requests.first.body), {'room_id': roomId.value});
  });

  test('alias lists validate at the handwritten API boundary', () async {
    var aliases = [alias.value];
    final httpClient = MockClient(
      (_) async => http.Response.bytes(
        utf8.encode(jsonEncode({'aliases': aliases})),
        200,
      ),
    );
    addTearDown(httpClient.close);
    final api = MatrixApi(
      homeserver: Uri.https('example.org'),
      accessToken: 'test-token',
      httpClient: httpClient,
    );
    expect(await api.getRoomAliases(roomId), [alias]);
    expect(await api.getLocalAliases(roomId.value), [alias.value]);
    aliases = ['not-an-alias'];
    await expectLater(api.getRoomAliases(roomId), throwsFormatException);
  });

  group('Room aliases', () {
    late Client client;
    late Room room;
    late List<http.Request> requests;
    late List<String> aliases;

    setUp(() async {
      requests = [];
      aliases = [];
      final httpClient = MockClient((request) async {
        requests.add(request);
        final response = request.url.pathSegments.last == 'aliases'
            ? <String, Object?>{'aliases': aliases}
            : request.url.pathSegments.contains('state')
            ? <String, Object?>{'event_id': r'$state'}
            : <String, Object?>{};
        return http.Response.bytes(utf8.encode(jsonEncode(response)), 200);
      });
      addTearDown(httpClient.close);
      client =
          Client(
              'alias-test',
              database: await getDatabase(),
              httpClient: httpClient,
            )
            ..homeserver = Uri.https('example.org')
            ..accessToken = 'test-token';
      addTearDown(client.dispose);
      room = Room(id: roomId.value, client: client);
      client.rooms.add(room);
    });

    void setAlias(Object? value) {
      room.setState(
        StrippedStateEvent(
          type: EventTypes.RoomCanonicalAlias,
          stateKey: '',
          senderId: '@alice:example.org',
          content: {'alias': value},
        ),
      );
    }

    test('reads state, finds cached rooms and encodes invite links', () async {
      expect(room.canonicalRoomAlias, isNull);
      setAlias(alias.value);
      expect(room.canonicalRoomAlias, alias);
      expect(client.findRoomByAlias(alias), same(room));
      expect(client.findRoomByAlias(RoomAlias('#missing:example.org')), isNull);
      expect(room.getLocalizedDisplayname(), alias.localpart);
      expect(
        (await room.matrixToInviteLink()).toString(),
        'https://matrix.to/#/${Uri.encodeComponent(alias.value)}',
      );
      // Legacy consumers continue to receive string values.
      // ignore: deprecated_member_use_from_same_package
      expect(room.canonicalAlias, alias.value);
      // ignore: deprecated_member_use_from_same_package
      expect(client.getRoomByAlias(alias.value), same(room));
    });

    test(
      'malformed optional state stays raw and is not exposed as an alias',
      () {
        for (final value in [null, '', 'not-an-alias', 42]) {
          setAlias(value);
          expect(room.canonicalRoomAlias, isNull);
          expect(
            room.getState(EventTypes.RoomCanonicalAlias)!.content['alias'],
            value,
          );
        }
        // ignore: deprecated_member_use_from_same_package
        expect(client.getRoomByAlias(''), isNull);
      },
    );

    test(
      'creates an alias before setting canonical state as raw JSON',
      () async {
        await room.setCanonicalRoomAlias(alias);
        expect(requests.map((request) => request.method), [
          'GET',
          'PUT',
          'PUT',
        ]);
        expect(requests[1].url.pathSegments.last, alias.value);
        expect(jsonDecode(requests[1].body), {'room_id': roomId.value});
        expect(jsonDecode(requests[2].body), {'alias': alias.value});
      },
    );

    test('does not recreate an existing alias', () async {
      aliases = [alias.value];
      await room.setCanonicalRoomAlias(RoomAlias.parse(alias.value));
      expect(requests.map((request) => request.method), ['GET', 'PUT']);
      expect(jsonDecode(requests.last.body), {'alias': alias.value});
    });

    test(
      'legacy setter validates before sending and accepts valid strings',
      () async {
        // ignore: deprecated_member_use_from_same_package
        await expectLater(
          room.setCanonicalAlias('invalid'),
          throwsFormatException,
        );
        expect(requests, isEmpty);
        // ignore: deprecated_member_use_from_same_package
        await room.setCanonicalAlias(alias.value);
        expect(jsonDecode(requests.last.body), {'alias': alias.value});
      },
    );

    test('applies push notification alias and name without synthetic events', () {
      final notification = PushNotification(
        roomName: 'Push Room',
        roomAlias: alias.value,
      );
      room.applyPushNotification(notification);
      expect(room.name, 'Push Room');
      expect(room.canonicalRoomAlias, alias);
      // ignore: deprecated_member_use_from_same_package
      expect(room.canonicalAlias, alias.value);
      // Ensure no synthetic events were added to states:
      expect(room.states, isEmpty);

      // When a real state event arrives, it clears the push notification hint:
      room.setState(
        StrippedStateEvent(
          type: EventTypes.RoomName,
          stateKey: '',
          senderId: '@alice:example.org',
          content: {'name': 'Real Name'},
        ),
      );
      expect(room.name, 'Real Name');
    });

    test(
      'PushNotification.parsedRoomAlias handles missing and malformed aliases',
      () {
        expect(const PushNotification().parsedRoomAlias, isNull);
        expect(
          const PushNotification(roomAlias: 'invalid').parsedRoomAlias,
          isNull,
        );
        expect(
          const PushNotification(roomAlias: '#valid:example.org')
              .parsedRoomAlias,
          RoomAlias('#valid:example.org'),
        );
      },
    );

    test('matrix_id_string_extension typed convenience accessors', () {
      expect('#alias:example.org'.asRoomAlias, RoomAlias('#alias:example.org'));
      expect('invalid'.asRoomAlias, isNull);
      expect('@alice:example.org'.asUserId, UserId('@alice:example.org'));
      expect('!room:example.org'.asRoomId, RoomId('!room:example.org'));
      expect(r'$event:example.org'.asEventId, EventId(r'$event:example.org'));
      expect('@alice:example.org'.asMatrixId, UserId('@alice:example.org'));
    });
  });
}
