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

import 'package:famedlysdk/src/client.dart';
import 'package:famedlysdk/src/event.dart';
import 'package:famedlysdk/src/room_account_data.dart';
import 'package:famedlysdk/src/sync/event_update.dart';
import 'package:famedlysdk/src/sync/room_update.dart';
import 'package:famedlysdk/src/utils/matrix_exception.dart';
import 'package:famedlysdk/src/utils/matrix_file.dart';
import 'package:famedlysdk/src/utils/mx_content.dart';
import 'package:mime_type/mime_type.dart';

import './user.dart';
import 'timeline.dart';
import 'utils/states_map.dart';

enum PushRuleState { notify, mentions_only, dont_notify }
enum JoinRules { public, knock, invite, private }
enum GuestAccess { can_join, forbidden }
enum HistoryVisibility { invited, joined, shared, world_readable }

/// Represents a Matrix room.
class Room {
  /// The full qualified Matrix ID for the room in the format '!localid:server.abc'.
  final String id;

  /// Membership status of the user for this room.
  Membership membership;

  /// The count of unread notifications.
  int notificationCount;

  /// The count of highlighted notifications.
  int highlightCount;

  /// A token that can be supplied to the from parameter of the rooms/{roomId}/messages endpoint.
  String prev_batch;

  /// The users which can be used to generate a room name if the room does not have one.
  /// Required if the room's m.room.name or m.room.canonical_alias state events are unset or empty.
  List<String> mHeroes = [];

  /// The number of users with membership of join, including the client's own user ID.
  int mJoinedMemberCount;

  /// The number of users with membership of invite.
  int mInvitedMemberCount;

  StatesMap states = StatesMap();

  /// Key-Value store for ephemerals.
  Map<String, RoomAccountData> ephemerals = {};

  /// Key-Value store for private account data only visible for this user.
  Map<String, RoomAccountData> roomAccountData = {};

  /// Returns the [Event] for the given [typeKey] and optional [stateKey].
  /// If no [stateKey] is provided, it defaults to an empty string.
  Event getState(String typeKey, [String stateKey = ""]) =>
      states.states[typeKey] != null ? states.states[typeKey][stateKey] : null;

  /// Adds the [state] to this room and overwrites a state with the same
  /// typeKey/stateKey key pair if there is one.
  void setState(Event state) {
    if (!states.states.containsKey(state.typeKey)) {
      states.states[state.typeKey] = {};
    }
    states.states[state.typeKey][state.stateKey ?? ""] = state;
  }

  /// ID of the fully read marker event.
  String get fullyRead => roomAccountData["m.fully_read"] != null
      ? roomAccountData["m.fully_read"].content["event_id"]
      : "";

  /// If something changes, this callback will be triggered. Will return the
  /// room id.
  final StreamController<String> onUpdate = StreamController.broadcast();

  /// The name of the room if set by a participant.
  String get name => states["m.room.name"] != null
      ? states["m.room.name"].content["name"]
      : "";

  /// The topic of the room if set by a participant.
  String get topic => states["m.room.topic"] != null
      ? states["m.room.topic"].content["topic"]
      : "";

  /// The avatar of the room if set by a participant.
  MxContent get avatar {
    if (states["m.room.avatar"] != null) {
      return MxContent(states["m.room.avatar"].content["url"]);
    }
    if (mHeroes != null && mHeroes.length == 1 && states[mHeroes[0]] != null) {
      return states[mHeroes[0]].asUser.avatarUrl;
    }
    if (membership == Membership.invite &&
        getState("m.room.member", client.userID) != null) {
      return getState("m.room.member", client.userID).sender.avatarUrl;
    }
    return MxContent("");
  }

  /// The address in the format: #roomname:homeserver.org.
  String get canonicalAlias => states["m.room.canonical_alias"] != null
      ? states["m.room.canonical_alias"].content["alias"]
      : "";

  /// If this room is a direct chat, this is the matrix ID of the user.
  /// Returns null otherwise.
  String get directChatMatrixID {
    String returnUserId;
    if (client.directChats is Map<String, dynamic>) {
      client.directChats.forEach((String userId, dynamic roomIds) {
        if (roomIds is List<dynamic>) {
          for (int i = 0; i < roomIds.length; i++) {
            if (roomIds[i] == this.id) {
              returnUserId = userId;
              break;
            }
          }
        }
      });
    }
    return returnUserId;
  }

  /// Wheither this is a direct chat or not
  bool get isDirectChat => directChatMatrixID != null;

  /// Must be one of [all, mention]
  String notificationSettings;

  Event get lastEvent {
    DateTime lastTime = DateTime.fromMillisecondsSinceEpoch(0);
    Event lastEvent = getState("m.room.message");
    if (lastEvent == null) {
      states.forEach((final String key, final entry) {
        if (!entry.containsKey("")) return;
        final Event state = entry[""];
        if (state.time != null &&
            state.time.millisecondsSinceEpoch >
                lastTime.millisecondsSinceEpoch) {
          lastTime = state.time;
          lastEvent = state;
        }
      });
    }
    return lastEvent;
  }

  /// Returns a list of all current typing users.
  List<User> get typingUsers {
    if (!ephemerals.containsKey("m.typing")) return [];
    List<dynamic> typingMxid = ephemerals["m.typing"].content["user_ids"];
    List<User> typingUsers = [];
    for (int i = 0; i < typingMxid.length; i++) {
      typingUsers.add(getUserByMXIDSync(typingMxid[i]));
    }
    return typingUsers;
  }

  /// Your current client instance.
  final Client client;

  Room({
    this.id,
    this.membership = Membership.join,
    this.notificationCount = 0,
    this.highlightCount = 0,
    this.prev_batch = "",
    this.client,
    this.notificationSettings,
    this.mHeroes = const [],
    this.mInvitedMemberCount = 0,
    this.mJoinedMemberCount = 0,
    this.roomAccountData = const {},
  });

  /// The default count of how much events should be requested when requesting the
  /// history of this room.
  static const int DefaultHistoryCount = 100;

  /// Calculates the displayname. First checks if there is a name, then checks for a canonical alias and
  /// then generates a name from the heroes.
  String get displayname {
    if (name != null && name.isNotEmpty) return name;
    if (canonicalAlias != null &&
        canonicalAlias.isNotEmpty &&
        canonicalAlias.length > 3) {
      return canonicalAlias.substring(1, canonicalAlias.length).split(":")[0];
    }
    List<String> heroes = [];
    if (mHeroes != null &&
        mHeroes.isNotEmpty &&
        mHeroes.any((h) => h.isNotEmpty)) {
      heroes = mHeroes;
    } else {
      if (states["m.room.member"] is Map<String, dynamic>) {
        for (var entry in states["m.room.member"].entries) {
          Event state = entry.value;
          if (state.type == EventTypes.RoomMember &&
              state.stateKey != client?.userID) heroes.add(state.stateKey);
        }
      }
    }
    if (heroes.isNotEmpty) {
      String displayname = "";
      for (int i = 0; i < heroes.length; i++) {
        if (heroes[i].isEmpty) continue;
        displayname += getUserByMXIDSync(heroes[i]).calcDisplayname() + ", ";
      }
      return displayname.substring(0, displayname.length - 2);
    }
    if (membership == Membership.invite &&
        getState("m.room.member", client.userID) != null) {
      return getState("m.room.member", client.userID).sender.calcDisplayname();
    }
    return "Empty chat";
  }

  /// The last message sent to this room.
  String get lastMessage {
    if (lastEvent != null) {
      return lastEvent.body;
    } else {
      return "";
    }
  }

  /// When the last message received.
  DateTime get timeCreated {
    if (lastEvent != null) {
      return lastEvent.time;
    }
    return DateTime.now();
  }

  /// Call the Matrix API to change the name of this room. Returns the event ID of the
  /// new m.room.name event.
  Future<String> setName(String newName) async {
    final Map<String, dynamic> resp = await client.jsonRequest(
        type: HTTPType.PUT,
        action: "/client/r0/rooms/${id}/state/m.room.name",
        data: {"name": newName});
    return resp["event_id"];
  }

  /// Call the Matrix API to change the topic of this room.
  Future<String> setDescription(String newName) async {
    final Map<String, dynamic> resp = await client.jsonRequest(
        type: HTTPType.PUT,
        action: "/client/r0/rooms/${id}/state/m.room.topic",
        data: {"topic": newName});
    return resp["event_id"];
  }

  Future<String> _sendRawEventNow(Map<String, dynamic> content,
      {String txid}) async {
    if (txid == null) txid = "txid${DateTime.now().millisecondsSinceEpoch}";
    final Map<String, dynamic> res = await client.jsonRequest(
        type: HTTPType.PUT,
        action: "/client/r0/rooms/${id}/send/m.room.message/$txid",
        data: content);
    return res["event_id"];
  }

  Future<String> sendTextEvent(String message, {String txid}) =>
      sendEvent({"msgtype": "m.text", "body": message}, txid: txid);

  /// Sends a [file] to this room after uploading it. The [msgType] is optional
  /// and will be detected by the mimetype of the file.
  Future<String> sendFileEvent(MatrixFile file,
      {String msgType = "m.file", String txid}) async {
    if (msgType == "m.image") return sendImageEvent(file);
    if (msgType == "m.audio") return sendVideoEvent(file);
    if (msgType == "m.video") return sendAudioEvent(file);
    String fileName = file.path.split("/").last;

    final String uploadResp = await client.upload(file);

    // Send event
    Map<String, dynamic> content = {
      "msgtype": msgType,
      "body": fileName,
      "filename": fileName,
      "url": uploadResp,
      "info": {
        "mimetype": mime(file.path),
        "size": file.size,
      }
    };
    return await sendEvent(content, txid: txid);
  }

  Future<String> sendAudioEvent(MatrixFile file,
      {String txid, int width, int height}) async {
    String fileName = file.path.split("/").last;
    final String uploadResp = await client.upload(file);
    Map<String, dynamic> content = {
      "msgtype": "m.audio",
      "body": fileName,
      "filename": fileName,
      "url": uploadResp,
      "info": {
        "mimetype": mime(fileName),
        "size": file.size,
      }
    };
    return await sendEvent(content, txid: txid);
  }

  Future<String> sendImageEvent(MatrixFile file,
      {String txid, int width, int height}) async {
    String fileName = file.path.split("/").last;
    final String uploadResp = await client.upload(file);
    Map<String, dynamic> content = {
      "msgtype": "m.image",
      "body": fileName,
      "url": uploadResp,
      "info": {
        "size": file.size,
        "mimetype": mime(fileName),
        "w": width,
        "h": height,
      },
    };
    return await sendEvent(content, txid: txid);
  }

  Future<String> sendVideoEvent(MatrixFile file,
      {String txid,
      int videoWidth,
      int videoHeight,
      int duration,
      MatrixFile thumbnail,
      int thumbnailWidth,
      int thumbnailHeight}) async {
    String fileName = file.path.split("/").last;
    final String uploadResp = await client.upload(file);
    Map<String, dynamic> content = {
      "msgtype": "m.video",
      "body": fileName,
      "url": uploadResp,
      "info": {
        "size": file.size,
        "mimetype": mime(fileName),
      },
    };
    if (videoWidth != null) {
      content["info"]["w"] = videoWidth;
    }
    if (thumbnailHeight != null) {
      content["info"]["h"] = thumbnailHeight;
    }
    if (duration != null) {
      content["info"]["duration"] = duration;
    }
    if (thumbnail != null) {
      String thumbnailName = file.path.split("/").last;
      final String thumbnailUploadResp = await client.upload(file);
      content["info"]["thumbnail_url"] = thumbnailUploadResp;
      content["info"]["thumbnail_info"] = {
        "size": thumbnail.size,
        "mimetype": mime(thumbnailName),
      };
      if (thumbnailWidth != null) {
        content["info"]["thumbnail_info"]["w"] = thumbnailWidth;
      }
      if (thumbnailHeight != null) {
        content["info"]["thumbnail_info"]["h"] = thumbnailHeight;
      }
    }
    return await sendEvent(content, txid: txid);
  }

  Future<String> sendEvent(Map<String, dynamic> content, {String txid}) async {
    final String type = "m.room.message";

    // Create new transaction id
    String messageID;
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (txid == null) {
      messageID = "msg$now";
    } else {
      messageID = txid;
    }

    // Display a *sending* event and store it.
    EventUpdate eventUpdate =
        EventUpdate(type: "timeline", roomID: id, eventType: type, content: {
      "type": type,
      "event_id": messageID,
      "sender": client.userID,
      "status": 0,
      "origin_server_ts": now,
      "content": content
    });
    client.onEvent.add(eventUpdate);
    await client.store?.transaction(() {
      client.store.storeEventUpdate(eventUpdate);
      return;
    });

    // Send the text and on success, store and display a *sent* event.
    try {
      final String res = await _sendRawEventNow(content, txid: messageID);
      eventUpdate.content["status"] = 1;
      eventUpdate.content["unsigned"] = {"transaction_id": messageID};
      eventUpdate.content["event_id"] = res;
      client.onEvent.add(eventUpdate);
      await client.store?.transaction(() {
        client.store.storeEventUpdate(eventUpdate);
        return;
      });
      return res;
    } catch (exception) {
      // On error, set status to -1
      eventUpdate.content["status"] = -1;
      eventUpdate.content["unsigned"] = {"transaction_id": messageID};
      client.onEvent.add(eventUpdate);
      await client.store?.transaction(() {
        client.store.storeEventUpdate(eventUpdate);
        return;
      });
    }
    return null;
  }

  /// Call the Matrix API to join this room if the user is not already a member.
  /// If this room is intended to be a direct chat, the direct chat flag will
  /// automatically be set.
  Future<void> join() async {
    try {
      await client.jsonRequest(
          type: HTTPType.POST, action: "/client/r0/rooms/${id}/join");
      if (states.containsKey(client.userID) &&
          states[client.userID].content["is_direct"] is bool &&
          states[client.userID].content["is_direct"]) {
        await addToDirectChat(states[client.userID].sender.id);
      }
    } on MatrixException catch (exception) {
      if (exception.errorMessage == "No known servers") {
        await client.store?.forgetRoom(id);
        client.onRoomUpdate.add(
          RoomUpdate(
              id: id,
              membership: Membership.leave,
              notification_count: 0,
              highlight_count: 0),
        );
      }
      rethrow;
    }
  }

  /// Call the Matrix API to leave this room. If this room is set as a direct
  /// chat, this will be removed too.
  Future<void> leave() async {
    if (directChatMatrixID != "") await removeFromDirectChat();
    await client.jsonRequest(
        type: HTTPType.POST, action: "/client/r0/rooms/${id}/leave");
    return;
  }

  /// Call the Matrix API to forget this room if you already left it.
  Future<void> forget() async {
    await client.store?.forgetRoom(id);
    await client.jsonRequest(
        type: HTTPType.POST, action: "/client/r0/rooms/${id}/forget");
    return;
  }

  /// Call the Matrix API to kick a user from this room.
  Future<void> kick(String userID) async {
    await client.jsonRequest(
        type: HTTPType.POST,
        action: "/client/r0/rooms/${id}/kick",
        data: {"user_id": userID});
    return;
  }

  /// Call the Matrix API to ban a user from this room.
  Future<void> ban(String userID) async {
    await client.jsonRequest(
        type: HTTPType.POST,
        action: "/client/r0/rooms/${id}/ban",
        data: {"user_id": userID});
    return;
  }

  /// Call the Matrix API to unban a banned user from this room.
  Future<void> unban(String userID) async {
    await client.jsonRequest(
        type: HTTPType.POST,
        action: "/client/r0/rooms/${id}/unban",
        data: {"user_id": userID});
    return;
  }

  /// Set the power level of the user with the [userID] to the value [power].
  /// Returns the event ID of the new state event. If there is no known
  /// power level event, there might something broken and this returns null.
  Future<String> setPower(String userID, int power) async {
    if (states["m.room.power_levels"] == null) return null;
    Map<String, dynamic> powerMap = {}
      ..addAll(states["m.room.power_levels"].content);
    if (powerMap["users"] == null) powerMap["users"] = {};
    powerMap["users"][userID] = power;

    final Map<String, dynamic> resp = await client.jsonRequest(
        type: HTTPType.PUT,
        action: "/client/r0/rooms/$id/state/m.room.power_levels",
        data: powerMap);
    return resp["event_id"];
  }

  /// Call the Matrix API to invite a user to this room.
  Future<void> invite(String userID) async {
    await client.jsonRequest(
        type: HTTPType.POST,
        action: "/client/r0/rooms/${id}/invite",
        data: {"user_id": userID});
    return;
  }

  /// Request more previous events from the server. [historyCount] defines how much events should
  /// be received maximum. When the request is answered, [onHistoryReceived] will be triggered **before**
  /// the historical events will be published in the onEvent stream.
  Future<void> requestHistory(
      {int historyCount = DefaultHistoryCount, onHistoryReceived}) async {
    final dynamic resp = await client.jsonRequest(
        type: HTTPType.GET,
        action:
            "/client/r0/rooms/$id/messages?from=${prev_batch}&dir=b&limit=$historyCount&filter=${Client.syncFilters}");

    if (onHistoryReceived != null) onHistoryReceived();
    prev_batch = resp["end"];
    await client.store?.storeRoomPrevBatch(this);

    if (!(resp["chunk"] is List<dynamic> &&
        resp["chunk"].length > 0 &&
        resp["end"] is String)) return;

    if (resp["state"] is List<dynamic>) {
      await client.store?.transaction(() {
        for (int i = 0; i < resp["state"].length; i++) {
          EventUpdate eventUpdate = EventUpdate(
            type: "state",
            roomID: id,
            eventType: resp["state"][i]["type"],
            content: resp["state"][i],
          );
          client.onEvent.add(eventUpdate);
          client.store.storeEventUpdate(eventUpdate);
        }
        return;
      });
      if (client.store == null) {
        for (int i = 0; i < resp["state"].length; i++) {
          EventUpdate eventUpdate = EventUpdate(
            type: "state",
            roomID: id,
            eventType: resp["state"][i]["type"],
            content: resp["state"][i],
          );
          client.onEvent.add(eventUpdate);
        }
      }
    }

    List<dynamic> history = resp["chunk"];
    await client.store?.transaction(() {
      for (int i = 0; i < history.length; i++) {
        EventUpdate eventUpdate = EventUpdate(
          type: "history",
          roomID: id,
          eventType: history[i]["type"],
          content: history[i],
        );
        client.onEvent.add(eventUpdate);
        client.store.storeEventUpdate(eventUpdate);
        client.store.txn.rawUpdate(
            "UPDATE Rooms SET prev_batch=? WHERE room_id=?", [resp["end"], id]);
      }
      return;
    });
    if (client.store == null) {
      for (int i = 0; i < history.length; i++) {
        EventUpdate eventUpdate = EventUpdate(
          type: "history",
          roomID: id,
          eventType: history[i]["type"],
          content: history[i],
        );
        client.onEvent.add(eventUpdate);
      }
    }
    client.onRoomUpdate.add(
      RoomUpdate(
        id: id,
        membership: membership,
        prev_batch: resp["end"],
        notification_count: notificationCount,
        highlight_count: highlightCount,
      ),
    );
  }

  /// Sets this room as a direct chat for this user if not already.
  Future<void> addToDirectChat(String userID) async {
    Map<String, dynamic> directChats = client.directChats;
    if (directChats.containsKey(userID)) {
      if (!directChats[userID].contains(id)) {
        directChats[userID].add(id);
      } else {
        return;
      } // Is already in direct chats
    } else {
      directChats[userID] = [id];
    }

    await client.jsonRequest(
        type: HTTPType.PUT,
        action: "/client/r0/user/${client.userID}/account_data/m.direct",
        data: directChats);
    return;
  }

  /// Removes this room from all direct chat tags.
  Future<void> removeFromDirectChat() async {
    Map<String, dynamic> directChats = client.directChats;
    if (directChats.containsKey(directChatMatrixID) &&
        directChats[directChatMatrixID].contains(id)) {
      directChats[directChatMatrixID].remove(id);
    } else {
      return;
    } // Nothing to do here

    await client.jsonRequest(
        type: HTTPType.PUT,
        action: "/client/r0/user/${client.userID}/account_data/m.direct",
        data: directChats);
    return;
  }

  /// Sends *m.fully_read* and *m.read* for the given event ID.
  Future<void> sendReadReceipt(String eventID) async {
    this.notificationCount = 0;
    await client?.store?.resetNotificationCount(this.id);
    await client.jsonRequest(
        type: HTTPType.POST,
        action: "/client/r0/rooms/$id/read_markers",
        data: {
          "m.fully_read": eventID,
          "m.read": eventID,
        });
    return;
  }

  /// Returns a Room from a json String which comes normally from the store. If the
  /// state are also given, the method will await them.
  static Future<Room> getRoomFromTableRow(
      Map<String, dynamic> row, Client matrix,
      {Future<List<Map<String, dynamic>>> states,
      Future<List<Map<String, dynamic>>> roomAccountData}) async {
    Room newRoom = Room(
      id: row["room_id"],
      membership: Membership.values
          .firstWhere((e) => e.toString() == 'Membership.' + row["membership"]),
      notificationCount: row["notification_count"],
      highlightCount: row["highlight_count"],
      notificationSettings: row["notification_settings"],
      prev_batch: row["prev_batch"],
      mInvitedMemberCount: row["invited_member_count"],
      mJoinedMemberCount: row["joined_member_count"],
      mHeroes: row["heroes"]?.split(",") ?? [],
      client: matrix,
      roomAccountData: {},
    );

    if (states != null) {
      List<Map<String, dynamic>> rawStates = await states;
      for (int i = 0; i < rawStates.length; i++) {
        Event newState = Event.fromJson(rawStates[i], newRoom);
        newRoom.setState(newState);
      }
    }

    Map<String, RoomAccountData> newRoomAccountData = {};
    if (roomAccountData != null) {
      List<Map<String, dynamic>> rawRoomAccountData = await roomAccountData;
      for (int i = 0; i < rawRoomAccountData.length; i++) {
        RoomAccountData newData =
            RoomAccountData.fromJson(rawRoomAccountData[i], newRoom);
        newRoomAccountData[newData.typeKey] = newData;
      }
      newRoom.roomAccountData = newRoomAccountData;
    }

    return newRoom;
  }

  /// Creates a timeline from the store. Returns a [Timeline] object.
  Future<Timeline> getTimeline(
      {onTimelineUpdateCallback onUpdate,
      onTimelineInsertCallback onInsert}) async {
    List<Event> events = [];
    if (client.store != null) {
      events = await client.store.getEventList(this);
    } else {
      prev_batch = "";
      await requestHistory();
    }
    return Timeline(
      room: this,
      events: events,
      onUpdate: onUpdate,
      onInsert: onInsert,
    );
  }

  /// Load all participants for a given room from the store.
  @deprecated
  Future<List<User>> loadParticipants() async {
    return await client.store.loadParticipants(this);
  }

  /// Returns all participants for this room. With lazy loading this
  /// list may not be complete. User [requestParticipants] in this
  /// case.
  List<User> getParticipants() {
    List<User> userList = [];
    if (states["m.room.member"] is Map<String, dynamic>) {
      for (var entry in states["m.room.member"].entries) {
        Event state = entry.value;
        if (state.type == EventTypes.RoomMember) userList.add(state.asUser);
      }
    }
    return userList;
  }

  /// Request the full list of participants from the server. The local list
  /// from the store is not complete if the client uses lazy loading.
  Future<List<User>> requestParticipants() async {
    List<User> participants = [];

    dynamic res = await client.jsonRequest(
        type: HTTPType.GET, action: "/client/r0/rooms/${id}/members");

    for (num i = 0; i < res["chunk"].length; i++) {
      User newUser = Event.fromJson(res["chunk"][i], this).asUser;
      if (newUser.membership != Membership.leave) participants.add(newUser);
    }

    return participants;
  }

  /// Returns the [User] object for the given [mxID] or requests it from
  /// the homeserver and waits for a response.
  Future<User> getUserByMXID(String mxID) async {
    if (states[mxID] != null) return states[mxID].asUser;
    return requestUser(mxID);
  }

  /// Returns the [User] object for the given [mxID] or requests it from
  /// the homeserver and returns a default [User] object while waiting.
  User getUserByMXIDSync(String mxID) {
    if (states[mxID] != null) {
      return states[mxID].asUser;
    } else {
      try {
        requestUser(mxID);
      } catch (_) {}
      return User(mxID, room: this);
    }
  }

  Set<String> _requestingMatrixIds = Set();

  /// Requests a missing [User] for this room. Important for clients using
  /// lazy loading.
  Future<User> requestUser(String mxID) async {
    if (mxID == null || !_requestingMatrixIds.add(mxID)) return null;
    Map<String, dynamic> resp;
    try {
      resp = await client.jsonRequest(
          type: HTTPType.GET,
          action: "/client/r0/rooms/$id/state/m.room.member/$mxID");
    } catch (exception) {
      _requestingMatrixIds.remove(mxID);
      rethrow;
    }
    final User user = User(mxID,
        displayName: resp["displayname"],
        avatarUrl: resp["avatar_url"],
        room: this);
    states[mxID] = user;
    if (client.store != null) {
      await client.store.transaction(() {
        client.store.storeEventUpdate(
          EventUpdate(
              content: resp,
              roomID: id,
              type: "state",
              eventType: "m.room.member"),
        );
        return;
      });
    }
    if (onUpdate != null) onUpdate.add(id);
    _requestingMatrixIds.remove(mxID);
    return user;
  }

  /// Searches for the event on the server. Returns null if not found.
  Future<Event> getEventById(String eventID) async {
    final dynamic resp = await client.jsonRequest(
        type: HTTPType.GET, action: "/client/r0/rooms/$id/event/$eventID");
    return Event.fromJson(resp, this);
  }

  /// Returns the power level of the given user ID.
  int getPowerLevelByUserId(String userId) {
    int powerLevel = 0;
    Event powerLevelState = states["m.room.power_levels"];
    if (powerLevelState == null) return powerLevel;
    if (powerLevelState.content["users_default"] is int) {
      powerLevel = powerLevelState.content["users_default"];
    }
    if (powerLevelState.content["users"] is Map<String, dynamic> &&
        powerLevelState.content["users"][userId] != null) {
      powerLevel = powerLevelState.content["users"][userId];
    }
    return powerLevel;
  }

  /// Returns the user's own power level.
  int get ownPowerLevel => getPowerLevelByUserId(client.userID);

  /// Returns the power levels from all users for this room or null if not given.
  Map<String, int> get powerLevels {
    Event powerLevelState = states["m.room.power_levels"];
    if (powerLevelState.content["users"] is Map<String, int>) {
      return powerLevelState.content["users"];
    }
    return null;
  }

  /// Uploads a new user avatar for this room. Returns the event ID of the new
  /// m.room.avatar event.
  Future<String> setAvatar(MatrixFile file) async {
    final String uploadResp = await client.upload(file);
    final Map<String, dynamic> setAvatarResp = await client.jsonRequest(
        type: HTTPType.PUT,
        action: "/client/r0/rooms/$id/state/m.room.avatar/",
        data: {"url": uploadResp});
    return setAvatarResp["event_id"];
  }

  bool _hasPermissionFor(String action) {
    if (getState("m.room.power_levels") == null ||
        getState("m.room.power_levels").content[action] == null) return true;
    return ownPowerLevel >= getState("m.room.power_levels").content[action];
  }

  /// The level required to ban a user.
  bool get canBan => _hasPermissionFor("ban");

  /// The default level required to send message events. Can be overridden by the events key.
  bool get canSendDefaultMessages => _hasPermissionFor("events_default");

  /// The level required to invite a user.
  bool get canInvite => _hasPermissionFor("invite");

  /// The level required to kick a user.
  bool get canKick => _hasPermissionFor("kick");

  /// The level required to redact an event.
  bool get canRedact => _hasPermissionFor("redact");

  ///  	The default level required to send state events. Can be overridden by the events key.
  bool get canSendDefaultStates => _hasPermissionFor("state_default");

  bool get canChangePowerLevel => canSendEvent("m.room.power_levels");

  bool canSendEvent(String eventType) {
    if (getState("m.room.power_levels") == null) return true;
    if (getState("m.room.power_levels").content["events"] == null ||
        getState("m.room.power_levels").content["events"][eventType] == null) {
      return eventType == "m.room.message"
          ? canSendDefaultMessages
          : canSendDefaultStates;
    }
    return ownPowerLevel >=
        getState("m.room.power_levels").content["events"][eventType];
  }

  /// Returns the [PushRuleState] for this room, based on the m.push_rules stored in
  /// the account_data.
  PushRuleState get pushRuleState {
    if (!client.accountData.containsKey("m.push_rules") ||
        !(client.accountData["m.push_rules"].content["global"] is Map)) {
      return PushRuleState.notify;
    }
    final Map<String, dynamic> globalPushRules =
        client.accountData["m.push_rules"].content["global"];
    if (globalPushRules == null) return PushRuleState.notify;

    if (globalPushRules["override"] is List) {
      for (var i = 0; i < globalPushRules["override"].length; i++) {
        if (globalPushRules["override"][i]["rule_id"] == id) {
          if (globalPushRules["override"][i]["actions"]
                  .indexOf("dont_notify") !=
              -1) {
            return PushRuleState.dont_notify;
          }
          break;
        }
      }
    }

    if (globalPushRules["room"] is List) {
      for (var i = 0; i < globalPushRules["room"].length; i++) {
        if (globalPushRules["room"][i]["rule_id"] == id) {
          if (globalPushRules["room"][i]["actions"].indexOf("dont_notify") !=
              -1) {
            return PushRuleState.mentions_only;
          }
          break;
        }
      }
    }

    return PushRuleState.notify;
  }

  /// Sends a request to the homeserver to set the [PushRuleState] for this room.
  /// Returns ErrorResponse if something goes wrong.
  Future<dynamic> setPushRuleState(PushRuleState newState) async {
    if (newState == pushRuleState) return null;
    dynamic resp;
    switch (newState) {
      // All push notifications should be sent to the user
      case PushRuleState.notify:
        if (pushRuleState == PushRuleState.dont_notify) {
          resp = await client.jsonRequest(
              type: HTTPType.DELETE,
              action: "/client/r0/pushrules/global/override/$id",
              data: {});
        } else if (pushRuleState == PushRuleState.mentions_only) {
          resp = await client.jsonRequest(
              type: HTTPType.DELETE,
              action: "/client/r0/pushrules/global/room/$id",
              data: {});
        }
        break;
      // Only when someone mentions the user, a push notification should be sent
      case PushRuleState.mentions_only:
        if (pushRuleState == PushRuleState.dont_notify) {
          resp = await client.jsonRequest(
              type: HTTPType.DELETE,
              action: "/client/r0/pushrules/global/override/$id",
              data: {});
          resp = await client.jsonRequest(
              type: HTTPType.PUT,
              action: "/client/r0/pushrules/global/room/$id",
              data: {
                "actions": ["dont_notify"]
              });
        } else if (pushRuleState == PushRuleState.notify) {
          resp = await client.jsonRequest(
              type: HTTPType.PUT,
              action: "/client/r0/pushrules/global/room/$id",
              data: {
                "actions": ["dont_notify"]
              });
        }
        break;
      // No push notification should be ever sent for this room.
      case PushRuleState.dont_notify:
        if (pushRuleState == PushRuleState.mentions_only) {
          resp = await client.jsonRequest(
              type: HTTPType.DELETE,
              action: "/client/r0/pushrules/global/room/$id",
              data: {});
        }
        resp = await client.jsonRequest(
            type: HTTPType.PUT,
            action: "/client/r0/pushrules/global/override/$id",
            data: {
              "actions": ["dont_notify"],
              "conditions": [
                {"key": "room_id", "kind": "event_match", "pattern": id}
              ]
            });
    }
    return resp;
  }

  /// Redacts this event. Returns [ErrorResponse] on error.
  Future<dynamic> redactEvent(String eventId,
      {String reason, String txid}) async {
    // Create new transaction id
    String messageID;
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (txid == null) {
      messageID = "msg$now";
    } else {
      messageID = txid;
    }
    Map<String, dynamic> data = {};
    if (reason != null) data["reason"] = reason;
    final dynamic resp = await client.jsonRequest(
        type: HTTPType.PUT,
        action: "/client/r0/rooms/$id/redact/$eventId/$messageID",
        data: data);
    return resp;
  }

  Future<dynamic> sendTypingInfo(bool isTyping, {int timeout}) {
    Map<String, dynamic> data = {
      "typing": isTyping,
    };
    if (timeout != null) data["timeout"] = timeout;
    return client.jsonRequest(
      type: HTTPType.PUT,
      action: "/client/r0/rooms/${this.id}/typing/${client.userID}",
      data: data,
    );
  }

  /// This is sent by the caller when they wish to establish a call.
  /// [callId] is a unique identifier for the call.
  /// [version] is the version of the VoIP specification this message adheres to. This specification is version 0.
  /// [lifetime] is the time in milliseconds that the invite is valid for. Once the invite age exceeds this value,
  /// clients should discard it. They should also no longer show the call as awaiting an answer in the UI.
  /// [type] The type of session description. Must be 'offer'.
  /// [sdp] The SDP text of the session description.
  Future<String> inviteToCall(String callId, int lifetime, String sdp,
      {String type = "offer", int version = 0, String txid}) async {
    if (txid == null) txid = "txid${DateTime.now().millisecondsSinceEpoch}";
    final Map<String, dynamic> response = await client.jsonRequest(
      type: HTTPType.PUT,
      action: "/client/r0/rooms/$id/send/m.call.invite/$txid",
      data: {
        "call_id": callId,
        "lifetime": lifetime,
        "offer": {"sdp": sdp, "type": type},
        "version": version,
      },
    );
    return response["event_id"];
  }

  /// This is sent by callers after sending an invite and by the callee after answering.
  /// Its purpose is to give the other party additional ICE candidates to try using to communicate.
  ///
  /// [callId] The ID of the call this event relates to.
  ///
  /// [version] The version of the VoIP specification this messages adheres to. This specification is version 0.
  ///
  /// [candidates] Array of objects describing the candidates. Example:
  ///
  /// ```
  /// [
  ///       {
  ///           "candidate": "candidate:863018703 1 udp 2122260223 10.9.64.156 43670 typ host generation 0",
  ///           "sdpMLineIndex": 0,
  ///           "sdpMid": "audio"
  ///       }
  ///   ],
  /// ```
  Future<String> sendCallCandidates(
    String callId,
    List<Map<String, dynamic>> candidates, {
    int version = 0,
    String txid,
  }) async {
    if (txid == null) txid = "txid${DateTime.now().millisecondsSinceEpoch}";
    final Map<String, dynamic> response = await client.jsonRequest(
      type: HTTPType.PUT,
      action: "/client/r0/rooms/$id/send/m.call.candidates/$txid",
      data: {
        "call_id": callId,
        "candidates": candidates,
        "version": version,
      },
    );
    return response["event_id"];
  }

  /// This event is sent by the callee when they wish to answer the call.
  /// [callId] is a unique identifier for the call.
  /// [version] is the version of the VoIP specification this message adheres to. This specification is version 0.
  /// [type] The type of session description. Must be 'answer'.
  /// [sdp] The SDP text of the session description.
  Future<String> answerCall(String callId, String sdp,
      {String type = "answer", int version = 0, String txid}) async {
    if (txid == null) txid = "txid${DateTime.now().millisecondsSinceEpoch}";
    final Map<String, dynamic> response = await client.jsonRequest(
      type: HTTPType.PUT,
      action: "/client/r0/rooms/$id/send/m.call.answer/$txid",
      data: {
        "call_id": callId,
        "answer": {"sdp": sdp, "type": type},
        "version": version,
      },
    );
    return response["event_id"];
  }

  /// This event is sent by the callee when they wish to answer the call.
  /// [callId] The ID of the call this event relates to.
  /// [version] is the version of the VoIP specification this message adheres to. This specification is version 0.
  Future<String> hangupCall(String callId,
      {int version = 0, String txid}) async {
    if (txid == null) txid = "txid${DateTime.now().millisecondsSinceEpoch}";
    final Map<String, dynamic> response = await client.jsonRequest(
      type: HTTPType.PUT,
      action: "/client/r0/rooms/$id/send/m.call.hangup/$txid",
      data: {
        "call_id": callId,
        "version": version,
      },
    );
    return response["event_id"];
  }

  /// Returns all aliases for this room.
  List<String> get aliases {
    List<String> aliases = [];
    for (Event aliasEvent in states.states["m.room.aliases"].values) {
      if (aliasEvent.content["aliases"] is List) {
        aliases.addAll(aliasEvent.content["aliases"]);
      }
    }
    return aliases;
  }

  /// A room may be public meaning anyone can join the room without any prior action. Alternatively,
  /// it can be invite meaning that a user who wishes to join the room must first receive an invite
  /// to the room from someone already inside of the room. Currently, knock and private are reserved
  /// keywords which are not implemented.
  JoinRules get joinRules => getState("m.room.join_rules") != null
      ? JoinRules.values.firstWhere(
          (r) =>
              r.toString().replaceAll("JoinRules.", "") ==
              getState("m.room.join_rules").content["join_rule"],
          orElse: () => null)
      : null;

  /// Changes the join rules. You should check first if the user is able to change it.
  Future<void> setJoinRules(JoinRules joinRules) async {
    await client.jsonRequest(
      type: HTTPType.PUT,
      action: "/client/r0/rooms/$id/state/m.room.join_rules/",
      data: {
        "join_rule": joinRules.toString().replaceAll("JoinRules.", ""),
      },
    );
    return;
  }

  /// Whether the user has the permission to change the join rules.
  bool get canChangeJoinRules => canSendEvent("m.room.join_rules");

  /// This event controls whether guest users are allowed to join rooms. If this event
  /// is absent, servers should act as if it is present and has the guest_access value "forbidden".
  GuestAccess get guestAccess => getState("m.room.guest_access") != null
      ? GuestAccess.values.firstWhere(
          (r) =>
              r.toString().replaceAll("GuestAccess.", "") ==
              getState("m.room.guest_access").content["guest_access"],
          orElse: () => GuestAccess.forbidden)
      : GuestAccess.forbidden;

  /// Changes the guest access. You should check first if the user is able to change it.
  Future<void> setGuestAccess(GuestAccess guestAccess) async {
    await client.jsonRequest(
      type: HTTPType.PUT,
      action: "/client/r0/rooms/$id/state/m.room.guest_access/",
      data: {
        "guest_access": guestAccess.toString().replaceAll("GuestAccess.", ""),
      },
    );
    return;
  }

  /// Whether the user has the permission to change the guest access.
  bool get canChangeGuestAccess => canSendEvent("m.room.guest_access");

  /// This event controls whether a user can see the events that happened in a room from before they joined.
  HistoryVisibility get historyVisibility =>
      getState("m.room.history_visibility") != null
          ? HistoryVisibility.values.firstWhere(
              (r) =>
                  r.toString().replaceAll("HistoryVisibility.", "") ==
                  getState("m.room.history_visibility")
                      .content["history_visibility"],
              orElse: () => null)
          : null;

  /// Changes the history visibility. You should check first if the user is able to change it.
  Future<void> setHistoryVisibility(HistoryVisibility historyVisibility) async {
    await client.jsonRequest(
      type: HTTPType.PUT,
      action: "/client/r0/rooms/$id/state/m.room.history_visibility/",
      data: {
        "history_visibility":
            historyVisibility.toString().replaceAll("HistoryVisibility.", ""),
      },
    );
    return;
  }

  /// Whether the user has the permission to change the history visibility.
  bool get canChangeHistoryVisibility =>
      canSendEvent("m.room.history_visibility");
}
