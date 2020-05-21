import 'package:famedlysdk/famedlysdk.dart';
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
  print('++++ Login $testUserA ++++');
  var testClientA = Client('TestClient', debug: false);
  testClientA.database = getDatabase();
  await testClientA.checkServer(homeserver);
  await testClientA.login(testUserA, testPasswordA);
  assert(testClientA.encryptionEnabled);

  print('++++ Login $testUserB ++++');
  var testClientB = Client('TestClient', debug: false);
  testClientB.database = getDatabase();
  await testClientB.checkServer(homeserver);
  await testClientB.login(testUserB, testPasswordA);
  assert(testClientB.encryptionEnabled);

  print('++++ ($testUserA) Leave all rooms ++++');
  while (testClientA.rooms.isNotEmpty) {
    var room = testClientA.rooms.first;
    if (room.canonicalAlias?.isNotEmpty ?? false) {
      break;
    }
    try {
      await room.leave();
      await room.forget();
    } catch (e) {
      print(e);
    }
  }

  print('++++ ($testUserB) Leave all rooms ++++');
  for (var i = 0; i < 3; i++) {
    if (testClientB.rooms.isNotEmpty) {
      var room = testClientB.rooms.first;
      try {
        await room.leave();
        await room.forget();
      } catch (e) {
        print(e);
      }
    }
  }

  print('++++ Check if own olm device is verified by default ++++');
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

  print('++++ ($testUserA) Create room and invite $testUserB ++++');
  await testClientA.createRoom(invite: [User(testUserB)]);
  await Future.delayed(Duration(seconds: 1));
  var room = testClientA.rooms.first;
  assert(room != null);
  final roomId = room.id;

  print('++++ ($testUserB) Join room ++++');
  var inviteRoom = testClientB.getRoomById(roomId);
  await inviteRoom.join();
  await Future.delayed(Duration(seconds: 1));
  assert(inviteRoom.membership == Membership.join);

  print('++++ ($testUserA) Enable encryption ++++');
  assert(room.encrypted == false);
  await room.enableEncryption();
  await Future.delayed(Duration(seconds: 5));
  assert(room.encrypted == true);
  assert(room.outboundGroupSession == null);

  print('++++ ($testUserA) Check known olm devices ++++');
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

  print('++++ Check if own olm device is verified by default ++++');
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

  print("++++ ($testUserA) Send encrypted message: '$testMessage' ++++");
  await room.sendTextEvent(testMessage);
  await Future.delayed(Duration(seconds: 5));
  assert(room.outboundGroupSession != null);
  var currentSessionIdA = room.outboundGroupSession.session_id();
  assert(room.inboundGroupSessions.containsKey(room.outboundGroupSession.session_id()));
  assert(testClientA.olmSessions[testClientB.identityKey].length == 1);
  assert(testClientB.olmSessions[testClientA.identityKey].length == 1);
  assert(testClientA.olmSessions[testClientB.identityKey].first.session_id() ==
      testClientB.olmSessions[testClientA.identityKey].first.session_id());
  assert(inviteRoom.inboundGroupSessions
      .containsKey(room.outboundGroupSession.session_id()));
  assert(room.lastMessage == testMessage);
  assert(inviteRoom.lastMessage == testMessage);
  print(
      "++++ ($testUserB) Received decrypted message: '${inviteRoom.lastMessage}' ++++");

  print("++++ ($testUserA) Send again encrypted message: '$testMessage2' ++++");
  await room.sendTextEvent(testMessage2);
  await Future.delayed(Duration(seconds: 5));
  assert(testClientA.olmSessions[testClientB.identityKey].length == 1);
  assert(testClientB.olmSessions[testClientA.identityKey].length == 1);
  assert(testClientA.olmSessions[testClientB.identityKey].first.session_id() ==
      testClientB.olmSessions[testClientA.identityKey].first.session_id());

  assert(room.outboundGroupSession.session_id() == currentSessionIdA);
  assert(inviteRoom.inboundGroupSessions
      .containsKey(room.outboundGroupSession.session_id()));
  assert(room.lastMessage == testMessage2);
  assert(inviteRoom.lastMessage == testMessage2);
  print(
      "++++ ($testUserB) Received decrypted message: '${inviteRoom.lastMessage}' ++++");

  print("++++ ($testUserB) Send again encrypted message: '$testMessage3' ++++");
  await inviteRoom.sendTextEvent(testMessage3);
  await Future.delayed(Duration(seconds: 5));
  assert(testClientA.olmSessions[testClientB.identityKey].length == 1);
  assert(testClientB.olmSessions[testClientA.identityKey].length == 1);
  assert(room.outboundGroupSession.session_id() == currentSessionIdA);
  assert(inviteRoom.outboundGroupSession != null);
  assert(inviteRoom.inboundGroupSessions
      .containsKey(inviteRoom.outboundGroupSession.session_id()));
  assert(room.inboundGroupSessions
      .containsKey(inviteRoom.outboundGroupSession.session_id()));
  assert(inviteRoom.lastMessage == testMessage3);
  assert(room.lastMessage == testMessage3);
  print(
      "++++ ($testUserA) Received decrypted message: '${room.lastMessage}' ++++");

  print('++++ Login $testUserB in another client ++++');
  var testClientC = Client('TestClient', debug: false);
  testClientC.database = getDatabase();
  await testClientC.checkServer(homeserver);
  await testClientC.login(testUserB, testPasswordA);
  await Future.delayed(Duration(seconds: 3));
  assert(room.outboundGroupSession == null);

  print("++++ ($testUserA) Send again encrypted message: '$testMessage4' ++++");
  await room.sendTextEvent(testMessage4);
  await Future.delayed(Duration(seconds: 5));
  assert(testClientA.olmSessions[testClientB.identityKey].length == 1);
  assert(testClientB.olmSessions[testClientA.identityKey].length == 1);
  assert(testClientA.olmSessions[testClientB.identityKey].first.session_id() ==
      testClientB.olmSessions[testClientA.identityKey].first.session_id());
  assert(testClientA.olmSessions[testClientC.identityKey].length == 1);
  assert(testClientC.olmSessions[testClientA.identityKey].length == 1);
  assert(testClientA.olmSessions[testClientC.identityKey].first.session_id() ==
      testClientC.olmSessions[testClientA.identityKey].first.session_id());
  assert(room.outboundGroupSession.session_id() != currentSessionIdA);
  currentSessionIdA = room.outboundGroupSession.session_id();
  assert(inviteRoom.inboundGroupSessions
      .containsKey(room.outboundGroupSession.session_id()));
  assert(room.lastMessage == testMessage4);
  assert(inviteRoom.lastMessage == testMessage4);
  print(
      "++++ ($testUserB) Received decrypted message: '${inviteRoom.lastMessage}' ++++");

  print('++++ Logout $testUserB another client ++++');
  await testClientC.logout();
  testClientC = null;
  await Future.delayed(Duration(seconds: 5));
  assert(room.outboundGroupSession == null);
  assert(inviteRoom.outboundGroupSession == null);

  print("++++ ($testUserA) Send again encrypted message: '$testMessage6' ++++");
  await room.sendTextEvent(testMessage6);
  await Future.delayed(Duration(seconds: 5));
  assert(testClientA.olmSessions[testClientB.identityKey].length == 1);
  assert(testClientB.olmSessions[testClientA.identityKey].length == 1);
  assert(testClientA.olmSessions[testClientB.identityKey].first.session_id() ==
      testClientB.olmSessions[testClientA.identityKey].first.session_id());
  assert(room.outboundGroupSession.session_id() != currentSessionIdA);
  currentSessionIdA = room.outboundGroupSession.session_id();
  assert(inviteRoom.inboundGroupSessions
      .containsKey(room.outboundGroupSession.session_id()));
  assert(room.lastMessage == testMessage6);
  assert(inviteRoom.lastMessage == testMessage6);
  print(
      "++++ ($testUserB) Received decrypted message: '${inviteRoom.lastMessage}' ++++");

  print('++++ ($testUserA) Restore user ++++');
  final clientADatabase = testClientA.database;
  testClientA = null;
  testClientA = Client('TestClient', debug: false);
  testClientA.database = clientADatabase;
  testClientA.connect();
  await Future.delayed(Duration(seconds: 3));
  var restoredRoom = testClientA.rooms.first;
  assert(room != null);
  assert(restoredRoom.id == room.id);
  assert(restoredRoom.outboundGroupSession.session_id() ==
      room.outboundGroupSession.session_id());
  assert(restoredRoom.inboundGroupSessions.length == 4);
  assert(restoredRoom.inboundGroupSessions.length == room.inboundGroupSessions.length);
  for (var i = 0; i < restoredRoom.inboundGroupSessions.length; i++) {
    assert(restoredRoom.inboundGroupSessions.keys.toList()[i] ==
        room.inboundGroupSessions.keys.toList()[i]);
  }
  assert(testClientA.olmSessions[testClientB.identityKey].length == 1);
  assert(testClientB.olmSessions[testClientA.identityKey].length == 1);
  assert(testClientA.olmSessions[testClientB.identityKey].first.session_id() ==
      testClientB.olmSessions[testClientA.identityKey].first.session_id());

  print("++++ ($testUserA) Send again encrypted message: '$testMessage5' ++++");
  await restoredRoom.sendTextEvent(testMessage5);
  await Future.delayed(Duration(seconds: 5));
  assert(testClientA.olmSessions[testClientB.identityKey].length == 1);
  assert(testClientB.olmSessions[testClientA.identityKey].length == 1);
  assert(testClientA.olmSessions[testClientB.identityKey].first.session_id() ==
      testClientB.olmSessions[testClientA.identityKey].first.session_id());
  /*assert(restoredRoom.outboundGroupSession.session_id() == currentSessionIdA);
  assert(inviteRoom.inboundGroupSessions
      .containsKey(restoredRoom.outboundGroupSession.session_id()));*/
  assert(restoredRoom.lastMessage == testMessage5);
  assert(inviteRoom.lastMessage == testMessage5);
  assert(testClientB.getRoomById(roomId).lastMessage == testMessage5);
  print(
      "++++ ($testUserB) Received decrypted message: '${inviteRoom.lastMessage}' ++++");

  print('++++ Logout $testUserA and $testUserB ++++');
  await room.leave();
  await room.forget();
  await inviteRoom.leave();
  await inviteRoom.forget();
  await Future.delayed(Duration(seconds: 1));
  await testClientA.jsonRequest(
      type: HTTPType.POST, action: '/client/r0/logout/all');
  await testClientB.jsonRequest(
      type: HTTPType.POST, action: '/client/r0/logout/all');
  testClientA = null;
  testClientB = null;
  return;
}
