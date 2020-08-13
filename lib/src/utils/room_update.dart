/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020 Famedly GmbH
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

import '../../matrix_api.dart';

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

  factory RoomUpdate.fromSyncRoomUpdate(
    SyncRoomUpdate update,
    String roomId,
  ) =>
      update is JoinedRoomUpdate
          ? RoomUpdate(
              id: roomId,
              membership: Membership.join,
              notification_count:
                  update.unreadNotifications?.notificationCount ?? 0,
              highlight_count: update.unreadNotifications?.highlightCount ?? 0,
              limitedTimeline: update.timeline?.limited ?? false,
              prev_batch: update.timeline?.prevBatch ?? '',
              summary: update.summary,
            )
          : update is InvitedRoomUpdate
              ? RoomUpdate(
                  id: roomId,
                  membership: Membership.invite,
                  notification_count: 0,
                  highlight_count: 0,
                  limitedTimeline: false,
                  prev_batch: '',
                  summary: null,
                )
              : update is LeftRoomUpdate
                  ? RoomUpdate(
                      id: roomId,
                      membership: Membership.leave,
                      notification_count: 0,
                      highlight_count: 0,
                      limitedTimeline: update.timeline?.limited ?? false,
                      prev_batch: update.timeline?.prevBatch ?? '',
                      summary: null,
                    )
                  : null;
}
