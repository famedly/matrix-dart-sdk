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

import 'dart:convert';

import 'package:test/test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:matrix/matrix.dart';
import './fake_client.dart';

void main() async {
  /// All Tests related to device keys
  group('Device keys', tags: 'olm', () {
    Logs().level = Level.error;

    late Client client;

    Future? vodInit;

    test('setupClient', () async {
      vodInit ??= vod.init(
        wasmPath: './pkg/',
        libraryPath: './rust/target/debug/',
      );
      await vodInit;
      client = await getClient();
      await client.abortSync();
    });

    test('fromJson', () async {
      var rawJson = <String, dynamic>{
        'user_id': '@alice:example.com',
        'device_id': 'JLAFKJWSCS',
        'algorithms': [
          AlgorithmTypes.olmV1Curve25519AesSha2,
          AlgorithmTypes.megolmV1AesSha2,
        ],
        'keys': {
          'curve25519:JLAFKJWSCS':
              '3C5BFWi2Y8MaVvjM8M22DBmh24PmgR0nPvJOIArzgyI',
          'ed25519:JLAFKJWSCS': 'lEuiRJBit0IG6nUf5pUzWTUEsRVVe/HJkoKuEww9ULI',
        },
        'signatures': {
          '@alice:example.com': {
            'ed25519:JLAFKJWSCS':
                'dSO80A01XiigH3uBiDVx/EjzaoycHcjq9lfQX0uWsqxl2giMIiSPR8a4d291W1ihKJL/a+myXS367WT6NAIcBA',
          },
        },
        'unsigned': {'device_display_name': "Alice's mobile phone"},
      };

      final key = DeviceKeys.fromJson(rawJson, client);
      // NOTE(Nico): this actually doesn't do anything, because the device signature is invalid...
      await key.setVerified(false, false);
      await key.setBlocked(true);
      expect(json.encode(key.toJson()), json.encode(rawJson));
      expect(key.directVerified, false);
      expect(key.blocked, true);

      rawJson = <String, dynamic>{
        'user_id': '@test:fakeServer.notExisting',
        'usage': ['master'],
        'keys': {
          'ed25519:82mAXjsmbTbrE6zyShpR869jnrANO75H8nYY0nDLoJ8':
              '82mAXjsmbTbrE6zyShpR869jnrANO75H8nYY0nDLoJ8',
        },
        'signatures': {},
      };
      final crossKey = CrossSigningKey.fromJson(rawJson, client);
      expect(json.encode(crossKey.toJson()), json.encode(rawJson));
      expect(crossKey.usage.first, 'master');
    });

    test('reject devices without self-signature', () async {
      var key = DeviceKeys.fromJson(
        {
          'user_id': '@test:fakeServer.notExisting',
          'device_id': 'BADDEVICE',
          'algorithms': [
            AlgorithmTypes.olmV1Curve25519AesSha2,
            AlgorithmTypes.megolmV1AesSha2,
          ],
          'keys': {
            'curve25519:BADDEVICE':
                'ds6+bItpDiWyRaT/b0ofoz1R+GCy7YTbORLJI4dmYho',
            'ed25519:BADDEVICE': 'CdDKVf44LO2QlfWopP6VWmqedSrRaf9rhHKvdVyH38w',
          },
        },
        client,
      );
      expect(key.isValid, false);
      expect(key.selfSigned, false);
      key = DeviceKeys.fromJson(
        {
          'user_id': '@test:fakeServer.notExisting',
          'device_id': 'BADDEVICE',
          'algorithms': [
            AlgorithmTypes.olmV1Curve25519AesSha2,
            AlgorithmTypes.megolmV1AesSha2,
          ],
          'keys': {
            'curve25519:BADDEVICE':
                'ds6+bItpDiWyRaT/b0ofoz1R+GCy7YTbORLJI4dmYho',
            'ed25519:BADDEVICE': 'CdDKVf44LO2QlfWopP6VWmqedSrRaf9rhHKvdVyH38w',
          },
          'signatures': {
            '@test:fakeServer.notExisting': {
              'ed25519:BADDEVICE': 'invalid',
            },
          },
        },
        client,
      );
      expect(key.isValid, false);
      expect(key.selfSigned, false);
    });

    test('set blocked / verified', () async {
      final key =
          client.userDeviceKeys[client.userID]!.deviceKeys['OTHERDEVICE']!;
      client.userDeviceKeys[client.userID]?.deviceKeys['UNSIGNEDDEVICE'] =
          DeviceKeys.fromJson(
        {
          'user_id': '@test:fakeServer.notExisting',
          'device_id': 'UNSIGNEDDEVICE',
          'algorithms': [
            AlgorithmTypes.olmV1Curve25519AesSha2,
            AlgorithmTypes.megolmV1AesSha2,
          ],
          'keys': {
            'curve25519:UNSIGNEDDEVICE':
                'ds6+bItpDiWyRaT/b0ofoz1R+GCy7YTbORLJI4dmYho',
            'ed25519:UNSIGNEDDEVICE':
                'CdDKVf44LO2QlfWopP6VWmqedSrRaf9rhHKvdVyH38w',
          },
          'signatures': {
            '@test:fakeServer.notExisting': {
              'ed25519:UNSIGNEDDEVICE':
                  'f2p1kv6PIz+hnoFYnHEurhUKIyRsdxwR2RTKT1EnQ3aF2zlZOjmnndOCtIT24Q8vs2PovRw+/jkHKj4ge2yDDw',
            },
          },
        },
        client,
      );

      client.shareKeysWith = ShareKeysWith.all;
      expect(key.encryptToDevice, true);

      client.shareKeysWith = ShareKeysWith.directlyVerifiedOnly;
      expect(key.encryptToDevice, false);
      await key.setVerified(true);
      expect(key.encryptToDevice, true);
      await key.setVerified(false);

      client.shareKeysWith = ShareKeysWith.crossVerified;
      expect(key.encryptToDevice, true);

      client.shareKeysWith = ShareKeysWith.crossVerified;
      // Disable cross signing for this user manually so encryptToDevice should return `false`
      final dropUserDeviceKeys = client.userDeviceKeys.remove(key.userId);
      expect(key.encryptToDevice, false);
      // But crossVerifiedIfEnabled should return `true` now:
      client.shareKeysWith = ShareKeysWith.crossVerifiedIfEnabled;
      expect(key.encryptToDevice, true);

      client.userDeviceKeys[key.userId] = dropUserDeviceKeys!;
      client.shareKeysWith = ShareKeysWith.all;
      final masterKey = client.userDeviceKeys[client.userID]!.masterKey!;
      masterKey.setDirectVerified(true);
      // we need to populate the ssss cache to be able to test signing easily
      final handle = client.encryption!.ssss.open();
      await handle.unlock(recoveryKey: ssssKey);
      await handle.maybeCacheAll();

      expect(key.verified, true);
      expect(key.encryptToDevice, true);
      await key.setBlocked(true);
      expect(key.verified, false);
      expect(key.encryptToDevice, false);
      await key.setBlocked(false);
      expect(key.directVerified, false);
      expect(key.verified, true); // still verified via cross-sgining
      expect(key.encryptToDevice, true);
      expect(
        client.userDeviceKeys[client.userID]?.deviceKeys['UNSIGNEDDEVICE']
            ?.encryptToDevice,
        true,
      );

      expect(masterKey.verified, true);
      await masterKey.setBlocked(true);
      expect(masterKey.verified, false);
      expect(
        client.userDeviceKeys[client.userID]?.deviceKeys['UNSIGNEDDEVICE']
            ?.encryptToDevice,
        true,
      );
      await masterKey.setBlocked(false);
      expect(masterKey.verified, true);

      FakeMatrixApi.calledEndpoints.clear();
      await key.setVerified(true);
      await Future.delayed(Duration(milliseconds: 10));
      expect(
        FakeMatrixApi.calledEndpoints.keys
            .any((k) => k == '/client/v3/keys/signatures/upload'),
        true,
      );
      expect(key.directVerified, true);

      FakeMatrixApi.calledEndpoints.clear();
      await key.setVerified(false);
      await Future.delayed(Duration(milliseconds: 10));
      expect(
        FakeMatrixApi.calledEndpoints.keys
            .any((k) => k == '/client/v3/keys/signatures/upload'),
        false,
      );
      expect(key.directVerified, false);
      client.userDeviceKeys[client.userID]?.deviceKeys.remove('UNSIGNEDDEVICE');
    });

    test('verification based on signatures', () async {
      final user = client.userDeviceKeys[client.userID]!;
      user.masterKey?.setDirectVerified(true);
      expect(user.deviceKeys['GHTYAJCE']?.crossVerified, true);
      expect(user.deviceKeys['GHTYAJCE']?.signed, true);
      expect(user.getKey('GHTYAJCE')?.crossVerified, true);
      expect(user.deviceKeys['OTHERDEVICE']?.crossVerified, true);
      expect(user.selfSigningKey?.crossVerified, true);
      expect(
        user
            .getKey('F9ypFzgbISXCzxQhhSnXMkc1vq12Luna3Nw5rqViOJY')
            ?.crossVerified,
        true,
      );
      expect(user.userSigningKey?.crossVerified, true);
      expect(user.verified, UserVerifiedStatus.verified);
      user.masterKey?.setDirectVerified(false);
      expect(user.deviceKeys['GHTYAJCE']?.crossVerified, false);
      expect(user.deviceKeys['OTHERDEVICE']?.crossVerified, false);
      expect(user.verified, UserVerifiedStatus.unknown);

      user.deviceKeys['OTHERDEVICE']?.setDirectVerified(true);
      expect(user.verified, UserVerifiedStatus.verified);
      user.deviceKeys['OTHERDEVICE']?.setDirectVerified(false);

      user.masterKey?.setDirectVerified(true);
      user.deviceKeys['GHTYAJCE']?.signatures?[client.userID]
          ?.removeWhere((k, v) => k != 'ed25519:GHTYAJCE');
      expect(
        user.deviceKeys['GHTYAJCE']?.verified,
        true,
      ); // it's our own device, should be direct verified
      expect(
        user.deviceKeys['GHTYAJCE']?.signed,
        false,
      ); // not verified for others
      user.deviceKeys['OTHERDEVICE']?.signatures?.clear();
      expect(user.verified, UserVerifiedStatus.unknownDevice);
    });

    test('start verification', () async {
      var req = await client
          .userDeviceKeys['@alice:example.com']?.deviceKeys['JLAFKJWSCS']
          ?.startVerification();
      expect(req != null, true);
      expect(req?.room != null, false);

      final createRoomRequestCount =
          FakeMatrixApi.calledEndpoints['/client/v3/createRoom']?.length ?? 0;

      Future<void> verifyDeviceKeys() async {
        req = await client.userDeviceKeys['@alice:example.com']
            ?.startVerification(newDirectChatEnableEncryption: false);
        expect(req != null, true);
        expect(req?.room != null, true);
      }

      await verifyDeviceKeys();
      // a new room should be created since there is no existing DM room
      expect(
        FakeMatrixApi.calledEndpoints['/client/v3/createRoom']?.length,
        createRoomRequestCount + 1,
      );

      await verifyDeviceKeys();
      // no new room should be created since the room already exists
      expect(
        FakeMatrixApi.calledEndpoints['/client/v3/createRoom']?.length,
        createRoomRequestCount + 1,
      );

      final dmRoomId = client.getDirectChatFromUserId('@alice:example.com');
      expect(dmRoomId != null, true);
      final dmRoom = client.getRoomById(dmRoomId!);
      expect(dmRoom != null, true);
      // old state event should not overwrite current state events
      dmRoom!.partial = false;

      // mock invite bob to the room
      await client.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              dmRoomId: JoinedRoomUpdate(
                state: [
                  MatrixEvent(
                    type: EventTypes.RoomMember,
                    content: {
                      'displayname': 'testclient',
                      'is_direct': true,
                      'membership': Membership.join.name,
                    },
                    senderId: client.userID!,
                    eventId: 'eventId',
                    stateKey: client.userID!,
                    originServerTs: DateTime.now(),
                  ),
                  MatrixEvent(
                    type: EventTypes.RoomMember,
                    content: {
                      'displayname': 'Bob the builder',
                      'is_direct': true,
                      'membership': Membership.invite.name,
                    },
                    senderId: '@bob:example.com',
                    eventId: 'eventId',
                    stateKey: '@bob:example.com',
                    originServerTs: DateTime.now(),
                  ),
                ],
                summary: RoomSummary.fromJson({
                  'm.joined_member_count': 1,
                  'm.invited_member_count': 1,
                  'm.heroes': [],
                }),
              ),
            },
          ),
        ),
      );
      expect(
        dmRoom.getParticipants([Membership.invite, Membership.join]).length,
        2,
      );
      dmRoom.partial = true;

      await verifyDeviceKeys();
      // a second room should now be created because bob(someone else other than
      // alice) is invited into the first DM room
      expect(
        FakeMatrixApi.calledEndpoints['/client/v3/createRoom']?.length,
        createRoomRequestCount + 2,
      );

      final dmRoomId2 = client.getDirectChatFromUserId('@alice:example.com');
      expect(dmRoomId2 != null, true);
      final dmRoom2 = client.getRoomById(dmRoomId2!);
      expect(dmRoom2 != null, true);
      // old state event should not overwrite current state events
      dmRoom2!.partial = false;

      // mock invite alice and ban bob to the room
      await client.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              dmRoomId2: JoinedRoomUpdate(
                state: [
                  MatrixEvent(
                    type: EventTypes.RoomMember,
                    content: {
                      'displayname': 'Alice Catgirl',
                      'is_direct': true,
                      'membership': Membership.invite.name,
                    },
                    senderId: '@alice:example.com',
                    eventId: 'eventId',
                    stateKey: '@alice:example.com',
                    originServerTs: DateTime.now(),
                  ),
                  MatrixEvent(
                    type: EventTypes.RoomMember,
                    content: {
                      'displayname': 'Bob the builder',
                      'is_direct': true,
                      'membership': Membership.ban.name,
                    },
                    senderId: '@bob:example.com',
                    eventId: 'eventId',
                    stateKey: '@bob:example.com',
                    originServerTs: DateTime.now(),
                  ),
                ],
                summary: RoomSummary.fromJson({
                  'm.joined_member_count': 1,
                  'm.invited_member_count': 1,
                  'm.heroes': [],
                }),
              ),
            },
          ),
        ),
      );
      expect(
        dmRoom2.getParticipants([Membership.invite, Membership.join]).length,
        2,
      );
      dmRoom2.partial = true;

      await verifyDeviceKeys();
      // no new room should be created because only alice has been invited to the
      // second room
      expect(
        FakeMatrixApi.calledEndpoints['/client/v3/createRoom']?.length,
        createRoomRequestCount + 2,
      );

      // old state event should not overwrite current state events
      dmRoom2.partial = false;
      // mock join alice and invite bob to the room
      await client.handleSync(
        SyncUpdate(
          nextBatch: 'something',
          rooms: RoomsUpdate(
            join: {
              dmRoomId2: JoinedRoomUpdate(
                state: [
                  MatrixEvent(
                    type: EventTypes.RoomMember,
                    content: {
                      'displayname': 'Alice Catgirl',
                      'is_direct': true,
                      'membership': Membership.join.name,
                    },
                    senderId: '@alice:example.com',
                    eventId: 'eventId',
                    stateKey: '@alice:example.com',
                    originServerTs: DateTime.now(),
                  ),
                  MatrixEvent(
                    type: EventTypes.RoomMember,
                    content: {
                      'displayname': 'Bob the builder',
                      'is_direct': true,
                      'membership': Membership.invite.name,
                    },
                    senderId: '@bob:example.com',
                    eventId: 'eventId',
                    stateKey: '@bob:example.com',
                    originServerTs: DateTime.now(),
                  ),
                ],
                summary: RoomSummary.fromJson({
                  'm.joined_member_count': 2,
                  'm.invited_member_count': 1,
                  'm.heroes': [],
                }),
              ),
            },
          ),
        ),
      );
      expect(
        dmRoom.getParticipants([Membership.invite, Membership.join]).length,
        3,
      );
      dmRoom2.partial = true;

      await verifyDeviceKeys();
      // a third room should now be created because someone else (other than
      // alice) is also invited into the second DM room
      expect(
        FakeMatrixApi.calledEndpoints['/client/v3/createRoom']?.length,
        createRoomRequestCount + 3,
      );
    });

    test('dispose client', () async {
      await client.dispose(closeDatabase: true);
    });
  });
}
