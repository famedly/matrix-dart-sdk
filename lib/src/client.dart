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

import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/src/account_data.dart';
import 'package:famedlysdk/src/presence.dart';
import 'package:famedlysdk/src/store_api.dart';
import 'package:famedlysdk/src/sync/user_update.dart';
import 'package:famedlysdk/src/utils/matrix_file.dart';
import 'package:famedlysdk/src/utils/turn_server_credentials.dart';
import 'package:pedantic/pedantic.dart';
import 'room.dart';
import 'event.dart';
import 'user.dart';
import 'utils/profile.dart';
import 'dart:convert';
import 'package:famedlysdk/src/room.dart';
import 'package:http/http.dart' as http;
import 'package:mime_type/mime_type.dart';
import 'sync/event_update.dart';
import 'sync/room_update.dart';
import 'sync/user_update.dart';
import 'utils/matrix_exception.dart';

typedef RoomSorter = int Function(Room a, Room b);

enum HTTPType { GET, POST, PUT, DELETE }

enum LoginState { logged, loggedOut }

/// Represents a Matrix client to communicate with a
/// [Matrix](https://matrix.org) homeserver and is the entry point for this
/// SDK.
class Client {
  /// Handles the connection for this client.
  @deprecated
  Client get connection => this;

  /// Optional persistent store for all data.
  StoreAPI store;

  Client(this.clientName, {this.debug = false, this.store}) {
    if (this.clientName != "testclient") store = null; //Store(this);
    this.onLoginStateChanged.stream.listen((loginState) {
      print("LoginState: ${loginState.toString()}");
    });
  }

  /// Whether debug prints should be displayed.
  final bool debug;

  /// The required name for this client.
  final String clientName;

  /// The homeserver this client is communicating with.
  String get homeserver => _homeserver;
  String _homeserver;

  /// The Matrix ID of the current logged user.
  String get userID => _userID;
  String _userID;

  /// This is the access token for the matrix client. When it is undefined, then
  /// the user needs to sign in first.
  String get accessToken => _accessToken;
  String _accessToken;

  /// This points to the position in the synchronization history.
  String prevBatch;

  /// The device ID is an unique identifier for this device.
  String get deviceID => _deviceID;
  String _deviceID;

  /// The device name is a human readable identifier for this device.
  String get deviceName => _deviceName;
  String _deviceName;

  /// Which version of the matrix specification does this server support?
  List<String> get matrixVersions => _matrixVersions;
  List<String> _matrixVersions;

  /// Wheither the server supports lazy load members.
  bool get lazyLoadMembers => _lazyLoadMembers;
  bool _lazyLoadMembers = false;

  /// Returns the current login state.
  bool isLogged() => accessToken != null;

  /// A list of all rooms the user is participating or invited.
  List<Room> get rooms => _rooms;
  List<Room> _rooms = [];

  /// Warning! This endpoint is for testing only!
  set rooms(List<Room> newList) {
    print("Warning! This endpoint is for testing only!");
    _rooms = newList;
  }

  /// Key/Value store of account data.
  Map<String, AccountData> accountData = {};

  /// Presences of users by a given matrix ID
  Map<String, Presence> presences = {};

  Room getRoomByAlias(String alias) {
    for (int i = 0; i < rooms.length; i++) {
      if (rooms[i].canonicalAlias == alias) return rooms[i];
    }
    return null;
  }

  Room getRoomById(String id) {
    for (int j = 0; j < rooms.length; j++) {
      if (rooms[j].id == id) return rooms[j];
    }
    return null;
  }

  void handleUserUpdate(UserUpdate userUpdate) {
    if (userUpdate.type == "account_data") {
      AccountData newAccountData = AccountData.fromJson(userUpdate.content);
      accountData[newAccountData.typeKey] = newAccountData;
      if (onAccountData != null) onAccountData.add(newAccountData);
    }
    if (userUpdate.type == "presence") {
      Presence newPresence = Presence.fromJson(userUpdate.content);
      presences[newPresence.sender] = newPresence;
      if (onPresence != null) onPresence.add(newPresence);
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
      if (getRoomById(accountData["m.direct"].content[userId][0]) != null) {
        return accountData["m.direct"].content[userId][0];
      }
      (accountData["m.direct"].content[userId] as List<dynamic>)
          .remove(accountData["m.direct"].content[userId][0]);
      this.jsonRequest(
          type: HTTPType.PUT,
          action: "/client/r0/user/${userID}/account_data/m.direct",
          data: directChats);
      return getDirectChatFromUserId(userId);
    }
    for (int i = 0; i < this.rooms.length; i++) {
      if (this.rooms[i].membership == Membership.invite &&
          this.rooms[i].states[userID]?.senderId == userId &&
          this.rooms[i].states[userID].content["is_direct"] == true) {
        return this.rooms[i].id;
      }
    }
    return null;
  }

  /// Checks the supported versions of the Matrix protocol and the supported
  /// login types. Returns false if the server is not compatible with the
  /// client. Automatically sets [matrixVersions] and [lazyLoadMembers].
  /// Throws FormatException, TimeoutException and MatrixException on error.
  Future<bool> checkServer(serverUrl) async {
    try {
      _homeserver = serverUrl;
      final versionResp = await this
          .jsonRequest(type: HTTPType.GET, action: "/client/versions");

      final List<String> versions = List<String>.from(versionResp["versions"]);

      for (int i = 0; i < versions.length; i++) {
        if (versions[i] == "r0.5.0") {
          break;
        } else if (i == versions.length - 1) {
          return false;
        }
      }

      _matrixVersions = versions;

      if (versionResp.containsKey("unstable_features") &&
          versionResp["unstable_features"].containsKey("m.lazy_load_members")) {
        _lazyLoadMembers = versionResp["unstable_features"]
                ["m.lazy_load_members"]
            ? true
            : false;
      }

      final loginResp = await this
          .jsonRequest(type: HTTPType.GET, action: "/client/r0/login");

      final List<dynamic> flows = loginResp["flows"];

      for (int i = 0; i < flows.length; i++) {
        if (flows[i].containsKey("type") &&
            flows[i]["type"] == "m.login.password") {
          break;
        } else if (i == flows.length - 1) {
          return false;
        }
      }
      return true;
    } catch (_) {
      this._homeserver = this._matrixVersions = null;
      rethrow;
    }
  }

  /// Handles the login and allows the client to call all APIs which require
  /// authentication. Returns false if the login was not successful. Throws
  /// MatrixException if login was not successful.
  Future<bool> login(String username, String password) async {
    final loginResp = await jsonRequest(
        type: HTTPType.POST,
        action: "/client/r0/login",
        data: {
          "type": "m.login.password",
          "user": username,
          "identifier": {
            "type": "m.id.user",
            "user": username,
          },
          "password": password,
          "initial_device_display_name": "Famedly Talk"
        });

    final userID = loginResp["user_id"];
    final accessToken = loginResp["access_token"];
    if (userID == null || accessToken == null) {
      return false;
    }

    await this.connect(
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
    try {
      await this.jsonRequest(type: HTTPType.POST, action: "/client/r0/logout");
    } catch (exception) {
      rethrow;
    } finally {
      await this.clear();
    }
  }

  /// Get the combined profile information for this user. This API may be used to
  /// fetch the user's own profile information or other users; either locally
  /// or on remote homeservers.
  Future<Profile> getProfileFromUserId(String userId) async {
    final dynamic resp = await this.jsonRequest(
        type: HTTPType.GET, action: "/client/r0/profile/${userId}");
    return Profile.fromJson(resp);
  }

  Future<List<Room>> get archive async {
    List<Room> archiveList = [];
    String syncFilters =
        '{"room":{"include_leave":true,"timeline":{"limit":10}}}';
    String action = "/client/r0/sync?filter=$syncFilters&timeout=0";
    final sync = await this.jsonRequest(type: HTTPType.GET, action: action);
    if (sync["rooms"]["leave"] is Map<String, dynamic>) {
      for (var entry in sync["rooms"]["leave"].entries) {
        final String id = entry.key;
        final dynamic room = entry.value;
        print(id);
        print(room.toString());
        Room leftRoom = Room(
            id: id,
            membership: Membership.leave,
            client: this,
            roomAccountData: {},
            mHeroes: []);
        if (room["account_data"] is Map<String, dynamic> &&
            room["account_data"]["events"] is List<dynamic>) {
          for (dynamic event in room["account_data"]["events"]) {
            leftRoom.roomAccountData[event["type"]] =
                RoomAccountData.fromJson(event, leftRoom);
          }
        }
        if (room["timeline"] is Map<String, dynamic> &&
            room["timeline"]["events"] is List<dynamic>) {
          for (dynamic event in room["timeline"]["events"]) {
            leftRoom.setState(Event.fromJson(event, leftRoom));
          }
        }
        if (room["state"] is Map<String, dynamic> &&
            room["state"]["events"] is List<dynamic>) {
          for (dynamic event in room["state"]["events"]) {
            leftRoom.setState(Event.fromJson(event, leftRoom));
          }
        }
        archiveList.add(leftRoom);
      }
    }
    return archiveList;
  }

  Future<dynamic> joinRoomById(String id) async {
    return await this
        .jsonRequest(type: HTTPType.POST, action: "/client/r0/join/$id");
  }

  /// Loads the contact list for this user excluding the user itself.
  /// Currently the contacts are found by discovering the contacts of
  /// the famedlyContactDiscovery room, which is
  /// defined by the autojoin room feature in Synapse.
  Future<List<User>> loadFamedlyContacts() async {
    List<User> contacts = [];
    Room contactDiscoveryRoom =
        this.getRoomByAlias("#famedlyContactDiscovery:${userID.split(":")[1]}");
    if (contactDiscoveryRoom != null) {
      contacts = await contactDiscoveryRoom.requestParticipants();
    } else {
      Map<String, bool> userMap = {};
      for (int i = 0; i < this.rooms.length; i++) {
        List<User> roomUsers = this.rooms[i].getParticipants();
        for (int j = 0; j < roomUsers.length; j++) {
          if (userMap[roomUsers[j].id] != true) contacts.add(roomUsers[j]);
          userMap[roomUsers[j].id] = true;
        }
      }
    }
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
    if (params == null && invite != null) {
      for (int i = 0; i < invite.length; i++) {
        inviteIDs.add(invite[i].id);
      }
    }

    try {
      final dynamic resp = await this.jsonRequest(
          type: HTTPType.POST,
          action: "/client/r0/createRoom",
          data: params == null
              ? {
                  "invite": inviteIDs,
                }
              : params);
      return resp["room_id"];
    } catch (e) {
      rethrow;
    }
  }

  /// Uploads a new user avatar for this user.
  Future<void> setAvatar(MatrixFile file) async {
    final uploadResp = await this.upload(file);
    await this.jsonRequest(
        type: HTTPType.PUT,
        action: "/client/r0/profile/$userID/avatar_url",
        data: {"avatar_url": uploadResp});
    return;
  }

  /// Get credentials for the client to use when initiating calls.
  Future<TurnServerCredentials> getTurnServerCredentials() async {
    final Map<String, dynamic> response = await this.jsonRequest(
      type: HTTPType.GET,
      action: "/client/r0/voip/turnServer",
    );
    return TurnServerCredentials.fromJson(response);
  }

  /// Fetches the pushrules for the logged in user.
  /// These are needed for notifications on Android
  Future<PushRules> getPushrules() async {
    final dynamic resp = await this.jsonRequest(
      type: HTTPType.GET,
      action: "/client/r0/pushrules/",
    );

    return PushRules.fromJson(resp);
  }

  /// This endpoint allows the creation, modification and deletion of pushers for this user ID.
  Future<void> setPushers(String pushKey, String kind, String appId,
      String appDisplayName, String deviceDisplayName, String lang, String url,
      {bool append, String profileTag, String format}) async {
    Map<String, dynamic> data = {
      "lang": lang,
      "kind": kind,
      "app_display_name": appDisplayName,
      "device_display_name": deviceDisplayName,
      "profile_tag": profileTag,
      "app_id": appId,
      "pushkey": pushKey,
      "data": {"url": url}
    };

    if (format != null) data["data"]["format"] = format;
    if (profileTag != null) data["profile_tag"] = profileTag;
    if (append != null) data["append"] = append;

    await this.jsonRequest(
      type: HTTPType.POST,
      action: "/client/r0/pushers/set",
      data: data,
    );
    return;
  }

  static String syncFilters = '{"room":{"state":{"lazy_load_members":true}}}';

  http.Client httpClient = http.Client();

  /// The newEvent signal is the most important signal in this concept. Every time
  /// the app receives a new synchronization, this event is called for every signal
  /// to update the GUI. For example, for a new message, it is called:
  /// onRoomEvent( "m.room.message", "!chat_id:server.com", "timeline", {sender: "@bob:server.com", body: "Hello world"} )
  final StreamController<EventUpdate> onEvent = StreamController.broadcast();

  /// Outside of the events there are updates for the global chat states which
  /// are handled by this signal:
  final StreamController<RoomUpdate> onRoomUpdate =
      StreamController.broadcast();

  /// Outside of rooms there are account updates like account_data or presences.
  final StreamController<UserUpdate> onUserEvent = StreamController.broadcast();

  /// Called when the login state e.g. user gets logged out.
  final StreamController<LoginState> onLoginStateChanged =
      StreamController.broadcast();

  /// Synchronization erros are coming here.
  final StreamController<MatrixException> onError =
      StreamController.broadcast();

  /// This is called once, when the first sync has received.
  final StreamController<bool> onFirstSync = StreamController.broadcast();

  /// When a new sync response is coming in, this gives the complete payload.
  final StreamController<dynamic> onSync = StreamController.broadcast();

  /// Callback will be called on presences.
  final StreamController<Presence> onPresence = StreamController.broadcast();

  /// Callback will be called on account data updates.
  final StreamController<AccountData> onAccountData =
      StreamController.broadcast();

  /// Will be called on call invites.
  final StreamController<Event> onCallInvite = StreamController.broadcast();

  /// Will be called on call hangups.
  final StreamController<Event> onCallHangup = StreamController.broadcast();

  /// Will be called on call candidates.
  final StreamController<Event> onCallCandidates = StreamController.broadcast();

  /// Will be called on call answers.
  final StreamController<Event> onCallAnswer = StreamController.broadcast();

  /// Matrix synchronisation is done with https long polling. This needs a
  /// timeout which is usually 30 seconds.
  int syncTimeoutSec = 30;

  /// How long should the app wait until it retrys the synchronisation after
  /// an error?
  int syncErrorTimeoutSec = 3;

  /// Sets the user credentials and starts the synchronisation.
  ///
  /// Before you can connect you need at least an [accessToken], a [homeserver],
  /// a [userID], a [deviceID], and a [deviceName].
  ///
  /// You get this informations
  /// by logging in to your Matrix account, using the [login API](https://matrix.org/docs/spec/client_server/r0.4.0.html#post-matrix-client-r0-login).
  ///
  /// To log in you can use [jsonRequest()] after you have set the [homeserver]
  /// to a valid url. For example:
  ///
  /// ```
  /// final resp = await matrix
  ///          .jsonRequest(type: HTTPType.POST, action: "/client/r0/login", data: {
  ///        "type": "m.login.password",
  ///        "user": "test",
  ///        "password": "1234",
  ///        "initial_device_display_name": "Fluffy Matrix Client"
  ///      });
  /// ```
  ///
  /// Returns:
  ///
  /// ```
  /// {
  ///  "user_id": "@cheeky_monkey:matrix.org",
  ///  "access_token": "abc123",
  ///  "device_id": "GHTYAJCE"
  /// }
  /// ```
  ///
  /// Sends [LoginState.logged] to [onLoginStateChanged].
  void connect(
      {String newToken,
      String newHomeserver,
      String newUserID,
      String newDeviceName,
      String newDeviceID,
      List<String> newMatrixVersions,
      bool newLazyLoadMembers,
      String newPrevBatch}) async {
    this._accessToken = newToken;
    this._homeserver = newHomeserver;
    this._userID = newUserID;
    this._deviceID = newDeviceID;
    this._deviceName = newDeviceName;
    this._matrixVersions = newMatrixVersions;
    this._lazyLoadMembers = newLazyLoadMembers;
    this.prevBatch = newPrevBatch;

    if (this.store != null) {
      await this.store.storeClient();
      this._rooms = await this.store.getRoomList(onlyLeft: false);
      this._sortRooms();
      this.accountData = await this.store.getAccountData();
      this.presences = await this.store.getPresences();
    }

    _userEventSub ??= onUserEvent.stream.listen(this.handleUserUpdate);

    onLoginStateChanged.add(LoginState.logged);

    return _sync();
  }

  StreamSubscription _userEventSub;

  /// Resets all settings and stops the synchronisation.
  void clear() {
    this.store?.clear();
    this._accessToken = this._homeserver = this._userID = this._deviceID = this
            ._deviceName =
        this._matrixVersions = this._lazyLoadMembers = this.prevBatch = null;
    onLoginStateChanged.add(LoginState.loggedOut);
  }

  /// Used for all Matrix json requests using the [c2s API](https://matrix.org/docs/spec/client_server/r0.4.0.html).
  ///
  /// Throws: TimeoutException, FormatException, MatrixException
  ///
  /// You must first call [this.connect()] or set [this.homeserver] before you can use
  /// this! For example to send a message to a Matrix room with the id
  /// '!fjd823j:example.com' you call:
  ///
  /// ```
  /// final resp = await jsonRequest(
  ///   type: HTTPType.PUT,
  ///   action: "/r0/rooms/!fjd823j:example.com/send/m.room.message/$txnId",
  ///   data: {
  ///     "msgtype": "m.text",
  ///     "body": "hello"
  ///   }
  ///  );
  /// ```
  ///
  Future<Map<String, dynamic>> jsonRequest(
      {HTTPType type,
      String action,
      dynamic data = "",
      int timeout,
      String contentType = "application/json"}) async {
    if (this.isLogged() == false && this.homeserver == null) {
      throw ("No homeserver specified.");
    }
    if (timeout == null) timeout = syncTimeoutSec + 5;
    dynamic json;
    if (data is Map) data.removeWhere((k, v) => v == null);
    (!(data is String)) ? json = jsonEncode(data) : json = data;
    if (data is List<int> || action.startsWith("/media/r0/upload")) json = data;

    final url = "${this.homeserver}/_matrix${action}";

    Map<String, String> headers = {};
    if (type == HTTPType.PUT || type == HTTPType.POST) {
      headers["Content-Type"] = contentType;
    }
    if (this.isLogged()) {
      headers["Authorization"] = "Bearer ${this.accessToken}";
    }

    if (this.debug) {
      print(
          "[REQUEST ${type.toString().split('.').last}] Action: $action, Data: $data");
    }

    http.Response resp;
    Map<String, dynamic> jsonResp = {};
    try {
      switch (type.toString().split('.').last) {
        case "GET":
          resp = await httpClient
              .get(url, headers: headers)
              .timeout(Duration(seconds: timeout));
          break;
        case "POST":
          resp = await httpClient
              .post(url, body: json, headers: headers)
              .timeout(Duration(seconds: timeout));
          break;
        case "PUT":
          resp = await httpClient
              .put(url, body: json, headers: headers)
              .timeout(Duration(seconds: timeout));
          break;
        case "DELETE":
          resp = await httpClient
              .delete(url, headers: headers)
              .timeout(Duration(seconds: timeout));
          break;
      }
      jsonResp = jsonDecode(String.fromCharCodes(resp.body.runes))
          as Map<String, dynamic>; // May throw FormatException

      if (jsonResp.containsKey("errcode") && jsonResp["errcode"] is String) {
        // The server has responsed with an matrix related error.
        MatrixException exception = MatrixException(resp);
        if (exception.error == MatrixError.M_UNKNOWN_TOKEN) {
          // The token is no longer valid. Need to sign off....
          onError.add(exception);
          clear();
        }

        throw exception;
      }

      if (this.debug) print("[RESPONSE] ${jsonResp.toString()}");
    } on ArgumentError catch (exception) {
      print(exception);
      // Ignore this error
    } catch (_) {
      print(_);
      rethrow;
    }

    return jsonResp;
  }

  /// Uploads a file with the name [fileName] as base64 encoded to the server
  /// and returns the mxc url as a string.
  Future<String> upload(MatrixFile file) async {
    dynamic fileBytes;
    if (this.homeserver != "https://fakeServer.notExisting") {
      fileBytes = file.bytes;
    }
    String fileName = file.path.split("/").last.toLowerCase();
    String mimeType = mime(file.path);
    print("[UPLOADING] $fileName, type: $mimeType, size: ${fileBytes?.length}");
    final Map<String, dynamic> resp = await jsonRequest(
        type: HTTPType.POST,
        action: "/media/r0/upload?filename=$fileName",
        data: fileBytes,
        contentType: mimeType);
    return resp["content_uri"];
  }

  Future<dynamic> _syncRequest;

  Future<void> _sync() async {
    if (this.isLogged() == false) return;

    String action = "/client/r0/sync?filter=$syncFilters";

    if (this.prevBatch != null) {
      action += "&timeout=30000";
      action += "&since=${this.prevBatch}";
    }
    try {
      _syncRequest = jsonRequest(type: HTTPType.GET, action: action);
      final int hash = _syncRequest.hashCode;
      final syncResp = await _syncRequest;
      if (hash != _syncRequest.hashCode) return;
      if (this.store != null) {
        await this.store.transaction(() {
          handleSync(syncResp);
          this.store.storePrevBatch(syncResp);
          return;
        });
      } else {
        await handleSync(syncResp);
      }
      if (this.prevBatch == null) this.onFirstSync.add(true);
      this.prevBatch = syncResp["next_batch"];
      if (hash == _syncRequest.hashCode) unawaited(_sync());
    } on MatrixException catch (exception) {
      onError.add(exception);
      await Future.delayed(Duration(seconds: syncErrorTimeoutSec), _sync);
    } catch (exception) {
      await Future.delayed(Duration(seconds: syncErrorTimeoutSec), _sync);
    }
  }

  void handleSync(dynamic sync) {
    if (sync["rooms"] is Map<String, dynamic>) {
      if (sync["rooms"]["join"] is Map<String, dynamic>) {
        _handleRooms(sync["rooms"]["join"], Membership.join);
      }
      if (sync["rooms"]["invite"] is Map<String, dynamic>) {
        _handleRooms(sync["rooms"]["invite"], Membership.invite);
      }
      if (sync["rooms"]["leave"] is Map<String, dynamic>) {
        _handleRooms(sync["rooms"]["leave"], Membership.leave);
      }
    }
    if (sync["presence"] is Map<String, dynamic> &&
        sync["presence"]["events"] is List<dynamic>) {
      _handleGlobalEvents(sync["presence"]["events"], "presence");
    }
    if (sync["account_data"] is Map<String, dynamic> &&
        sync["account_data"]["events"] is List<dynamic>) {
      _handleGlobalEvents(sync["account_data"]["events"], "account_data");
    }
    if (sync["to_device"] is Map<String, dynamic> &&
        sync["to_device"]["events"] is List<dynamic>) {
      _handleGlobalEvents(sync["to_device"]["events"], "to_device");
    }
    onSync.add(sync);
  }

  void _handleRooms(Map<String, dynamic> rooms, Membership membership) {
    rooms.forEach((String id, dynamic room) async {
      // calculate the notification counts, the limitedTimeline and prevbatch
      num highlight_count = 0;
      num notification_count = 0;
      String prev_batch = "";
      bool limitedTimeline = false;

      if (room["unread_notifications"] is Map<String, dynamic>) {
        if (room["unread_notifications"]["highlight_count"] is num) {
          highlight_count = room["unread_notifications"]["highlight_count"];
        }
        if (room["unread_notifications"]["notification_count"] is num) {
          notification_count =
              room["unread_notifications"]["notification_count"];
        }
      }

      if (room["timeline"] is Map<String, dynamic>) {
        if (room["timeline"]["limited"] is bool) {
          limitedTimeline = room["timeline"]["limited"];
        }
        if (room["timeline"]["prev_batch"] is String) {
          prev_batch = room["timeline"]["prev_batch"];
        }
      }

      RoomSummary summary;

      if (room["summary"] is Map<String, dynamic>) {
        summary = RoomSummary.fromJson(room["summary"]);
      }

      RoomUpdate update = RoomUpdate(
        id: id,
        membership: membership,
        notification_count: notification_count,
        highlight_count: highlight_count,
        limitedTimeline: limitedTimeline,
        prev_batch: prev_batch,
        summary: summary,
      );
      _updateRoomsByRoomUpdate(update);
      unawaited(this.store?.storeRoomUpdate(update));
      onRoomUpdate.add(update);

      /// Handle now all room events and save them in the database
      if (room["state"] is Map<String, dynamic> &&
          room["state"]["events"] is List<dynamic>) {
        _handleRoomEvents(id, room["state"]["events"], "state");
      }

      if (room["invite_state"] is Map<String, dynamic> &&
          room["invite_state"]["events"] is List<dynamic>) {
        _handleRoomEvents(id, room["invite_state"]["events"], "invite_state");
      }

      if (room["timeline"] is Map<String, dynamic> &&
          room["timeline"]["events"] is List<dynamic>) {
        _handleRoomEvents(id, room["timeline"]["events"], "timeline");
      }

      if (room["ephemeral"] is Map<String, dynamic> &&
          room["ephemeral"]["events"] is List<dynamic>) {
        _handleEphemerals(id, room["ephemeral"]["events"]);
      }

      if (room["account_data"] is Map<String, dynamic> &&
          room["account_data"]["events"] is List<dynamic>) {
        _handleRoomEvents(id, room["account_data"]["events"], "account_data");
      }
    });
  }

  void _handleEphemerals(String id, List<dynamic> events) {
    for (num i = 0; i < events.length; i++) {
      _handleEvent(events[i], id, "ephemeral");

      // Receipt events are deltas between two states. We will create a
      // fake room account data event for this and store the difference
      // there.
      if (events[i]["type"] == "m.receipt") {
        Room room = this.getRoomById(id);
        if (room == null) room = Room(id: id);

        Map<String, dynamic> receiptStateContent =
            room.roomAccountData["m.receipt"]?.content ?? {};
        for (var eventEntry in events[i]["content"].entries) {
          final String eventID = eventEntry.key;
          if (events[i]["content"][eventID]["m.read"] != null) {
            final Map<String, dynamic> userTimestampMap =
                events[i]["content"][eventID]["m.read"];
            for (var userTimestampMapEntry in userTimestampMap.entries) {
              final String mxid = userTimestampMapEntry.key;

              // Remove previous receipt event from this user
              for (var entry in receiptStateContent.entries) {
                if (entry.value["m.read"] is Map<String, dynamic> &&
                    entry.value["m.read"].containsKey(mxid)) {
                  entry.value["m.read"].remove(mxid);
                  break;
                }
              }
              if (userTimestampMap[mxid] is Map<String, dynamic> &&
                  userTimestampMap[mxid].containsKey("ts")) {
                receiptStateContent[mxid] = {
                  "event_id": eventID,
                  "ts": userTimestampMap[mxid]["ts"],
                };
              }
            }
          }
        }
        events[i]["content"] = receiptStateContent;
        _handleEvent(events[i], id, "account_data");
      }
    }
  }

  void _handleRoomEvents(String chat_id, List<dynamic> events, String type) {
    for (num i = 0; i < events.length; i++) {
      _handleEvent(events[i], chat_id, type);
    }
  }

  void _handleGlobalEvents(List<dynamic> events, String type) {
    for (int i = 0; i < events.length; i++) {
      if (events[i]["type"] is String &&
          events[i]["content"] is Map<String, dynamic>) {
        UserUpdate update = UserUpdate(
          eventType: events[i]["type"],
          type: type,
          content: events[i],
        );
        this.store?.storeUserEventUpdate(update);
        onUserEvent.add(update);
      }
    }
  }

  void _handleEvent(Map<String, dynamic> event, String roomID, String type) {
    if (event["type"] is String && event["content"] is Map<String, dynamic>) {
      EventUpdate update = EventUpdate(
        eventType: event["type"],
        roomID: roomID,
        type: type,
        content: event,
      );
      _updateRoomsByEventUpdate(update);
      this.store?.storeEventUpdate(update);
      onEvent.add(update);

      if (event["type"] == "m.call.invite") {
        onCallInvite.add(Event.fromJson(event, getRoomById(roomID)));
      } else if (event["type"] == "m.call.hangup") {
        onCallHangup.add(Event.fromJson(event, getRoomById(roomID)));
      } else if (event["type"] == "m.call.answer") {
        onCallAnswer.add(Event.fromJson(event, getRoomById(roomID)));
      } else if (event["type"] == "m.call.candidates") {
        onCallCandidates.add(Event.fromJson(event, getRoomById(roomID)));
      }
    }
  }

  void _updateRoomsByRoomUpdate(RoomUpdate chatUpdate) {
    // Update the chat list item.
    // Search the room in the rooms
    num j = 0;
    for (j = 0; j < rooms.length; j++) {
      if (rooms[j].id == chatUpdate.id) break;
    }
    final bool found = (j < rooms.length && rooms[j].id == chatUpdate.id);
    final bool isLeftRoom = chatUpdate.membership == Membership.leave;

    // Does the chat already exist in the list rooms?
    if (!found && !isLeftRoom) {
      num position = chatUpdate.membership == Membership.invite ? 0 : j;
      // Add the new chat to the list
      Room newRoom = Room(
        id: chatUpdate.id,
        membership: chatUpdate.membership,
        prev_batch: chatUpdate.prev_batch,
        highlightCount: chatUpdate.highlight_count,
        notificationCount: chatUpdate.notification_count,
        mHeroes: chatUpdate.summary?.mHeroes,
        mJoinedMemberCount: chatUpdate.summary?.mJoinedMemberCount,
        mInvitedMemberCount: chatUpdate.summary?.mInvitedMemberCount,
        roomAccountData: {},
        client: this,
      );
      rooms.insert(position, newRoom);
    }
    // If the membership is "leave" then remove the item and stop here
    else if (found && isLeftRoom) {
      rooms.removeAt(j);
    }
    // Update notification, highlight count and/or additional informations
    else if (found &&
        chatUpdate.membership != Membership.leave &&
        (rooms[j].membership != chatUpdate.membership ||
            rooms[j].notificationCount != chatUpdate.notification_count ||
            rooms[j].highlightCount != chatUpdate.highlight_count ||
            chatUpdate.summary != null)) {
      rooms[j].membership = chatUpdate.membership;
      rooms[j].notificationCount = chatUpdate.notification_count;
      rooms[j].highlightCount = chatUpdate.highlight_count;
      if (chatUpdate.prev_batch != null) {
        rooms[j].prev_batch = chatUpdate.prev_batch;
      }
      if (chatUpdate.summary != null) {
        if (chatUpdate.summary.mHeroes != null) {
          rooms[j].mHeroes = chatUpdate.summary.mHeroes;
        }
        if (chatUpdate.summary.mJoinedMemberCount != null) {
          rooms[j].mJoinedMemberCount = chatUpdate.summary.mJoinedMemberCount;
        }
        if (chatUpdate.summary.mInvitedMemberCount != null) {
          rooms[j].mInvitedMemberCount = chatUpdate.summary.mInvitedMemberCount;
        }
      }
      if (rooms[j].onUpdate != null) rooms[j].onUpdate.add(rooms[j].id);
    }
    _sortRooms();
  }

  void _updateRoomsByEventUpdate(EventUpdate eventUpdate) {
    if (eventUpdate.type == "history") return;
    // Search the room in the rooms
    num j = 0;
    for (j = 0; j < rooms.length; j++) {
      if (rooms[j].id == eventUpdate.roomID) break;
    }
    final bool found = (j < rooms.length && rooms[j].id == eventUpdate.roomID);
    if (!found) return;
    if (eventUpdate.type == "timeline" ||
        eventUpdate.type == "state" ||
        eventUpdate.type == "invite_state") {
      Event stateEvent = Event.fromJson(eventUpdate.content, rooms[j]);
      if (stateEvent.type == EventTypes.Redaction) {
        final String redacts = eventUpdate.content["redacts"];
        rooms[j].states.states.forEach(
              (String key, Map<String, Event> states) => states.forEach(
                (String key, Event state) {
                  if (state.eventId == redacts) {
                    state.setRedactionEvent(stateEvent);
                  }
                },
              ),
            );
      } else {
        Event prevState =
            rooms[j].getState(stateEvent.typeKey, stateEvent.stateKey);
        if (prevState != null &&
            prevState.time.millisecondsSinceEpoch >
                stateEvent.time.millisecondsSinceEpoch) return;
        rooms[j].setState(stateEvent);
      }
    } else if (eventUpdate.type == "account_data") {
      rooms[j].roomAccountData[eventUpdate.eventType] =
          RoomAccountData.fromJson(eventUpdate.content, rooms[j]);
    } else if (eventUpdate.type == "ephemeral") {
      rooms[j].ephemerals[eventUpdate.eventType] =
          RoomAccountData.fromJson(eventUpdate.content, rooms[j]);
    }
    if (rooms[j].onUpdate != null) rooms[j].onUpdate.add(rooms[j].id);
    if (eventUpdate.type == "timeline") _sortRooms();
  }

  bool _sortLock = false;

  /// The compare function how the rooms should be sorted internally. By default
  /// rooms are sorted by timestamp of the last m.room.message event or the last
  /// event if there is no known message.
  RoomSorter sortRoomsBy = (a, b) => b.timeCreated.millisecondsSinceEpoch
      .compareTo(a.timeCreated.millisecondsSinceEpoch);

  _sortRooms() {
    if (_sortLock || rooms.length < 2) return;
    _sortLock = true;
    rooms?.sort(sortRoomsBy);
    _sortLock = false;
  }
}
