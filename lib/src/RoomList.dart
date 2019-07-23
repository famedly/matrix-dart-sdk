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

import 'dart:async';
import 'dart:core';

import 'Client.dart';
import 'Event.dart';
import 'Room.dart';
import 'User.dart';
import 'sync/EventUpdate.dart';
import 'sync/RoomUpdate.dart';
import 'utils/ChatTime.dart';
import 'utils/MxContent.dart';

/// Represents a list of rooms for this client, which will automatically update
/// itself and call the [onUpdate], [onInsert] and [onDelete] callbacks. To get
/// the initial room list, use the store or create a RoomList instance by using
/// [client.getRoomList].
class RoomList {
  final Client client;
  List<Room> rooms = [];

  final bool onlyLeft;
  final bool onlyDirect;
  final bool onlyGroups;

  /// Will be called, when the room list has changed. Can be used e.g. to update
  /// the state of a StatefulWidget.
  final onRoomListUpdateCallback onUpdate;

  /// Will be called, when a new room is added to the list.
  final onRoomListInsertCallback onInsert;

  /// Will be called, when a room has been removed from the list.
  final onRoomListRemoveCallback onRemove;

  StreamSubscription<EventUpdate> eventSub;
  StreamSubscription<RoomUpdate> roomSub;

  RoomList(
      {this.client,
      this.rooms,
      this.onUpdate,
      this.onInsert,
      this.onRemove,
      this.onlyLeft = false,
      this.onlyDirect = false,
      this.onlyGroups = false}) {
    eventSub ??= client.connection.onEvent.stream.listen(_handleEventUpdate);
    roomSub ??= client.connection.onRoomUpdate.stream.listen(_handleRoomUpdate);
  }

  void _handleRoomUpdate(RoomUpdate chatUpdate) async {
    // Update the chat list item.
    // Search the room in the rooms
    num j = 0;
    for (j = 0; j < rooms.length; j++) {
      if (rooms[j].id == chatUpdate.id) break;
    }
    final bool found = (j < rooms.length - 1 && rooms[j].id == chatUpdate.id);
    final bool isLeftRoom = chatUpdate.membership == Membership.leave;

    // Does the chat already exist in the list rooms?
    if (!found && ((!onlyLeft && !isLeftRoom) || (onlyLeft && isLeftRoom))) {
      num position = chatUpdate.membership == Membership.invite ? 0 : j;
      // Add the new chat to the list
      Room newRoom = Room(
          id: chatUpdate.id,
          name: "",
          membership: chatUpdate.membership,
          prev_batch: chatUpdate.prev_batch,
          highlightCount: chatUpdate.highlight_count,
          notificationCount: chatUpdate.notification_count);
      rooms.insert(position, newRoom);
      if (onInsert != null) onInsert(position);
    }
    // If the membership is "leave" or not "leave" but onlyLeft=true then remove the item and stop here
    else if (found &&
        ((!onlyLeft && isLeftRoom) || (onlyLeft && !isLeftRoom))) {
      rooms.removeAt(j);
      if (onRemove != null) onRemove(j);
    }
    // Update notification and highlight count
    else if (found &&
        chatUpdate.membership != Membership.leave &&
        (rooms[j].notificationCount != chatUpdate.notification_count ||
            rooms[j].highlightCount != chatUpdate.highlight_count)) {
      rooms[j].notificationCount = chatUpdate.notification_count;
      rooms[j].highlightCount = chatUpdate.highlight_count;
    }
    sortAndUpdate();
  }

  void _handleEventUpdate(EventUpdate eventUpdate) {
    // Is the event necessary for the chat list? If not, then return
    if (!(eventUpdate.type == "timeline" ||
        eventUpdate.eventType == "m.room.avatar" ||
        eventUpdate.eventType == "m.room.name")) return;

    // Search the room in the rooms
    num j = 0;
    for (j = 0; j < rooms.length; j++) {
      if (rooms[j].id == eventUpdate.roomID) break;
    }
    final bool found = (j < rooms.length && rooms[j].id == eventUpdate.roomID);
    if (!found) {
      rooms.insert(0, Room(id: eventUpdate.roomID));
      if (onInsert != null) onInsert(0);
      j = 0;
    }

    // Is this an old timeline event? Then stop here...
    /*if (eventUpdate.type == "timeline" &&
        ChatTime(eventUpdate.content["origin_server_ts"]) <=
            rooms[j].timeCreated) return;*/

    if (eventUpdate.type == "timeline") {
      // Update the last message preview
      rooms[j].lastEvent = Event(
        eventUpdate.content["id"],
        User(eventUpdate.content["sender"]),
        ChatTime(eventUpdate.content["origin_server_ts"]),
        room: rooms[j],
        content: eventUpdate.content["content"],
        environment: "timeline",
        status: 2,
      );
    }
    if (eventUpdate.eventType == "m.room.name") {
      // Update the room name
      rooms[j].name = eventUpdate.content["content"]["name"];
    } else if (eventUpdate.eventType == "m.room.avatar") {
      // Update the room avatar
      rooms[j].avatar = MxContent(eventUpdate.content["content"]["url"]);
    }
    sortAndUpdate();
  }

  sortAndUpdate() {
    rooms?.sort((a, b) =>
        b.timeCreated.toTimeStamp().compareTo(a.timeCreated.toTimeStamp()));
    if (onUpdate != null) onUpdate();
  }
}

typedef onRoomListUpdateCallback = void Function();
typedef onRoomListInsertCallback = void Function(int insertID);
typedef onRoomListRemoveCallback = void Function(int insertID);
