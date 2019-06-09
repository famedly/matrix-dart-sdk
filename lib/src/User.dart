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

  /// The membership status of the user
  final String status;

  /// The full qualified Matrix ID in the format @username:server.abc
  final String mxid;

  /// The displayname of the user if the user has set one.
  final String displayName;

  /// The avatar if the user has one.
  final MxContent avatar_url;

  final String directChatRoomId;

  final Room room;

  const User(
    this.mxid, {
    this.status,
    this.displayName,
    this.avatar_url,
    this.directChatRoomId,
    this.room,
  });

  /// Returns the displayname or the local part of the Matrix ID if the user
  /// has no displayname.
  String calcDisplayname() => displayName.isEmpty
      ? mxid.replaceFirst("@", "").split(":")[0]
      : displayName;

  /// Creates a new User object from a json string like a row from the database.
  static User fromJson(Map<String, dynamic> json) {
    return User(json['matrix_id'],
        displayName: json['displayname'],
        avatar_url: MxContent(json['avatar_url']),
        status: "",
        directChatRoomId: "");
  }
}
