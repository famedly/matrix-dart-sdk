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

import 'dart:async';

import '../matrix_api.dart';
import 'event.dart';
import 'room.dart';
import 'utils/event_update.dart';
import 'utils/logs.dart';
import 'utils/room_update.dart';

typedef onTimelineUpdateCallback = void Function();
typedef onTimelineInsertCallback = void Function(int insertID);

/// Represents the timeline of a room. The callbacks [onUpdate], [onDelete],
/// [onInsert] and [onResort] will be triggered automatically. The initial
/// event list will be retreived when created by the [room.getTimeline] method.
class Timeline {
  final Room room;
  List<Event> events = [];

  /// Map of event ID to map of type to set of aggregated events
  Map<String, Map<String, Set<Event>>> aggregatedEvents = {};

  final onTimelineUpdateCallback onUpdate;
  final onTimelineInsertCallback onInsert;

  StreamSubscription<EventUpdate> sub;
  StreamSubscription<RoomUpdate> roomSub;
  StreamSubscription<String> sessionIdReceivedSub;
  bool _requestingHistoryLock = false;

  final Map<String, Event> _eventCache = {};

  /// Searches for the event in this timeline. If not
  /// found, requests from the server. Requested events
  /// are cached.
  Future<Event> getEventById(String id) async {
    for (var i = 0; i < events.length; i++) {
      if (events[i].eventId == id) return events[i];
    }
    if (_eventCache.containsKey(id)) return _eventCache[id];
    final requestedEvent = await room.getEventById(id);
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
          if (room.prev_batch.isEmpty || room.prev_batch == null) {
            events.clear();
            aggregatedEvents.clear();
          }
        },
      );
      await Future.delayed(const Duration(seconds: 2));
      _requestingHistoryLock = false;
    }
  }

  Timeline({this.room, this.events, this.onUpdate, this.onInsert}) {
    sub ??= room.client.onEvent.stream.listen(_handleEventUpdate);
    // if the timeline is limited we want to clear our events cache
    // as r.limitedTimeline can be "null" sometimes, we need to check for == true
    // as after receiving a limited timeline room update new events are expected
    // to be received via the onEvent stream, it is unneeded to call sortAndUpdate
    roomSub ??= room.client.onRoomUpdate.stream
        .where((r) => r.id == room.id && r.limitedTimeline == true)
        .listen((r) {
      events.clear();
      aggregatedEvents.clear();
    });
    sessionIdReceivedSub ??=
        room.onSessionKeyReceived.stream.listen(_sessionKeyReceived);

    // we want to populate our aggregated events
    for (final e in events) {
      addAggregatedEvent(e);
    }
    _sort();
  }

  /// Don't forget to call this before you dismiss this object!
  void cancelSubscriptions() {
    sub?.cancel();
    roomSub?.cancel();
    sessionIdReceivedSub?.cancel();
  }

  void _sessionKeyReceived(String sessionId) async {
    var decryptAtLeastOneEvent = false;
    final decryptFn = () async {
      if (!room.client.encryptionEnabled) {
        return;
      }
      for (var i = 0; i < events.length; i++) {
        if (events[i].type == EventTypes.Encrypted &&
            events[i].messageType == MessageTypes.BadEncrypted &&
            events[i].content['can_request_session'] == true &&
            events[i].content['session_id'] == sessionId) {
          events[i] = await room.client.encryption
              .decryptRoomEvent(room.id, events[i], store: true);
          if (events[i].type != EventTypes.Encrypted) {
            decryptAtLeastOneEvent = true;
          }
        }
      }
    };
    if (room.client.database != null) {
      await room.client.database.transaction(decryptFn);
    } else {
      await decryptFn();
    }
    if (decryptAtLeastOneEvent) onUpdate();
  }

  int _findEvent({String event_id, String unsigned_txid}) {
    // we want to find any existing event where either the passed event_id or the passed unsigned_txid
    // matches either the event_id or transaction_id of the existing event.
    // For that we create two sets, searchNeedle, what we search, and searchHaystack, where we check if there is a match.
    // Now, after having these two sets, if the intersect between them is non-empty, we know that we have at least one match in one pair,
    // thus meaning we found our element.
    final searchNeedle = <String>{};
    if (event_id != null) {
      searchNeedle.add(event_id);
    }
    if (unsigned_txid != null) {
      searchNeedle.add(unsigned_txid);
    }
    int i;
    for (i = 0; i < events.length; i++) {
      final searchHaystack = <String>{};
      if (events[i].eventId != null) {
        searchHaystack.add(events[i].eventId);
      }
      if (events[i].unsigned != null &&
          events[i].unsigned['transaction_id'] != null) {
        searchHaystack.add(events[i].unsigned['transaction_id']);
      }
      if (searchNeedle.intersection(searchHaystack).isNotEmpty) {
        break;
      }
    }
    return i;
  }

  void _removeEventFromSet(Set<Event> eventSet, Event event) {
    eventSet.removeWhere((e) =>
        e.matchesEventOrTransactionId(event.eventId) ||
        (event.unsigned != null &&
            e.matchesEventOrTransactionId(event.unsigned['transaction_id'])));
  }

  void addAggregatedEvent(Event event) {
    // we want to add an event to the aggregation tree
    if (event.relationshipType == null || event.relationshipEventId == null) {
      return; // nothing to do
    }
    if (!aggregatedEvents.containsKey(event.relationshipEventId)) {
      aggregatedEvents[event.relationshipEventId] = <String, Set<Event>>{};
    }
    if (!aggregatedEvents[event.relationshipEventId]
        .containsKey(event.relationshipType)) {
      aggregatedEvents[event.relationshipEventId]
          [event.relationshipType] = <Event>{};
    }
    // remove a potential old event
    _removeEventFromSet(
        aggregatedEvents[event.relationshipEventId][event.relationshipType],
        event);
    // add the new one
    aggregatedEvents[event.relationshipEventId][event.relationshipType]
        .add(event);
  }

  void removeAggregatedEvent(Event event) {
    aggregatedEvents.remove(event.eventId);
    if (event.unsigned != null) {
      aggregatedEvents.remove(event.unsigned['transaction_id']);
    }
    for (final types in aggregatedEvents.values) {
      for (final events in types.values) {
        _removeEventFromSet(events, event);
      }
    }
  }

  void _handleEventUpdate(EventUpdate eventUpdate) async {
    try {
      if (eventUpdate.roomID != room.id) return;

      if (eventUpdate.type == 'timeline' || eventUpdate.type == 'history') {
        var status = eventUpdate.content['status'] ??
            (eventUpdate.content['unsigned'] is Map<String, dynamic>
                ? eventUpdate.content['unsigned'][MessageSendingStatusKey]
                : null) ??
            2;
        // Redaction events are handled as modification for existing events.
        if (eventUpdate.eventType == EventTypes.Redaction) {
          final eventId = _findEvent(event_id: eventUpdate.content['redacts']);
          if (eventId < events.length) {
            removeAggregatedEvent(events[eventId]);
            events[eventId].setRedactionEvent(Event.fromJson(
                eventUpdate.content, room, eventUpdate.sortOrder));
          }
        } else if (status == -2) {
          var i = _findEvent(event_id: eventUpdate.content['event_id']);
          if (i < events.length) {
            removeAggregatedEvent(events[i]);
            events.removeAt(i);
          }
        } else {
          var i = _findEvent(
              event_id: eventUpdate.content['event_id'],
              unsigned_txid: eventUpdate.content['unsigned'] is Map
                  ? eventUpdate.content['unsigned']['transaction_id']
                  : null);

          if (i < events.length) {
            // if the old status is larger than the new one, we also want to preserve the old status
            final oldStatus = events[i].status;
            events[i] = Event.fromJson(
                eventUpdate.content, room, eventUpdate.sortOrder);
            // do we preserve the status? we should allow 0 -> -1 updates and status increases
            if (status < oldStatus && !(status == -1 && oldStatus == 0)) {
              events[i].status = oldStatus;
            }
            addAggregatedEvent(events[i]);
          } else {
            var newEvent = Event.fromJson(
                eventUpdate.content, room, eventUpdate.sortOrder);

            if (eventUpdate.type == 'history' &&
                events.indexWhere(
                        (e) => e.eventId == eventUpdate.content['event_id']) !=
                    -1) return;

            events.insert(0, newEvent);
            addAggregatedEvent(newEvent);
            if (onInsert != null) onInsert(0);
          }
        }
      }
      _sort();
      if (onUpdate != null) onUpdate();
    } catch (e, s) {
      Logs.warning('Handle event update failed: ${e.toString()}', s);
    }
  }

  bool _sortLock = false;

  void _sort() {
    if (_sortLock || events.length < 2) return;
    _sortLock = true;
    events?.sort((a, b) {
      if (b.status == -1 && a.status != -1) {
        return 1;
      }
      if (a.status == -1 && b.status != -1) {
        return -1;
      }
      return b.sortOrder - a.sortOrder > 0 ? 1 : -1;
    });
    _sortLock = false;
  }
}
