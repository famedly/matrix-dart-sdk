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
import 'package:famedlysdk/src/room.dart';
import 'package:famedlysdk/src/event.dart';
import 'package:famedlysdk/src/utils/mx_content.dart';

enum Membership { join, invite, leave, ban }

/// Represents a Matrix User which may be a participant in a Matrix Room.
class User extends Event {
  factory User(
    String id, {
    String membership,
    String displayName,
    String avatarUrl,
    Room room,
  }) {
    var content = <String, String>{};
    if (membership != null) content['membership'] = membership;
    if (displayName != null) content['displayname'] = displayName;
    if (avatarUrl != null) content['avatar_url'] = avatarUrl;
    return User.fromState(
      stateKey: id,
      content: content,
      typeKey: 'm.room.member',
      roomId: room?.id,
      room: room,
      time: DateTime.now(),
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
      DateTime time,
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
  String get displayName => content != null ? content['displayname'] : null;

  /// Returns the power level of this user.
  int get powerLevel => room?.getPowerLevelByUserId(id);

  /// The membership status of the user. One of:
  /// join
  /// invite
  /// leave
  /// ban
  Membership get membership => Membership.values.firstWhere((e) {
        if (content['membership'] != null) {
          return e.toString() == 'Membership.' + content['membership'];
        }
        return false;
      }, orElse: () => Membership.join);

  /// The avatar if the user has one.
  MxContent get avatarUrl => content != null && content['avatar_url'] is String
      ? MxContent(content['avatar_url'])
      : MxContent('');

  /// Returns the displayname or the local part of the Matrix ID if the user
  /// has no displayname. If [formatLocalpart] is true, then the localpart will
  /// be formatted in the way, that all "_" characters are becomming white spaces and
  /// the first character of each word becomes uppercase.
  String calcDisplayname({bool formatLocalpart = true}) {
    if (displayName?.isNotEmpty ?? false) {
      return displayName;
    }
    if (stateKey != null) {
      if (!formatLocalpart) {
        return stateKey.localpart;
      }
      var words = stateKey.localpart.replaceAll('_', ' ').split(' ');
      for (var i = 0; i < words.length; i++) {
        if (words[i].isNotEmpty) {
          words[i] = words[i][0].toUpperCase() + words[i].substring(1);
        }
      }
      return words.join(' ');
    }
    return 'Unknown User';
  }

  /// Call the Matrix API to kick this user from this room.
  Future<void> kick() => room.kick(id);

  /// Call the Matrix API to ban this user from this room.
  Future<void> ban() => room.ban(id);

  /// Call the Matrix API to unban this banned user from this room.
  Future<void> unban() => room.unban(id);

  /// Call the Matrix API to change the power level of this user.
  Future<void> setPower(int power) => room.setPower(id, power);

  /// Returns an existing direct chat ID with this user or creates a new one.
  /// Returns null on error.
  Future<String> startDirectChat() async {
    // Try to find an existing direct chat
    var roomID = await room.client?.getDirectChatFromUserId(id);
    if (roomID != null) return roomID;

    // Start a new direct chat
    final dynamic resp = await room.client.jsonRequest(
        type: HTTPType.POST,
        action: '/client/r0/createRoom',
        data: {
          'invite': [id],
          'is_direct': true,
          'preset': 'trusted_private_chat'
        });

    final String newRoomID = resp['room_id'];

    if (newRoomID == null) return newRoomID;

    await Room(id: newRoomID, client: room.client).addToDirectChat(id);

    return newRoomID;
  }

  /// The newest presence of this user if there is any and null if not.
  Presence get presence => room.client.presences[id];

  /// Whether the client is able to ban/unban this user.
  bool get canBan =>
      membership != Membership.ban &&
      room.canBan &&
      powerLevel < room.ownPowerLevel;

  /// Whether the client is able to kick this user.
  bool get canKick =>
      [Membership.join, Membership.invite].contains(membership) &&
      room.canKick &&
      powerLevel < room.ownPowerLevel;

  /// Whether the client is allowed to change the power level of this user.
  /// Please be aware that you can only set the power level to at least your own!
  bool get canChangePowerLevel =>
      room.canChangePowerLevel && powerLevel < room.ownPowerLevel;
}
