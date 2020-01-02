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

import 'Event.dart';
import 'Room.dart';
import 'User.dart';
import 'sync/EventUpdate.dart';

typedef onTimelineUpdateCallback = void Function();
typedef onTimelineInsertCallback = void Function(int insertID);

/// Represents the timeline of a room. The callbacks [onUpdate], [onDelete],
/// [onInsert] and [onResort] will be triggered automatically. The initial
/// event list will be retreived when created by the [room.getTimeline] method.
class Timeline {
  final Room room;
  List<Event> events = [];

  final onTimelineUpdateCallback onUpdate;
  final onTimelineInsertCallback onInsert;

  StreamSubscription<EventUpdate> sub;
  bool _requestingHistoryLock = false;

  Map<String, Event> _eventCache = {};

  /// Searches for the event in this timeline. If not
  /// found, requests from the server. Requested events
  /// are cached.
  Future<Event> getEventById(String id) async {
    for (int i = 0; i < events.length; i++) {
      if (events[i].eventId == id) return events[i];
    }
    if (_eventCache.containsKey(id)) return _eventCache[id];
    final Event requestedEvent = await room.getEventById(id);
    if (requestedEvent == null) return null;
    _eventCache[id] = requestedEvent;
    return _eventCache[id];
  }

  Future<void> requestHistory(
      {int historyCount = Room.DefaultHistoryCount}) async {
    if (!_requestingHistoryLock) {
      _requestingHistoryLock = true;
      await room.requestHistory(
        historyCount: historyCount,
        onHistoryReceived: () {
          if (room.prev_batch.isEmpty || room.prev_batch == null) events = [];
        },
      );
      _requestingHistoryLock = false;
    }
  }

  Timeline({this.room, this.events, this.onUpdate, this.onInsert}) {
    sub ??= room.client.onEvent.stream.listen(_handleEventUpdate);
  }

  int _findEvent({String event_id, String unsigned_txid}) {
    int i;
    for (i = 0; i < events.length; i++) {
      if (events[i].eventId == event_id ||
          (unsigned_txid != null && events[i].eventId == unsigned_txid)) break;
    }
    return i;
  }

  void _handleEventUpdate(EventUpdate eventUpdate) async {
    try {
      if (eventUpdate.roomID != room.id) return;
      if (eventUpdate.type == "timeline" || eventUpdate.type == "history") {
        // Redaction events are handled as modification for existing events.
        if (eventUpdate.eventType == "m.room.redaction") {
          final int eventId =
              _findEvent(event_id: eventUpdate.content["redacts"]);
          if (eventId != null) {
            events[eventId]
                .setRedactionEvent(Event.fromJson(eventUpdate.content, room));
          }
        } else if (eventUpdate.content["status"] == -2) {
          int i = _findEvent(event_id: eventUpdate.content["event_id"]);
          if (i < events.length) events.removeAt(i);
        }
        // Is this event already in the timeline?
        else if (eventUpdate.content.containsKey("unsigned") &&
            eventUpdate.content["unsigned"]["transaction_id"] is String) {
          int i = _findEvent(
              event_id: eventUpdate.content["event_id"],
              unsigned_txid: eventUpdate.content.containsKey("unsigned")
                  ? eventUpdate.content["unsigned"]["transaction_id"]
                  : null);

          if (i < events.length) {
            events[i] = Event.fromJson(eventUpdate.content, room);
          }
        } else {
          Event newEvent;
          User senderUser = await room.client.store
              ?.getUser(matrixID: eventUpdate.content["sender"], room: room);
          if (senderUser != null) {
            eventUpdate.content["displayname"] = senderUser.displayName;
            eventUpdate.content["avatar_url"] = senderUser.avatarUrl.mxc;
          }

          newEvent = Event.fromJson(eventUpdate.content, room);

          if (eventUpdate.type == "history" &&
              events.indexWhere(
                      (e) => e.eventId == eventUpdate.content["event_id"]) !=
                  -1) return;

          events.insert(0, newEvent);
          if (onInsert != null) onInsert(0);
        }
      }
      sortAndUpdate();
    } catch (e) {
      if (room.client.debug) {
        print("[WARNING] (_handleEventUpdate) ${e.toString()}");
      }
    }
  }

  bool sortLock = false;

  sort() {
    if (sortLock || events.length < 2) return;
    sortLock = true;
    events?.sort((a, b) =>
        b.time.millisecondsSinceEpoch.compareTo(a.time.millisecondsSinceEpoch));
    sortLock = false;
  }

  sortAndUpdate() {
    sort();
    if (onUpdate != null) onUpdate();
  }
}
