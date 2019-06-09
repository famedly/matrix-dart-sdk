import 'package:flutter_test/flutter_test.dart';
import 'package:famedlysdk/src/Client.dart';
import 'package:famedlysdk/src/Connection.dart';
import 'package:famedlysdk/src/sync/EventUpdate.dart';
import 'package:famedlysdk/src/sync/RoomUpdate.dart';
import 'package:famedlysdk/src/responses/ErrorResponse.dart';
import 'dart:async';
import 'FakeMatrixApi.dart';

void main() {
  Client matrix;

  Future<List<RoomUpdate>> roomUpdateListFuture;
  Future<List<EventUpdate>> eventUpdateListFuture;

  /// All Tests related to the Login
  group("FluffyMatrix", () {
    /// Check if all Elements get created

    final create = (WidgetTester tester) {

      matrix = Client("testclient");
      matrix.connection.httpClient = FakeMatrixApi();
      matrix.homeserver = "https://fakeServer.notExisting";

      roomUpdateListFuture = matrix.connection.onRoomUpdate.stream.toList();
      eventUpdateListFuture = matrix.connection.onEvent.stream.toList();
    };
    testWidgets('should get created', create);

    test("Get version", () async {
      final versionResp =
      await matrix.connection.jsonRequest(type: "GET", action: "/client/versions");
      expect(versionResp is ErrorResponse, false);
      expect(versionResp["versions"].indexOf("r0.4.0") != -1, true);
      matrix.matrixVersions = List<String>.from(versionResp["versions"]);
      matrix.lazyLoadMembers = true;
    });

    test("Get login types", () async {
      final resp =
      await matrix.connection.jsonRequest(type: "GET", action: "/client/r0/login");
      expect(resp is ErrorResponse, false);
      expect(resp["flows"] is List<dynamic>, true);
      bool hasMLoginType = false;
      for (int i = 0; i < resp["flows"].length; i++)
        if (resp["flows"][i]["type"] is String &&
            resp["flows"][i]["type"] == "m.login.password") {
          hasMLoginType = true;
          break;
        }
      expect(hasMLoginType, true);
    });

    final loginText = () async{
      final resp = await matrix
          .connection.jsonRequest(type: "POST", action: "/client/r0/login", data: {
        "type": "m.login.password",
        "user": "test",
        "password": "1234",
        "initial_device_display_name": "Fluffy Matrix Client"
      });
      expect(resp is ErrorResponse, false);

      Future<LoginState> loginStateFuture = matrix.connection.onLoginStateChanged.stream.first;
      Future<bool> firstSyncFuture = matrix.connection.onFirstSync.stream.first;
      Future<dynamic> syncFuture = matrix.connection.onSync.stream.first;

      matrix.connection.connect(
          newToken: resp["access_token"],
          newUserID: resp["user_id"],
          newHomeserver: matrix.homeserver,
          newDeviceName: "Text Matrix Client",
          newDeviceID: resp["device_id"],
          newMatrixVersions: matrix.matrixVersions,
          newLazyLoadMembers: matrix.lazyLoadMembers);

      expect(matrix.accessToken == resp["access_token"], true);
      expect(matrix.deviceName == "Text Matrix Client", true);
      expect(matrix.deviceID == resp["device_id"], true);
      expect(matrix.userID == resp["user_id"], true);

      LoginState loginState = await loginStateFuture;
      bool firstSync = await firstSyncFuture;
      dynamic sync = await syncFuture;

      expect(loginState, LoginState.logged);
      expect(firstSync, true);
      expect(sync["next_batch"] == matrix.prevBatch, true);
    };

    test('Login', loginText);

    test('Try to get ErrorResponse', () async{
      final resp = await matrix
          .connection.jsonRequest(type: "PUT", action: "/non/existing/path");
      expect(resp is ErrorResponse, true);
    });

    test('Logout', () async{
      final dynamic resp = await matrix
          .connection.jsonRequest(type: "POST", action: "/client/r0/logout");
      expect(resp is ErrorResponse, false);

      Future<LoginState> loginStateFuture = matrix.connection.onLoginStateChanged.stream.first;

      matrix.connection.clear();

      expect(matrix.accessToken == null, true);
      expect(matrix.homeserver == null, true);
      expect(matrix.userID == null, true);
      expect(matrix.deviceID == null, true);
      expect(matrix.deviceName == null, true);
      expect(matrix.matrixVersions == null, true);
      expect(matrix.lazyLoadMembers == null, true);
      expect(matrix.prevBatch == null, true);

      LoginState loginState = await loginStateFuture;
      expect(loginState, LoginState.loggedOut);
    });

    test('Room Update Test', () async{
      matrix.connection.onRoomUpdate.close();

      List<RoomUpdate> roomUpdateList = await roomUpdateListFuture;

      expect(roomUpdateList.length,3);

      expect(roomUpdateList[0].id=="!726s6s6q:example.com", true);
      expect(roomUpdateList[0].membership=="join", true);
      expect(roomUpdateList[0].prev_batch=="t34-23535_0_0", true);
      expect(roomUpdateList[0].limitedTimeline==true, true);
      expect(roomUpdateList[0].notification_count==2, true);
      expect(roomUpdateList[0].highlight_count==2, true);

      expect(roomUpdateList[1].id=="!696r7674:example.com", true);
      expect(roomUpdateList[1].membership=="invite", true);
      expect(roomUpdateList[1].prev_batch=="", true);
      expect(roomUpdateList[1].limitedTimeline==false, true);
      expect(roomUpdateList[1].notification_count==0, true);
      expect(roomUpdateList[1].highlight_count==0, true);

      expect(roomUpdateList[2].id=="!5345234234:example.com", true);
      expect(roomUpdateList[2].membership=="leave", true);
      expect(roomUpdateList[2].prev_batch=="", true);
      expect(roomUpdateList[2].limitedTimeline==false, true);
      expect(roomUpdateList[2].notification_count==0, true);
      expect(roomUpdateList[2].highlight_count==0, true);
    });

    test('Event Update Test', () async{
      matrix.connection.onEvent.close();

      List<EventUpdate> eventUpdateList = await eventUpdateListFuture;

      expect(eventUpdateList.length,10);

      expect(eventUpdateList[0].eventType=="m.room.member", true);
      expect(eventUpdateList[0].roomID=="!726s6s6q:example.com", true);
      expect(eventUpdateList[0].type=="state", true);

      expect(eventUpdateList[1].eventType=="m.room.member", true);
      expect(eventUpdateList[1].roomID=="!726s6s6q:example.com", true);
      expect(eventUpdateList[1].type=="timeline", true);

      expect(eventUpdateList[2].eventType=="m.room.message", true);
      expect(eventUpdateList[2].roomID=="!726s6s6q:example.com", true);
      expect(eventUpdateList[2].type=="timeline", true);

      expect(eventUpdateList[3].eventType=="m.tag", true);
      expect(eventUpdateList[3].roomID=="!726s6s6q:example.com", true);
      expect(eventUpdateList[3].type=="account_data", true);

      expect(eventUpdateList[4].eventType=="org.example.custom.room.config", true);
      expect(eventUpdateList[4].roomID=="!726s6s6q:example.com", true);
      expect(eventUpdateList[4].type=="account_data", true);

      expect(eventUpdateList[5].eventType=="m.room.name", true);
      expect(eventUpdateList[5].roomID=="!696r7674:example.com", true);
      expect(eventUpdateList[5].type=="invite_state", true);

      expect(eventUpdateList[6].eventType=="m.room.member", true);
      expect(eventUpdateList[6].roomID=="!696r7674:example.com", true);
      expect(eventUpdateList[6].type=="invite_state", true);

      expect(eventUpdateList[7].eventType=="m.presence", true);
      expect(eventUpdateList[7].roomID=="presence", true);
      expect(eventUpdateList[7].type=="presence", true);

      expect(eventUpdateList[8].eventType=="org.example.custom.config", true);
      expect(eventUpdateList[8].roomID=="account_data", true);
      expect(eventUpdateList[8].type=="account_data", true);

      expect(eventUpdateList[9].eventType=="m.new_device", true);
      expect(eventUpdateList[9].roomID=="to_device", true);
      expect(eventUpdateList[9].type=="to_device", true);


    });

    testWidgets('should get created', create);

    test('Login', loginText);

    test('Logout when token is unknown', () async{
      Future<LoginState> loginStateFuture = matrix.connection.onLoginStateChanged.stream.first;
      final resp = await matrix
          .connection.jsonRequest(type: "DELETE", action: "/unknown/token");

      LoginState state = await loginStateFuture;
      expect(state, LoginState.loggedOut);
      expect(matrix.isLogged(), false);
    });

  });
}
