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
 * along with Foobar.  If not, see <http://www.gnu.org/licenses/>.
 */

import 'package:famedlysdk/src/Client.dart';
import 'package:famedlysdk/src/utils/ChatTime.dart';
import 'package:famedlysdk/src/utils/MxContent.dart';
import 'package:famedlysdk/src/responses/ErrorResponse.dart';
import 'package:famedlysdk/src/Event.dart';
import './User.dart';

/// Represents a Matrix room.
class Room {
  /// The full qualified Matrix ID for the room in the format '!localid:server.abc'.
  final String id;

  /// Membership status of the user for this room.
  String membership;

  /// The name of the room if set by a participant.
  String name;

  /// The topic of the room if set by a participant.
  String topic;

  /// The avatar of the room if set by a participant.
  MxContent avatar;

  /// The count of unread notifications.
  int notificationCount;

  /// The count of highlighted notifications.
  int highlightCount;

  String prev_batch;

  String draft;

  /// Time when the user has last read the chat.
  ChatTime unread;

  /// ID of the fully read marker event.
  String fullyRead;

  /// The address in the format: #roomname:homeserver.org.
  String canonicalAlias;

  /// If this room is a direct chat, this is the matrix ID of the user
  String directChatMatrixID;

  /// Must be one of [all, mention]
  String notificationSettings;

  /// Are guest users allowed?
  String guestAccess;

  /// Who can see the history of this room?
  String historyVisibility;

  /// Who is allowed to join this room?
  String joinRules;

  /// The needed power levels for all actions.
  Map<String,int> powerLevels = {};

  /// The list of events in this room. If the room is created by the
  /// [getRoomList()] of the [Store], this will contain only the last event.
  List<Event> events = [];

  /// The list of participants in this room. If the room is created by the
  /// [getRoomList()] of the [Store], this will contain only the sender of the
  /// last event.
  List<User> participants = [];

  /// Your current client instance.
  final Client client;

  @Deprecated("Rooms.roomID is deprecated! Use Rooms.id instead!")
  String get roomID =>this.id;

  @Deprecated("Rooms.matrix is deprecated! Use Rooms.client instead!")
  Client get matrix => this.client;

  @Deprecated("Rooms.status is deprecated! Use Rooms.membership instead!")
  String get status => this.membership;

  Room({
    this.id,
    this.membership,
    this.name,
    this.topic,
    this.avatar,
    this.notificationCount,
    this.highlightCount,
    this.prev_batch,
    this.draft,
    this.unread,
    this.fullyRead,
    this.canonicalAlias,
    this.directChatMatrixID,
    this.notificationSettings,
    this.guestAccess,
    this.historyVisibility,
    this.joinRules,
    this.powerLevels,
    this.events,
    this.participants,
    this.client,
  });

  /// The last message sent to this room.
  String get lastMessage {
    if (events.length > 0)
      return events[0].getBody();
    else return "";
  }

  /// When the last message received.
  ChatTime get timeCreated {
    if (events.length > 0)
      return events[0].time;
    else return ChatTime.now();
  }

  /// Call the Matrix API to change the name of this room.
  Future<dynamic> setName(String newName) async{
    dynamic res = await client.connection.jsonRequest(
        type: "PUT",
        action:
        "/client/r0/rooms/${id}/send/m.room.name/${new DateTime.now()}",
        data: {"name": newName});
    if (res is ErrorResponse) client.connection.onError.add(res);
    return res;
  }

  /// Call the Matrix API to change the topic of this room.
  Future<dynamic> setDescription(String newName) async{
    dynamic res = await client.connection.jsonRequest(
        type: "PUT",
        action:
        "/client/r0/rooms/${id}/send/m.room.topic/${new DateTime.now()}",
        data: {"topic": newName});
    if (res is ErrorResponse) client.connection.onError.add(res);
    return res;
  }

  @Deprecated("Use the client.connection streams instead!")
  Stream<List<Event>> get eventsStream {
    return Stream<List<Event>>.fromIterable(Iterable<List<Event>>.generate(
        this.events.length, (int index) => this.events)).asBroadcastStream();
  }

  /// Call the Matrix API to send a simple text message.
  Future<void> sendText(String message) async {
    dynamic res = await client.connection.jsonRequest(
        type: "PUT",
        action:
            "/client/r0/rooms/${id}/send/m.room.message/${new DateTime.now()}",
        data: {"msgtype": "m.text", "body": message});
    if (res["errcode"] == "M_LIMIT_EXCEEDED") client.connection.onError.add(res["error"]);
  }

  /// Call the Matrix API to leave this room.
  Future<dynamic> leave() async {
    dynamic res = await client.connection.jsonRequest(
        type: "POST",
        action:
        "/client/r0/rooms/${id}/leave");
    if (res is ErrorResponse) client.connection.onError.add(res);
    return res;
  }

  /// Call the Matrix API to forget this room if you already left it.
  Future<dynamic> forget() async {
    dynamic res = await client.connection.jsonRequest(
        type: "POST",
        action:
        "/client/r0/rooms/${id}/forget");
    if (res is ErrorResponse) client.connection.onError.add(res);
    return res;
  }

  /// Call the Matrix API to kick a user from this room.
  Future<dynamic> kick(String userID) async {
    dynamic res = await client.connection.jsonRequest(
        type: "POST",
        action:
        "/client/r0/rooms/${id}/kick",
        data: {"user_id": userID});
    if (res is ErrorResponse) client.connection.onError.add(res);
    return res;
  }

  /// Call the Matrix API to ban a user from this room.
  Future<dynamic> ban(String userID) async {
    dynamic res = await client.connection.jsonRequest(
        type: "POST",
        action:
        "/client/r0/rooms/${id}/ban",
        data: {"user_id": userID});
    if (res is ErrorResponse) client.connection.onError.add(res);
    return res;
  }

  /// Call the Matrix API to unban a banned user from this room.
  Future<dynamic> unban(String userID) async {
    dynamic res = await client.connection.jsonRequest(
        type: "POST",
        action:
        "/client/r0/rooms/${id}/unban",
        data: {"user_id": userID});
    if (res is ErrorResponse) client.connection.onError.add(res);
    return res;
  }

  /// Call the Matrix API to invite a user to this room.
  Future<dynamic> invite(String userID) async {
    dynamic res = await client.connection.jsonRequest(
        type: "POST",
        action:
        "/client/r0/rooms/${id}/invite",
        data: {"user_id": userID});
    if (res is ErrorResponse) client.connection.onError.add(res);
    return res;
  }

  /// Returns a Room from a json String which comes normally from the store.
  static Future<Room> getRoomFromTableRow(
      Map<String, dynamic> row, Client matrix) async {

    String name = row["topic"];
    if (name == "") name = await matrix.store?.getChatNameFromMemberNames(row["id"]) ?? "";

    if (row["avatar_url"] == "")
      row["avatar_url"] = await matrix.store?.getAvatarFromSingleChat(row["id"]) ?? "";

    return Room(
      id: row["id"],
      name: name,
      topic: row["description"],
      avatar: MxContent(row["avatar_url"]),
      notificationCount: row["notification_count"],
      highlightCount: row["highlight_count"],
      unread: ChatTime(row["unread"]),
      fullyRead: row["fully_read"],
      notificationSettings: row["notification_settings"],
      directChatMatrixID: row["direct_chat_matrix_id"],
      draft: row["draft"],
      prev_batch: row["prev_batch"],

      guestAccess: row["guest_access"],
      historyVisibility: row["history_visibility"],
      joinRules: row["join_rules"],

      powerLevels: {
        "power_events_default": row["power_events_default"],
        "power_state_default": row["power_state_default"],
        "power_redact": row["power_redact"],
        "power_invite": row["power_invite"],
        "power_ban": row["power_ban"],
        "power_kick": row["power_kick"],
        "power_user_default": row["power_user_default"],
        "power_event_avatar": row["power_event_avatar"],
        "power_event_history_visibility": row["power_event_history_visibility"],
        "power_event_canonical_alias": row["power_event_canonical_alias"],
        "power_event_aliases": row["power_event_aliases"],
        "power_event_name": row["power_event_name"],
        "power_event_power_levels": row["power_event_power_levels"],
      },

      client: matrix,
      events: [],
      participants: [],
    );
  }

  @Deprecated("Use client.store.getRoomById(String id) instead!")
  static Future<Room> getRoomById(String id, Client matrix) async {
    Room room = await matrix.store.getRoomById(id);
    return room;
  }

  /// Load a room from the store including all room events.
  static Future<Room> loadRoomEvents(String id, Client matrix) async {
      Room room = await matrix.store.getRoomById(id);
      await room.loadEvents();
      return room;
  }

  /// Load all events for a given room from the store. This includes all
  /// senders of those events, who will be added to the participants list.
  Future<List<Event>> loadEvents() async {
    this.events = await client.store.getEventList(this);

    Map<String,bool> participantMap = {};
    for (num i = 0; i < events.length; i++) {
      if (!participantMap.containsKey(events[i].sender.mxid)) {
        participants.add(events[i].sender);
        participantMap[events[i].sender.mxid] = true;
      }
    }

    return this.events;
  }

  /// Load all participants for a given room from the store.
  Future<List<User>> loadParticipants() async {
    this.participants = await client.store.loadParticipants(this);
    return this.participants;
  }

  /// Request the full list of participants from the server. The local list
  /// from the store is not complete if the client uses lazy loading.
  Future<List<User>> requestParticipants(Client matrix) async {
    List<User> participants = [];

    dynamic res = await matrix.connection.jsonRequest(
        type: "GET", action: "/client/r0/rooms/${id}/members");
    if (res is ErrorResponse || !(res["chunk"] is List<dynamic>))
      return participants;

    for (num i = 0; i < res["chunk"].length; i++) {
      User newUser = User(res["chunk"][i]["state_key"],
          displayName: res["chunk"][i]["content"]["displayname"] ?? "",
          membership: res["chunk"][i]["content"]["membership"] ?? "",
          avatarUrl:
              MxContent(res["chunk"][i]["content"]["avatar_url"] ?? ""),
          room: this);
      if (newUser.membership != "leave") participants.add(newUser);
    }

    this.participants = participants;

    return this.participants;
  }
}
