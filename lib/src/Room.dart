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
  final String roomID;
  String name;
  String lastMessage;
  MxContent avatar;
  ChatTime timeCreated;
  int notificationCount;
  int highlightCount;
  String topic;
  User user;
  final Client matrix;
  List<Event> events = [];

  Room({
    this.roomID,
    this.name,
    this.lastMessage,
    this.avatar,
    this.timeCreated,
    this.notificationCount,
    this.highlightCount,
    this.topic,
    this.user,
    this.matrix,
    this.events,
  });

  String get status {
    if (this.user != null) {
      return this.user.status;
    }
    return this.topic;
  }

  Future<dynamic> setName(String newName) async{
    dynamic res = await matrix.connection.jsonRequest(
        type: "PUT",
        action:
        "/client/r0/rooms/${roomID}/send/m.room.name/${new DateTime.now()}",
        data: {"name": newName});
    if (res is ErrorResponse) matrix.connection.onError.add(res);
    return res;
  }

  Future<dynamic> setDescription(String newName) async{
    dynamic res = await matrix.connection.jsonRequest(
        type: "PUT",
        action:
        "/client/r0/rooms/${roomID}/send/m.room.topic/${new DateTime.now()}",
        data: {"topic": newName});
    if (res is ErrorResponse) matrix.connection.onError.add(res);
    return res;
  }

  Stream<List<Event>> get eventsStream {
    return Stream<List<Event>>.fromIterable(Iterable<List<Event>>.generate(
        this.events.length, (int index) => this.events)).asBroadcastStream();
  }

  Future<void> sendText(String message) async {
    dynamic res = await matrix.connection.jsonRequest(
        type: "PUT",
        action:
            "/client/r0/rooms/${roomID}/send/m.room.message/${new DateTime.now()}",
        data: {"msgtype": "m.text", "body": message});
    if (res["errcode"] == "M_LIMIT_EXCEEDED") matrix.connection.onError.add(res["error"]);
  }

  Future<dynamic> leave() async {
    dynamic res = await matrix.connection.jsonRequest(
        type: "POST",
        action:
        "/client/r0/rooms/${roomID}/leave");
    if (res is ErrorResponse) matrix.connection.onError.add(res);
    return res;
  }

  Future<dynamic> forget() async {
    dynamic res = await matrix.connection.jsonRequest(
        type: "POST",
        action:
        "/client/r0/rooms/${roomID}/forget");
    if (res is ErrorResponse) matrix.connection.onError.add(res);
    return res;
  }

  Future<dynamic> kick(String userID) async {
    dynamic res = await matrix.connection.jsonRequest(
        type: "POST",
        action:
        "/client/r0/rooms/${roomID}/kick",
        data: {"user_id": userID});
    if (res is ErrorResponse) matrix.connection.onError.add(res);
    return res;
  }

  Future<dynamic> ban(String userID) async {
    dynamic res = await matrix.connection.jsonRequest(
        type: "POST",
        action:
        "/client/r0/rooms/${roomID}/ban",
        data: {"user_id": userID});
    if (res is ErrorResponse) matrix.connection.onError.add(res);
    return res;
  }

  Future<dynamic> unban(String userID) async {
    dynamic res = await matrix.connection.jsonRequest(
        type: "POST",
        action:
        "/client/r0/rooms/${roomID}/unban",
        data: {"user_id": userID});
    if (res is ErrorResponse) matrix.connection.onError.add(res);
    return res;
  }

  Future<dynamic> invite(String userID) async {
    dynamic res = await matrix.connection.jsonRequest(
        type: "POST",
        action:
        "/client/r0/rooms/${roomID}/invite",
        data: {"user_id": userID});
    if (res is ErrorResponse) matrix.connection.onError.add(res);
    return res;
  }

  static Future<Room> getRoomFromTableRow(
      Map<String, dynamic> row, Client matrix) async {
    String name = row["topic"];
    if (name == "") name = await matrix.store.getChatNameFromMemberNames(row["id"]);

    String content_body = row["content_body"];
    if (content_body == null || content_body == "")
      content_body = "Keine vorhergehenden Nachrichten";

    String avatarMxcUrl = row["avatar_url"];

    if (avatarMxcUrl == "")
      avatarMxcUrl = await matrix.store.getAvatarFromSingleChat(row["id"]);

    return Room(
      roomID: row["id"],
      name: name,
      lastMessage: content_body,
      avatar: MxContent(avatarMxcUrl),
      timeCreated: ChatTime(row["origin_server_ts"]),
      notificationCount: row["notification_count"],
      highlightCount: row["highlight_count"],
      topic: "",
      matrix: matrix,
      events: [],
    );
  }

  static Future<Room> getRoomById(String id, Client matrix) async {
    List<Map<String, dynamic>> res =
        await matrix.store.db.rawQuery("SELECT * FROM Chats WHERE id=?", [id]);
    if (res.length != 1) return null;
    return getRoomFromTableRow(res[0], matrix);
  }

  static Future<Room> loadRoomEvents(String id, Client matrix) async {
      Room room = await Room.getRoomById(id, matrix);
      room.events = await Event.getEventList(matrix, id);
      return room;
  }

  Future<List<User>> requestParticipants(Client matrix) async {
    List<User> participants = [];

    dynamic res = await matrix.connection.jsonRequest(
        type: "GET", action: "/client/r0/rooms/${roomID}/members");
    if (res is ErrorResponse || !(res["chunk"] is List<dynamic>))
      return participants;

    for (num i = 0; i < res["chunk"].length; i++) {
      User newUser = User(res["chunk"][i]["state_key"],
          displayName: res["chunk"][i]["content"]["displayname"] ?? "",
          status: res["chunk"][i]["content"]["membership"] ?? "",
          directChatRoomId: "",
          avatar_url:
              MxContent(res["chunk"][i]["content"]["avatar_url"] ?? ""));
      if (newUser.status != "leave") participants.add(newUser);
    }

    return participants;
  }
}
