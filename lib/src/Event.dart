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

import 'package:famedlysdk/src/sync/EventUpdate.dart';
import 'package:famedlysdk/src/utils/ChatTime.dart';

import './Room.dart';
import './RawEvent.dart';

/// Defines a timeline event for a room.
class Event extends RawEvent {
  /// The status of this event.
  /// -1=ERROR
  ///  0=SENDING
  ///  1=SENT
  ///  2=RECEIVED
  int status;

  Event(
      {this.status,
      dynamic content,
      String typeKey,
      String eventId,
      String roomId,
      String sender,
      ChatTime time,
      dynamic unsigned,
      Room room})
      : super(
            content: content,
            typeKey: typeKey,
            eventId: eventId,
            roomId: roomId,
            sender: sender,
            time: time,
            unsigned: unsigned,
            room: room);

  /// Get a State event from a table row or from the event stream.
  factory Event.fromJson(
      Map<String, dynamic> jsonPayload, int status, Room room) {
    final Map<String, dynamic> content =
        RawEvent.getMapFromPayload(jsonPayload['content']);
    final Map<String, dynamic> unsigned =
        RawEvent.getMapFromPayload(jsonPayload['unsigned']);
    return Event(
        status: status,
        content: content,
        typeKey: jsonPayload['type'],
        eventId: jsonPayload['event_id'],
        roomId: jsonPayload['room_id'],
        sender: jsonPayload['sender'],
        time: ChatTime(jsonPayload['origin_server_ts']),
        unsigned: unsigned,
        room: room);
  }

  /// Returns the body of this event if it has a body.
  String get text => content["body"] ?? "";

  /// Returns the formatted boy of this event if it has a formatted body.
  String get formattedText => content["formatted_body"] ?? "";

  /// Use this to get the body.
  String getBody() {
    if (text != "") return text;
    if (formattedText != "") return formattedText;
    return "$type";
  }

  /// Removes this event if the status is < 1. This event will just be removed
  /// from the database and the timelines. Returns false if not removed.
  Future<bool> remove() async {
    if (status < 1) {
      if (room.client.store != null)
        await room.client.store.db
            .rawDelete("DELETE FROM Events WHERE id=?", [eventId]);

      room.client.connection.onEvent.add(EventUpdate(
          roomID: room.id,
          type: "timeline",
          eventType: typeKey,
          content: {
            "event_id": eventId,
            "status": -2,
            "content": {"body": "Removed..."}
          }));
      return true;
    }
    return false;
  }

  /// Try to send this event again. Only works with events of status -1.
  Future<String> sendAgain({String txid}) async {
    if (status != -1) return null;
    remove();
    final String eventID = await room.sendTextEvent(text, txid: txid);
    return eventID;
  }
}
