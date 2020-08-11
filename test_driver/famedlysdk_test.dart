import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/matrix_api.dart';
import 'package:famedlysdk/src/utils/logs.dart';
import '../test/fake_database.dart';

void main() => test();

const String homeserver = 'https://matrix.test.famedly.de';
const String testUserA = '@tick:test.famedly.de';
const String testPasswordA = 'test';
const String testUserB = '@trick:test.famedly.de';
const String testPasswordB = 'test';
const String testMessage = 'Hello world';
const String testMessage2 = 'Hello moon';
const String testMessage3 = 'Hello sun';
const String testMessage4 = 'Hello star';
const String testMessage5 = 'Hello earth';
const String testMessage6 = 'Hello mars';

void test() async {
  Logs.success('++++ Login $testUserA ++++');
  var testClientA = Client('TestClientA');
  testClientA.database = getDatabase();
  await testClientA.checkServer(homeserver);
  await testClientA.login(user: testUserA, password: testPasswordA);
  assert(testClientA.encryptionEnabled);

  Logs.success('++++ Login $testUserB ++++');
  var testClientB = Client('TestClientB');
  testClientB.database = getDatabase();
  await testClientB.checkServer(homeserver);
  await testClientB.login(user: testUserB, password: testPasswordA);
  assert(testClientB.encryptionEnabled);

  Logs.success('++++ ($testUserA) Leave all rooms ++++');
  while (testClientA.rooms.isNotEmpty) {
    var room = testClientA.rooms.first;
    if (room.canonicalAlias?.isNotEmpty ?? false) {
      break;
    }
    try {
      await room.leave();
      await room.forget();
    } catch (_) {}
  }

  Logs.success('++++ ($testUserB) Leave all rooms ++++');
  for (var i = 0; i < 3; i++) {
    if (testClientB.rooms.isNotEmpty) {
      var room = testClientB.rooms.first;
      try {
        await room.leave();
        await room.forget();
      } catch (_) {}
    }
  }

  Logs.success('++++ Check if own olm device is verified by default ++++');
  assert(testClientA.userDeviceKeys.containsKey(testUserA));
  assert(testClientA.userDeviceKeys[testUserA].deviceKeys
      .containsKey(testClientA.deviceID));
  assert(testClientA
      .userDeviceKeys[testUserA].deviceKeys[testClientA.deviceID].verified);
  assert(!testClientA
      .userDeviceKeys[testUserA].deviceKeys[testClientA.deviceID].blocked);
  assert(testClientB.userDeviceKeys.containsKey(testUserB));
  assert(testClientB.userDeviceKeys[testUserB].deviceKeys
      .containsKey(testClientB.deviceID));
  assert(testClientB
      .userDeviceKeys[testUserB].deviceKeys[testClientB.deviceID].verified);
  assert(!testClientB
      .userDeviceKeys[testUserB].deviceKeys[testClientB.deviceID].blocked);

  Logs.success('++++ ($testUserA) Create room and invite $testUserB ++++');
  await testClientA.createRoom(invite: [testUserB]);
  await Future.delayed(Duration(seconds: 1));
  var room = testClientA.rooms.first;
  assert(room != null);
  final roomId = room.id;

  Logs.success('++++ ($testUserB) Join room ++++');
  var inviteRoom = testClientB.getRoomById(roomId);
  await inviteRoom.join();
  await Future.delayed(Duration(seconds: 1));
  assert(inviteRoom.membership == Membership.join);

  Logs.success('++++ ($testUserA) Enable encryption ++++');
  assert(room.encrypted == false);
  await room.enableEncryption();
  await Future.delayed(Duration(seconds: 5));
  assert(room.encrypted == true);
  assert(room.client.encryption.keyManager.getOutboundGroupSession(room.id) ==
      null);

  Logs.success('++++ ($testUserA) Check known olm devices ++++');
  assert(testClientA.userDeviceKeys.containsKey(testUserB));
  assert(testClientA.userDeviceKeys[testUserB].deviceKeys
      .containsKey(testClientB.deviceID));
  assert(!testClientA
      .userDeviceKeys[testUserB].deviceKeys[testClientB.deviceID].verified);
  assert(!testClientA
      .userDeviceKeys[testUserB].deviceKeys[testClientB.deviceID].blocked);
  assert(testClientB.userDeviceKeys.containsKey(testUserA));
  assert(testClientB.userDeviceKeys[testUserA].deviceKeys
      .containsKey(testClientA.deviceID));
  assert(!testClientB
      .userDeviceKeys[testUserA].deviceKeys[testClientA.deviceID].verified);
  assert(!testClientB
      .userDeviceKeys[testUserA].deviceKeys[testClientA.deviceID].blocked);
  await testClientA.userDeviceKeys[testUserB].deviceKeys[testClientB.deviceID]
      .setVerified(true);

  Logs.success('++++ Check if own olm device is verified by default ++++');
  assert(testClientA.userDeviceKeys.containsKey(testUserA));
  assert(testClientA.userDeviceKeys[testUserA].deviceKeys
      .containsKey(testClientA.deviceID));
  assert(testClientA
      .userDeviceKeys[testUserA].deviceKeys[testClientA.deviceID].verified);
  assert(testClientB.userDeviceKeys.containsKey(testUserB));
  assert(testClientB.userDeviceKeys[testUserB].deviceKeys
      .containsKey(testClientB.deviceID));
  assert(testClientB
      .userDeviceKeys[testUserB].deviceKeys[testClientB.deviceID].verified);

  Logs.success("++++ ($testUserA) Send encrypted message: '$testMessage' ++++");
  await room.sendTextEvent(testMessage);
  await Future.delayed(Duration(seconds: 5));
  assert(room.client.encryption.keyManager.getOutboundGroupSession(room.id) !=
      null);
  var currentSessionIdA = room.client.encryption.keyManager
      .getOutboundGroupSession(room.id)
      .outboundGroupSession
      .session_id();
  assert(room.client.encryption.keyManager
          .getInboundGroupSession(room.id, currentSessionIdA, '') !=
      null);
  assert(testClientA
          .encryption.olmManager.olmSessions[testClientB.identityKey].length ==
      1);
  assert(testClientB
          .encryption.olmManager.olmSessions[testClientA.identityKey].length ==
      1);
  assert(testClientA.encryption.olmManager.olmSessions[testClientB.identityKey]
          .first.sessionId ==
      testClientB.encryption.olmManager.olmSessions[testClientA.identityKey]
          .first.sessionId);
  assert(inviteRoom.client.encryption.keyManager
          .getInboundGroupSession(inviteRoom.id, currentSessionIdA, '') !=
      null);
  assert(room.lastMessage == testMessage);
  assert(inviteRoom.lastMessage == testMessage);
  Logs.success(
      "++++ ($testUserB) Received decrypted message: '${inviteRoom.lastMessage}' ++++");

  Logs.success(
      "++++ ($testUserA) Send again encrypted message: '$testMessage2' ++++");
  await room.sendTextEvent(testMessage2);
  await Future.delayed(Duration(seconds: 5));
  assert(testClientA
          .encryption.olmManager.olmSessions[testClientB.identityKey].length ==
      1);
  assert(testClientB
          .encryption.olmManager.olmSessions[testClientA.identityKey].length ==
      1);
  assert(testClientA.encryption.olmManager.olmSessions[testClientB.identityKey]
          .first.sessionId ==
      testClientB.encryption.olmManager.olmSessions[testClientA.identityKey]
          .first.sessionId);

  assert(room.client.encryption.keyManager
          .getOutboundGroupSession(room.id)
          .outboundGroupSession
          .session_id() ==
      currentSessionIdA);
  assert(room.client.encryption.keyManager
          .getInboundGroupSession(room.id, currentSessionIdA, '') !=
      null);
  assert(room.lastMessage == testMessage2);
  assert(inviteRoom.lastMessage == testMessage2);
  Logs.success(
      "++++ ($testUserB) Received decrypted message: '${inviteRoom.lastMessage}' ++++");

  Logs.success(
      "++++ ($testUserB) Send again encrypted message: '$testMessage3' ++++");
  await inviteRoom.sendTextEvent(testMessage3);
  await Future.delayed(Duration(seconds: 5));
  assert(testClientA
          .encryption.olmManager.olmSessions[testClientB.identityKey].length ==
      1);
  assert(testClientB
          .encryption.olmManager.olmSessions[testClientA.identityKey].length ==
      1);
  assert(room.client.encryption.keyManager
          .getOutboundGroupSession(room.id)
          .outboundGroupSession
          .session_id() ==
      currentSessionIdA);
  var inviteRoomOutboundGroupSession = inviteRoom.client.encryption.keyManager
      .getOutboundGroupSession(inviteRoom.id);

  assert(inviteRoomOutboundGroupSession != null);
  assert(inviteRoom.client.encryption.keyManager.getInboundGroupSession(
          inviteRoom.id,
          inviteRoomOutboundGroupSession.outboundGroupSession.session_id(),
          '') !=
      null);
  assert(room.client.encryption.keyManager.getInboundGroupSession(
          room.id,
          inviteRoomOutboundGroupSession.outboundGroupSession.session_id(),
          '') !=
      null);
  assert(inviteRoom.lastMessage == testMessage3);
  assert(room.lastMessage == testMessage3);
  Logs.success(
      "++++ ($testUserA) Received decrypted message: '${room.lastMessage}' ++++");

  Logs.success('++++ Login $testUserB in another client ++++');
  var testClientC = Client('TestClientC', database: getDatabase());
  await testClientC.checkServer(homeserver);
  await testClientC.login(user: testUserB, password: testPasswordA);
  await Future.delayed(Duration(seconds: 3));

  Logs.success(
      "++++ ($testUserA) Send again encrypted message: '$testMessage4' ++++");
  await room.sendTextEvent(testMessage4);
  await Future.delayed(Duration(seconds: 5));
  assert(testClientA
          .encryption.olmManager.olmSessions[testClientB.identityKey].length ==
      1);
  assert(testClientB
          .encryption.olmManager.olmSessions[testClientA.identityKey].length ==
      1);
  assert(testClientA.encryption.olmManager.olmSessions[testClientB.identityKey]
          .first.sessionId ==
      testClientB.encryption.olmManager.olmSessions[testClientA.identityKey]
          .first.sessionId);
  assert(testClientA
          .encryption.olmManager.olmSessions[testClientC.identityKey].length ==
      1);
  assert(testClientC
          .encryption.olmManager.olmSessions[testClientA.identityKey].length ==
      1);
  assert(testClientA.encryption.olmManager.olmSessions[testClientC.identityKey]
          .first.sessionId ==
      testClientC.encryption.olmManager.olmSessions[testClientA.identityKey]
          .first.sessionId);
  assert(room.client.encryption.keyManager
          .getOutboundGroupSession(room.id)
          .outboundGroupSession
          .session_id() !=
      currentSessionIdA);
  currentSessionIdA = room.client.encryption.keyManager
      .getOutboundGroupSession(room.id)
      .outboundGroupSession
      .session_id();
  assert(inviteRoom.client.encryption.keyManager
          .getInboundGroupSession(inviteRoom.id, currentSessionIdA, '') !=
      null);
  assert(room.lastMessage == testMessage4);
  assert(inviteRoom.lastMessage == testMessage4);
  Logs.success(
      "++++ ($testUserB) Received decrypted message: '${inviteRoom.lastMessage}' ++++");

  Logs.success('++++ Logout $testUserB another client ++++');
  await testClientC.dispose();
  await testClientC.logout();
  testClientC = null;
  await Future.delayed(Duration(seconds: 5));

  Logs.success(
      "++++ ($testUserA) Send again encrypted message: '$testMessage6' ++++");
  await room.sendTextEvent(testMessage6);
  await Future.delayed(Duration(seconds: 5));
  assert(testClientA
          .encryption.olmManager.olmSessions[testClientB.identityKey].length ==
      1);
  assert(testClientB
          .encryption.olmManager.olmSessions[testClientA.identityKey].length ==
      1);
  assert(testClientA.encryption.olmManager.olmSessions[testClientB.identityKey]
          .first.sessionId ==
      testClientB.encryption.olmManager.olmSessions[testClientA.identityKey]
          .first.sessionId);
  assert(room.client.encryption.keyManager
          .getOutboundGroupSession(room.id)
          .outboundGroupSession
          .session_id() !=
      currentSessionIdA);
  currentSessionIdA = room.client.encryption.keyManager
      .getOutboundGroupSession(room.id)
      .outboundGroupSession
      .session_id();
  assert(inviteRoom.client.encryption.keyManager
          .getInboundGroupSession(inviteRoom.id, currentSessionIdA, '') !=
      null);
  assert(room.lastMessage == testMessage6);
  assert(inviteRoom.lastMessage == testMessage6);
  Logs.success(
      "++++ ($testUserB) Received decrypted message: '${inviteRoom.lastMessage}' ++++");

/*  Logs.success('++++ ($testUserA) Restore user ++++');
  await testClientA.dispose();
  testClientA = null;
  testClientA = Client(
    'TestClientA',
    debug: false,
    database: getDatabase(),
  );
  testClientA.connect();
  await Future.delayed(Duration(seconds: 3));
  var restoredRoom = testClientA.rooms.first;
  assert(room != null);
  assert(restoredRoom.id == room.id);
  assert(restoredRoom.outboundGroupSession.session_id() ==
      room.outboundGroupSession.session_id());
  assert(restoredRoom.inboundGroupSessions.length == 4);
  assert(restoredRoom.inboundGroupSessions.length ==
      room.inboundGroupSessions.length);
  for (var i = 0; i < restoredRoom.inboundGroupSessions.length; i++) {
    assert(restoredRoom.inboundGroupSessions.keys.toList()[i] ==
        room.inboundGroupSessions.keys.toList()[i]);
  }
  assert(testClientA.encryption.olmManager.olmSessions[testClientB.identityKey].length == 1);
  assert(testClientB.encryption.olmManager.olmSessions[testClientA.identityKey].length == 1);
  assert(testClientA.encryption.olmManager.olmSessions[testClientB.identityKey].first.session_id() ==
      testClientB.encryption.olmManager.olmSessions[testClientA.identityKey].first.session_id());

  Logs.success("++++ ($testUserA) Send again encrypted message: '$testMessage5' ++++");
  await restoredRoom.sendTextEvent(testMessage5);
  await Future.delayed(Duration(seconds: 5));
  assert(testClientA.encryption.olmManager.olmSessions[testClientB.identityKey].length == 1);
  assert(testClientB.encryption.olmManager.olmSessions[testClientA.identityKey].length == 1);
  assert(testClientA.encryption.olmManager.olmSessions[testClientB.identityKey].first.session_id() ==
      testClientB.encryption.olmManager.olmSessions[testClientA.identityKey].first.session_id());
  assert(restoredRoom.lastMessage == testMessage5);
  assert(inviteRoom.lastMessage == testMessage5);
  assert(testClientB.getRoomById(roomId).lastMessage == testMessage5);
  Logs.success(
      "++++ ($testUserB) Received decrypted message: '${inviteRoom.lastMessage}' ++++");*/

  Logs.success('++++ Logout $testUserA and $testUserB ++++');
  await room.leave();
  await room.forget();
  await inviteRoom.leave();
  await inviteRoom.forget();
  await Future.delayed(Duration(seconds: 1));
  await testClientA.dispose();
  await testClientB.dispose();
  await testClientA.logoutAll();
  await testClientB.logoutAll();
  testClientA = null;
  testClientB = null;
  return;
}
