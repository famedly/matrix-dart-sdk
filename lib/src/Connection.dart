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
import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:famedlysdk/src/Room.dart';
import 'package:famedlysdk/src/RoomList.dart';
import 'package:http/http.dart' as http;
import 'package:mime_type/mime_type.dart';

import 'Client.dart';
import 'User.dart';
import 'responses/ErrorResponse.dart';
import 'sync/EventUpdate.dart';
import 'sync/RoomUpdate.dart';
import 'sync/UserUpdate.dart';

enum HTTPType { GET, POST, PUT, DELETE }

/// Represents a Matrix connection to communicate with a
/// [Matrix](https://matrix.org) homeserver.
class Connection {
  final Client client;

  Connection(this.client);

  static String syncFilters = '{"room":{"state":{"lazy_load_members":true}}}';

  static String firstSyncFilters =
      '{"room":{"include_leave":true,"state":{"lazy_load_members":true}}}';

  /// Handles the connection to the Matrix Homeserver. You can change this to a
  /// MockClient for testing.
  http.Client httpClient = http.Client();

  /// The newEvent signal is the most important signal in this concept. Every time
  /// the app receives a new synchronization, this event is called for every signal
  /// to update the GUI. For example, for a new message, it is called:
  /// onRoomEvent( "m.room.message", "!chat_id:server.com", "timeline", {sender: "@bob:server.com", body: "Hello world"} )
  final StreamController<EventUpdate> onEvent =
      new StreamController.broadcast();

  /// Outside of the events there are updates for the global chat states which
  /// are handled by this signal:
  final StreamController<RoomUpdate> onRoomUpdate =
      new StreamController.broadcast();

  /// Outside of rooms there are account updates like account_data or presences.
  final StreamController<UserUpdate> onUserEvent =
      new StreamController.broadcast();

  /// Called when the login state e.g. user gets logged out.
  final StreamController<LoginState> onLoginStateChanged =
      new StreamController.broadcast();

  /// Synchronization erros are coming here.
  final StreamController<ErrorResponse> onError =
      new StreamController.broadcast();

  /// This is called once, when the first sync has received.
  final StreamController<bool> onFirstSync = new StreamController.broadcast();

  /// When a new sync response is coming in, this gives the complete payload.
  final StreamController<dynamic> onSync = new StreamController.broadcast();

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
    client.accessToken = newToken;
    client.homeserver = newHomeserver;
    client.userID = newUserID;
    client.deviceID = newDeviceID;
    client.deviceName = newDeviceName;
    client.matrixVersions = newMatrixVersions;
    client.lazyLoadMembers = newLazyLoadMembers;
    client.prevBatch = newPrevBatch;

    List<Room> rooms = [];
    List<Room> archivedRooms = [];
    if (client.store != null) {
      client.store.storeClient();
      rooms = await client.store.getRoomList(onlyLeft: false);
      archivedRooms = await client.store.getRoomList(onlyLeft: true);
      client.accountData = await client.store.getAccountData();
      client.presences = await client.store.getPresences();
    }

    client.roomList = RoomList(
        client: client,
        onlyLeft: false,
        onUpdate: null,
        onInsert: null,
        onRemove: null,
        rooms: rooms);

    client.archive = RoomList(
        client: client,
        onlyLeft: true,
        onUpdate: null,
        onInsert: null,
        onRemove: null,
        rooms: archivedRooms);

    _userEventSub ??= onUserEvent.stream.listen(client.handleUserUpdate);

    onLoginStateChanged.add(LoginState.logged);

    _sync();
  }

  StreamSubscription _userEventSub;

  /// Resets all settings and stops the synchronisation.
  void clear() {
    client.store?.clear();
    client.accessToken = client.homeserver = client.userID = client.deviceID =
        client.deviceName = client.matrixVersions =
            client.lazyLoadMembers = client.prevBatch = null;
    onLoginStateChanged.add(LoginState.loggedOut);
  }

  /// Used for all Matrix json requests using the [c2s API](https://matrix.org/docs/spec/client_server/r0.4.0.html).
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
  Future<dynamic> jsonRequest(
      {HTTPType type,
      String action,
      dynamic data = "",
      int timeout,
      String contentType = "application/json"}) async {
    if (client.isLogged() == false && client.homeserver == null)
      throw ("No homeserver specified.");
    if (timeout == null) timeout = syncTimeoutSec + 5;
    dynamic json;
    if (data is Map) data.removeWhere((k, v) => v == null);
    (!(data is String)) ? json = jsonEncode(data) : json = data;
    if (data is List<int>) json = data;

    final url = "${client.homeserver}/_matrix${action}";

    Map<String, String> headers = {};
    if (type == HTTPType.PUT || type == HTTPType.POST)
      headers["Content-Type"] = contentType;
    if (client.isLogged())
      headers["Authorization"] = "Bearer ${client.accessToken}";

    if (client.debug)
      print(
          "[REQUEST ${type.toString().split('.').last}] Action: $action, Data: $data");

    http.Response resp;
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
    } on TimeoutException catch (_) {
      return ErrorResponse(
          error: "No connection possible...",
          errcode: "TIMEOUT",
          request: resp?.request);
    } catch (e) {
      return ErrorResponse(
          error: "No connection possible...",
          errcode: "NO_CONNECTION",
          request: resp?.request);
    }

    Map<String, dynamic> jsonResp;
    try {
      jsonResp = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      return ErrorResponse(
          error: "No connection possible...",
          errcode: "MALFORMED",
          request: resp?.request);
    }
    if (jsonResp.containsKey("errcode") && jsonResp["errcode"] is String) {
      if (jsonResp["errcode"] == "M_UNKNOWN_TOKEN") clear();
      return ErrorResponse.fromJson(jsonResp, resp?.request);
    }

    if (client.debug) print("[RESPONSE] ${jsonResp.toString()}");

    return jsonResp;
  }

  /// Uploads a file with the name [fileName] as base64 encoded to the server
  /// and returns the mxc url as a string or an [ErrorResponse].
  Future<dynamic> upload(File file) async {
    List<int> fileBytes;
    if (client.homeserver != "https://fakeServer.notExisting")
      fileBytes = await file.readAsBytes();
    String fileName = file.path.split("/").last;
    String mimeType = mime(file.path);
    print("[UPLOADING] $fileName, type: $mimeType, size: ${fileBytes?.length}");
    final dynamic resp = await jsonRequest(
        type: HTTPType.POST,
        action: "/media/r0/upload?filename=$fileName",
        data: fileBytes,
        contentType: mimeType);
    if (resp is ErrorResponse) return resp;
    return resp["content_uri"];
  }

  Future<dynamic> _syncRequest;

  Future<void> _sync() async {
    if (client.isLogged() == false) return;

    String action = "/client/r0/sync?filter=$firstSyncFilters";

    if (client.prevBatch != null) {
      action = "/client/r0/sync?filter=$syncFilters";
      action += "&timeout=30000";
      action += "&since=${client.prevBatch}";
    }
    _syncRequest = jsonRequest(type: HTTPType.GET, action: action);
    final int hash = _syncRequest.hashCode;
    final syncResp = await _syncRequest;
    if (hash != _syncRequest.hashCode) return;
    if (syncResp is ErrorResponse) {
      //onError.add(syncResp);
      await Future.delayed(Duration(seconds: syncErrorTimeoutSec), () {});
    } else {
      try {
        if (client.store != null)
          await client.store.transaction(() {
            _handleSync(syncResp);
            client.store.storePrevBatch(syncResp);
            return;
          });
        else
          await _handleSync(syncResp);
        if (client.prevBatch == null) client.connection.onFirstSync.add(true);
        client.prevBatch = syncResp["next_batch"];
      } catch (e) {
        onError
            .add(ErrorResponse(errcode: "CRITICAL_ERROR", error: e.toString()));
        await Future.delayed(Duration(seconds: syncErrorTimeoutSec), () {});
      }
    }
    if (hash == _syncRequest.hashCode) _sync();
  }

  void _handleSync(dynamic sync) {
    if (sync["rooms"] is Map<String, dynamic>) {
      if (sync["rooms"]["join"] is Map<String, dynamic>)
        _handleRooms(sync["rooms"]["join"], Membership.join);
      if (sync["rooms"]["invite"] is Map<String, dynamic>)
        _handleRooms(sync["rooms"]["invite"], Membership.invite);
      if (sync["rooms"]["leave"] is Map<String, dynamic>)
        _handleRooms(sync["rooms"]["leave"], Membership.leave);
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
        if (room["unread_notifications"]["highlight_count"] is num)
          highlight_count = room["unread_notifications"]["highlight_count"];
        if (room["unread_notifications"]["notification_count"] is num)
          notification_count =
              room["unread_notifications"]["notification_count"];
      }

      if (room["timeline"] is Map<String, dynamic>) {
        if (room["timeline"]["limited"] is bool)
          limitedTimeline = room["timeline"]["limited"];
        if (room["timeline"]["prev_batch"] is String)
          prev_batch = room["timeline"]["prev_batch"];
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
      client.store?.storeRoomUpdate(update);
      onRoomUpdate.add(update);

      /// Handle now all room events and save them in the database
      if (room["state"] is Map<String, dynamic> &&
          room["state"]["events"] is List<dynamic>)
        _handleRoomEvents(id, room["state"]["events"], "state");

      if (room["invite_state"] is Map<String, dynamic> &&
          room["invite_state"]["events"] is List<dynamic>)
        _handleRoomEvents(id, room["invite_state"]["events"], "invite_state");

      if (room["timeline"] is Map<String, dynamic> &&
          room["timeline"]["events"] is List<dynamic>)
        _handleRoomEvents(id, room["timeline"]["events"], "timeline");

      if (room["ephemetal"] is Map<String, dynamic> &&
          room["ephemetal"]["events"] is List<dynamic>)
        _handleEphemerals(id, room["ephemetal"]["events"]);

      if (room["account_data"] is Map<String, dynamic> &&
          room["account_data"]["events"] is List<dynamic>)
        _handleRoomEvents(id, room["account_data"]["events"], "account_data");
    });
  }

  void _handleEphemerals(String id, List<dynamic> events) {
    for (num i = 0; i < events.length; i++) {
      if (!(events[i]["type"] is String &&
          events[i]["content"] is Map<String, dynamic>)) continue;
      if (events[i]["type"] == "m.receipt") {
        events[i]["content"].forEach((String e, dynamic value) {
          if (!(events[i]["content"][e] is Map<String, dynamic> &&
              events[i]["content"][e]["m.read"] is Map<String, dynamic>))
            return;
          events[i]["content"][e]["m.read"]
              .forEach((String user, dynamic value) async {
            if (!(events[i]["content"][e]["m.read"]["user"]
                    is Map<String, dynamic> &&
                events[i]["content"][e]["m.read"]["ts"] is num)) return;

            _handleEvent(events[i], id, "ephemeral");
          });
        });
      } else if (events[i]["type"] == "m.typing") {
        if (!(events[i]["content"]["user_ids"] is List<String>)) continue;

        List<String> user_ids = events[i]["content"]["user_ids"];

        /// If the user is typing, remove his id from the list of typing users
        var ownTyping = user_ids.indexOf(client.userID);
        if (ownTyping != -1) user_ids.removeAt(1);

        _handleEvent(events[i], id, "ephemeral");
      }
    }
  }

  void _handleRoomEvents(String chat_id, List<dynamic> events, String type) {
    for (num i = 0; i < events.length; i++) {
      _handleEvent(events[i], chat_id, type);
    }
  }

  void _handleGlobalEvents(List<dynamic> events, String type) {
    for (int i = 0; i < events.length; i++)
      if (events[i]["type"] is String &&
          events[i]["content"] is Map<String, dynamic>) {
        UserUpdate update = UserUpdate(
          eventType: events[i]["type"],
          type: type,
          content: events[i],
        );
        client.store?.storeUserEventUpdate(update);
        onUserEvent.add(update);
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
      client.store?.storeEventUpdate(update);
      onEvent.add(update);
    }
  }
}

enum LoginState { logged, loggedOut }
