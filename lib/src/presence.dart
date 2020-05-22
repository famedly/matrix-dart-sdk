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
import './database/database.dart' show DbPresence;

enum PresenceType { online, offline, unavailable }

/// Informs the client of a user's presence state change.
class Presence {
  /// The user who sent this presence.
  final String sender;

  /// The current display name for this user, if any.
  final String displayname;

  /// The current avatar URL for this user, if any.
  final Uri avatarUrl;
  final bool currentlyActive;
  final int lastActiveAgo;
  final PresenceType presence;
  final String statusMsg;
  final DateTime time;

  Presence(
      {this.sender,
      this.displayname,
      this.avatarUrl,
      this.currentlyActive,
      this.lastActiveAgo,
      this.presence,
      this.statusMsg,
      this.time});

  Presence.fromJson(Map<String, dynamic> json)
      : sender = json['sender'],
        displayname = json['content']['displayname'],
        avatarUrl = json['content']['avatar_url'] != null
            ? Uri.parse(json['content']['avatar_url'])
            : null,
        currentlyActive = json['content']['currently_active'],
        lastActiveAgo = json['content']['last_active_ago'],
        time = DateTime.fromMillisecondsSinceEpoch(
            DateTime.now().millisecondsSinceEpoch -
                (json['content']['last_active_ago'] ?? 0)),
        presence = PresenceType.values.firstWhere(
            (e) =>
                e.toString() == "PresenceType.${json['content']['presence']}",
            orElse: () => null),
        statusMsg = json['content']['status_msg'];

  factory Presence.fromDb(DbPresence dbEntry) {
    final content = Event.getMapFromPayload(dbEntry.content);
    return Presence(
      sender: dbEntry.sender,
      displayname: content['displayname'],
      avatarUrl: content['avatar_url'] != null
          ? Uri.parse(content['avatar_url'])
          : null,
      currentlyActive: content['currently_active'],
      lastActiveAgo: content['last_active_ago'],
      time: DateTime.fromMillisecondsSinceEpoch(
          DateTime.now().millisecondsSinceEpoch -
              (content['last_active_ago'] ?? 0)),
      presence: PresenceType.values.firstWhere(
          (e) => e.toString() == "PresenceType.${content['presence']}",
          orElse: () => null),
      statusMsg: content['status_msg'],
    );
  }
}
