import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/matrix_api.dart';
import 'package:famedlysdk/src/utils/logs.dart';
import '../test/fake_database.dart';
import 'test_config.dart';
import 'package:olm/olm.dart' as olm;

void main() => test();
const String testMessage = 'Hello world';
const String testMessage2 = 'Hello moon';
const String testMessage3 = 'Hello sun';
const String testMessage4 = 'Hello star';
const String testMessage5 = 'Hello earth';
const String testMessage6 = 'Hello mars';

void test() async {
  Client testClientA, testClientB;

  try {
    await olm.init();
    olm.Account();
    Logs.success('[LibOlm] Enabled');

    Logs.success('++++ Login Alice at ++++');
    testClientA = Client('TestClientA');
    testClientA.database = getDatabase();
    await testClientA.checkHomeserver(TestUser.homeserver);
    await testClientA.login(
        user: TestUser.username, password: TestUser.password);
    assert(testClientA.encryptionEnabled);

    Logs.success('++++ Login Bob ++++');
    testClientB = Client('TestClientB');
    testClientB.database = getDatabase();
    await testClientB.checkHomeserver(TestUser.homeserver);
    await testClientB.login(
        user: TestUser.username2, password: TestUser.password);
    assert(testClientB.encryptionEnabled);

    Logs.success('++++ (Alice) Leave all rooms ++++');
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

    Logs.success('++++ (Bob) Leave all rooms ++++');
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
    assert(testClientA.userDeviceKeys.containsKey(TestUser.username));
    assert(testClientA.userDeviceKeys[TestUser.username].deviceKeys
        .containsKey(testClientA.deviceID));
    assert(testClientA.userDeviceKeys[TestUser.username]
        .deviceKeys[testClientA.deviceID].verified);
    assert(!testClientA.userDeviceKeys[TestUser.username]
        .deviceKeys[testClientA.deviceID].blocked);
    assert(testClientB.userDeviceKeys.containsKey(TestUser.username2));
    assert(testClientB.userDeviceKeys[TestUser.username2].deviceKeys
        .containsKey(testClientB.deviceID));
    assert(testClientB.userDeviceKeys[TestUser.username2]
        .deviceKeys[testClientB.deviceID].verified);
    assert(!testClientB.userDeviceKeys[TestUser.username2]
        .deviceKeys[testClientB.deviceID].blocked);

    Logs.success('++++ (Alice) Create room and invite Bob ++++');
    await testClientA.createRoom(invite: [TestUser.username2]);
    await Future.delayed(Duration(seconds: 1));
    var room = testClientA.rooms.first;
    assert(room != null);
    final roomId = room.id;

    Logs.success('++++ (Bob) Join room ++++');
    var inviteRoom = testClientB.getRoomById(roomId);
    await inviteRoom.join();
    await Future.delayed(Duration(seconds: 1));
    assert(inviteRoom.membership == Membership.join);

    Logs.success('++++ (Alice) Enable encryption ++++');
    assert(room.encrypted == false);
    await room.enableEncryption();
    await Future.delayed(Duration(seconds: 5));
    assert(room.encrypted == true);
    assert(room.client.encryption.keyManager.getOutboundGroupSession(room.id) ==
        null);

    Logs.success('++++ (Alice) Check known olm devices ++++');
    assert(testClientA.userDeviceKeys.containsKey(TestUser.username2));
    assert(testClientA.userDeviceKeys[TestUser.username2].deviceKeys
        .containsKey(testClientB.deviceID));
    assert(!testClientA.userDeviceKeys[TestUser.username2]
        .deviceKeys[testClientB.deviceID].verified);
    assert(!testClientA.userDeviceKeys[TestUser.username2]
        .deviceKeys[testClientB.deviceID].blocked);
    assert(testClientB.userDeviceKeys.containsKey(TestUser.username));
    assert(testClientB.userDeviceKeys[TestUser.username].deviceKeys
        .containsKey(testClientA.deviceID));
    assert(!testClientB.userDeviceKeys[TestUser.username]
        .deviceKeys[testClientA.deviceID].verified);
    assert(!testClientB.userDeviceKeys[TestUser.username]
        .deviceKeys[testClientA.deviceID].blocked);
    await testClientA
        .userDeviceKeys[TestUser.username2].deviceKeys[testClientB.deviceID]
        .setVerified(true);

    Logs.success('++++ Check if own olm device is verified by default ++++');
    assert(testClientA.userDeviceKeys.containsKey(TestUser.username));
    assert(testClientA.userDeviceKeys[TestUser.username].deviceKeys
        .containsKey(testClientA.deviceID));
    assert(testClientA.userDeviceKeys[TestUser.username]
        .deviceKeys[testClientA.deviceID].verified);
    assert(testClientB.userDeviceKeys.containsKey(TestUser.username2));
    assert(testClientB.userDeviceKeys[TestUser.username2].deviceKeys
        .containsKey(testClientB.deviceID));
    assert(testClientB.userDeviceKeys[TestUser.username2]
        .deviceKeys[testClientB.deviceID].verified);

    Logs.success("++++ (Alice) Send encrypted message: '$testMessage' ++++");
    await room.sendTextEvent(testMessage);
    await Future.delayed(Duration(seconds: 5));
    assert(room.client.encryption.keyManager.getOutboundGroupSession(room.id) !=
        null);
    var currentSessionIdA = room.client.encryption.keyManager
        .getOutboundGroupSession(room.id)
        .outboundGroupSession
        .session_id();
    /*assert(room.client.encryption.keyManager
          .getInboundGroupSession(room.id, currentSessionIdA, '') !=
      null);*/
    assert(testClientA.encryption.olmManager
            .olmSessions[testClientB.identityKey].length ==
        1);
    assert(testClientB.encryption.olmManager
            .olmSessions[testClientA.identityKey].length ==
        1);
    assert(testClientA.encryption.olmManager
            .olmSessions[testClientB.identityKey].first.sessionId ==
        testClientB.encryption.olmManager.olmSessions[testClientA.identityKey]
            .first.sessionId);
    /*assert(inviteRoom.client.encryption.keyManager
          .getInboundGroupSession(inviteRoom.id, currentSessionIdA, '') !=
      null);*/
    assert(room.lastMessage == testMessage);
    assert(inviteRoom.lastMessage == testMessage);
    Logs.success(
        "++++ (Bob) Received decrypted message: '${inviteRoom.lastMessage}' ++++");

    Logs.success(
        "++++ (Alice) Send again encrypted message: '$testMessage2' ++++");
    await room.sendTextEvent(testMessage2);
    await Future.delayed(Duration(seconds: 5));
    assert(testClientA.encryption.olmManager
            .olmSessions[testClientB.identityKey].length ==
        1);
    assert(testClientB.encryption.olmManager
            .olmSessions[testClientA.identityKey].length ==
        1);
    assert(testClientA.encryption.olmManager
            .olmSessions[testClientB.identityKey].first.sessionId ==
        testClientB.encryption.olmManager.olmSessions[testClientA.identityKey]
            .first.sessionId);

    assert(room.client.encryption.keyManager
            .getOutboundGroupSession(room.id)
            .outboundGroupSession
            .session_id() ==
        currentSessionIdA);
    /*assert(room.client.encryption.keyManager
          .getInboundGroupSession(room.id, currentSessionIdA, '') !=
      null);*/
    assert(room.lastMessage == testMessage2);
    assert(inviteRoom.lastMessage == testMessage2);
    Logs.success(
        "++++ (Bob) Received decrypted message: '${inviteRoom.lastMessage}' ++++");

    Logs.success(
        "++++ (Bob) Send again encrypted message: '$testMessage3' ++++");
    await inviteRoom.sendTextEvent(testMessage3);
    await Future.delayed(Duration(seconds: 5));
    assert(testClientA.encryption.olmManager
            .olmSessions[testClientB.identityKey].length ==
        1);
    assert(testClientB.encryption.olmManager
            .olmSessions[testClientA.identityKey].length ==
        1);
    assert(room.client.encryption.keyManager
            .getOutboundGroupSession(room.id)
            .outboundGroupSession
            .session_id() ==
        currentSessionIdA);
    var inviteRoomOutboundGroupSession = inviteRoom.client.encryption.keyManager
        .getOutboundGroupSession(inviteRoom.id);

    assert(inviteRoomOutboundGroupSession != null);
    /*assert(inviteRoom.client.encryption.keyManager.getInboundGroupSession(
          inviteRoom.id,
          inviteRoomOutboundGroupSession.outboundGroupSession.session_id(),
          '') !=
      null);
  assert(room.client.encryption.keyManager.getInboundGroupSession(
          room.id,
          inviteRoomOutboundGroupSession.outboundGroupSession.session_id(),
          '') !=
      null);*/
    assert(inviteRoom.lastMessage == testMessage3);
    assert(room.lastMessage == testMessage3);
    Logs.success(
        "++++ (Alice) Received decrypted message: '${room.lastMessage}' ++++");

    Logs.success('++++ Login Bob in another client ++++');
    var testClientC = Client('TestClientC', database: getDatabase());
    await testClientC.checkHomeserver(TestUser.homeserver);
    await testClientC.login(
        user: TestUser.username2, password: TestUser.password);
    await Future.delayed(Duration(seconds: 3));

    Logs.success(
        "++++ (Alice) Send again encrypted message: '$testMessage4' ++++");
    await room.sendTextEvent(testMessage4);
    await Future.delayed(Duration(seconds: 5));
    assert(testClientA.encryption.olmManager
            .olmSessions[testClientB.identityKey].length ==
        1);
    assert(testClientB.encryption.olmManager
            .olmSessions[testClientA.identityKey].length ==
        1);
    assert(testClientA.encryption.olmManager
            .olmSessions[testClientB.identityKey].first.sessionId ==
        testClientB.encryption.olmManager.olmSessions[testClientA.identityKey]
            .first.sessionId);
    assert(testClientA.encryption.olmManager
            .olmSessions[testClientC.identityKey].length ==
        1);
    assert(testClientC.encryption.olmManager
            .olmSessions[testClientA.identityKey].length ==
        1);
    assert(testClientA.encryption.olmManager
            .olmSessions[testClientC.identityKey].first.sessionId ==
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
    /*assert(inviteRoom.client.encryption.keyManager
          .getInboundGroupSession(inviteRoom.id, currentSessionIdA, '') !=
      null);*/
    assert(room.lastMessage == testMessage4);
    assert(inviteRoom.lastMessage == testMessage4);
    Logs.success(
        "++++ (Bob) Received decrypted message: '${inviteRoom.lastMessage}' ++++");

    Logs.success('++++ Logout Bob another client ++++');
    await testClientC.dispose();
    await testClientC.logout();
    testClientC = null;
    await Future.delayed(Duration(seconds: 5));

    Logs.success(
        "++++ (Alice) Send again encrypted message: '$testMessage6' ++++");
    await room.sendTextEvent(testMessage6);
    await Future.delayed(Duration(seconds: 5));
    assert(testClientA.encryption.olmManager
            .olmSessions[testClientB.identityKey].length ==
        1);
    assert(testClientB.encryption.olmManager
            .olmSessions[testClientA.identityKey].length ==
        1);
    assert(testClientA.encryption.olmManager
            .olmSessions[testClientB.identityKey].first.sessionId ==
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
    /*assert(inviteRoom.client.encryption.keyManager
          .getInboundGroupSession(inviteRoom.id, currentSessionIdA, '') !=
      null);*/
    assert(room.lastMessage == testMessage6);
    assert(inviteRoom.lastMessage == testMessage6);
    Logs.success(
        "++++ (Bob) Received decrypted message: '${inviteRoom.lastMessage}' ++++");

    await room.leave();
    await room.forget();
    await inviteRoom.leave();
    await inviteRoom.forget();
    await Future.delayed(Duration(seconds: 1));
  } catch (e, s) {
    Logs.error('Test failed: ${e.toString()}', s);
    rethrow;
  } finally {
    Logs.success('++++ Logout Alice and Bob ++++');
    if (testClientA?.isLogged() ?? false) await testClientA.logoutAll();
    if (testClientA?.isLogged() ?? false) await testClientB.logoutAll();
    await testClientA?.dispose();
    await testClientB?.dispose();
    testClientA = null;
    testClientB = null;
  }
  return;
}
