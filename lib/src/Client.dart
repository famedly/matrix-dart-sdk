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
import 'dart:io';

import 'package:famedlysdk/src/AccountData.dart';
import 'package:famedlysdk/src/Presence.dart';
import 'package:famedlysdk/src/sync/UserUpdate.dart';

import 'Connection.dart';
import 'Room.dart';
import 'RoomList.dart';
import 'Store.dart';
import 'User.dart';
import 'requests/SetPushersRequest.dart';
import 'responses/ErrorResponse.dart';
import 'responses/PushrulesResponse.dart';

typedef AccountDataEventCB = void Function(AccountData accountData);
typedef PresenceCB = void Function(Presence presence);

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

  /// A list of all rooms the user is participating or invited.
  RoomList roomList;

  /// A list of all rooms the user is not participating anymore.
  RoomList archive;

  /// Key/Value store of account data.
  Map<String, AccountData> accountData = {};

  /// Presences of users by a given matrix ID
  Map<String, Presence> presences = {};

  /// Callback will be called on account data updates.
  AccountDataEventCB onAccountData;

  /// Callback will be called on presences.
  PresenceCB onPresence;

  void handleUserUpdate(UserUpdate userUpdate) {
    if (userUpdate.type == "account_data") {
      AccountData newAccountData = AccountData.fromJson(userUpdate.content);
      accountData[newAccountData.typeKey] = newAccountData;
      if (onAccountData != null) onAccountData(newAccountData);
    }
    if (userUpdate.type == "presence") {
      Presence newPresence = Presence.fromJson(userUpdate.content);
      presences[newPresence.sender] = newPresence;
      if (onPresence != null) onPresence(newPresence);
    }
  }

  Map<String, dynamic> get directChats =>
      accountData["m.direct"] != null ? accountData["m.direct"].content : {};

  /// Returns the (first) room ID from the store which is a private chat with the user [userId].
  /// Returns null if there is none.
  String getDirectChatFromUserId(String userId) {
    if (accountData["m.direct"] != null &&
        accountData["m.direct"].content[userId] is List<dynamic> &&
        accountData["m.direct"].content[userId].length > 0) {
      if (roomList.getRoomById(accountData["m.direct"].content[userId][0]) !=
          null) return accountData["m.direct"].content[userId][0];
      (accountData["m.direct"].content[userId] as List<dynamic>)
          .remove(accountData["m.direct"].content[userId][0]);
      connection.jsonRequest(
          type: HTTPType.PUT,
          action: "/client/r0/user/${userID}/account_data/m.direct",
          data: directChats);
      return getDirectChatFromUserId(userId);
    }
    for (int i = 0; i < roomList.rooms.length; i++)
      if (roomList.rooms[i].membership == Membership.invite &&
          roomList.rooms[i].states[userID]?.senderId == userId &&
          roomList.rooms[i].states[userID].content["is_direct"] == true)
        return roomList.rooms[i].id;
    return null;
  }

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
      if (versions[i] == "r0.5.0")
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

  /// Creates a new [RoomList] object.
  RoomList getRoomList(
      {bool onlyLeft = false,
      onRoomListUpdateCallback onUpdate,
      onRoomListInsertCallback onInsert,
      onRoomListRemoveCallback onRemove}) {
    List<Room> rooms = onlyLeft ? archive.rooms : roomList.rooms;
    return RoomList(
        client: this,
        onlyLeft: onlyLeft,
        onUpdate: onUpdate,
        onInsert: onInsert,
        onRemove: onRemove,
        rooms: rooms);
  }

  /// Searches in the roomList and in the archive for a room with the given [id].
  Room getRoomById(String id) {
    Room room = roomList.getRoomById(id);
    if (room == null) room = archive.getRoomById(id);
    return room;
  }

  Future<dynamic> joinRoomById(String id) async {
    return await connection.jsonRequest(
        type: HTTPType.POST, action: "/client/r0/join/$id");
  }

  /// Loads the contact list for this user excluding the user itself.
  /// Currently the contacts are found by discovering the contacts of
  /// the famedlyContactDiscovery room, which is
  /// defined by the autojoin room feature in Synapse.
  Future<List<User>> loadFamedlyContacts() async {
    List<User> contacts = [];
    Room contactDiscoveryRoom = roomList
        .getRoomByAlias("#famedlyContactDiscovery:${userID.split(":")[1]}");
    if (contactDiscoveryRoom != null)
      contacts = await contactDiscoveryRoom.requestParticipants();
    else
      contacts = await store?.loadContacts();
    return contacts;
  }

  @Deprecated('Please use [createRoom] instead!')
  Future<String> createGroup(List<User> users) => createRoom(invite: users);

  /// Creates a new group chat and invites the given Users and returns the new
  /// created room ID. If [params] are provided, invite will be ignored. For the
  /// moment please look at https://matrix.org/docs/spec/client_server/r0.5.0#post-matrix-client-r0-createroom
  /// to configure [params].
  Future<String> createRoom(
      {List<User> invite, Map<String, dynamic> params}) async {
    List<String> inviteIDs = [];
    if (params == null && invite != null)
      for (int i = 0; i < invite.length; i++) inviteIDs.add(invite[i].id);

    final dynamic resp = await connection.jsonRequest(
        type: HTTPType.POST,
        action: "/client/r0/createRoom",
        data: params == null
            ? {
                "invite": inviteIDs,
              }
            : params);

    if (resp is ErrorResponse) {
      connection.onError.add(resp);
      return null;
    }

    return resp["room_id"];
  }

  /// Uploads a new user avatar for this user. Returns ErrorResponse if something went wrong.
  Future<dynamic> setAvatar(File file) async {
    final uploadResp = await connection.upload(file);
    if (uploadResp is ErrorResponse) return uploadResp;
    final setAvatarResp = await connection.jsonRequest(
        type: HTTPType.PUT,
        action: "/client/r0/profile/$userID/avatar_url",
        data: {"avatar_url": uploadResp});
    if (setAvatarResp is ErrorResponse) return setAvatarResp;
    return null;
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
  Future<dynamic> setPushers(SetPushersRequest data) async {
    final dynamic resp = await connection.jsonRequest(
      type: HTTPType.POST,
      action: "/client/r0/pushers/set",
      data: data.toJson(),
    );

    if (resp is ErrorResponse) {
      connection.onError.add(resp);
    }

    return resp;
  }
}
