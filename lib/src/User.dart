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

import 'package:famedlysdk/src/Room.dart';
import 'package:famedlysdk/src/responses/ErrorResponse.dart';
import 'package:famedlysdk/src/utils/MxContent.dart';

import 'Connection.dart';

enum Membership { join, invite, leave, ban }

/// Represents a Matrix User which may be a participant in a Matrix Room.
class User {
  /// The full qualified Matrix ID in the format @username:server.abc.
  final String id;

  /// The displayname of the user if the user has set one.
  final String displayName;

  /// The membership status of the user. One of:
  /// join
  /// invite
  /// leave
  /// ban
  Membership membership;

  /// The avatar if the user has one.
  MxContent avatarUrl;

  /// The powerLevel of the user. Normally:
  /// 0=Normal user
  /// 50=Moderator
  /// 100=Admin
  int powerLevel = 0;

  /// All users normally belong to a room.
  final Room room;

  @Deprecated("Use membership instead!")
  String get status => membership.toString().split('.').last;

  @Deprecated("Use ID instead!")
  String get mxid => id;

  @Deprecated("Use avatarUrl instead!")
  MxContent get avatar_url => avatarUrl;

  User(
    String id, {
    this.membership,
    this.displayName,
    this.avatarUrl,
    this.powerLevel,
    this.room,
  }) : this.id = id ?? "";

  /// Returns the displayname or the local part of the Matrix ID if the user
  /// has no displayname.
  String calcDisplayname() => (displayName == null || displayName.isEmpty)
      ? id.replaceFirst("@", "").split(":")[0]
      : displayName;

  /// Creates a new User object from a json string like a row from the database.
  static User fromJson(Map<String, dynamic> json, Room room) {
    return User(json['matrix_id'] ?? json['sender'],
        displayName: json['displayname'],
        avatarUrl: MxContent(json['avatar_url']),
        membership: Membership.values.firstWhere((e) {
          if (json["membership"] != null) {
            return e.toString() == 'Membership.' + json['membership'];
          }
          return false;
        }, orElse: () => null),
        powerLevel: json['power_level'],
        room: room);
  }

  /// Checks if the client's user has the permission to kick this user.
  Future<bool> get canKick async {
    final int ownPowerLevel = await room.client.store.getPowerLevel(room.id);
    return ownPowerLevel > powerLevel &&
        ownPowerLevel >= room.powerLevels["power_kick"];
  }

  /// Checks if the client's user has the permission to ban or unban this user.
  Future<bool> get canBan async {
    final int ownPowerLevel = await room.client.store.getPowerLevel(room.id);
    return ownPowerLevel > powerLevel &&
        ownPowerLevel >= room.powerLevels["power_ban"];
  }

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
    String roomID = await room.client?.store?.getDirectChatRoomID(id);
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
}
