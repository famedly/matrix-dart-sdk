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

import 'package:famedlysdk/src/RoomState.dart';
import 'package:famedlysdk/src/sync/EventUpdate.dart';
import 'package:famedlysdk/src/utils/ChatTime.dart';
import 'package:famedlysdk/src/utils/Receipt.dart';

import './Room.dart';

/// Defines a timeline event for a room.
class Event extends RoomState {
  /// The status of this event.
  /// -1=ERROR
  ///  0=SENDING
  ///  1=SENT
  ///  2=RECEIVED
  int status;

  static const int defaultStatus = 2;

  Event(
      {this.status = defaultStatus,
      dynamic content,
      String typeKey,
      String eventId,
      String roomId,
      String senderId,
      ChatTime time,
      dynamic unsigned,
      dynamic prevContent,
      String stateKey,
      Room room})
      : super(
            content: content,
            typeKey: typeKey,
            eventId: eventId,
            roomId: roomId,
            senderId: senderId,
            time: time,
            unsigned: unsigned,
            prevContent: prevContent,
            stateKey: stateKey,
            room: room);

  /// Get a State event from a table row or from the event stream.
  factory Event.fromJson(Map<String, dynamic> jsonPayload, Room room) {
    final Map<String, dynamic> content =
        RoomState.getMapFromPayload(jsonPayload['content']);
    final Map<String, dynamic> unsigned =
        RoomState.getMapFromPayload(jsonPayload['unsigned']);
    final Map<String, dynamic> prevContent =
        RoomState.getMapFromPayload(jsonPayload['prev_content']);
    return Event(
        status: jsonPayload['status'] ?? defaultStatus,
        content: content,
        typeKey: jsonPayload['type'],
        eventId: jsonPayload['event_id'],
        roomId: jsonPayload['room_id'],
        senderId: jsonPayload['sender'],
        time: ChatTime(jsonPayload['origin_server_ts']),
        unsigned: unsigned,
        prevContent: prevContent,
        stateKey: jsonPayload['state_key'],
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

  /// Returns a list of [Receipt] instances for this event.
  List<Receipt> get receipts {
    if (!(room.roomAccountData.containsKey("m.receipt"))) return [];
    List<Receipt> receiptsList = [];
    for (var entry in room.roomAccountData["m.receipt"].content.entries) {
      if (entry.value["event_id"] == eventId)
        receiptsList.add(Receipt(
            room.getUserByMXIDSync(entry.key), ChatTime(entry.value["ts"])));
    }
    return receiptsList;
  }

  /// Removes this event if the status is < 1. This event will just be removed
  /// from the database and the timelines. Returns false if not removed.
  Future<bool> remove() async {
    if (status < 1) {
      if (room.client.store != null)
        await room.client.store.removeEvent(eventId);

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

  /// Whether the client is allowed to redact this event.
  bool get canRedact => senderId == room.client.userID || room.canRedact;
}
