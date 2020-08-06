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

import 'dart:typed_data';
import 'package:famedlysdk/matrix_api.dart';
import 'package:famedlysdk/matrix_api/model/matrix_keys.dart';
import 'package:famedlysdk/matrix_api/model/filter.dart';
import 'package:famedlysdk/matrix_api/model/matrix_exception.dart';
import 'package:famedlysdk/matrix_api/model/presence_content.dart';
import 'package:famedlysdk/matrix_api/model/push_rule_set.dart';
import 'package:famedlysdk/matrix_api/model/pusher.dart';
import 'package:test/test.dart';

import 'fake_matrix_api.dart';

void main() {
  /// All Tests related to device keys
  group('Matrix API', () {
    final matrixApi = MatrixApi(
      httpClient: FakeMatrixApi(),
    );
    test('MatrixException test', () async {
      final exception = MatrixException.fromJson({
        'flows': [
          {
            'stages': ['example.type.foo']
          }
        ],
        'params': {
          'example.type.baz': {'example_key': 'foobar'}
        },
        'session': 'xxxxxxyz',
        'completed': ['example.type.foo']
      });
      expect(
          exception.authenticationFlows.first.stages.first, 'example.type.foo');
      expect(exception.authenticationParams['example.type.baz'],
          {'example_key': 'foobar'});
      expect(exception.session, 'xxxxxxyz');
      expect(exception.completedAuthenticationFlows, ['example.type.foo']);
      expect(exception.requireAdditionalAuthentication, true);
      expect(exception.retryAfterMs, null);
      expect(exception.error, MatrixError.M_UNKNOWN);
      expect(exception.errcode, 'M_FORBIDDEN');
      expect(exception.errorMessage, 'Require additional authentication');
    });
    test('triggerNotFoundError', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      bool error;
      error = false;
      try {
        await matrixApi.request(RequestType.GET, '/fake/path');
      } catch (_) {
        error = true;
      }
      expect(error, true);
      error = false;
      try {
        await matrixApi.request(RequestType.POST, '/fake/path');
      } catch (_) {
        error = true;
      }
      expect(error, true);
      error = false;
      try {
        await matrixApi.request(RequestType.PUT, '/fake/path');
      } catch (_) {
        error = true;
      }
      expect(error, true);
      error = false;
      try {
        await matrixApi.request(RequestType.DELETE, '/fake/path');
      } catch (_) {
        error = true;
      }
      expect(error, true);
      error = false;
      try {
        await matrixApi.request(RequestType.GET, '/path/to/auth/error/');
      } catch (exception) {
        expect(exception is MatrixException, true);
        expect((exception as MatrixException).errcode, 'M_FORBIDDEN');
        expect((exception as MatrixException).error, MatrixError.M_FORBIDDEN);
        expect((exception as MatrixException).errorMessage, 'Blabla');
        expect((exception as MatrixException).requireAdditionalAuthentication,
            false);
        expect(
            (exception as MatrixException).toString(), 'M_FORBIDDEN: Blabla');
        error = true;
      }
      expect(error, true);
      matrixApi.homeserver = null;
    });
    test('getSupportedVersions', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      final supportedVersions = await matrixApi.requestSupportedVersions();
      expect(supportedVersions.versions.contains('r0.5.0'), true);
      expect(supportedVersions.unstableFeatures['m.lazy_load_members'], true);
      expect(FakeMatrixApi.api['GET']['/client/versions']({}),
          supportedVersions.toJson());
      matrixApi.homeserver = null;
    });
    test('getWellKnownInformations', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      final wellKnownInformations =
          await matrixApi.requestWellKnownInformations();
      expect(wellKnownInformations.mHomeserver.baseUrl,
          'https://matrix.example.com');
      expect(wellKnownInformations.toJson(), {
        'm.homeserver': {'base_url': 'https://matrix.example.com'},
        'm.identity_server': {'base_url': 'https://identity.example.com'},
        'org.example.custom.property': {
          'app_url': 'https://custom.app.example.org'
        }
      });
    });
    test('getLoginTypes', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      final loginTypes = await matrixApi.requestLoginTypes();
      expect(loginTypes.flows.first.type, 'm.login.password');
      expect(FakeMatrixApi.api['GET']['/client/r0/login']({}),
          loginTypes.toJson());
      matrixApi.homeserver = null;
    });
    test('login', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      final loginResponse =
          await matrixApi.login(userIdentifierType: 'username');
      expect(FakeMatrixApi.api['POST']['/client/r0/login']({}),
          loginResponse.toJson());
      matrixApi.homeserver = null;
    });
    test('logout', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      await matrixApi.logout();
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('logoutAll', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      await matrixApi.logoutAll();
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('register', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      final registerResponse =
          await matrixApi.register(kind: 'guest', username: 'test');
      expect(FakeMatrixApi.api['POST']['/client/r0/register?kind=guest']({}),
          registerResponse.toJson());
      matrixApi.homeserver = null;
    });
    test('requestEmailToken', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      final response = await matrixApi.requestEmailToken(
        'alice@example.com',
        '1234',
        1,
        nextLink: 'https://example.com',
        idServer: 'https://example.com',
        idAccessToken: '1234',
      );
      expect(
          FakeMatrixApi.api['POST']
              ['/client/r0/register/email/requestToken']({}),
          response.toJson());
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestMsisdnToken', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      final response = await matrixApi.requestMsisdnToken(
        'en',
        '1234',
        '1234',
        1,
        nextLink: 'https://example.com',
        idServer: 'https://example.com',
        idAccessToken: '1234',
      );
      expect(
          FakeMatrixApi.api['POST']
              ['/client/r0/register/email/requestToken']({}),
          response.toJson());
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('changePassword', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      await matrixApi.changePassword('1234', auth: {
        'type': 'example.type.foo',
        'session': 'xxxxx',
        'example_credential': 'verypoorsharedsecret'
      });
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('resetPasswordUsingEmail', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      await matrixApi.resetPasswordUsingEmail(
        'alice@example.com',
        '1234',
        1,
        nextLink: 'https://example.com',
        idServer: 'https://example.com',
        idAccessToken: '1234',
      );
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('resetPasswordUsingMsisdn', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      await matrixApi.resetPasswordUsingMsisdn(
        'en',
        '1234',
        '1234',
        1,
        nextLink: 'https://example.com',
        idServer: 'https://example.com',
        idAccessToken: '1234',
      );
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('deactivateAccount', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      final response = await matrixApi
          .deactivateAccount(idServer: 'https://example.com', auth: {
        'type': 'example.type.foo',
        'session': 'xxxxx',
        'example_credential': 'verypoorsharedsecret'
      });
      expect(response, IdServerUnbindResult.success);
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('usernameAvailable', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      final loginResponse = await matrixApi.usernameAvailable('testuser');
      expect(loginResponse, true);
      matrixApi.homeserver = null;
    });
    test('getThirdPartyIdentifiers', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      final response = await matrixApi.requestThirdPartyIdentifiers();
      expect(FakeMatrixApi.api['GET']['/client/r0/account/3pid']({}),
          {'threepids': response.map((t) => t.toJson()).toList()});
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('addThirdPartyIdentifier', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      await matrixApi.addThirdPartyIdentifier('1234', '1234', auth: {});
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('bindThirdPartyIdentifier', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      await matrixApi.bindThirdPartyIdentifier(
        '1234',
        '1234',
        'https://example.com',
        '1234',
      );
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('deleteThirdPartyIdentifier', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      final response = await matrixApi.deleteThirdPartyIdentifier(
        'alice@example.com',
        ThirdPartyIdentifierMedium.email,
        'https://example.com',
      );
      expect(response, IdServerUnbindResult.success);
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('unbindThirdPartyIdentifier', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      final response = await matrixApi.unbindThirdPartyIdentifier(
        'alice@example.com',
        ThirdPartyIdentifierMedium.email,
        'https://example.com',
      );
      expect(response, IdServerUnbindResult.success);
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestEmailValidationToken', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      await matrixApi.requestEmailValidationToken(
        'alice@example.com',
        '1234',
        1,
        nextLink: 'https://example.com',
        idServer: 'https://example.com',
        idAccessToken: '1234',
      );
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestMsisdnValidationToken', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      await matrixApi.requestMsisdnValidationToken(
        'en',
        '1234',
        '1234',
        1,
        nextLink: 'https://example.com',
        idServer: 'https://example.com',
        idAccessToken: '1234',
      );
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestMsisdnValidationToken', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      final response = await matrixApi.whoAmI();
      expect(response, 'alice@example.com');
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('getServerCapabilities', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      final response = await matrixApi.requestServerCapabilities();
      expect(FakeMatrixApi.api['GET']['/client/r0/capabilities']({}),
          {'capabilities': response.toJson()});
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('uploadFilter', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      final response =
          await matrixApi.uploadFilter('alice@example.com', Filter());
      expect(response, '1234');
      final filter = Filter(
        room: RoomFilter(
          notRooms: ['!1234'],
          rooms: ['!1234'],
          ephemeral: StateFilter(
            limit: 10,
            senders: ['@alice:example.com'],
            types: ['type1'],
            notTypes: ['type2'],
            notRooms: ['!1234'],
            notSenders: ['@bob:example.com'],
            lazyLoadMembers: true,
            includeRedundantMembers: false,
            containsUrl: true,
          ),
          includeLeave: true,
          state: StateFilter(),
          timeline: StateFilter(),
          accountData: StateFilter(limit: 10, types: ['type1']),
        ),
        presence: EventFilter(
          limit: 10,
          senders: ['@alice:example.com'],
          types: ['type1'],
          notRooms: ['!1234'],
          notSenders: ['@bob:example.com'],
        ),
        eventFormat: EventFormat.client,
        eventFields: ['type', 'content', 'sender'],
        accountData: EventFilter(
          types: ['m.accountdatatest'],
          notSenders: ['@alice:example.com'],
        ),
      );
      expect(filter.toJson(), {
        'room': {
          'not_rooms': ['!1234'],
          'rooms': ['!1234'],
          'ephemeral': {
            'limit': 10,
            'types': ['type1'],
            'not_rooms': ['!1234'],
            'not_senders': ['@bob:example.com'],
            'not_types': ['type2'],
            'lazy_load_members': ['type2'],
            'include_redundant_members': ['type2'],
            'contains_url': ['type2']
          },
          'account_data': {
            'limit': 10,
            'types': ['type1'],
          },
          'include_leave': true,
          'state': {},
          'timeline': {},
        },
        'presence': {
          'limit': 10,
          'types': ['type1'],
          'not_rooms': ['!1234'],
          'not_senders': ['@bob:example.com']
        },
        'event_format': 'client',
        'event_fields': ['type', 'content', 'sender'],
        'account_data': {
          'types': ['m.accountdatatest'],
          'not_senders': ['@alice:example.com']
        },
      });
      await matrixApi.uploadFilter(
        'alice@example.com',
        filter,
      );
      final filterMap = {
        'room': {
          'state': {
            'types': ['m.room.*'],
            'not_rooms': ['!726s6s6q:example.com']
          },
          'timeline': {
            'limit': 10,
            'types': ['m.room.message'],
            'not_rooms': ['!726s6s6q:example.com'],
            'not_senders': ['@spam:example.com']
          },
          'ephemeral': {
            'types': ['m.receipt', 'm.typing'],
            'not_rooms': ['!726s6s6q:example.com'],
            'not_senders': ['@spam:example.com']
          }
        },
        'presence': {
          'types': ['m.presence'],
          'not_senders': ['@alice:example.com']
        },
        'account_data': {
          'types': ['m.accountdatatest'],
          'not_senders': ['@alice:example.com']
        },
        'event_format': 'client',
        'event_fields': ['type', 'content', 'sender']
      };
      expect(filterMap, Filter.fromJson(filterMap).toJson());
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('downloadFilter', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      await matrixApi.downloadFilter('alice@example.com', '1234');
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('sync', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      final response = await matrixApi.sync(
        filter: '{}',
        since: '1234',
        fullState: false,
        setPresence: PresenceType.unavailable,
        timeout: 15,
      );
      expect(
          FakeMatrixApi.api['GET'][
                  '/client/r0/sync?filter=%7B%7D&since=1234&full_state=false&set_presence=unavailable&timeout=15'](
              {}) as Map,
          response.toJson());
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestEvent', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final event =
          await matrixApi.requestEvent('!localpart:server.abc', '1234');
      expect(event.eventId, '143273582443PhrSn:example.org');
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestStateContent', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.requestStateContent(
        '!localpart:server.abc',
        'm.room.member',
        '@getme:example.com',
      );
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestStates', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final states = await matrixApi.requestStates('!localpart:server.abc');
      expect(states.length, 4);

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestMembers', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final states = await matrixApi.requestMembers(
        '!localpart:server.abc',
        at: '1234',
        membership: Membership.join,
        notMembership: Membership.leave,
      );
      expect(states.length, 1);

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestJoinedMembers', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final states = await matrixApi.requestJoinedMembers(
        '!localpart:server.abc',
      );
      expect(states.length, 1);
      expect(states['@bar:example.com'].toJson(), {
        'display_name': 'Bar',
        'avatar_url': 'mxc://riot.ovh/printErCATzZijQsSDWorRaK'
      });

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestMessages', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final timelineHistoryResponse = await matrixApi.requestMessages(
        '!localpart:server.abc',
        '1234',
        Direction.b,
        limit: 10,
        filter: '{"lazy_load_members":true}',
        to: '1234',
      );

      expect(
          FakeMatrixApi.api['GET'][
                  '/client/r0/rooms/!localpart%3Aserver.abc/messages?from=1234&dir=b&to=1234&limit=10&filter=%7B%22lazy_load_members%22%3Atrue%7D'](
              {}) as Map,
          timelineHistoryResponse.toJson());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('sendState', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final eventId = await matrixApi.sendState(
          '!localpart:server.abc', 'm.room.avatar', {'url': 'mxc://1234'});

      expect(eventId, 'YUwRidLecu:example.com');

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('sendMessage', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final eventId = await matrixApi.sendMessage(
        '!localpart:server.abc',
        'm.room.message',
        '1234',
        {'body': 'hello world', 'msgtype': 'm.text'},
      );

      expect(eventId, 'YUwRidLecu:example.com');

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('redact', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final eventId = await matrixApi.redact(
        '!localpart:server.abc',
        '1234',
        '1234',
        reason: 'hello world',
      );

      expect(eventId, 'YUwRidLecu:example.com');

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('createRoom', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final roomId = await matrixApi.createRoom(
        visibility: Visibility.public,
        roomAliasName: '#testroom:example.com',
        name: 'testroom',
        topic: 'just for testing',
        invite: ['@bob:example.com'],
        invite3pid: [],
        roomVersion: '2',
        creationContent: {},
        initialState: [],
        preset: CreateRoomPreset.public_chat,
        isDirect: false,
        powerLevelContentOverride: {},
      );

      expect(roomId, '!1234:fakeServer.notExisting');

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('createRoomAlias', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.createRoomAlias(
        '#testalias:example.com',
        '!1234:example.com',
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestRoomAliasInformations', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final roomAliasInformations =
          await matrixApi.requestRoomAliasInformations(
        '#testalias:example.com',
      );

      expect(
          FakeMatrixApi.api['GET']
              ['/client/r0/directory/room/%23testalias%3Aexample.com']({}),
          roomAliasInformations.toJson());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('removeRoomAlias', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.removeRoomAlias('#testalias:example.com');

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestRoomAliases', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final list = await matrixApi.requestRoomAliases('!localpart:example.com');
      expect(list.length, 3);

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestJoinedRooms', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final list = await matrixApi.requestJoinedRooms();
      expect(list.length, 1);

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('inviteToRoom', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.inviteToRoom(
          '!localpart:example.com', '@bob:example.com');

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('joinRoom', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final roomId = '!localpart:example.com';
      final response = await matrixApi.joinRoom(
        roomId,
        thirdPidSignedSender: '@bob:example.com',
        thirdPidSignedmxid: '@alice:example.com',
        thirdPidSignedToken: '1234',
        thirdPidSignedSiganture: {
          'example.org': {'ed25519:0': 'some9signature'}
        },
      );
      expect(response, roomId);

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('joinRoomOrAlias', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final roomId = '!localpart:example.com';
      final response = await matrixApi.joinRoomOrAlias(
        roomId,
        servers: ['example.com', 'example.abc'],
        thirdPidSignedSender: '@bob:example.com',
        thirdPidSignedmxid: '@alice:example.com',
        thirdPidSignedToken: '1234',
        thirdPidSignedSiganture: {
          'example.org': {'ed25519:0': 'some9signature'}
        },
      );
      expect(response, roomId);

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('leave', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.leaveRoom('!localpart:example.com');

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('forget', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.forgetRoom('!localpart:example.com');

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('kickFromRoom', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.kickFromRoom(
        '!localpart:example.com',
        '@bob:example.com',
        reason: 'test',
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('banFromRoom', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.banFromRoom(
        '!localpart:example.com',
        '@bob:example.com',
        reason: 'test',
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('unbanInRoom', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.unbanInRoom(
        '!localpart:example.com',
        '@bob:example.com',
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestRoomVisibility', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final visibility =
          await matrixApi.requestRoomVisibility('!localpart:example.com');
      expect(visibility, Visibility.public);

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('setRoomVisibility', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.setRoomVisibility(
          '!localpart:example.com', Visibility.private);

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestPublicRooms', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.requestPublicRooms(
        limit: 10,
        since: '1234',
        server: 'example.com',
      );

      expect(
          FakeMatrixApi.api['GET'][
              '/client/r0/publicRooms?limit=10&since=1234&server=example.com']({}),
          response.toJson());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('searchPublicRooms', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.searchPublicRooms(
        limit: 10,
        since: '1234',
        server: 'example.com',
        genericSearchTerm: 'test',
        includeAllNetworks: false,
        thirdPartyInstanceId: 'id',
      );

      expect(
          FakeMatrixApi.api['POST']
              ['/client/r0/publicRooms?server=example.com']({}),
          response.toJson());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('searchUser', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.searchUser(
        'test',
        limit: 10,
      );

      expect(FakeMatrixApi.api['POST']['/client/r0/user_directory/search']({}),
          response.toJson());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('setDisplayname', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.setDisplayname('@alice:example.com', 'Alice M');

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestDisplayname', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.requestDisplayname('@alice:example.com');

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('setAvatarUrl', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.setAvatarUrl(
        '@alice:example.com',
        Uri.parse('mxc://test'),
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestAvatarUrl', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.requestAvatarUrl('@alice:example.com');
      expect(response, Uri.parse('mxc://test'));

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestProfile', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.requestProfile('@alice:example.com');
      expect(
          FakeMatrixApi.api['GET']
              ['/client/r0/profile/%40alice%3Aexample.com']({}),
          response.toJson());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestTurnServerCredentials', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.requestTurnServerCredentials();
      expect(FakeMatrixApi.api['GET']['/client/r0/voip/turnServer']({}),
          response.toJson());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('sendTypingNotification', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.sendTypingNotification(
        '@alice:example.com',
        '!localpart:example.com',
        true,
        timeout: 10,
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('sendReceiptMarker', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.sendReceiptMarker(
        '!localpart:example.com',
        '\$1234:example.com',
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('sendReadMarker', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.sendReadMarker(
        '!localpart:example.com',
        '\$1234:example.com',
        readReceiptLocationEventId: '\$1234:example.com',
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('sendPresence', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.sendPresence(
        '@alice:example.com',
        PresenceType.offline,
        statusMsg: 'test',
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestPresence', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.requestPresence(
        '@alice:example.com',
      );
      expect(
          FakeMatrixApi.api['GET'][
              '/client/r0/presence/${Uri.encodeComponent('@alice:example.com')}/status']({}),
          response.toJson());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('upload', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      final response = await matrixApi.upload(Uint8List(0), 'file.jpeg');
      expect(response, 'mxc://example.com/AQwafuaFswefuhsfAFAgsw');
      var throwsException = false;
      try {
        await matrixApi.upload(Uint8List(0), 'file.jpg');
      } on MatrixException catch (_) {
        throwsException = true;
      }
      expect(throwsException, true);
      matrixApi.homeserver = null;
    });
    test('requestOpenGraphDataForUrl', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final openGraphData = await matrixApi.requestOpenGraphDataForUrl(
        Uri.parse('https://matrix.org'),
        ts: 10,
      );
      expect(
          FakeMatrixApi.api['GET']
              ['/media/r0/preview_url?url=https%3A%2F%2Fmatrix.org&ts=10']({}),
          openGraphData.toJson());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestMaxUploadSize', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.requestMaxUploadSize();
      expect(response, 50000000);

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('sendToDevice', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.sendToDevice('m.test', '1234', {
        '@alice:example.com': {
          'TLLBEANAAG': {'example_content_key': 'value'}
        }
      });

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestDevices', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final devices = await matrixApi.requestDevices();
      expect(FakeMatrixApi.api['GET']['/client/r0/devices']({})['devices'],
          devices.map((i) => i.toJson()).toList());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestDevice', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.requestDevice('QBUAZIFURK');

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('setDeviceMetadata', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.setDeviceMetadata('QBUAZIFURK', displayName: 'test');

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('deleteDevice', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.deleteDevice('QBUAZIFURK', auth: {});

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('deleteDevices', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.deleteDevices(['QBUAZIFURK'], auth: {});

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('uploadDeviceKeys', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.uploadDeviceKeys(
        deviceKeys: MatrixDeviceKeys(
          '@alice:example.com',
          'ABCD',
          ['caesar-chiffre'],
          {},
          {},
          unsigned: {},
        ),
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestDeviceKeys', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.requestDeviceKeys(
        {
          '@alice:example.com': [],
        },
        timeout: 10,
        token: '1234',
      );
      expect(
          response
              .deviceKeys['@alice:example.com']['JLAFKJWSCS'].deviceDisplayName,
          'Alices mobile phone');
      expect(
          FakeMatrixApi.api['POST']
              ['/client/r0/keys/query']({'device_keys': {}}),
          response.toJson());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestOneTimeKeys', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.requestOneTimeKeys(
        {
          '@alice:example.com': {'JLAFKJWSCS': 'signed_curve25519'}
        },
        timeout: 10,
      );
      expect(FakeMatrixApi.api['POST']['/client/r0/keys/claim']({}),
          response.toJson());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestDeviceListsUpdate', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.requestDeviceListsUpdate('1234', '1234');

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('uploadDeviceSigningKeys', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final masterKey = MatrixCrossSigningKey.fromJson({
        'user_id': '@test:fakeServer.notExisting',
        'usage': ['master'],
        'keys': {
          'ed25519:82mAXjsmbTbrE6zyShpR869jnrANO75H8nYY0nDLoJ8':
              '82mAXjsmbTbrE6zyShpR869jnrANO75H8nYY0nDLoJ8',
        },
        'signatures': {},
      });
      final selfSigningKey = MatrixCrossSigningKey.fromJson({
        'user_id': '@test:fakeServer.notExisting',
        'usage': ['self_signing'],
        'keys': {
          'ed25519:F9ypFzgbISXCzxQhhSnXMkc1vq12Luna3Nw5rqViOJY':
              'F9ypFzgbISXCzxQhhSnXMkc1vq12Luna3Nw5rqViOJY',
        },
        'signatures': {},
      });
      final userSigningKey = MatrixCrossSigningKey.fromJson({
        'user_id': '@test:fakeServer.notExisting',
        'usage': ['user_signing'],
        'keys': {
          'ed25519:0PiwulzJ/RU86LlzSSZ8St80HUMN3dqjKa/orIJoA0g':
              '0PiwulzJ/RU86LlzSSZ8St80HUMN3dqjKa/orIJoA0g',
        },
        'signatures': {},
      });
      await matrixApi.uploadDeviceSigningKeys(
          masterKey: masterKey,
          selfSigningKey: selfSigningKey,
          userSigningKey: userSigningKey);
    });
    test('uploadKeySignatures', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final key1 = MatrixDeviceKeys.fromJson({
        'user_id': '@alice:example.com',
        'device_id': 'JLAFKJWSCS',
        'algorithms': ['m.olm.v1.curve25519-aes-sha2', 'm.megolm.v1.aes-sha2'],
        'keys': {
          'curve25519:JLAFKJWSCS':
              '3C5BFWi2Y8MaVvjM8M22DBmh24PmgR0nPvJOIArzgyI',
          'ed25519:JLAFKJWSCS': 'lEuiRJBit0IG6nUf5pUzWTUEsRVVe/HJkoKuEww9ULI'
        },
        'signatures': {
          '@alice:example.com': {
            'ed25519:JLAFKJWSCS':
                'dSO80A01XiigH3uBiDVx/EjzaoycHcjq9lfQX0uWsqxl2giMIiSPR8a4d291W1ihKJL/a+myXS367WT6NAIcBA'
          }
        },
        'unsigned': {'device_display_name': 'Alices mobile phone'},
      });
      final key2 = MatrixDeviceKeys.fromJson({
        'user_id': '@alice:example.com',
        'device_id': 'JLAFKJWSCS',
        'algorithms': ['m.olm.v1.curve25519-aes-sha2', 'm.megolm.v1.aes-sha2'],
        'keys': {
          'curve25519:JLAFKJWSCS':
              '3C5BFWi2Y8MaVvjM8M22DBmh24PmgR0nPvJOIArzgyI',
          'ed25519:JLAFKJWSCS': 'lEuiRJBit0IG6nUf5pUzWTUEsRVVe/HJkoKuEww9ULI'
        },
        'signatures': {
          '@alice:example.com': {'ed25519:OTHERDEVICE': 'OTHERSIG'}
        },
        'unsigned': {'device_display_name': 'Alices mobile phone'},
      });
      final ret = await matrixApi.uploadKeySignatures([key1, key2]);
      expect(
        FakeMatrixApi.api['POST']['/client/r0/keys/signatures/upload']({}),
        ret.toJson(),
      );
    });
    test('requestPushers', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.requestPushers();
      expect(
        FakeMatrixApi.api['GET']['/client/r0/pushers']({}),
        {'pushers': response.map((i) => i.toJson()).toList()},
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('setPusher', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.setPusher(
        Pusher(
          '1234',
          'app.id',
          'appDisplayName',
          'deviceDisplayName',
          'en',
          PusherData(
              format: 'event_id_only', url: Uri.parse('https://matrix.org')),
          profileTag: 'tag',
          kind: 'http',
        ),
        append: true,
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestNotifications', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.requestNotifications(
        from: '1234',
        limit: 10,
        only: '1234',
      );
      expect(
        FakeMatrixApi.api['GET']
            ['/client/r0/notifications?from=1234&limit=10&only=1234']({}),
        response.toJson(),
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestPushRules', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.requestPushRules();
      expect(
        FakeMatrixApi.api['GET']['/client/r0/pushrules']({}),
        {'global': response.toJson()},
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestPushRule', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.requestPushRule(
          'global', PushRuleKind.content, 'nocake');
      expect(
        FakeMatrixApi.api['GET']
            ['/client/r0/pushrules/global/content/nocake']({}),
        response.toJson(),
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('deletePushRule', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.deletePushRule('global', PushRuleKind.content, 'nocake');

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('setPushRule', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.setPushRule(
        'global',
        PushRuleKind.content,
        'nocake',
        [PushRuleAction.notify],
        before: '1',
        after: '2',
        conditions: [
          PushConditions(
            'event_match',
            key: 'key',
            pattern: 'pattern',
            isOperator: '+',
          )
        ],
        pattern: 'pattern',
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestPushRuleEnabled', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final enabled = await matrixApi.requestPushRuleEnabled(
          'global', PushRuleKind.content, 'nocake');
      expect(enabled, true);

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('enablePushRule', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.enablePushRule(
        'global',
        PushRuleKind.content,
        'nocake',
        true,
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestPushRuleActions', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final actions = await matrixApi.requestPushRuleActions(
          'global', PushRuleKind.content, 'nocake');
      expect(actions.first, PushRuleAction.notify);

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('setPushRuleActions', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.setPushRuleActions(
        'global',
        PushRuleKind.content,
        'nocake',
        [PushRuleAction.dont_notify],
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('globalSearch', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.globalSearch({});

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('globalSearch', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.requestEvents(
          from: '1234', roomId: '!1234', timeout: 10);
      expect(
        FakeMatrixApi.api['GET']
            ['/client/r0/events?from=1234&timeout=10&roomId=%211234']({}),
        response.toJson(),
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestRoomTags', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.requestRoomTags(
          '@alice:example.com', '!localpart:example.com');
      expect(
        FakeMatrixApi.api['GET'][
            '/client/r0/user/%40alice%3Aexample.com/rooms/!localpart%3Aexample.com/tags']({}),
        {'tags': response.map((k, v) => MapEntry(k, v.toJson()))},
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('addRoomTag', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.addRoomTag(
        '@alice:example.com',
        '!localpart:example.com',
        'testtag',
        order: 0.5,
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('addRoomTag', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.removeRoomTag(
        '@alice:example.com',
        '!localpart:example.com',
        'testtag',
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('setAccountData', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.setAccountData(
        '@alice:example.com',
        'test.account.data',
        {'foo': 'bar'},
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestAccountData', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.requestAccountData(
        '@alice:example.com',
        'test.account.data',
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('setRoomAccountData', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.setRoomAccountData(
        '@alice:example.com',
        '1234',
        'test.account.data',
        {'foo': 'bar'},
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestRoomAccountData', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.requestRoomAccountData(
        '@alice:example.com',
        '1234',
        'test.account.data',
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestWhoIsInfo', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.requestWhoIsInfo('@alice:example.com');
      expect(
        FakeMatrixApi.api['GET']
            ['/client/r0/admin/whois/%40alice%3Aexample.com']({}),
        response.toJson(),
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestEventContext', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.requestEventContext('1234', '1234',
          limit: 10, filter: '{}');
      expect(
        FakeMatrixApi.api['GET']
            ['/client/r0/rooms/1234/context/1234?filter=%7B%7D&limit=10']({}),
        response.toJson(),
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('reportEvent', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.reportEvent(
        '1234',
        '1234',
        'test',
        -100,
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestSupportedProtocols', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.requestSupportedProtocols();
      expect(
        FakeMatrixApi.api['GET']['/client/r0/thirdparty/protocols']({}),
        response.map((k, v) => MapEntry(k, v.toJson())),
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestSupportedProtocol', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.requestSupportedProtocol('irc');
      expect(
        FakeMatrixApi.api['GET']['/client/r0/thirdparty/protocol/irc']({}),
        response.toJson(),
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestThirdPartyLocations', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.requestThirdPartyLocations('irc');
      expect(
        FakeMatrixApi.api['GET']['/client/r0/thirdparty/location/irc']({}),
        response.map((i) => i.toJson()).toList(),
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestThirdPartyUsers', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.requestThirdPartyUsers('irc');
      expect(
        FakeMatrixApi.api['GET']['/client/r0/thirdparty/user/irc']({}),
        response.map((i) => i.toJson()).toList(),
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestThirdPartyLocationsByAlias', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response =
          await matrixApi.requestThirdPartyLocationsByAlias('1234');
      expect(
        FakeMatrixApi.api['GET']
            ['/client/r0/thirdparty/location?alias=1234']({}),
        response.map((i) => i.toJson()).toList(),
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestThirdPartyUsersByUserId', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.requestThirdPartyUsersByUserId('1234');
      expect(
        FakeMatrixApi.api['GET']['/client/r0/thirdparty/user?userid=1234']({}),
        response.map((i) => i.toJson()).toList(),
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestOpenIdCredentials', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.requestOpenIdCredentials('1234');
      expect(
        FakeMatrixApi.api['POST']
            ['/client/r0/user/1234/openid/request_token']({}),
        response.toJson(),
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('upgradeRoom', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.upgradeRoom('1234', '2');

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('createRoomKeysBackup', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final algorithm = RoomKeysAlgorithmType.v1Curve25519AesSha2;
      final authData = <String, dynamic>{
        'public_key': 'GXYaxqhNhUK28zUdxOmEsFRguz+PzBsDlTLlF0O0RkM',
        'signatures': {},
      };
      final ret = await matrixApi.createRoomKeysBackup(algorithm, authData);
      expect(
          FakeMatrixApi.api['POST']
              ['/client/unstable/room_keys/version']({})['version'],
          ret);
    });
    test('getRoomKeysBackup', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final ret = await matrixApi.getRoomKeysBackup();
      expect(FakeMatrixApi.api['GET']['/client/unstable/room_keys/version']({}),
          ret.toJson());
    });
    test('updateRoomKeysBackup', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final algorithm = RoomKeysAlgorithmType.v1Curve25519AesSha2;
      final authData = <String, dynamic>{
        'public_key': 'GXYaxqhNhUK28zUdxOmEsFRguz+PzBsDlTLlF0O0RkM',
        'signatures': {},
      };
      await matrixApi.updateRoomKeysBackup('5', algorithm, authData);
    });
    test('deleteRoomKeysBackup', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.deleteRoomKeysBackup('5');
    });
    test('storeRoomKeysSingleKey', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final roomId = '!726s6s6q:example.com';
      final sessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
      final session = RoomKeysSingleKey.fromJson({
        'first_message_index': 0,
        'forwarded_count': 0,
        'is_verified': true,
        'session_data': {
          'ephemeral': 'fwRxYh+seqLykz5mQCLypJ4/59URdcFJ2s69OU1dGRc',
          'ciphertext':
              '19jkQYlbgdP+VL9DH3qY/Dvpk6onJZgf+6frZFl1TinPCm9OMK9AZZLuM1haS9XLAUK1YsREgjBqfl6T+Tq8JlJ5ONZGg2Wttt24sGYc0iTMZJ8rXcNDeKMZhM96ETyjufJSeYoXLqifiVLDw9rrVBmNStF7PskYp040em+0OZ4pF85Cwsdf7l9V7MMynzh9BoXqVUCBiwT03PNYH9AEmNUxXX+6ZwCpe/saONv8MgGt5uGXMZIK29phA3D8jD6uV/WOHsB8NjHNq9FrfSEAsl+dAcS4uiYie4BKSSeQN+zGAQqu1MMW4OAdxGOuf8WpIINx7n+7cKQfxlmc/Cgg5+MmIm2H0oDwQ+Xu7aSxp1OCUzbxQRdjz6+tnbYmZBuH0Ov2RbEvC5tDb261LRqKXpub0llg5fqKHl01D0ahv4OAQgRs5oU+4mq+H2QGTwIFGFqP9tCRo0I+aICawpxYOfoLJpFW6KvEPnM2Lr3sl6Nq2fmkz6RL5F7nUtzxN8OKazLQpv8DOYzXbi7+ayEsqS0/EINetq7RfCqgjrEUgfNWYuFXWqvUT8lnxLdNu+8cyrJqh1UquFjXWTw1kWcJ0pkokVeBtK9YysCnF1UYh/Iv3rl2ZoYSSLNtuvMSYlYHggZ8xV8bz9S3X2/NwBycBiWIy5Ou/OuSX7trIKgkkmda0xjBWEM1a2acVuqu2OFbMn2zFxm2a3YwKP//OlIgMg',
          'mac': 'QzKV/fgAs4U',
        },
      });
      final ret = await matrixApi.storeRoomKeysSingleKey(
          roomId, sessionId, '5', session);
      expect(
          FakeMatrixApi.api['PUT'][
              '/client/unstable/room_keys/keys/${Uri.encodeComponent('!726s6s6q:example.com')}/${Uri.encodeComponent('ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU')}?version=5']({}),
          ret.toJson());
    });
    test('getRoomKeysSingleKey', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final roomId = '!726s6s6q:example.com';
      final sessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
      final ret = await matrixApi.getRoomKeysSingleKey(roomId, sessionId, '5');
      expect(
          FakeMatrixApi.api['GET'][
              '/client/unstable/room_keys/keys/${Uri.encodeComponent('!726s6s6q:example.com')}/${Uri.encodeComponent('ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU')}?version=5']({}),
          ret.toJson());
    });
    test('deleteRoomKeysSingleKey', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final roomId = '!726s6s6q:example.com';
      final sessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
      final ret =
          await matrixApi.deleteRoomKeysSingleKey(roomId, sessionId, '5');
      expect(
          FakeMatrixApi.api['DELETE'][
              '/client/unstable/room_keys/keys/${Uri.encodeComponent('!726s6s6q:example.com')}/${Uri.encodeComponent('ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU')}?version=5']({}),
          ret.toJson());
    });
    test('storeRoomKeysRoom', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final roomId = '!726s6s6q:example.com';
      final sessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
      final session = RoomKeysRoom.fromJson({
        'sessions': {
          sessionId: {
            'first_message_index': 0,
            'forwarded_count': 0,
            'is_verified': true,
            'session_data': {
              'ephemeral': 'fwRxYh+seqLykz5mQCLypJ4/59URdcFJ2s69OU1dGRc',
              'ciphertext':
                  '19jkQYlbgdP+VL9DH3qY/Dvpk6onJZgf+6frZFl1TinPCm9OMK9AZZLuM1haS9XLAUK1YsREgjBqfl6T+Tq8JlJ5ONZGg2Wttt24sGYc0iTMZJ8rXcNDeKMZhM96ETyjufJSeYoXLqifiVLDw9rrVBmNStF7PskYp040em+0OZ4pF85Cwsdf7l9V7MMynzh9BoXqVUCBiwT03PNYH9AEmNUxXX+6ZwCpe/saONv8MgGt5uGXMZIK29phA3D8jD6uV/WOHsB8NjHNq9FrfSEAsl+dAcS4uiYie4BKSSeQN+zGAQqu1MMW4OAdxGOuf8WpIINx7n+7cKQfxlmc/Cgg5+MmIm2H0oDwQ+Xu7aSxp1OCUzbxQRdjz6+tnbYmZBuH0Ov2RbEvC5tDb261LRqKXpub0llg5fqKHl01D0ahv4OAQgRs5oU+4mq+H2QGTwIFGFqP9tCRo0I+aICawpxYOfoLJpFW6KvEPnM2Lr3sl6Nq2fmkz6RL5F7nUtzxN8OKazLQpv8DOYzXbi7+ayEsqS0/EINetq7RfCqgjrEUgfNWYuFXWqvUT8lnxLdNu+8cyrJqh1UquFjXWTw1kWcJ0pkokVeBtK9YysCnF1UYh/Iv3rl2ZoYSSLNtuvMSYlYHggZ8xV8bz9S3X2/NwBycBiWIy5Ou/OuSX7trIKgkkmda0xjBWEM1a2acVuqu2OFbMn2zFxm2a3YwKP//OlIgMg',
              'mac': 'QzKV/fgAs4U',
            },
          },
        },
      });
      final ret = await matrixApi.storeRoomKeysRoom(roomId, '5', session);
      expect(
          FakeMatrixApi.api['PUT'][
              '/client/unstable/room_keys/keys/${Uri.encodeComponent('!726s6s6q:example.com')}?version=5']({}),
          ret.toJson());
    });
    test('getRoomKeysRoom', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final roomId = '!726s6s6q:example.com';
      final ret = await matrixApi.getRoomKeysRoom(roomId, '5');
      expect(
          FakeMatrixApi.api['GET'][
              '/client/unstable/room_keys/keys/${Uri.encodeComponent('!726s6s6q:example.com')}?version=5']({}),
          ret.toJson());
    });
    test('deleteRoomKeysRoom', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final roomId = '!726s6s6q:example.com';
      final ret = await matrixApi.deleteRoomKeysRoom(roomId, '5');
      expect(
          FakeMatrixApi.api['DELETE'][
              '/client/unstable/room_keys/keys/${Uri.encodeComponent('!726s6s6q:example.com')}?version=5']({}),
          ret.toJson());
    });
    test('storeRoomKeys', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final roomId = '!726s6s6q:example.com';
      final sessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
      final session = RoomKeys.fromJson({
        'rooms': {
          roomId: {
            'sessions': {
              sessionId: {
                'first_message_index': 0,
                'forwarded_count': 0,
                'is_verified': true,
                'session_data': {
                  'ephemeral': 'fwRxYh+seqLykz5mQCLypJ4/59URdcFJ2s69OU1dGRc',
                  'ciphertext':
                      '19jkQYlbgdP+VL9DH3qY/Dvpk6onJZgf+6frZFl1TinPCm9OMK9AZZLuM1haS9XLAUK1YsREgjBqfl6T+Tq8JlJ5ONZGg2Wttt24sGYc0iTMZJ8rXcNDeKMZhM96ETyjufJSeYoXLqifiVLDw9rrVBmNStF7PskYp040em+0OZ4pF85Cwsdf7l9V7MMynzh9BoXqVUCBiwT03PNYH9AEmNUxXX+6ZwCpe/saONv8MgGt5uGXMZIK29phA3D8jD6uV/WOHsB8NjHNq9FrfSEAsl+dAcS4uiYie4BKSSeQN+zGAQqu1MMW4OAdxGOuf8WpIINx7n+7cKQfxlmc/Cgg5+MmIm2H0oDwQ+Xu7aSxp1OCUzbxQRdjz6+tnbYmZBuH0Ov2RbEvC5tDb261LRqKXpub0llg5fqKHl01D0ahv4OAQgRs5oU+4mq+H2QGTwIFGFqP9tCRo0I+aICawpxYOfoLJpFW6KvEPnM2Lr3sl6Nq2fmkz6RL5F7nUtzxN8OKazLQpv8DOYzXbi7+ayEsqS0/EINetq7RfCqgjrEUgfNWYuFXWqvUT8lnxLdNu+8cyrJqh1UquFjXWTw1kWcJ0pkokVeBtK9YysCnF1UYh/Iv3rl2ZoYSSLNtuvMSYlYHggZ8xV8bz9S3X2/NwBycBiWIy5Ou/OuSX7trIKgkkmda0xjBWEM1a2acVuqu2OFbMn2zFxm2a3YwKP//OlIgMg',
                  'mac': 'QzKV/fgAs4U',
                },
              },
            },
          },
        },
      });
      final ret = await matrixApi.storeRoomKeys('5', session);
      expect(
          FakeMatrixApi.api['PUT']
              ['/client/unstable/room_keys/keys?version=5']({}),
          ret.toJson());
    });
    test('getRoomKeys', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final ret = await matrixApi.getRoomKeys('5');
      expect(
          FakeMatrixApi.api['GET']
              ['/client/unstable/room_keys/keys?version=5']({}),
          ret.toJson());
    });
    test('deleteRoomKeys', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final ret = await matrixApi.deleteRoomKeys('5');
      expect(
          FakeMatrixApi.api['DELETE']
              ['/client/unstable/room_keys/keys?version=5']({}),
          ret.toJson());
    });
  });
}
