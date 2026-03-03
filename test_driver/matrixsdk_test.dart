/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020, 2021 Famedly GmbH
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
import 'dart:io';

import 'package:test/test.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:matrix/encryption/utils/crypto_setup_extension.dart';
import 'package:matrix/matrix.dart';
import '../test/fake_database.dart';
import 'test_config.dart';

const String testMessage = 'Hello world';
const String testMessage2 = 'Hello moon';
const String testMessage3 = 'Hello sun';
const String testMessage4 = 'Hello star';
const String testMessage5 = 'Hello earth';
const String testMessage6 = 'Hello mars';

void main() => group(
      'Integration tests',
      () {
        setUpAll(() async {
          await vod.init(
            wasmPath: './pkg/',
            libraryPath: './rust/target/debug/',
          );
        });

        test('E2EE', () async {
          Client? testClientA, testClientB;

          try {
            final homeserverUri = Uri.parse(homeserver);
            Logs().i('++++ Using homeserver $homeserverUri ++++');

            Logs().i('++++ Login Alice at ++++');
            testClientA = Client('TestClientA', database: await getDatabase());
            await testClientA.checkHomeserver(homeserverUri);
            await testClientA.login(
              LoginType.mLoginPassword,
              identifier: AuthenticationUserIdentifier(user: Users.user1.name),
              password: Users.user1.password,
            );
            expect(testClientA.encryptionEnabled, true);

            Logs().i('++++ Login Bob ++++');
            testClientB = Client('TestClientB', database: await getDatabase());
            await testClientB.checkHomeserver(homeserverUri);
            await testClientB.login(
              LoginType.mLoginPassword,
              identifier: AuthenticationUserIdentifier(user: Users.user2.name),
              password: Users.user2.password,
            );
            expect(testClientB.encryptionEnabled, true);

            Logs().i('++++ (Alice) Leave all rooms ++++');
            while (testClientA.rooms.isNotEmpty) {
              final room = testClientA.rooms.first;
              if (room.canonicalAlias.isNotEmpty) {
                break;
              }
              try {
                await room.leave();
                await room.forget();
              } catch (_) {}
            }

            Logs().i('++++ (Bob) Leave all rooms ++++');
            for (var i = 0; i < 3; i++) {
              if (testClientB.rooms.isNotEmpty) {
                final room = testClientB.rooms.first;
                try {
                  await room.leave();
                  await room.forget();
                } catch (_) {}
              }
            }

            Logs()
                .i('++++ Check if own olm device is verified by default ++++');
            expect(testClientA.userDeviceKeys, contains(testClientA.userID));
            expect(
              testClientA.userDeviceKeys[testClientA.userID]!.deviceKeys,
              contains(testClientA.deviceID),
            );
            expect(
              testClientA.userDeviceKeys[testClientA.userID]!
                  .deviceKeys[testClientA.deviceID!]!.verified,
              isTrue,
            );
            expect(
              !testClientA.userDeviceKeys[testClientA.userID]!
                  .deviceKeys[testClientA.deviceID!]!.blocked,
              isTrue,
            );
            expect(testClientB.userDeviceKeys, contains(testClientB.userID));
            expect(
              testClientB.userDeviceKeys[testClientB.userID]!.deviceKeys,
              contains(testClientB.deviceID),
            );
            expect(
              testClientB.userDeviceKeys[testClientB.userID]!
                  .deviceKeys[testClientB.deviceID!]!.verified,
              isTrue,
            );
            expect(
              !testClientB.userDeviceKeys[testClientB.userID]!
                  .deviceKeys[testClientB.deviceID!]!.blocked,
              isTrue,
            );

            Logs().i('++++ (Alice) Create room and invite Bob ++++');
            await testClientA.startDirectChat(
              testClientB.userID!,
              enableEncryption: false,
            );
            await Future.delayed(Duration(seconds: 1));
            final room = testClientA.rooms.first;
            final roomId = room.id;

            Logs().i('++++ (Bob) Join room ++++');
            final inviteRoom = testClientB.getRoomById(roomId)!;
            await inviteRoom.join();
            await Future.delayed(Duration(seconds: 1));
            expect(inviteRoom.membership, Membership.join);

            Logs().i('++++ (Alice) Enable encryption ++++');
            expect(room.encrypted, false);
            await room.enableEncryption();
            var waitSeconds = 0;
            while (!room.encrypted) {
              await Future.delayed(Duration(seconds: 1));
              waitSeconds++;
              if (waitSeconds >= 60) {
                throw Exception('Unable to enable encryption');
              }
            }
            expect(room.encrypted, isTrue);
            expect(
              room.client.encryption!.keyManager
                  .getOutboundGroupSession(room.id),
              isNull,
            );

            Logs().i('++++ (Alice) Check known olm devices ++++');
            expect(testClientA.userDeviceKeys, contains(testClientB.userID));
            expect(
              testClientA.userDeviceKeys[testClientB.userID]!.deviceKeys,
              contains(testClientB.deviceID),
            );
            expect(
              testClientA.userDeviceKeys[testClientB.userID]!
                  .deviceKeys[testClientB.deviceID!]!.verified,
              isFalse,
            );
            expect(
              testClientA.userDeviceKeys[testClientB.userID]!
                  .deviceKeys[testClientB.deviceID!]!.blocked,
              isFalse,
            );
            expect(testClientB.userDeviceKeys, contains(testClientA.userID));
            expect(
              testClientB.userDeviceKeys[testClientA.userID]!.deviceKeys,
              contains(testClientA.deviceID),
            );
            expect(
              testClientB.userDeviceKeys[testClientA.userID]!
                  .deviceKeys[testClientA.deviceID!]!.verified,
              isFalse,
            );
            expect(
              testClientB.userDeviceKeys[testClientA.userID]!
                  .deviceKeys[testClientA.deviceID!]!.blocked,
              isFalse,
            );
            await Future.wait([
              testClientA.updateUserDeviceKeys(),
              testClientB.updateUserDeviceKeys(),
            ]);
            await testClientA.userDeviceKeys[testClientB.userID]!
                .deviceKeys[testClientB.deviceID!]!
                .setVerified(true);

            Logs()
                .i('++++ Check if own olm device is verified by default ++++');
            expect(testClientA.userDeviceKeys, contains(testClientA.userID));
            expect(
              testClientA.userDeviceKeys[testClientA.userID]!.deviceKeys,
              contains(testClientA.deviceID),
            );
            expect(
              testClientA.userDeviceKeys[testClientA.userID]!
                  .deviceKeys[testClientA.deviceID!]!.verified,
              isTrue,
            );
            expect(testClientB.userDeviceKeys, contains(testClientB.userID));
            expect(
              testClientB.userDeviceKeys[testClientB.userID]!.deviceKeys,
              contains(testClientB.deviceID),
            );
            expect(
              testClientB.userDeviceKeys[testClientB.userID]!
                  .deviceKeys[testClientB.deviceID!]!.verified,
              isTrue,
            );

            Logs()
                .i("++++ (Alice) Send encrypted message: '$testMessage' ++++");
            await room.sendTextEvent(testMessage);
            await Future.delayed(Duration(seconds: 5));
            expect(
              room.client.encryption!.keyManager
                  .getOutboundGroupSession(room.id),
              isNotNull,
            );
            var currentSessionIdA = room.client.encryption!.keyManager
                .getOutboundGroupSession(room.id)!
                .outboundGroupSession!
                .sessionId;
            /*expect(room.client.encryption.keyManager
          .getInboundGroupSession(room.id, currentSessionIdA, '') !=
      null);*/
            expect(
              testClientA.encryption!.olmManager
                  .olmSessions[testClientB.identityKey]!.length,
              olmLengthMatcher,
            );
            expect(
              testClientB.encryption!.olmManager
                  .olmSessions[testClientA.identityKey]!.length,
              olmLengthMatcher,
            );
            expect(
              testClientA.encryption!.olmManager
                  .olmSessions[testClientB.identityKey]!.first.sessionId,
              testClientB.encryption!.olmManager
                  .olmSessions[testClientA.identityKey]!.first.sessionId,
            );
            /*expect(inviteRoom.client.encryption.keyManager
          .getInboundGroupSession(inviteRoom.id, currentSessionIdA, '') !=
      null);*/
            expect(room.lastEvent!.body, testMessage);
            expect(inviteRoom.lastEvent!.body, testMessage);
            Logs().i(
              "++++ (Bob) Received decrypted message: '${inviteRoom.lastEvent!.body}' ++++",
            );

            Logs().i(
              "++++ (Alice) Send again encrypted message: '$testMessage2' ++++",
            );
            await room.sendTextEvent(testMessage2);
            await Future.delayed(Duration(seconds: 5));
            expect(
              testClientA.encryption!.olmManager
                  .olmSessions[testClientB.identityKey]!.length,
              olmLengthMatcher,
            );
            expect(
              testClientB.encryption!.olmManager
                  .olmSessions[testClientA.identityKey]!.length,
              olmLengthMatcher,
            );
            expect(
              testClientA.encryption!.olmManager
                  .olmSessions[testClientB.identityKey]!.first.sessionId,
              testClientB.encryption!.olmManager
                  .olmSessions[testClientA.identityKey]!.first.sessionId,
            );

            expect(
              room.client.encryption!.keyManager
                  .getOutboundGroupSession(room.id)!
                  .outboundGroupSession!
                  .sessionId,
              currentSessionIdA,
            );
            /*expect(room.client.encryption.keyManager
          .getInboundGroupSession(room.id, currentSessionIdA, '') !=
      null);*/
            expect(room.lastEvent!.body, testMessage2);
            expect(inviteRoom.lastEvent!.body, testMessage2);
            Logs().i(
              "++++ (Bob) Received decrypted message: '${inviteRoom.lastEvent!.body}' ++++",
            );

            Logs().i(
              "++++ (Bob) Send again encrypted message: '$testMessage3' ++++",
            );
            await inviteRoom.sendTextEvent(testMessage3);
            await Future.delayed(Duration(seconds: 5));
            expect(
              testClientA.encryption!.olmManager
                  .olmSessions[testClientB.identityKey]!.length,
              olmLengthMatcher,
            );
            expect(
              testClientB.encryption!.olmManager
                  .olmSessions[testClientA.identityKey]!.length,
              olmLengthMatcher,
            );
            expect(
              room.client.encryption!.keyManager
                  .getOutboundGroupSession(room.id)!
                  .outboundGroupSession!
                  .sessionId,
              currentSessionIdA,
            );
            final inviteRoomOutboundGroupSession = inviteRoom
                .client.encryption!.keyManager
                .getOutboundGroupSession(inviteRoom.id)!;

            expect(inviteRoomOutboundGroupSession.isValid, isTrue);
            /*expect(inviteRoom.client.encryption.keyManager.getInboundGroupSession(
          inviteRoom.id,
          inviteRoomOutboundGroupSession.outboundGroupSession.sessionId,
          '') !=
      null);
  expect(room.client.encryption.keyManager.getInboundGroupSession(
          room.id,
          inviteRoomOutboundGroupSession.outboundGroupSession.sessionId,
          '') !=
      null);*/
            expect(inviteRoom.lastEvent!.body, testMessage3);
            expect(room.lastEvent!.body, testMessage3);
            Logs().i(
              "++++ (Alice) Received decrypted message: '${room.lastEvent!.body}' ++++",
            );

            Logs().i('++++ Login Bob in another client ++++');
            final testClientC =
                Client('TestClientC', database: await getDatabase());
            await testClientC.checkHomeserver(homeserverUri);
            // We can't sign in using the displayname, since that breaks e2ee on dendrite: https://github.com/matrix-org/dendrite/issues/2914
            await testClientC.login(
              LoginType.mLoginPassword,
              identifier: AuthenticationUserIdentifier(user: Users.user2.name),
              password: Users.user2.password,
            );
            await Future.delayed(Duration(seconds: 3));

            Logs().i(
              "++++ (Alice) Send again encrypted message: '$testMessage4' ++++",
            );
            await room.sendTextEvent(testMessage4);
            await Future.delayed(Duration(seconds: 7));
            expect(
              testClientA.encryption!.olmManager
                  .olmSessions[testClientB.identityKey]!.length,
              olmLengthMatcher,
            );
            expect(
              testClientB.encryption!.olmManager
                  .olmSessions[testClientA.identityKey]!.length,
              olmLengthMatcher,
            );
            expect(
              testClientA.encryption!.olmManager
                  .olmSessions[testClientB.identityKey]!.first.sessionId,
              testClientB.encryption!.olmManager
                  .olmSessions[testClientA.identityKey]!.first.sessionId,
            );
            expect(
              testClientA.encryption!.olmManager
                  .olmSessions[testClientC.identityKey]!.length,
              olmLengthMatcher,
            );
            expect(
              testClientC.encryption!.olmManager
                  .olmSessions[testClientA.identityKey]!.length,
              olmLengthMatcher,
            );
            expect(
              testClientA.encryption!.olmManager
                  .olmSessions[testClientC.identityKey]!.first.sessionId,
              testClientC.encryption!.olmManager
                  .olmSessions[testClientA.identityKey]!.first.sessionId,
            );
            expect(
              room.client.encryption!.keyManager
                  .getOutboundGroupSession(room.id)!
                  .outboundGroupSession!
                  .sessionId,
              currentSessionIdA,
            );
            /*expect(inviteRoom.client.encryption.keyManager
          .getInboundGroupSession(inviteRoom.id, currentSessionIdA, '') !=
      null);*/
            expect(room.lastEvent!.body, testMessage4);
            expect(inviteRoom.lastEvent!.body, testMessage4);
            Logs().i(
              "++++ (Bob) Received decrypted message: '${inviteRoom.lastEvent!.body}' ++++",
            );

            Logs().i(
              '++++ Logout Bob another client ${testClientC.deviceID} ++++',
            );
            await testClientC.dispose(closeDatabase: false);
            await testClientC.logout();
            await Future.delayed(Duration(seconds: 5));

            Logs().i(
              "++++ (Alice) Send again encrypted message: '$testMessage6' ++++",
            );
            await room.sendTextEvent(testMessage6);
            await Future.delayed(Duration(seconds: 5));
            expect(
              testClientA.encryption!.olmManager
                  .olmSessions[testClientB.identityKey]!.length,
              olmLengthMatcher,
            );
            expect(
              testClientB.encryption!.olmManager
                  .olmSessions[testClientA.identityKey]!.length,
              olmLengthMatcher,
            );
            expect(
              testClientA.encryption!.olmManager
                  .olmSessions[testClientB.identityKey]!.first.sessionId,
              testClientB.encryption!.olmManager
                  .olmSessions[testClientA.identityKey]!.first.sessionId,
            );

            // This does not work on conduit because of a server bug: https://gitlab.com/famedly/conduit/-/issues/325
            if (Platform.environment['HOMESERVER_IMPLEMENTATION'] !=
                'conduit') {
              expect(
                room.client.encryption!.keyManager
                    .getOutboundGroupSession(room.id)!
                    .outboundGroupSession!
                    .sessionId,
                isNot(currentSessionIdA),
              );
            }
            currentSessionIdA = room.client.encryption!.keyManager
                .getOutboundGroupSession(room.id)!
                .outboundGroupSession!
                .sessionId;
            /*expect(inviteRoom.client.encryption.keyManager
          .getInboundGroupSession(inviteRoom.id, currentSessionIdA, '') !=
      null);*/
            expect(room.lastEvent!.body, testMessage6);
            expect(inviteRoom.lastEvent!.body, testMessage6);
            Logs().i(
              "++++ (Bob) Received decrypted message: '${inviteRoom.lastEvent!.body}' ++++",
            );

            Logs().i('++++ (Alice) Init crypto identity ++++');
            if (Platform.environment['HOMESERVER_IMPLEMENTATION'] !=
                'conduit') {
              const passphrase = 'aliceSecurePassphrase100%';
              await testClientA.initCryptoIdentity(passphrase: passphrase);
              await testClientA.logout();
              await testClientA.checkHomeserver(homeserverUri);
              await testClientA.login(
                LoginType.mLoginPassword,
                identifier:
                    AuthenticationUserIdentifier(user: Users.user1.name),
                password: Users.user1.password,
              );
              await testClientA.oneShotSync();
              await testClientA.restoreCryptoIdentity(passphrase);
              final newSessionRoomA = testClientA.getRoomById(roomId)!;
              await newSessionRoomA.lastEvent?.requestKey();
              expect(newSessionRoomA.lastEvent!.body, testMessage6);
              await newSessionRoomA.leave();
              await newSessionRoomA.forget();
            } else {
              await room.leave();
              await room.forget();
            }

            await inviteRoom.leave();
            await inviteRoom.forget();
            await Future.delayed(Duration(seconds: 1));
          } catch (e, s) {
            Logs().e('Test failed', e, s);
            rethrow;
          } finally {
            Logs().i('++++ Logout Alice and Bob ++++');
            if (testClientA?.isLogged() ?? false) {
              await testClientA!.logoutAll();
            }
            if (testClientA?.isLogged() ?? false) {
              await testClientB!.logoutAll();
            }
            await testClientA?.dispose(closeDatabase: false);
            await testClientB?.dispose(closeDatabase: false);
            testClientA = null;
            testClientB = null;
          }
          return;
        });

        test('dm creation', () async {
          Client? testClientA, testClientB;

          try {
            final homeserverUri = Uri.parse(homeserver);
            Logs().i('++++ Using homeserver $homeserverUri ++++');

            Logs().i('++++ Login Alice at ++++');
            testClientA = Client('TestClientA', database: await getDatabase());
            await testClientA.checkHomeserver(homeserverUri);
            await testClientA.login(
              LoginType.mLoginPassword,
              identifier: AuthenticationUserIdentifier(user: Users.user1.name),
              password: Users.user1.password,
            );
            expect(testClientA.encryptionEnabled, true);

            Logs().i('++++ Login Bob ++++');
            testClientB = Client('TestClientB', database: await getDatabase());
            await testClientB.checkHomeserver(homeserverUri);
            await testClientB.login(
              LoginType.mLoginPassword,
              identifier: AuthenticationUserIdentifier(user: Users.user2.name),
              password: Users.user2.password,
            );
            expect(testClientB.encryptionEnabled, true);

            Logs().i('++++ (Alice) Leave all rooms ++++');
            while (testClientA.rooms.isNotEmpty) {
              final room = testClientA.rooms.first;
              if (room.canonicalAlias.isNotEmpty) {
                break;
              }
              try {
                await room.leave();
                await room.forget();
              } catch (_) {}
            }

            Logs().i('++++ (Bob) Leave all rooms ++++');
            for (var i = 0; i < 3; i++) {
              if (testClientB.rooms.isNotEmpty) {
                final room = testClientB.rooms.first;
                try {
                  await room.leave();
                  await room.forget();
                } catch (_) {}
              }
            }

            Logs().i('++++ (Alice) Create DM ++++');
            final dmRoom =
                await testClientA.startDirectChat(testClientB.userID!);

            if (testClientB.getRoomById(dmRoom) == null) {
              await testClientB.waitForRoomInSync(dmRoom, invite: true);
            }
            // Wait at least for one additional sync to make sure the invite landed
            // correctly. Workaround for synapse CI job failing.
            await testClientB.onSync.stream.first;

            Logs().i('++++ (Bob) Create DM ++++');
            final dmRoomFromB =
                await testClientB.startDirectChat(testClientA.userID!);

            expect(
              dmRoom,
              dmRoomFromB,
              reason:
                  "Bob should join alice's DM room instead of creating a new one",
            );
            expect(
              testClientB.getRoomById(dmRoom)?.membership,
              Membership.join,
              reason: 'Room should actually be in the join state now.',
            );
            expect(
              testClientA.getRoomById(dmRoom)?.membership,
              Membership.join,
              reason: 'Room should actually be in the join state now.',
            );
          } catch (e, s) {
            Logs().e('Test failed', e, s);
            rethrow;
          } finally {
            Logs().i('++++ Logout Alice and Bob ++++');
            if (testClientA?.isLogged() ?? false) {
              await testClientA!.logoutAll();
            }
            if (testClientA?.isLogged() ?? false) {
              await testClientB!.logoutAll();
            }
            await testClientA?.dispose(closeDatabase: false);
            await testClientB?.dispose(closeDatabase: false);
            testClientA = null;
            testClientB = null;
          }
          return;
        });

        test('Dehydrated devices', () async {
          // Dehydrated devices are only supported on Synapse
          if (Platform.environment['HOMESERVER_IMPLEMENTATION'] != 'synapse') {
            Logs()
                .i('++++ Skipping dehydrated devices test (not Synapse) ++++');
            return;
          }

          Client? testClientA, testClientB;
          StreamSubscription<UiaRequest>? uiaSubscription;

          try {
            final homeserverUri = Uri.parse(homeserver);
            Logs().i('++++ Using homeserver $homeserverUri ++++');

            Logs().i('++++ Login Alice with dehydrated devices enabled ++++');
            testClientA = Client(
              'TestClientA',
              database: await getDatabase(),
              enableDehydratedDevices: true,
            );
            await testClientA.checkHomeserver(homeserverUri);
            await testClientA.login(
              LoginType.mLoginPassword,
              identifier: AuthenticationUserIdentifier(user: Users.user1.name),
              password: Users.user1.password,
            );
            expect(testClientA.encryptionEnabled, true);

            // Set up UIA handler for cross-signing setup
            final handledUiaRequests = <int>{};
            uiaSubscription =
                testClientA.onUiaRequest.stream.listen((uiaRequest) async {
              // Prevent duplicate handling of the same request
              if (handledUiaRequests.contains(uiaRequest.hashCode)) return;
              handledUiaRequests.add(uiaRequest.hashCode);

              if (uiaRequest.nextStages
                  .contains(AuthenticationTypes.password)) {
                try {
                  await uiaRequest.completeStage(
                    AuthenticationPassword(
                      session: uiaRequest.session,
                      password: Users.user1.password,
                      identifier: AuthenticationUserIdentifier(
                        user: Users.user1.name,
                      ),
                    ),
                  );
                } catch (e) {
                  Logs().e('UIA password stage failed', e);
                }
              }
            });
            testClientA.backgroundSync = true;

            Logs().i('++++ Login Bob ++++');
            testClientB = Client('TestClientB', database: await getDatabase());
            await testClientB.checkHomeserver(homeserverUri);
            await testClientB.login(
              LoginType.mLoginPassword,
              identifier: AuthenticationUserIdentifier(user: Users.user2.name),
              password: Users.user2.password,
            );
            expect(testClientB.encryptionEnabled, true);
            testClientB.backgroundSync = true;

            Logs().i('++++ Alice and Bob background sync active ++++');

            Logs().i(
              '++++ (Alice) Set up cross-signing (required for dehydrated devices) ++++',
            );
            const passphrase = 'aliceSecurePassphrase100%';
            await testClientA.initCryptoIdentity(passphrase: passphrase);
            Logs().i('++++ (Alice) Crypto identity initialized ++++');

            Logs().i('++++ (Alice) Create encrypted DM room with Bob ++++');
            final roomId = await testClientA.startDirectChat(
              testClientB.userID!,
              enableEncryption: true,
            );
            await Future.delayed(Duration(seconds: 2));
            final room = testClientA.getRoomById(roomId)!;
            expect(room.encrypted, isTrue);

            Logs().i('++++ (Bob) Join room ++++');
            if (testClientB.getRoomById(roomId) == null) {
              await testClientB.waitForRoomInSync(roomId, invite: true);
            }
            final bobRoom = testClientB.getRoomById(roomId)!;
            if (bobRoom.membership == Membership.invite) {
              await bobRoom.join();
            }
            await Future.delayed(Duration(seconds: 1));
            expect(bobRoom.membership, Membership.join);

            Logs().i(
              '++++ (Alice) Now logout (dehydrated device remains on server) ++++',
            );
            await testClientA.logout();
            await testClientA.dispose(closeDatabase: false);
            testClientA = null;

            Logs().i(
              '++++ (Bob) Send encrypted message while Alice is offline ++++',
            );
            const offlineMessage = 'Secret message while you were away';
            await bobRoom.sendTextEvent(offlineMessage);
            await Future.delayed(Duration(seconds: 5));

            Logs().i('++++ (Alice) Login again on new device ++++');
            testClientA = Client(
              'TestClientA2',
              database: await getDatabase(),
              enableDehydratedDevices: true,
            );
            await testClientA.checkHomeserver(homeserverUri);
            await testClientA.login(
              LoginType.mLoginPassword,
              identifier: AuthenticationUserIdentifier(user: Users.user1.name),
              password: Users.user1.password,
            );
            testClientA.backgroundSync = true;
            await testClientA.onSync.stream.first;

            Logs().i(
              '++++ (Alice) Restore crypto identity (this fetches dehydrated device events) ++++',
            );
            await testClientA.restoreCryptoIdentity(passphrase);
            await Future.delayed(Duration(seconds: 5));

            Logs().i('++++ (Alice) Verify message can be decrypted ++++');
            final newRoom = testClientA.getRoomById(roomId)!;
            // Request key if needed
            if (newRoom.lastEvent?.body != offlineMessage) {
              await newRoom.lastEvent?.requestKey();
              await Future.delayed(Duration(seconds: 5));
            }
            expect(
              newRoom.lastEvent!.body,
              offlineMessage,
              reason: 'Dehydrated device should have received the room key',
            );
            Logs().i(
              "++++ SUCCESS: Decrypted message '${newRoom.lastEvent!.body}' ++++",
            );

            await newRoom.leave();
            await newRoom.forget();
            await bobRoom.leave();
            await bobRoom.forget();
          } catch (e, s) {
            Logs().e('Test failed', e, s);
            rethrow;
          } finally {
            Logs().i('++++ Logout Alice and Bob ++++');
            await uiaSubscription?.cancel();
            if (testClientA?.isLogged() ?? false) {
              await testClientA!.logoutAll();
            }
            if (testClientB?.isLogged() ?? false) {
              await testClientB!.logoutAll();
            }
            await testClientA?.dispose(closeDatabase: false);
            await testClientB?.dispose(closeDatabase: false);
            testClientA = null;
            testClientB = null;
          }
          return;
        });
      },
      timeout: Timeout(Duration(minutes: 6)),
    );

Object get olmLengthMatcher {
  return
      // workarounding weird Dendrite bug
      Platform.environment['HOMESERVER_IMPLEMENTATION'] != 'dendrite'
          ? 1
          : predicate(
              [1, 2].contains,
              'is either 1 or two',
            );
}
