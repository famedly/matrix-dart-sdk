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

import 'dart:convert';
import 'package:famedlysdk/src/sync/EventUpdate.dart';
import 'package:famedlysdk/src/utils/ChatTime.dart';
import 'package:famedlysdk/src/Client.dart';
import './User.dart';
import './Room.dart';

/// A single Matrix event, e.g. a message in a chat.
class Event {
  /// The Matrix ID for this event in the format '$localpart:server.abc'.
  final String id;

  /// The room this event belongs to.
  final Room room;

  /// The time this event has received at the server.
  final ChatTime time;

  /// The user who has sent this event.
  final User sender;

  /// The user who is the target of this event e.g. for a m.room.member event.
  final User stateKey;

  /// The type of this event. Mostly this is 'timeline'.
  final String environment;

  /// The status of this event.
  /// -1=ERROR
  ///  0=SENDING
  ///  1=SENT
  ///  2=RECEIVED
  int status;

  /// The json payload of the content. The content highly depends on the type.
  final Map<String, dynamic> content;

  Event(
    this.id,
    this.sender,
    this.time, {
    this.room,
    this.stateKey,
    this.status = 2,
    this.environment,
    this.content,
  });

  /// Returns the body of this event if it has a body.
  String get text => content["body"] ?? "";

  /// Returns the formatted boy of this event if it has a formatted body.
  String get formattedText => content["formatted_body"] ?? "";

  /// Use this to get the body.
  String getBody() {
    if (text != "") return text;
    if (formattedText != "") return formattedText;
    return "*** Unable to parse Content ***";
  }

  /// Get the real type.
  EventTypes get type {
    switch (environment) {
      case "m.room.avatar":
        return EventTypes.RoomAvatar;
      case "m.room.name":
        return EventTypes.RoomName;
      case "m.room.topic":
        return EventTypes.RoomTopic;
      case "m.room.Aliases":
        return EventTypes.RoomAliases;
      case "m.room.canonical_alias":
        return EventTypes.RoomCanonicalAlias;
      case "m.room.create":
        return EventTypes.RoomCreate;
      case "m.room.join_rules":
        return EventTypes.RoomJoinRules;
      case "m.room.member":
        return EventTypes.RoomMember;
      case "m.room.power_levels":
        return EventTypes.RoomPowerLevels;
      case "m.room.message":
        switch (content["msgtype"] ?? "m.text") {
          case "m.text":
            return EventTypes.Text;
          case "m.notice":
            return EventTypes.Notice;
          case "m.emote":
            return EventTypes.Emote;
          case "m.image":
            return EventTypes.Image;
          case "m.video":
            return EventTypes.Video;
          case "m.audio":
            return EventTypes.Audio;
          case "m.file":
            return EventTypes.File;
          case "m.location":
            return EventTypes.Location;
        }
    }
  }

  /// Generate a new Event object from a json string, mostly a table row.
  static Event fromJson(Map<String, dynamic> jsonObj, Room room) {
    Map<String, dynamic> content = jsonObj["content"];

    if (content == null)
      try {
        content = json.decode(jsonObj["content_json"]);
      } catch (e) {
        print("jsonObj decode of event content failed: ${e.toString()}");
        content = {};
      }

    return Event(
      jsonObj["event_id"] ?? jsonObj["id"],
      User.fromJson(jsonObj, room),
      ChatTime(jsonObj["origin_server_ts"]),
      stateKey: User(jsonObj["state_key"]),
      environment: jsonObj["type"],
      status: jsonObj["status"] ?? 2,
      content: content,
      room: room,
    );
  }

  /// Removes this event if the status is < 1. This event will just be removed
  /// from the database and the timelines.
  Future<dynamic> remove() async {
    if (status < 1) {
      room.client.connection.onEvent.add(EventUpdate(
          roomID: room.id,
          type: "timeline",
          eventType: environment,
          content: {"event_id": id, "status": -2, "content": {}}));
    }
  }

  /// Try to send this event again. Only works with events of status -1.
  Future<dynamic> sendAgain({String txid}) async {
    if (status != -1) return;
    remove();
    room.sendTextEvent(text, txid: txid);
  }

  @Deprecated("Use [client.store.getEventList(Room room)] instead!")
  static Future<List<Event>> getEventList(Client matrix, Room room) async {
    List<Event> eventList = await matrix.store.getEventList(room);
    return eventList;
  }
}

enum EventTypes {
  Text,
  Emote,
  Notice,
  Image,
  Video,
  Audio,
  File,
  Location,
  RoomAliases,
  RoomCanonicalAlias,
  RoomCreate,
  RoomJoinRules,
  RoomMember,
  RoomPowerLevels,
  RoomName,
  RoomTopic,
  RoomAvatar,
}

final Map<String, int> StatusTypes = {
  "REMOVE": -2,
  "ERROR": -1,
  "SENDING": 0,
  "SENT": 1,
  "RECEIVED": 2,
};
