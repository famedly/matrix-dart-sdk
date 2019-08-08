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
import 'package:famedlysdk/src/utils/ChatTime.dart';

import './Room.dart';
import './RawEvent.dart';

class State extends RawEvent {
  /// Optional. The previous content for this state.
  /// This will be present only for state events appearing in the timeline.
  /// If this is not a state event, or there is no previous content, this key will be null.
  final Map<String, dynamic> prevContent;

  /// Optional. This key will only be present for state events. A unique key which defines
  /// the overwriting semantics for this piece of room state.
  final String stateKey;

  User get stateKeyUser => room.states[stateKey] ?? User(stateKey);

  State(
      {this.prevContent,
      this.stateKey,
      dynamic content,
      String typeKey,
      String eventId,
      String roomId,
      String senderId,
      ChatTime time,
      dynamic unsigned,
      Room room})
      : super(
            content: content,
            typeKey: typeKey,
            eventId: eventId,
            roomId: roomId,
            senderId: senderId,
            time: time,
            unsigned: unsigned,
            room: room);

  /// Get a State event from a table row or from the event stream.
  factory State.fromJson(Map<String, dynamic> jsonPayload, Room room) {
    final Map<String, dynamic> content =
        RawEvent.getMapFromPayload(jsonPayload['content']);
    final Map<String, dynamic> unsigned =
        RawEvent.getMapFromPayload(jsonPayload['unsigned']);
    final Map<String, dynamic> prevContent =
        RawEvent.getMapFromPayload(jsonPayload['prev_content']);
    return State(
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
}
