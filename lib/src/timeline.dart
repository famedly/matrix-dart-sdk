/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2019, 2020, 2021 Famedly GmbH
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

import 'package:collection/src/iterable_extensions.dart';

import '../matrix.dart';

/// Represents the timeline of a room. The callback [onUpdate] will be triggered
/// automatically. The initial
/// event list will be retreived when created by the `room.getTimeline()` method.
class Timeline {
  final Room room;
  final List<Event> events;

  /// Map of event ID to map of type to set of aggregated events
  final Map<String, Map<String, Set<Event>>> aggregatedEvents = {};

  final void Function()? onUpdate;
  final void Function(int index)? onChange;
  final void Function(int index)? onInsert;
  final void Function(int index)? onRemove;
  final void Function(int count)? onHistoryReceived;

  StreamSubscription<EventUpdate>? sub;
  StreamSubscription<SyncUpdate>? roomSub;
  StreamSubscription<String>? sessionIdReceivedSub;
  bool isRequestingHistory = false;

  final Map<String, Event> _eventCache = {};

  /// Searches for the event in this timeline. If not
  /// found, requests from the server. Requested events
  /// are cached.
  Future<Event?> getEventById(String id) async {
    for (final event in events) {
      if (event.eventId == id) return event;
    }
    if (_eventCache.containsKey(id)) return _eventCache[id];
    final requestedEvent = await room.getEventById(id);
    if (requestedEvent == null) return null;
    _eventCache[id] = requestedEvent;
    return _eventCache[id];
  }

  // When fetching history, we will collect them into the `_historyUpdates` set
  // first, and then only process all events at once, once we have the full history.
  // This ensures that the entire history fetching only triggers `onUpdate` only *once*,
  // even if /sync's complete while history is being proccessed.
  bool _collectHistoryUpdates = false;

  bool get canRequestHistory {
    if (events.isEmpty) return true;
    return events.last.type != EventTypes.RoomCreate;
  }

  Future<void> requestHistory(
      {int historyCount = Room.defaultHistoryCount}) async {
    if (isRequestingHistory) {
      return;
    }
    isRequestingHistory = true;
    onUpdate?.call();

    try {
      // Look up for events in hive first
      final eventsFromStore = await room.client.database?.getEventList(
        room,
        start: events.length,
        limit: Room.defaultHistoryCount,
      );
      if (eventsFromStore != null && eventsFromStore.isNotEmpty) {
        events.addAll(eventsFromStore);
        onHistoryReceived?.call(eventsFromStore.length);
      } else {
        Logs().v('No more events found in the store. Request from server...');
        final count = await room.requestHistory(
          historyCount: historyCount,
          onHistoryReceived: () {
            _collectHistoryUpdates = true;
          },
        );
        onHistoryReceived?.call(count);
      }
    } finally {
      _collectHistoryUpdates = false;
      isRequestingHistory = false;
      onUpdate?.call();
    }
  }

  Timeline({
    required this.room,
    List<Event>? events,
    this.onUpdate,
    this.onChange,
    this.onInsert,
    this.onRemove,
    this.onHistoryReceived,
  }) : events = events ?? [] {
    sub = room.client.onEvent.stream.listen(_handleEventUpdate);

    // If the timeline is limited we want to clear our events cache
    roomSub = room.client.onSync.stream
        .where((sync) => sync.rooms?.join?[room.id]?.timeline?.limited == true)
        .listen(_removeEventsNotInThisSync);

    sessionIdReceivedSub =
        room.onSessionKeyReceived.stream.listen(_sessionKeyReceived);

    // we want to populate our aggregated events
    for (final e in this.events) {
      addAggregatedEvent(e);
    }
  }

  /// Removes all entries from [events] which are not in this SyncUpdate.
  void _removeEventsNotInThisSync(SyncUpdate sync) {
    final newSyncEvents = sync.rooms?.join?[room.id]?.timeline?.events ?? [];
    final keepEventIds = newSyncEvents.map((e) => e.eventId);
    events.removeWhere((e) => !keepEventIds.contains(e.eventId));
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
      final encryption = room.client.encryption;
      if (!room.client.encryptionEnabled || encryption == null) {
        return;
      }
      for (var i = 0; i < events.length; i++) {
        if (events[i].type == EventTypes.Encrypted &&
            events[i].messageType == MessageTypes.BadEncrypted &&
            events[i].content['session_id'] == sessionId) {
          events[i] = await encryption.decryptRoomEvent(room.id, events[i],
              store: true);
          onChange?.call(i);
          if (events[i].type != EventTypes.Encrypted) {
            decryptAtLeastOneEvent = true;
          }
        }
      }
    };
    if (room.client.database != null) {
      await room.client.database?.transaction(decryptFn);
    } else {
      await decryptFn();
    }
    if (decryptAtLeastOneEvent) onUpdate?.call();
  }

  /// Request the keys for undecryptable events of this timeline
  void requestKeys() {
    for (final event in events) {
      if (event.type == EventTypes.Encrypted &&
          event.messageType == MessageTypes.BadEncrypted &&
          event.content['can_request_session'] == true) {
        try {
          room.client.encryption?.keyManager.maybeAutoRequest(room.id,
              event.content['session_id'], event.content['sender_key']);
        } catch (_) {
          // dispose
        }
      }
    }
  }

  /// Set the read marker to the last synced event in this timeline.
  Future<void> setReadMarker([String? eventId]) async {
    eventId ??=
        events.firstWhereOrNull((event) => event.status.isSynced)?.eventId;
    if (eventId == null) return;
    return room.setReadMarker(eventId, mRead: eventId);
  }

  int _findEvent({String? event_id, String? unsigned_txid}) {
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
      final searchHaystack = <String>{events[i].eventId};

      final txnid = events[i].unsigned?['transaction_id'];
      if (txnid != null) {
        searchHaystack.add(txnid);
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
            e.matchesEventOrTransactionId(event.unsigned?['transaction_id'])));
  }

  void addAggregatedEvent(Event event) {
    // we want to add an event to the aggregation tree
    final relationshipType = event.relationshipType;
    final relationshipEventId = event.relationshipEventId;
    if (relationshipType == null || relationshipEventId == null) {
      return; // nothing to do
    }
    final events = (aggregatedEvents[relationshipEventId] ??=
        <String, Set<Event>>{})[relationshipType] ??= <Event>{};
    // remove a potential old event
    _removeEventFromSet(events, event);
    // add the new one
    events.add(event);
    if (onChange != null) {
      final index = _findEvent(event_id: relationshipEventId);
      onChange?.call(index);
    }
  }

  void removeAggregatedEvent(Event event) {
    aggregatedEvents.remove(event.eventId);
    if (event.unsigned != null) {
      aggregatedEvents.remove(event.unsigned?['transaction_id']);
    }
    for (final types in aggregatedEvents.values) {
      for (final events in types.values) {
        _removeEventFromSet(events, event);
      }
    }
  }

  void _handleEventUpdate(EventUpdate eventUpdate, {bool update = true}) {
    try {
      if (eventUpdate.roomID != room.id) return;

      if (eventUpdate.type != EventUpdateType.timeline &&
          eventUpdate.type != EventUpdateType.history) {
        return;
      }
      final status = eventStatusFromInt(eventUpdate.content['status'] ??
          (eventUpdate.content['unsigned'] is Map<String, dynamic>
              ? eventUpdate.content['unsigned'][messageSendingStatusKey]
              : null) ??
          EventStatus.synced.intValue);
      // Redaction events are handled as modification for existing events.
      if (eventUpdate.content['type'] == EventTypes.Redaction) {
        final index = _findEvent(event_id: eventUpdate.content['redacts']);
        if (index < events.length) {
          removeAggregatedEvent(events[index]);
          events[index].setRedactionEvent(Event.fromJson(
            eventUpdate.content,
            room,
          ));
          onChange?.call(index);
        }
      } else if (status.isRemoved) {
        final i = _findEvent(event_id: eventUpdate.content['event_id']);
        if (i < events.length) {
          removeAggregatedEvent(events[i]);
          events.removeAt(i);
          onRemove?.call(i);
        }
      } else {
        final i = _findEvent(
            event_id: eventUpdate.content['event_id'],
            unsigned_txid: eventUpdate.content['unsigned'] is Map
                ? eventUpdate.content['unsigned']['transaction_id']
                : null);

        if (i < events.length) {
          // if the old status is larger than the new one, we also want to preserve the old status
          final oldStatus = events[i].status;
          events[i] = Event.fromJson(
            eventUpdate.content,
            room,
          );
          // do we preserve the status? we should allow 0 -> -1 updates and status increases
          if ((latestEventStatus(status, oldStatus) == oldStatus) &&
              !(status.isError && oldStatus.isSending)) {
            events[i].status = oldStatus;
          }
          addAggregatedEvent(events[i]);
          onChange?.call(i);
        } else {
          final newEvent = Event.fromJson(
            eventUpdate.content,
            room,
          );

          if (eventUpdate.type == EventUpdateType.history &&
              events.indexWhere(
                      (e) => e.eventId == eventUpdate.content['event_id']) !=
                  -1) return;
          var index = events.length;
          if (eventUpdate.type == EventUpdateType.history) {
            events.add(newEvent);
          } else {
            index = events.firstIndexWhereNotError;
            events.insert(index, newEvent);
            onInsert?.call(index);
          }

          addAggregatedEvent(newEvent);
        }
      }
      if (update && !_collectHistoryUpdates) {
        onUpdate?.call();
      }
    } catch (e, s) {
      Logs().w('Handle event update failed', e, s);
    }
  }
}

extension on List<Event> {
  int get firstIndexWhereNotError {
    if (isEmpty) return 0;
    final index = indexWhere((event) => !event.status.isError);
    if (index == -1) return length;
    return index;
  }
}
