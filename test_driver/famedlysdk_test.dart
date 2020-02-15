import 'package:famedlysdk/famedlysdk.dart';
import '../test/fake_store.dart';

void main() => test();

const String homeserver = "https://matrix.test.famedly.de";
const String testUserA = "@tick:test.famedly.de";
const String testPasswordA = "test";
const String testUserB = "@trick:test.famedly.de";
const String testPasswordB = "test";
const String testMessage = "Hello world";
const String testMessage2 = "Hello moon";
const String testMessage3 = "Hello sun";

void test() async {
  print("++++ Login $testUserA ++++");
  Client testClientA = Client("TestClient", debug: false);
  testClientA.storeAPI = FakeStore(testClientA, Map<String, dynamic>());
  await testClientA.checkServer(homeserver);
  await testClientA.login(testUserA, testPasswordA);

  print("++++ Login $testUserB ++++");
  Client testClientB = Client("TestClient", debug: false);
  testClientB.storeAPI = FakeStore(testClientB, Map<String, dynamic>());
  await testClientB.checkServer(homeserver);
  await testClientB.login(testUserB, testPasswordA);

  print("++++ ($testUserA) Leave all rooms ++++");
  while (testClientA.rooms.isNotEmpty) {
    Room room = testClientA.rooms.first;
    if (room.canonicalAlias?.isNotEmpty ?? false) {
      break;
    }
    await room.leave();
    await room.forget();
  }

  print("++++ ($testUserB) Leave all rooms ++++");
  if (testClientB.rooms.isNotEmpty) {
    Room room = testClientB.rooms.first;
    await room.leave();
    await room.forget();
  }
  if (testClientB.rooms.isNotEmpty) {
    Room room = testClientB.rooms.first;
    await room.leave();
    await room.forget();
  }

  print("++++ ($testUserA) Create room and invite $testUserB ++++");
  await testClientA.createRoom(invite: [User(testUserB)]);
  await Future.delayed(Duration(seconds: 1));
  Room room = testClientA.rooms.first;
  assert(room != null);
  final String roomId = room.id;

  print("++++ ($testUserB) Join room ++++");
  Room inviteRoom = testClientB.getRoomById(roomId);
  await inviteRoom.join();
  await Future.delayed(Duration(seconds: 1));
  assert(inviteRoom.membership == Membership.join);

  print("++++ ($testUserA) Enable encryption ++++");
  assert(room.encrypted == false);
  await room.enableEncryption();
  await Future.delayed(Duration(seconds: 5));
  assert(room.encrypted == true);
  assert(room.outboundGroupSession == null);

  print("++++ ($testUserA) Check known olm devices ++++");
  assert(testClientA.userDeviceKeys.containsKey(testUserB));
  assert(testClientA.userDeviceKeys[testUserB].deviceKeys
      .containsKey(testClientB.deviceID));

  print("++++ ($testUserA) Send encrypted message: '$testMessage' ++++");
  await room.sendTextEvent(testMessage);
  await Future.delayed(Duration(seconds: 5));
  assert(room.outboundGroupSession != null);
  final String currentSessionIdA = room.outboundGroupSession.session_id();
  assert(room.sessionKeys.containsKey(room.outboundGroupSession.session_id()));
  assert(testClientA.olmSessions[testClientB.identityKey].length == 1);
  assert(testClientB.olmSessions[testClientA.identityKey].length == 1);
  assert(inviteRoom.sessionKeys
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
  assert(room.outboundGroupSession.session_id() == currentSessionIdA);
  assert(inviteRoom.sessionKeys
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
  assert(inviteRoom.sessionKeys
      .containsKey(inviteRoom.outboundGroupSession.session_id()));
  assert(room.sessionKeys
      .containsKey(inviteRoom.outboundGroupSession.session_id()));
  assert(inviteRoom.lastMessage == testMessage3);
  assert(room.lastMessage == testMessage3);
  print(
      "++++ ($testUserA) Received decrypted message: '${room.lastMessage}' ++++");

  print("++++ Logout $testUserA and $testUserB ++++");
  await room.leave();
  await room.forget();
  await inviteRoom.leave();
  await inviteRoom.forget();
  await Future.delayed(Duration(seconds: 1));
  await testClientA.jsonRequest(
      type: HTTPType.POST, action: "/client/r0/logout/all");
  await testClientB.jsonRequest(
      type: HTTPType.POST, action: "/client/r0/logout/all");
  testClientA = null;
  testClientB = null;
}
