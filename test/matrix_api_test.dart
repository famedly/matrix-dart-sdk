/* MIT License
*
* Copyright (C) 2019, 2020, 2021 Famedly GmbH
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:matrix_api_lite/fake_matrix_api.dart';
import 'package:matrix_api_lite/matrix_api_lite.dart';

const emptyRequest = <String, Object?>{};

void main() {
  /// All Tests related to device keys
  group('Matrix API', () {
    test('Logger', () async {
      Logs().level = Level.verbose;
      Logs().v('Test log');
      Logs().d('Test log');
      Logs().w('Test log');
      Logs().e('Test log');
      Logs().wtf('Test log');
      Logs().v('Test log', Exception('There has been a verbose'));
      Logs().d('Test log', Exception('Test'));
      Logs().w('Test log', Exception('Very bad error'));
      Logs().e('Test log', Exception('Test'), StackTrace.current);
      Logs().wtf('Test log', Exception('Test'), StackTrace.current);
    });
    Logs().level = Level.error;
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
      expect(exception.authenticationFlows!.first.stages.first,
          'example.type.foo');
      expect(exception.authenticationParams!['example.type.baz'],
          {'example_key': 'foobar'});
      expect(exception.session, 'xxxxxxyz');
      expect(exception.completedAuthenticationFlows, ['example.type.foo']);
      expect(exception.requireAdditionalAuthentication, true);
      expect(exception.retryAfterMs, null);
      expect(exception.error, MatrixError.M_FORBIDDEN);
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
        expect(exception.error, MatrixError.M_FORBIDDEN);
        expect(exception.errorMessage, 'Blabla');
        expect(exception.requireAdditionalAuthentication, false);
        expect(exception.toString(), 'M_FORBIDDEN: Blabla');
        error = true;
      }
      expect(error, true);
      matrixApi.homeserver = null;
    });
    test('getSupportedVersions', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      final supportedVersions = await matrixApi.getVersions();
      expect(supportedVersions.versions.contains('r0.5.0'), true);
      expect(supportedVersions.unstableFeatures!['m.lazy_load_members'], true);
      expect(FakeMatrixApi.api['GET']!['/client/versions']!.call(emptyRequest),
          supportedVersions.toJson());
      matrixApi.homeserver = null;
    });
    test('getWellKnownInformation', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      final wellKnownInformation = await matrixApi.getWellknown();
      expect(wellKnownInformation.mHomeserver.baseUrl,
          Uri.parse('https://fakeserver.notexisting'));
      expect(wellKnownInformation.toJson(), {
        'm.homeserver': {'base_url': 'https://fakeserver.notexisting'},
        'm.identity_server': {
          'base_url': 'https://identity.fakeserver.notexisting'
        },
        'org.example.custom.property': {
          'app_url': 'https://custom.app.fakeserver.notexisting'
        }
      });
    });
    test('getLoginTypes', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      final loginTypes = await matrixApi.getLoginFlows();
      expect(loginTypes?.first.type, 'm.login.password');
      expect(FakeMatrixApi.api['GET']!['/client/v3/login']!.call(emptyRequest),
          {'flows': loginTypes?.map((x) => x.toJson()).toList()});
      matrixApi.homeserver = null;
    });
    test('login', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      final loginResponse = await matrixApi.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: 'username'),
      );
      expect(FakeMatrixApi.api['POST']!['/client/v3/login']!.call(emptyRequest),
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
          await matrixApi.register(kind: AccountKind.guest, username: 'test');
      expect(
          FakeMatrixApi.api['POST']!['/client/v3/register?kind=guest']!
              .call(emptyRequest),
          registerResponse.toJson());
      matrixApi.homeserver = null;
    });
    test('requestTokenToRegisterEmail', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      final response = await matrixApi.requestTokenToRegisterEmail(
        'alice@example.com',
        '1234',
        1,
        nextLink: 'https://example.com',
        idServer: 'https://example.com',
        idAccessToken: '1234',
      );
      expect(
          FakeMatrixApi.api['POST']!['/client/v3/register/email/requestToken']!
              .call(emptyRequest),
          response.toJson());
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestTokenToRegisterMSISDN', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      final response = await matrixApi.requestTokenToRegisterMSISDN(
        'en',
        '1234',
        '1234',
        1,
        nextLink: 'https://example.com',
        idServer: 'https://example.com',
        idAccessToken: '1234',
      );
      expect(
          FakeMatrixApi.api['POST']!['/client/v3/register/email/requestToken']!
              .call(emptyRequest),
          response.toJson());
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('changePassword', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      await matrixApi.changePassword(
        '1234',
        auth: AuthenticationData.fromJson({
          'type': 'example.type.foo',
          'session': 'xxxxx',
          'example_credential': 'verypoorsharedsecret'
        }),
      );
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestTokenToResetPasswordEmail', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      await matrixApi.requestTokenToResetPasswordEmail(
        'alice@example.com',
        '1234',
        1,
        nextLink: 'https://example.com',
        idServer: 'https://example.com',
        idAccessToken: '1234',
      );
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestTokenToResetPasswordMSISDN', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      await matrixApi.requestTokenToResetPasswordMSISDN(
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
      final response = await matrixApi.deactivateAccount(
        idServer: 'https://example.com',
        auth: AuthenticationData.fromJson({
          'type': 'example.type.foo',
          'session': 'xxxxx',
          'example_credential': 'verypoorsharedsecret'
        }),
      );
      expect(response, IdServerUnbindResult.success);
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('usernameAvailable', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      final loginResponse =
          await matrixApi.checkUsernameAvailability('testuser');
      expect(loginResponse, true);
      matrixApi.homeserver = null;
    });
    test('getThirdPartyIdentifiers', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      final response = await matrixApi.getAccount3PIDs();
      expect(
          FakeMatrixApi.api['GET']!['/client/v3/account/3pid']!
              .call(emptyRequest),
          {'threepids': response?.map((t) => t.toJson()).toList()});
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('addThirdPartyIdentifier', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      await matrixApi.add3PID('1234', '1234',
          auth: AuthenticationData.fromJson({'type': 'm.login.dummy'}));
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('bindThirdPartyIdentifier', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      await matrixApi.bind3PID(
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
      final response = await matrixApi.delete3pidFromAccount(
        'alice@example.com',
        ThirdPartyIdentifierMedium.email,
        idServer: 'https://example.com',
      );
      expect(response, IdServerUnbindResult.success);
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('unbindThirdPartyIdentifier', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      final response = await matrixApi.unbind3pidFromAccount(
        'alice@example.com',
        ThirdPartyIdentifierMedium.email,
        idServer: 'https://example.com',
      );
      expect(response, IdServerUnbindResult.success);
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestTokenTo3PIDEmail', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      await matrixApi.requestTokenTo3PIDEmail(
        'alice@example.com',
        '1234',
        1,
        nextLink: 'https://example.com',
        idServer: 'https://example.com',
        idAccessToken: '1234',
      );
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestTokenTo3PIDMSISDN', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      await matrixApi.requestTokenTo3PIDMSISDN(
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
    test('requestTokenTo3PIDMSISDN', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      final response = await matrixApi.getTokenOwner();
      expect(response.userId, 'alice@example.com');
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('getCapabilities', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      final response = await matrixApi.getCapabilities();
      expect(
          FakeMatrixApi.api['GET']!['/client/v3/capabilities']!
              .call(emptyRequest),
          {'capabilities': response.toJson()});
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('uploadFilter', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      final response =
          await matrixApi.defineFilter('alice@example.com', Filter());
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
        presence: StateFilter(
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
            'senders': ['@alice:example.com'],
            'types': ['type1'],
            'not_rooms': ['!1234'],
            'not_senders': ['@bob:example.com'],
            'not_types': ['type2'],
            'lazy_load_members': true,
            'include_redundant_members': false,
            'contains_url': true,
          },
          'account_data': {
            'limit': 10,
            'types': ['type1'],
          },
          'include_leave': true,
          'state': <String, Object?>{},
          'timeline': <String, Object?>{},
        },
        'presence': {
          'limit': 10,
          'senders': ['@alice:example.com'],
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
      await matrixApi.defineFilter(
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
      await matrixApi.getFilter('alice@example.com', '1234');
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
          FakeMatrixApi.api['GET']![
                  '/client/v3/sync?filter=%7B%7D&since=1234&full_state=false&set_presence=unavailable&timeout=15']!
              .call(emptyRequest) as Map?,
          response.toJson());
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestEvent', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final event =
          await matrixApi.getOneRoomEvent('!localpart:server.abc', '1234');
      expect(event.eventId, '143273582443PhrSn:example.org');
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('getRoomStateWithKey', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.getRoomStateWithKey(
        '!localpart:server.abc',
        'm.room.member',
        '@getme:example.com',
      );
      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestStates', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final states = await matrixApi.getRoomState('!localpart:server.abc');
      expect(states.length, 4);

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestMembers', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final states = await matrixApi.getMembersByRoom(
        '!localpart:server.abc',
        at: '1234',
        membership: Membership.join,
        notMembership: Membership.leave,
      );
      expect(states?.length, 1);

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestJoinedMembers', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final states = await matrixApi.getJoinedMembersByRoom(
        '!localpart:server.abc',
      );
      expect(states?.length, 1);
      expect(states?['@bar:example.com']?.toJson(), {
        'display_name': 'Bar',
        'avatar_url': 'mxc://riot.ovh/printErCATzZijQsSDWorRaK'
      });

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestMessages', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final timelineHistoryResponse = await matrixApi.getRoomEvents(
        '!localpart:server.abc',
        Direction.b,
        from: '1234',
        limit: 10,
        filter: '{"lazy_load_members":true}',
        to: '1234',
      );

      expect(
          FakeMatrixApi.api['GET']![
                  '/client/v3/rooms/!localpart%3Aserver.abc/messages?from=1234&to=1234&dir=b&limit=10&filter=%7B%22lazy_load_members%22%3Atrue%7D']!
              .call(emptyRequest) as Map?,
          timelineHistoryResponse.toJson());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('sendState', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final eventId = await matrixApi.setRoomStateWithKey(
          '!localpart:server.abc', 'm.room.avatar', '', {'url': 'mxc://1234'});

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

      final eventId = await matrixApi.redactEvent(
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
        preset: CreateRoomPreset.publicChat,
        isDirect: false,
        powerLevelContentOverride: {},
      );

      expect(roomId, '!1234:fakeServer.notExisting');

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('createRoomAlias', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.setRoomAlias(
        '#testalias:example.com',
        '!1234:example.com',
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestRoomAliasInformation', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final roomAliasInformation = await matrixApi.getRoomIdByAlias(
        '#testalias:example.com',
      );

      expect(
          FakeMatrixApi.api['GET']![
                  '/client/v3/directory/room/%23testalias%3Aexample.com']!
              .call(emptyRequest),
          roomAliasInformation.toJson());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('removeRoomAlias', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.deleteRoomAlias('#testalias:example.com');

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestRoomAliases', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final list = await matrixApi.getLocalAliases('!localpart:example.com');
      expect(list.length, 3);

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestJoinedRooms', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final list = await matrixApi.getJoinedRooms();
      expect(list.length, 1);

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('inviteUser', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.inviteUser('!localpart:example.com', '@bob:example.com');

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('joinRoom', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final roomId = '!localpart:example.com';
      final response = await matrixApi.joinRoomById(
        roomId,
        thirdPartySigned: ThirdPartySigned(
          sender: '@bob:example.com',
          mxid: '@alice:example.com',
          token: '1234',
          signatures: {
            'example.org': {'ed25519:0': 'some9signature'}
          },
        ),
      );
      expect(response, roomId);

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('joinRoomOrAlias', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final roomId = '!localpart:example.com';
      final response = await matrixApi.joinRoom(
        roomId,
        serverName: ['example.com', 'example.abc'],
        thirdPartySigned: ThirdPartySigned(
          sender: '@bob:example.com',
          mxid: '@alice:example.com',
          token: '1234',
          signatures: {
            'example.org': {'ed25519:0': 'some9signature'}
          },
        ),
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

      await matrixApi.kick(
        '!localpart:example.com',
        '@bob:example.com',
        reason: 'test',
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('banFromRoom', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.ban(
        '!localpart:example.com',
        '@bob:example.com',
        reason: 'test',
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('unbanInRoom', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.unban(
        '!localpart:example.com',
        '@bob:example.com',
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestRoomVisibility', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final visibility = await matrixApi
          .getRoomVisibilityOnDirectory('!localpart:example.com');
      expect(visibility, Visibility.public);

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('setRoomVisibility', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.setRoomVisibilityOnDirectory('!localpart:example.com',
          visibility: Visibility.private);

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestPublicRooms', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.getPublicRooms(
        limit: 10,
        since: '1234',
        server: 'example.com',
      );

      expect(
          FakeMatrixApi.api['GET']![
                  '/client/v3/publicRooms?limit=10&since=1234&server=example.com']!
              .call(emptyRequest),
          response.toJson());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('searchPublicRooms', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.queryPublicRooms(
        limit: 10,
        since: '1234',
        server: 'example.com',
        filter: PublicRoomQueryFilter(
          genericSearchTerm: 'test',
        ),
        includeAllNetworks: false,
        thirdPartyInstanceId: 'id',
      );

      expect(
          FakeMatrixApi
              .api['POST']!['/client/v3/publicRooms?server=example.com']!
              .call(emptyRequest),
          response.toJson());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('getSpaceHierarchy', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response =
          await matrixApi.getSpaceHierarchy('!gPxZhKUssFZKZcoCKY:neko.dev');

      expect(
          FakeMatrixApi.api['GET']![
                  '/client/v1/rooms/${Uri.encodeComponent('!gPxZhKUssFZKZcoCKY:neko.dev')}/hierarchy']!
              .call(emptyRequest),
          response.toJson());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('searchUser', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.searchUserDirectory(
        'test',
        limit: 10,
      );

      expect(
          FakeMatrixApi.api['POST']!['/client/v3/user_directory/search']!
              .call(emptyRequest),
          response.toJson());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('setDisplayname', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.setDisplayName('@alice:example.com', 'Alice M');

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestDisplayname', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.getDisplayName('@alice:example.com');

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

      final response = await matrixApi.getAvatarUrl('@alice:example.com');
      expect(response, Uri.parse('mxc://test'));

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestProfile', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.getUserProfile('@alice:example.com');
      expect(
          FakeMatrixApi
              .api['GET']!['/client/v3/profile/%40alice%3Aexample.com']!
              .call(emptyRequest),
          response.toJson());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestTurnServerCredentials', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.getTurnServer();
      expect(
          FakeMatrixApi.api['GET']!['/client/v3/voip/turnServer']!
              .call(emptyRequest),
          response.toJson());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('sendTypingNotification', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.setTyping(
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

      await matrixApi.postReceipt(
        '!localpart:example.com',
        ReceiptType.mRead,
        '\$1234:example.com',
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('sendReadMarker', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.setReadMarker(
        '!localpart:example.com',
        mFullyRead: '\$1234:example.com',
        mRead: '\$1234:example.com',
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('sendPresence', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.setPresence(
        '@alice:example.com',
        PresenceType.offline,
        statusMsg: 'test',
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestPresence', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.getPresence(
        '@alice:example.com',
      );
      expect(
          FakeMatrixApi.api['GET']![
                  '/client/v3/presence/${Uri.encodeComponent('@alice:example.com')}/status']!
              .call(emptyRequest),
          response.toJson());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('upload', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';
      final response =
          await matrixApi.uploadContent(Uint8List(0), filename: 'file.jpeg');
      expect(response, Uri.parse('mxc://example.com/AQwafuaFswefuhsfAFAgsw'));
      var throwsException = false;
      try {
        await matrixApi.uploadContent(Uint8List(0), filename: 'file.jpg');
      } catch (_) {
        throwsException = true;
      }
      expect(throwsException, true);
      matrixApi.homeserver = null;
    });
    test('requestOpenGraphDataForUrl', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final openGraphData = await matrixApi.getUrlPreview(
        Uri.parse('https://matrix.org'),
        ts: 10,
      );
      expect(
          FakeMatrixApi.api['GET']![
                  '/media/v3/preview_url?url=https%3A%2F%2Fmatrix.org&ts=10']!
              .call(emptyRequest),
          openGraphData.toJson());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('getConfig', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.getConfig();
      expect(response.mUploadSize, 50000000);

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

      final devices = await matrixApi.getDevices();
      expect(
          (FakeMatrixApi.api['GET']!['/client/v3/devices']!.call(emptyRequest)
              as Map<String, Object?>?)?['devices'],
          devices?.map((i) => i.toJson()).toList());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestDevice', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.getDevice('QBUAZIFURK');

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('setDeviceMetadata', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.updateDevice('QBUAZIFURK', displayName: 'test');

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('deleteDevice', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.deleteDevice('QBUAZIFURK');

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('deleteDevices', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.deleteDevices(['QBUAZIFURK']);

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('uploadDeviceKeys', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.uploadKeys(
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

      final response = await matrixApi.queryKeys(
        {
          '@alice:example.com': [],
        },
        timeout: 10,
        token: '1234',
      );
      expect(
          response.deviceKeys!['@alice:example.com']!['JLAFKJWSCS']!
              .deviceDisplayName,
          'Alices mobile phone');
      expect(
          FakeMatrixApi.api['POST']!['/client/v3/keys/query']!
              .call({'device_keys': emptyRequest}),
          response.toJson());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestOneTimeKeys', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.claimKeys(
        {
          '@alice:example.com': {'JLAFKJWSCS': 'signed_curve25519'}
        },
        timeout: 10,
      );
      expect(
          FakeMatrixApi.api['POST']!['/client/v3/keys/claim']!.call({
            'one_time_keys': {
              '@alice:example.com': {'JLAFKJWSCS': 'signed_curve25519'}
            }
          }),
          response.toJson());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestDeviceListsUpdate', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.getKeysChanges('1234', '1234');

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('uploadCrossSigningKeys', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final masterKey = MatrixCrossSigningKey.fromJson({
        'user_id': '@test:fakeServer.notExisting',
        'usage': ['master'],
        'keys': {
          'ed25519:82mAXjsmbTbrE6zyShpR869jnrANO75H8nYY0nDLoJ8':
              '82mAXjsmbTbrE6zyShpR869jnrANO75H8nYY0nDLoJ8',
        },
        'signatures': <String, Map<String, String>>{},
      });
      final selfSigningKey = MatrixCrossSigningKey.fromJson({
        'user_id': '@test:fakeServer.notExisting',
        'usage': ['self_signing'],
        'keys': {
          'ed25519:F9ypFzgbISXCzxQhhSnXMkc1vq12Luna3Nw5rqViOJY':
              'F9ypFzgbISXCzxQhhSnXMkc1vq12Luna3Nw5rqViOJY',
        },
        'signatures': <String, Map<String, String>>{},
      });
      final userSigningKey = MatrixCrossSigningKey.fromJson({
        'user_id': '@test:fakeServer.notExisting',
        'usage': ['user_signing'],
        'keys': {
          'ed25519:0PiwulzJ/RU86LlzSSZ8St80HUMN3dqjKa/orIJoA0g':
              '0PiwulzJ/RU86LlzSSZ8St80HUMN3dqjKa/orIJoA0g',
        },
        'signatures': <String, Map<String, String>>{},
      });
      await matrixApi.uploadCrossSigningKeys(
          masterKey: masterKey,
          selfSigningKey: selfSigningKey,
          userSigningKey: userSigningKey);
    });
    test('requestPushers', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.getPushers();
      expect(
        FakeMatrixApi.api['GET']!['/client/v3/pushers']!
            .call(<String, Object?>{}),
        {'pushers': response?.map((i) => i.toJson()).toList()},
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('setPusher', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.postPusher(
        Pusher(
          pushkey: '1234',
          appId: 'app.id',
          appDisplayName: 'appDisplayName',
          deviceDisplayName: 'deviceDisplayName',
          lang: 'en',
          data: PusherData(
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

      final response = await matrixApi.getNotifications(
        from: '1234',
        limit: 10,
        only: '1234',
      );
      expect(
        FakeMatrixApi.api['GET']![
                '/client/v3/notifications?from=1234&limit=10&only=1234']!
            .call(<String, Object?>{}),
        response.toJson(),
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestPushRules', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.getPushRules();
      expect(
        FakeMatrixApi.api['GET']!['/client/v3/pushrules']!
            .call(<String, Object?>{}),
        {'global': response.toJson()},
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestPushRule', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response =
          await matrixApi.getPushRule('global', PushRuleKind.content, 'nocake');
      expect(
        FakeMatrixApi.api['GET']!['/client/v3/pushrules/global/content/nocake']!
            .call(<String, Object?>{}),
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
          PushCondition(
            kind: 'event_match',
            key: 'key',
            pattern: 'pattern',
            is$: '+',
          )
        ],
        pattern: 'pattern',
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestPushRuleEnabled', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final enabled = await matrixApi.isPushRuleEnabled(
          'global', PushRuleKind.content, 'nocake');
      expect(enabled, true);

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('enablePushRule', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.setPushRuleEnabled(
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

      final actions = await matrixApi.getPushRuleActions(
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
        [PushRuleAction.dontNotify],
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('globalSearch', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.search(Categories());

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('globalSearch', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.peekEvents(
          from: '1234', roomId: '!1234', timeout: 10);
      expect(
        FakeMatrixApi.api['GET']![
                '/client/v3/events?from=1234&timeout=10&room_id=%211234']!
            .call(<String, Object?>{}),
        response.toJson(),
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestRoomTags', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.getRoomTags(
          '@alice:example.com', '!localpart:example.com');
      expect(
        FakeMatrixApi.api['GET']![
                '/client/v3/user/%40alice%3Aexample.com/rooms/!localpart%3Aexample.com/tags']!
            .call(<String, Object?>{}),
        {'tags': response?.map((k, v) => MapEntry(k, v.toJson()))},
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('addRoomTag', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.setRoomTag(
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

      await matrixApi.deleteRoomTag(
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

      await matrixApi.getAccountData(
        '@alice:example.com',
        'test.account.data',
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('setRoomAccountData', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.setAccountDataPerRoom(
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

      await matrixApi.getAccountDataPerRoom(
        '@alice:example.com',
        '1234',
        'test.account.data',
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestWhoIsInfo', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.getWhoIs('@alice:example.com');
      expect(
        FakeMatrixApi
            .api['GET']!['/client/v3/admin/whois/%40alice%3Aexample.com']!
            .call(emptyRequest),
        response.toJson(),
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestEventContext', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.getEventContext('1234', '1234',
          limit: 10, filter: '{}');
      expect(
        FakeMatrixApi.api['GET']![
                '/client/v3/rooms/1234/context/1234?limit=10&filter=%7B%7D']!
            .call(emptyRequest),
        response.toJson(),
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('reportEvent', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.reportContent(
        '1234',
        '1234',
        reason: 'test',
        score: -100,
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('getProtocols', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.getProtocols();
      expect(
        FakeMatrixApi.api['GET']!['/client/v3/thirdparty/protocols']!
            .call(emptyRequest),
        response.map((k, v) => MapEntry(k, v.toJson())),
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('getProtocol', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.getProtocolMetadata('irc');
      expect(
        FakeMatrixApi.api['GET']!['/client/v3/thirdparty/protocol/irc']!
            .call(emptyRequest),
        response.toJson(),
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('queryLocationByProtocol', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.queryLocationByProtocol('irc');
      expect(
        FakeMatrixApi.api['GET']!['/client/v3/thirdparty/location/irc']!
            .call(emptyRequest),
        response.map((i) => i.toJson()).toList(),
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('queryUserByProtocol', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.queryUserByProtocol('irc');
      expect(
        FakeMatrixApi.api['GET']!['/client/v3/thirdparty/user/irc']!
            .call(emptyRequest),
        response.map((i) => i.toJson()).toList(),
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('queryLocationByAlias', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.queryLocationByAlias('1234');
      expect(
        FakeMatrixApi.api['GET']!['/client/v3/thirdparty/location?alias=1234']!
            .call(emptyRequest),
        response.map((i) => i.toJson()).toList(),
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('queryUserByID', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.queryUserByID('1234');
      expect(
        FakeMatrixApi.api['GET']!['/client/v3/thirdparty/user?userid=1234']!
            .call(emptyRequest),
        response.map((i) => i.toJson()).toList(),
      );

      matrixApi.homeserver = matrixApi.accessToken = null;
    });
    test('requestOpenIdCredentials', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final response = await matrixApi.requestOpenIdToken('1234', {});
      expect(
        FakeMatrixApi.api['POST']!['/client/v3/user/1234/openid/request_token']!
            .call(emptyRequest),
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
    test('postRoomKeysVersion', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final algorithm = BackupAlgorithm.mMegolmBackupV1Curve25519AesSha2;
      final authData = <String, Object?>{
        'public_key': 'GXYaxqhNhUK28zUdxOmEsFRguz+PzBsDlTLlF0O0RkM',
        'signatures': <String, Map<String, String>>{},
      };
      final ret = await matrixApi.postRoomKeysVersion(algorithm, authData);
      expect(
          (FakeMatrixApi.api['POST']!['/client/v3/room_keys/version']!
              .call(emptyRequest) as Map<String, Object?>)['version'],
          ret);
    });
    test('getRoomKeysVersionCurrent', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final ret = await matrixApi.getRoomKeysVersionCurrent();
      expect(
          FakeMatrixApi.api['GET']!['/client/v3/room_keys/version']!
              .call(emptyRequest),
          ret.toJson());
    });
    test('putRoomKeysVersion', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final algorithm = BackupAlgorithm.mMegolmBackupV1Curve25519AesSha2;
      final authData = <String, Object?>{
        'public_key': 'GXYaxqhNhUK28zUdxOmEsFRguz+PzBsDlTLlF0O0RkM',
        'signatures': <String, Map<String, String>>{},
      };
      await matrixApi.putRoomKeysVersion('5', algorithm, authData);
    });
    test('deleteRoomKeys', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      await matrixApi.deleteRoomKeys('5');
    });
    test('putRoomKeyBySessionId', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final roomId = '!726s6s6q:example.com';
      final sessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
      final session = KeyBackupData.fromJson({
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
      final ret = await matrixApi.putRoomKeyBySessionId(
          roomId, sessionId, '5', session);
      expect(
          FakeMatrixApi.api['PUT']![
                  '/client/v3/room_keys/keys/${Uri.encodeComponent('!726s6s6q:example.com')}/${Uri.encodeComponent('ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU')}?version=5']!
              .call(emptyRequest),
          ret.toJson());
    });
    test('getRoomKeyBySessionId', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final roomId = '!726s6s6q:example.com';
      final sessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
      final ret = await matrixApi.getRoomKeyBySessionId(roomId, sessionId, '5');
      expect(
          FakeMatrixApi.api['GET']![
                  '/client/v3/room_keys/keys/${Uri.encodeComponent('!726s6s6q:example.com')}/${Uri.encodeComponent('ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU')}?version=5']!
              .call(emptyRequest),
          ret.toJson());
    });
    test('deleteRoomKeyBySessionId', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final roomId = '!726s6s6q:example.com';
      final sessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
      final ret =
          await matrixApi.deleteRoomKeyBySessionId(roomId, sessionId, '5');
      expect(
          FakeMatrixApi.api['DELETE']![
                  '/client/v3/room_keys/keys/${Uri.encodeComponent('!726s6s6q:example.com')}/${Uri.encodeComponent('ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU')}?version=5']!
              .call(emptyRequest),
          ret.toJson());
    });
    test('putRoomKeysByRoomId', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final roomId = '!726s6s6q:example.com';
      final sessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
      final session = RoomKeyBackup.fromJson({
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
      final ret = await matrixApi.putRoomKeysByRoomId(roomId, '5', session);
      expect(
          FakeMatrixApi.api['PUT']![
                  '/client/v3/room_keys/keys/${Uri.encodeComponent('!726s6s6q:example.com')}?version=5']!
              .call(emptyRequest),
          ret.toJson());
    });
    test('getRoomKeysByRoomId', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final roomId = '!726s6s6q:example.com';
      final ret = await matrixApi.getRoomKeysByRoomId(roomId, '5');
      expect(
          FakeMatrixApi.api['GET']![
                  '/client/v3/room_keys/keys/${Uri.encodeComponent('!726s6s6q:example.com')}?version=5']!
              .call(emptyRequest),
          ret.toJson());
    });
    test('deleteRoomKeysByRoomId', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final roomId = '!726s6s6q:example.com';
      final ret = await matrixApi.deleteRoomKeysByRoomId(roomId, '5');
      expect(
          FakeMatrixApi.api['DELETE']![
                  '/client/v3/room_keys/keys/${Uri.encodeComponent('!726s6s6q:example.com')}?version=5']!
              .call(emptyRequest),
          ret.toJson());
    });
    test('putRoomKeys', () async {
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
      final ret = await matrixApi.putRoomKeys('5', session);
      expect(
          FakeMatrixApi.api['PUT']!['/client/v3/room_keys/keys?version=5']!
              .call(emptyRequest),
          ret.toJson());
    });
    test('getRoomKeys', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final ret = await matrixApi.getRoomKeys('5');
      expect(
          FakeMatrixApi.api['GET']!['/client/v3/room_keys/keys?version=5']!
              .call(emptyRequest),
          ret.toJson());
    });
    test('deleteRoomKeys', () async {
      matrixApi.homeserver = Uri.parse('https://fakeserver.notexisting');
      matrixApi.accessToken = '1234';

      final ret = await matrixApi.deleteRoomKeys('5');
      expect(
          FakeMatrixApi.api['DELETE']!['/client/v3/room_keys/keys?version=5']!
              .call(emptyRequest),
          ret.toJson());
    });
    test('AuthenticationData', () {
      final json = {'session': '1234', 'type': 'm.login.dummy'};
      expect(AuthenticationData.fromJson(json).toJson(), json);
      expect(
          AuthenticationData(session: '1234', type: 'm.login.dummy').toJson(),
          json);
    });
    test('AuthenticationRecaptcha', () {
      final json = {
        'session': '1234',
        'type': 'm.login.recaptcha',
        'response': 'a',
      };
      expect(AuthenticationRecaptcha.fromJson(json).toJson(), json);
      expect(AuthenticationRecaptcha(session: '1234', response: 'a').toJson(),
          json);
    });
    test('AuthenticationToken', () {
      final json = {
        'session': '1234',
        'type': 'm.login.token',
        'token': 'a',
        'txn_id': '1'
      };
      expect(AuthenticationToken.fromJson(json).toJson(), json);
      expect(
          AuthenticationToken(session: '1234', token: 'a', txnId: '1').toJson(),
          json);
    });
    test('AuthenticationThreePidCreds', () {
      final json = {
        'type': 'm.login.email.identity',
        'threepid_creds': {
          'sid': '1',
          'client_secret': 'a',
          'id_server': 'matrix.org',
          'id_access_token': 'a',
        },
        'session': '1',
      };
      expect(AuthenticationThreePidCreds.fromJson(json).toJson(), json);
      expect(
          AuthenticationThreePidCreds(
            session: '1',
            type: AuthenticationTypes.emailIdentity,
            threepidCreds: ThreepidCreds(
              sid: '1',
              clientSecret: 'a',
              idServer: 'matrix.org',
              idAccessToken: 'a',
            ),
          ).toJson(),
          json);
    });
    test('AuthenticationIdentifier', () {
      final json = {'type': 'm.id.user'};
      expect(AuthenticationIdentifier.fromJson(json).toJson(), json);
      expect(AuthenticationIdentifier(type: 'm.id.user').toJson(), json);
    });
    test('AuthenticationPassword', () {
      final json = {
        'type': 'm.login.password',
        'identifier': {'type': 'm.id.user', 'user': 'a'},
        'password': 'a',
        'session': '1',
      };
      expect(AuthenticationPassword.fromJson(json).toJson(), json);
      expect(
          AuthenticationPassword(
            session: '1',
            password: 'a',
            identifier: AuthenticationUserIdentifier(user: 'a'),
          ).toJson(),
          json);
      json['identifier'] = {
        'type': 'm.id.thirdparty',
        'medium': 'a',
        'address': 'a',
      };
      expect(AuthenticationPassword.fromJson(json).toJson(), json);
      expect(
          AuthenticationPassword(
            session: '1',
            password: 'a',
            identifier:
                AuthenticationThirdPartyIdentifier(medium: 'a', address: 'a'),
          ).toJson(),
          json);
      json['identifier'] = {
        'type': 'm.id.phone',
        'country': 'a',
        'phone': 'a',
      };
      expect(AuthenticationPassword.fromJson(json).toJson(), json);
      expect(
          AuthenticationPassword(
            session: '1',
            password: 'a',
            identifier: AuthenticationPhoneIdentifier(country: 'a', phone: 'a'),
          ).toJson(),
          json);
    });
  });
}
