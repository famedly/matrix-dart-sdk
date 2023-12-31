/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020, 2021 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:matrix/matrix.dart';

class CachedPresence {
  PresenceType presence;
  DateTime? lastActiveTimestamp;
  String? statusMsg;
  bool? currentlyActive;
  String userid;

  factory CachedPresence.fromJson(Map<String, Object?> json) =>
      CachedPresence._(
        presence: PresenceType.values
            .singleWhere((type) => type.name == json['presence']),
        lastActiveTimestamp: json['last_active_timestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                json['last_active_timestamp'] as int)
            : null,
        statusMsg: json['status_msg'] as String?,
        currentlyActive: json['currently_active'] as bool?,
        userid: json['user_id'] as String,
      );

  Map<String, Object?> toJson() => {
        'user_id': userid,
        'presence': presence.name,
        if (lastActiveTimestamp != null)
          'last_active_timestamp': lastActiveTimestamp?.millisecondsSinceEpoch,
        if (statusMsg != null) 'status_msg': statusMsg,
        if (currentlyActive != null) 'currently_active': currentlyActive,
      };

  CachedPresence._({
    required this.userid,
    required this.presence,
    this.lastActiveTimestamp,
    this.statusMsg,
    this.currentlyActive,
  });

  CachedPresence(this.presence, int? lastActiveAgo, this.statusMsg,
      this.currentlyActive, this.userid) {
    if (lastActiveAgo != null) {
      lastActiveTimestamp =
          DateTime.now().subtract(Duration(milliseconds: lastActiveAgo));
    }
  }

  CachedPresence.fromMatrixEvent(Presence event)
      : this(
            event.presence.presence,
            event.presence.lastActiveAgo,
            event.presence.statusMsg,
            event.presence.currentlyActive,
            event.senderId);

  CachedPresence.fromPresenceResponse(GetPresenceResponse event, String userid)
      : this(event.presence, event.lastActiveAgo, event.statusMsg,
            event.currentlyActive, userid);

  CachedPresence.neverSeen(this.userid) : presence = PresenceType.offline;

  Presence toPresence() {
    final content = <String, dynamic>{
      'presence': presence.name.toString(),
    };
    if (currentlyActive != null) content['currently_active'] = currentlyActive!;
    if (lastActiveTimestamp != null) {
      content['last_active_ago'] =
          DateTime.now().difference(lastActiveTimestamp!).inMilliseconds;
    }
    if (statusMsg != null) content['status_msg'] = statusMsg!;

    final json = {
      'content': content,
      'sender': '@example:localhost',
      'type': 'm.presence'
    };

    return Presence.fromJson(json);
  }
}
