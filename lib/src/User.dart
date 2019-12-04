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

import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/src/Room.dart';
import 'package:famedlysdk/src/RoomState.dart';
import 'package:famedlysdk/src/responses/ErrorResponse.dart';
import 'package:famedlysdk/src/utils/ChatTime.dart';
import 'package:famedlysdk/src/utils/MxContent.dart';

import 'Connection.dart';

enum Membership { join, invite, leave, ban }

/// Represents a Matrix User which may be a participant in a Matrix Room.
class User extends RoomState {
  factory User(
    String id, {
    String membership,
    String displayName,
    String avatarUrl,
    Room room,
  }) {
    Map<String, String> content = {};
    if (membership != null) content["membership"] = membership;
    if (displayName != null) content["displayname"] = displayName;
    if (avatarUrl != null) content["avatar_url"] = avatarUrl;
    return User.fromState(
      stateKey: id,
      content: content,
      typeKey: "m.room.member",
      roomId: room?.id,
      room: room,
      time: ChatTime.now(),
    );
  }

  User.fromState(
      {dynamic prevContent,
      String stateKey,
      dynamic content,
      String typeKey,
      String eventId,
      String roomId,
      String senderId,
      ChatTime time,
      dynamic unsigned,
      Room room})
      : super(
            stateKey: stateKey,
            prevContent: prevContent,
            content: content,
            typeKey: typeKey,
            eventId: eventId,
            roomId: roomId,
            senderId: senderId,
            time: time,
            unsigned: unsigned,
            room: room);

  /// The full qualified Matrix ID in the format @username:server.abc.
  String get id => stateKey;

  /// The displayname of the user if the user has set one.
  String get displayName => content != null ? content["displayname"] : null;

  /// Returns the power level of this user.
  int get powerLevel => room?.getPowerLevelByUserId(id);

  /// The membership status of the user. One of:
  /// join
  /// invite
  /// leave
  /// ban
  Membership get membership => Membership.values.firstWhere((e) {
        if (content["membership"] != null) {
          return e.toString() == 'Membership.' + content['membership'];
        }
        return false;
      });

  /// The avatar if the user has one.
  MxContent get avatarUrl => content != null && content["avatar_url"] is String
      ? MxContent(content["avatar_url"])
      : MxContent("");

  /// Returns the displayname or the local part of the Matrix ID if the user
  /// has no displayname.
  String calcDisplayname() => (displayName == null || displayName.isEmpty)
      ? (stateKey != null
          ? stateKey.replaceFirst("@", "").split(":")[0]
          : "Unknown User")
      : displayName;

  /// Call the Matrix API to kick this user from this room.
  Future<dynamic> kick() async {
    dynamic res = await room.kick(id);
    return res;
  }

  /// Call the Matrix API to ban this user from this room.
  Future<dynamic> ban() async {
    dynamic res = await room.ban(id);
    return res;
  }

  /// Call the Matrix API to unban this banned user from this room.
  Future<dynamic> unban() async {
    dynamic res = await room.unban(id);
    return res;
  }

  /// Call the Matrix API to change the power level of this user.
  Future<dynamic> setPower(int power) async {
    dynamic res = await room.setPower(id, power);
    return res;
  }

  /// Returns an existing direct chat ID with this user or creates a new one.
  /// Returns null on error.
  Future<String> startDirectChat() async {
    // Try to find an existing direct chat
    String roomID = await room.client?.getDirectChatFromUserId(id);
    if (roomID != null) return roomID;

    // Start a new direct chat
    final dynamic resp = await room.client.connection.jsonRequest(
        type: HTTPType.POST,
        action: "/client/r0/createRoom",
        data: {
          "invite": [id],
          "is_direct": true,
          "preset": "trusted_private_chat"
        });

    if (resp is ErrorResponse) {
      room.client.connection.onError.add(resp);
      return null;
    }

    final String newRoomID = resp["room_id"];

    if (newRoomID == null) return newRoomID;

    await Room(id: newRoomID, client: room.client).addToDirectChat(id);

    return newRoomID;
  }

  /// The newest presence of this user if there is any and null if not.
  Presence get presence => room.client.presences[id];

  /// Whether the client is allowed to ban/unban this user.
  bool get canBan => room.canBan && powerLevel < room.ownPowerLevel;

  /// Whether the client is allowed to kick this user.
  bool get canKick => room.canKick && powerLevel < room.ownPowerLevel;

  /// Whether the client is allowed to change the power level of this user.
  /// Please be aware that you can only set the power level to at least your own!
  bool get canChangePowerLevel =>
      room.canChangePowerLevel && powerLevel < room.ownPowerLevel;
}
