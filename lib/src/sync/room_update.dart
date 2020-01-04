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

import '../user.dart';

/// Represents a new room or an update for an
/// already known room.
class RoomUpdate {
  /// All rooms have an idea in the format: !uniqueid:server.abc
  final String id;

  /// The current membership state of the user in this room.
  final Membership membership;

  /// Represents the number of unead notifications. This probably doesn't fit the number
  /// of unread messages.
  final num notification_count;

  // The number of unread highlighted notifications.
  final num highlight_count;

  /// If there are too much new messages, the [homeserver] will only send the
  /// last X (default is 10) messages and set the [limitedTimelinbe] flag to true.
  final bool limitedTimeline;

  /// Represents the current position of the client in the room history.
  final String prev_batch;

  final RoomSummary summary;

  RoomUpdate({
    this.id,
    this.membership,
    this.notification_count,
    this.highlight_count,
    this.limitedTimeline,
    this.prev_batch,
    this.summary,
  });
}

class RoomSummary {
  List<String> mHeroes;
  int mJoinedMemberCount;
  int mInvitedMemberCount;

  RoomSummary(
      {this.mHeroes, this.mJoinedMemberCount, this.mInvitedMemberCount});

  RoomSummary.fromJson(Map<String, dynamic> json) {
    mHeroes = json['m.heroes']?.cast<String>();
    mJoinedMemberCount = json['m.joined_member_count'];
    mInvitedMemberCount = json['m.invited_member_count'];
  }
}
