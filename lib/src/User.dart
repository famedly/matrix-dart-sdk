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
import 'package:famedlysdk/src/utils/MxContent.dart';
import 'package:famedlysdk/src/Room.dart';

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
  String membership;

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
  String get status => membership;

  @Deprecated("Use ID instead!")
  String get mxid => id;

  @Deprecated("Use avatarUrl instead!")
  MxContent get avatar_url => avatarUrl;

  User(this.id, {
    this.membership,
    this.displayName,
    this.avatarUrl,
    this.powerLevel,
    this.room,
  });

  /// Returns the displayname or the local part of the Matrix ID if the user
  /// has no displayname.
  String calcDisplayname() =>
      displayName.isEmpty
          ? mxid.replaceFirst("@", "").split(":")[0]
          : displayName;

  /// Creates a new User object from a json string like a row from the database.
  static User fromJson(Map<String, dynamic> json, Room room) {
    return User(json['matrix_id'],
        displayName: json['displayname'],
        avatarUrl: MxContent(json['avatar_url']),
        membership: json['membership'],
        room: room);
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
}
