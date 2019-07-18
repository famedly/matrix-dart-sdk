/*
 * Copyright (c) 2019 Zender & Kurtz GbR.
 *
 * Authors:
 *   Christian Pauly <krille@famedly.com>
 *   Marcel Radzio <mtrnord@famedly.com>
 *
 * This file is part of famedlysdk.
 *
 * famedlysdk is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * famedlysdk is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with famedlysdk.  If not, see <http://www.gnu.org/licenses/>.
 */

import 'dart:async';
import 'dart:core';

import 'Connection.dart';
import 'Room.dart';
import 'RoomList.dart';
import 'Store.dart';
import 'User.dart';
import 'requests/SetPushersRequest.dart';
import 'responses/ErrorResponse.dart';
import 'responses/PushrulesResponse.dart';

/// Represents a Matrix client to communicate with a
/// [Matrix](https://matrix.org) homeserver and is the entry point for this
/// SDK.
class Client {
  /// Handles the connection for this client.
  Connection connection;

  /// Optional persistent store for all data.
  Store store;

  Client(this.clientName, {this.debug = false}) {
    connection = Connection(this);

    if (this.clientName != "testclient") store = Store(this);
    connection.onLoginStateChanged.stream.listen((loginState) {
      print("LoginState: ${loginState.toString()}");
    });
  }

  /// Whether debug prints should be displayed.
  final bool debug;

  /// The required name for this client.
  final String clientName;

  /// The homeserver this client is communicating with.
  String homeserver;

  /// The Matrix ID of the current logged user.
  String userID;

  /// This is the access token for the matrix client. When it is undefined, then
  /// the user needs to sign in first.
  String accessToken;

  /// This points to the position in the synchronization history.
  String prevBatch;

  /// The device ID is an unique identifier for this device.
  String deviceID;

  /// The device name is a human readable identifier for this device.
  String deviceName;

  /// Which version of the matrix specification does this server support?
  List<String> matrixVersions;

  /// Wheither the server supports lazy load members.
  bool lazyLoadMembers = false;

  /// Returns the current login state.
  bool isLogged() => accessToken != null;

  /// Checks the supported versions of the Matrix protocol and the supported
  /// login types. Returns false if the server is not compatible with the
  /// client. Automatically sets [matrixVersions] and [lazyLoadMembers].
  Future<bool> checkServer(serverUrl) async {
    homeserver = serverUrl;

    final versionResp = await connection.jsonRequest(
        type: HTTPType.GET, action: "/client/versions");
    if (versionResp is ErrorResponse) {
      connection.onError.add(ErrorResponse(errcode: "NO_RESPONSE", error: ""));
      return false;
    }

    final List<String> versions = List<String>.from(versionResp["versions"]);

    if (versions == null) {
      connection.onError.add(ErrorResponse(errcode: "NO_RESPONSE", error: ""));
      return false;
    }

    for (int i = 0; i < versions.length; i++) {
      if (versions[i] == "r0.4.0")
        break;
      else if (i == versions.length - 1) {
        connection.onError.add(ErrorResponse(errcode: "NO_SUPPORT", error: ""));
        return false;
      }
    }

    matrixVersions = versions;

    if (versionResp.containsKey("unstable_features") &&
        versionResp["unstable_features"].containsKey("m.lazy_load_members")) {
      lazyLoadMembers = versionResp["unstable_features"]["m.lazy_load_members"]
          ? true
          : false;
    }

    final loginResp = await connection.jsonRequest(
        type: HTTPType.GET, action: "/client/r0/login");
    if (loginResp is ErrorResponse) {
      connection.onError.add(loginResp);
      return false;
    }

    final List<dynamic> flows = loginResp["flows"];

    for (int i = 0; i < flows.length; i++) {
      if (flows[i].containsKey("type") &&
          flows[i]["type"] == "m.login.password")
        break;
      else if (i == flows.length - 1) {
        connection.onError.add(ErrorResponse(errcode: "NO_SUPPORT", error: ""));
        return false;
      }
    }

    return true;
  }

  /// Handles the login and allows the client to call all APIs which require
  /// authentication. Returns false if the login was not successful.
  Future<bool> login(String username, String password) async {
    final loginResp = await connection
        .jsonRequest(type: HTTPType.POST, action: "/client/r0/login", data: {
      "type": "m.login.password",
      "user": username,
      "identifier": {
        "type": "m.id.user",
        "user": username,
      },
      "password": password,
      "initial_device_display_name": "Famedly Talk"
    });

    if (loginResp is ErrorResponse) {
      connection.onError.add(loginResp);
      return false;
    }

    final userID = loginResp["user_id"];
    final accessToken = loginResp["access_token"];
    if (userID == null || accessToken == null) {
      connection.onError.add(ErrorResponse(errcode: "NO_SUPPORT", error: ""));
    }

    await connection.connect(
        newToken: accessToken,
        newUserID: userID,
        newHomeserver: homeserver,
        newDeviceName: "",
        newDeviceID: "",
        newMatrixVersions: matrixVersions,
        newLazyLoadMembers: lazyLoadMembers);
    return true;
  }

  /// Sends a logout command to the homeserver and clears all local data,
  /// including all persistent data from the store.
  Future<void> logout() async {
    final dynamic resp = await connection.jsonRequest(
        type: HTTPType.POST, action: "/client/r0/logout/all");
    if (resp is ErrorResponse) connection.onError.add(resp);

    await connection.clear();
  }

  /// Loads the Rooms from the [store] and creates a new [RoomList] object.
  Future<RoomList> getRoomList(
      {bool onlyLeft = false,
      bool onlyDirect = false,
      bool onlyGroups = false,
      onRoomListUpdateCallback onUpdate,
      onRoomListInsertCallback onInsert,
      onRoomListRemoveCallback onRemove}) async {
    List<Room> rooms = await store.getRoomList(
        onlyLeft: onlyLeft, onlyGroups: onlyGroups, onlyDirect: onlyDirect);
    return RoomList(
        client: this,
        onlyLeft: onlyLeft,
        onlyDirect: onlyDirect,
        onlyGroups: onlyGroups,
        onUpdate: onUpdate,
        onInsert: onInsert,
        onRemove: onRemove,
        rooms: rooms);
  }

  Future<dynamic> joinRoomById(String id) async {
    return await connection.jsonRequest(
        type: HTTPType.POST, action: "/client/r0/join/$id");
  }

  /// Creates a new group chat and invites the given Users and returns the new
  /// created room ID.
  Future<String> createGroup(List<User> users) async {
    List<String> inviteIDs = [];
    for (int i = 0; i < users.length; i++) inviteIDs.add(users[i].id);

    final dynamic resp = await connection.jsonRequest(
        type: HTTPType.POST,
        action: "/client/r0/createRoom",
        data: {"invite": inviteIDs, "preset": "private_chat"});

    if (resp is ErrorResponse) {
      connection.onError.add(resp);
      return null;
    }

    return resp["room_id"];
  }

  /// Fetches the pushrules for the logged in user.
  /// These are needed for notifications on Android
  Future<PushrulesResponse> getPushrules() async {
    final dynamic resp = await connection.jsonRequest(
      type: HTTPType.GET,
      action: "/client/r0/pushrules/",
    );

    if (resp is ErrorResponse) {
      connection.onError.add(resp);
      return null;
    }

    return PushrulesResponse.fromJson(resp);
  }

  /// This endpoint allows the creation, modification and deletion of pushers for this user ID.
  Future setPushers(SetPushersRequest data) async {
    final dynamic resp = await connection.jsonRequest(
      type: HTTPType.POST,
      action: "/client/r0/pushers/set",
      data: data.toJson(),
    );

    if (resp is ErrorResponse) {
      connection.onError.add(resp);
      return null;
    }

    return null;
  }
}
