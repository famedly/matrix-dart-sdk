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
import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/src/utils/ChatTime.dart';
import './Room.dart';

class RoomState {
  /// The Matrix ID for this event in the format '$localpart:server.abc'. Please not
  /// that account data, presence and other events may not have an eventId.
  final String eventId;

  /// The json payload of the content. The content highly depends on the type.
  final Map<String, dynamic> content;

  /// The type String of this event. For example 'm.room.message'.
  final String typeKey;

  /// The ID of the room this event belongs to.
  final String roomId;

  /// The user who has sent this event if it is not a global account data event.
  final String senderId;

  User get sender => room.getUserByMXIDSync(senderId);

  /// The time this event has received at the server. May be null for events like
  /// account data.
  final ChatTime time;

  /// Optional additional content for this event.
  final Map<String, dynamic> unsigned;

  /// The room this event belongs to. May be null.
  final Room room;

  /// Optional. The previous content for this state.
  /// This will be present only for state events appearing in the timeline.
  /// If this is not a state event, or there is no previous content, this key will be null.
  final Map<String, dynamic> prevContent;

  /// Optional. This key will only be present for state events. A unique key which defines
  /// the overwriting semantics for this piece of room state.
  final String stateKey;

  User get stateKeyUser => room.getUserByMXIDSync(stateKey);

  RoomState(
      {this.content,
      this.typeKey,
      this.eventId,
      this.roomId,
      this.senderId,
      this.time,
      this.unsigned,
      this.prevContent,
      this.stateKey,
      this.room});

  static Map<String, dynamic> getMapFromPayload(dynamic payload) {
    if (payload is String)
      try {
        return json.decode(payload);
      } catch (e) {
        return {};
      }
    if (payload is Map<String, dynamic>) return payload;
    return {};
  }

  /// Get a State event from a table row or from the event stream.
  factory RoomState.fromJson(Map<String, dynamic> jsonPayload, Room room) {
    final Map<String, dynamic> content =
        RoomState.getMapFromPayload(jsonPayload['content']);
    final Map<String, dynamic> unsigned =
        RoomState.getMapFromPayload(jsonPayload['unsigned']);
    final Map<String, dynamic> prevContent =
        RoomState.getMapFromPayload(jsonPayload['prev_content']);
    return RoomState(
        stateKey: jsonPayload['state_key'],
        prevContent: prevContent,
        content: content,
        typeKey: jsonPayload['type'],
        eventId: jsonPayload['event_id'],
        roomId: jsonPayload['room_id'],
        senderId: jsonPayload['sender'],
        time: ChatTime(jsonPayload['origin_server_ts']),
        unsigned: unsigned,
        room: room);
  }

  Event get timelineEvent => Event(
        content: content,
        typeKey: typeKey,
        eventId: eventId,
        room: room,
        roomId: roomId,
        senderId: senderId,
        time: time,
        unsigned: unsigned,
        status: 1,
      );

  /// The unique key of this event. For events with a [stateKey], it will be the
  /// stateKey. Otherwise it will be the [type] as a string.
  @deprecated
  String get key => stateKey == null || stateKey.isEmpty ? typeKey : stateKey;

  User get asUser => User.fromState(
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

  /// Get the real type.
  EventTypes get type {
    switch (typeKey) {
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
      case "m.room.guest_access":
        return EventTypes.GuestAccess;
      case "m.room.history_visibility":
        return EventTypes.HistoryVisibility;
      case "m.room.message":
        switch (content["msgtype"] ?? "m.text") {
          case "m.text":
            if (content.containsKey("m.relates_to")) {
              return EventTypes.Reply;
            }
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
    return EventTypes.Unknown;
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
  Reply,
  RoomAliases,
  RoomCanonicalAlias,
  RoomCreate,
  RoomJoinRules,
  RoomMember,
  RoomPowerLevels,
  RoomName,
  RoomTopic,
  RoomAvatar,
  GuestAccess,
  HistoryVisibility,
  Unknown,
}
