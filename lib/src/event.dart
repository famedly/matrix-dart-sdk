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
import 'package:famedlysdk/src/utils/receipt.dart';
import './room.dart';

/// All data exchanged over Matrix is expressed as an "event". Typically each client action (e.g. sending a message) correlates with exactly one event.
class Event {
  /// The Matrix ID for this event in the format '$localpart:server.abc'. Please not
  /// that account data, presence and other events may not have an eventId.
  final String eventId;

  /// The json payload of the content. The content highly depends on the type.
  Map<String, dynamic> content;

  /// The type String of this event. For example 'm.room.message'.
  final String typeKey;

  /// The ID of the room this event belongs to.
  final String roomId;

  /// The user who has sent this event if it is not a global account data event.
  final String senderId;

  User get sender => room.getUserByMXIDSync(senderId);

  /// The time this event has received at the server. May be null for events like
  /// account data.
  final DateTime time;

  /// Optional additional content for this event.
  Map<String, dynamic> unsigned;

  /// The room this event belongs to. May be null.
  final Room room;

  /// Optional. The previous content for this state.
  /// This will be present only for state events appearing in the timeline.
  /// If this is not a state event, or there is no previous content, this key will be null.
  Map<String, dynamic> prevContent;

  /// Optional. This key will only be present for state events. A unique key which defines
  /// the overwriting semantics for this piece of room state.
  final String stateKey;

  /// The status of this event.
  /// -1=ERROR
  ///  0=SENDING
  ///  1=SENT
  ///  2=TIMELINE
  ///  3=ROOM_STATE
  int status;

  static const int defaultStatus = 2;
  static const Map<String, int> STATUS_TYPE = {
    "ERROR": -1,
    "SENDING": 0,
    "SENT": 1,
    "TIMELINE": 2,
    "ROOM_STATE": 3,
  };

  /// Optional. The event that redacted this event, if any. Otherwise null.
  Event get redactedBecause =>
      unsigned != null && unsigned.containsKey("redacted_because")
          ? Event.fromJson(unsigned["redacted_because"], room)
          : null;

  bool get redacted => redactedBecause != null;

  User get stateKeyUser => room.getUserByMXIDSync(stateKey);

  Event(
      {this.status = defaultStatus,
      this.content,
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
    if (payload is String) {
      try {
        return json.decode(payload);
      } catch (e) {
        return {};
      }
    }
    if (payload is Map<String, dynamic>) return payload;
    return {};
  }

  /// Get a State event from a table row or from the event stream.
  factory Event.fromJson(Map<String, dynamic> jsonPayload, Room room) {
    final Map<String, dynamic> content =
        Event.getMapFromPayload(jsonPayload['content']);
    final Map<String, dynamic> unsigned =
        Event.getMapFromPayload(jsonPayload['unsigned']);
    final Map<String, dynamic> prevContent =
        Event.getMapFromPayload(jsonPayload['prev_content']);
    return Event(
      status: jsonPayload['status'] ?? defaultStatus,
      stateKey: jsonPayload['state_key'],
      prevContent: prevContent,
      content: content,
      typeKey: jsonPayload['type'],
      eventId: jsonPayload['event_id'],
      roomId: jsonPayload['room_id'],
      senderId: jsonPayload['sender'],
      time: jsonPayload.containsKey('origin_server_ts')
          ? DateTime.fromMillisecondsSinceEpoch(jsonPayload['origin_server_ts'])
          : DateTime.now(),
      unsigned: unsigned,
      room: room,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    if (this.stateKey != null) data['state_key'] = this.stateKey;
    if (this.prevContent != null && this.prevContent.isNotEmpty) {
      data['prev_content'] = this.prevContent;
    }
    data['content'] = this.content;
    data['type'] = this.typeKey;
    data['event_id'] = this.eventId;
    data['room_id'] = this.roomId;
    data['sender'] = this.senderId;
    data['origin_server_ts'] = this.time.millisecondsSinceEpoch;
    if (this.unsigned != null && this.unsigned.isNotEmpty) {
      data['unsigned'] = this.unsigned;
    }
    return data;
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
      case "m.room.redaction":
        return EventTypes.Redaction;
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
      case "m.sticker":
        return EventTypes.Sticker;
      case "m.room.message":
        return EventTypes.Message;
      case "m.call.encrypted":
        return EventTypes.Encrypted;
      case "m.call.encryption":
        return EventTypes.Encryption;
      case "m.call.invite":
        return EventTypes.CallInvite;
      case "m.call.answer":
        return EventTypes.CallAnswer;
      case "m.call.candidates":
        return EventTypes.CallCandidates;
      case "m.call.hangup":
        return EventTypes.CallHangup;
    }
    return EventTypes.Unknown;
  }

  ///
  MessageTypes get messageType {
    switch (content["msgtype"] ?? "m.text") {
      case "m.text":
        if (content.containsKey("m.relates_to")) {
          return MessageTypes.Reply;
        }
        return MessageTypes.Text;
      case "m.notice":
        return MessageTypes.Notice;
      case "m.emote":
        return MessageTypes.Emote;
      case "m.image":
        return MessageTypes.Image;
      case "m.video":
        return MessageTypes.Video;
      case "m.audio":
        return MessageTypes.Audio;
      case "m.file":
        return MessageTypes.File;
      case "m.sticker":
        return MessageTypes.Sticker;
      case "m.location":
        return MessageTypes.Location;
      default:
        if (type == EventTypes.Message) {
          return MessageTypes.Text;
        }
        return MessageTypes.None;
    }
  }

  void setRedactionEvent(Event redactedBecause) {
    unsigned = {
      "redacted_because": redactedBecause.toJson(),
    };
    prevContent = null;
    List<String> contentKeyWhiteList = [];
    switch (type) {
      case EventTypes.RoomMember:
        contentKeyWhiteList.add("membership");
        break;
      case EventTypes.RoomCreate:
        contentKeyWhiteList.add("creator");
        break;
      case EventTypes.RoomJoinRules:
        contentKeyWhiteList.add("join_rule");
        break;
      case EventTypes.RoomPowerLevels:
        contentKeyWhiteList.add("ban");
        contentKeyWhiteList.add("events");
        contentKeyWhiteList.add("events_default");
        contentKeyWhiteList.add("kick");
        contentKeyWhiteList.add("redact");
        contentKeyWhiteList.add("state_default");
        contentKeyWhiteList.add("users");
        contentKeyWhiteList.add("users_default");
        break;
      case EventTypes.RoomAliases:
        contentKeyWhiteList.add("aliases");
        break;
      case EventTypes.HistoryVisibility:
        contentKeyWhiteList.add("history_visibility");
        break;
      default:
        break;
    }
    List<String> toRemoveList = [];
    for (var entry in content.entries) {
      if (!contentKeyWhiteList.contains(entry.key)) {
        toRemoveList.add(entry.key);
      }
    }
    toRemoveList.forEach((s) => content.remove(s));
  }

  /// Returns the body of this event if it has a body.
  String get text => content["body"] ?? "";

  /// Returns the formatted boy of this event if it has a formatted body.
  String get formattedText => content["formatted_body"] ?? "";

  /// Use this to get the body.
  String getBody() {
    if (redacted) return "Redacted";
    if (text != "") return text;
    if (formattedText != "") return formattedText;
    return "$type";
  }

  /// Returns a list of [Receipt] instances for this event.
  List<Receipt> get receipts {
    if (!(room.roomAccountData.containsKey("m.receipt"))) return [];
    List<Receipt> receiptsList = [];
    for (var entry in room.roomAccountData["m.receipt"].content.entries) {
      if (entry.value["event_id"] == eventId) {
        receiptsList.add(Receipt(room.getUserByMXIDSync(entry.key),
            DateTime.fromMillisecondsSinceEpoch(entry.value["ts"])));
      }
    }
    return receiptsList;
  }

  /// Removes this event if the status is < 1. This event will just be removed
  /// from the database and the timelines. Returns false if not removed.
  Future<bool> remove() async {
    if (status < 1) {
      if (room.client.store != null) {
        await room.client.store.removeEvent(eventId);
      }

      room.client.onEvent.add(EventUpdate(
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
    await remove();
    final String eventID = await room.sendTextEvent(text, txid: txid);
    return eventID;
  }

  /// Whether the client is allowed to redact this event.
  bool get canRedact => senderId == room.client.userID || room.canRedact;

  /// Redacts this event. Returns [ErrorResponse] on error.
  Future<dynamic> redact({String reason, String txid}) =>
      room.redactEvent(eventId, reason: reason, txid: txid);
}

enum MessageTypes {
  Text,
  Emote,
  Notice,
  Image,
  Video,
  Audio,
  File,
  Location,
  Reply,
  Sticker,
  None,
}

enum EventTypes {
  Message,
  Sticker,
  Redaction,
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
  Encryption,
  Encrypted,
  CallInvite,
  CallAnswer,
  CallCandidates,
  CallHangup,
  Unknown,
}
