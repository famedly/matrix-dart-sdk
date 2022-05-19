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
import 'dart:convert';

import 'package:collection/src/iterable_extensions.dart';

import '../matrix.dart';
import 'filteredList.dart';
import 'models/timeline_chunk.dart';

/// Represents the timeline of a room. The callback [onUpdate] will be triggered
/// automatically. The initial
/// event list will be retreived when created by the `room.getTimeline()` method.

class Timeline {
  final Room room;
  List<Event> get events => eventsList.filtered;
  List<Event> get uevents => eventsList.unfiltered;
  late FilteredList<Event> eventsList;

  /// Map of event ID to map of type to set of aggregated events
  final Map<String, Map<String, Set<Event>>> aggregatedEvents = {};

  final void Function()? onUpdate;
  final void Function(int index)? onChange;
  final void Function(int index)? onInsert;
  final void Function(int index)? onRemove;
  final void Function()? onNewEvent;
  final bool Function(Event)? filter;

  StreamSubscription<EventUpdate>? sub;
  StreamSubscription<SyncUpdate>? roomSub;
  StreamSubscription<String>? sessionIdReceivedSub;
  bool isRequestingHistory = false;
  bool isRequestingFuture = false;

  bool allowNewEvent = true;
  bool isFragmentedTimeline = false;

  final Map<String, Event> _eventCache = {};

  TimelineChunk chunk;

  /// Searches for the event in this timeline. If not
  /// found, requests from the server. Requested events
  /// are cached.
  Future<Event?> getEventById(String id) async {
    for (final event in uevents) {
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
    if (uevents.isEmpty) return true;
    return uevents.last.type != EventTypes.RoomCreate;
  }

  Future<void> requestHistory(
      {int historyCount = Room.defaultHistoryCount}) async {
    if (isRequestingHistory) {
      return;
    }

    isRequestingHistory = true;
    await _requestEvents(direction: Direction.b, historyCount: historyCount);
    isRequestingHistory = false;
  }

  bool get canRequestFuture => !allowNewEvent;

  Future<void> requestFuture(
      {int historyCount = Room.defaultHistoryCount}) async {
    if (allowNewEvent) {
      return; // we shouldn't force to add new events if they will autatically be added
    }

    if (isRequestingFuture) return;
    isRequestingFuture = true;
    await _requestEvents(direction: Direction.f, historyCount: historyCount);
    isRequestingFuture = false;
  }

  Future<void> _requestEvents(
      {int historyCount = Room.defaultHistoryCount,
      required Direction direction}) async {
    onUpdate?.call();

    try {
      // Look up for events in the database first. With fragmented view, we should delete the database cache
      final eventsFromStore = isFragmentedTimeline
          ? null
          : await room.client.database?.getEventList(
              room,
              start: uevents.length,
              limit: Room.defaultHistoryCount,
            );

      if (eventsFromStore != null && eventsFromStore.isNotEmpty) {
        // Fetch all users from database we have got here.
        for (final event in events) {
          if (room.getState(EventTypes.RoomMember, event.senderId) != null) {
            continue;
          }
          final dbUser =
              await room.client.database?.getUser(event.senderId, room);
          if (dbUser != null) room.setState(dbUser);
        }

        if (direction == Direction.b) {
          eventsList.addAll(eventsFromStore);
          final startIndex = events.length - eventsFromStore.length;
          final endIndex = events.length;
          for (var i = startIndex; i < endIndex; i++) {
            onInsert?.call(i);
          }
        } else {
          eventsList.insertAll(0, eventsFromStore);
          final startIndex = eventsFromStore.length;
          final endIndex = 0;
          for (var i = startIndex; i > endIndex; i--) {
            onInsert?.call(i);
          }
        }
      } else {
        Logs().i('No more events found in the store. Request from server...');
        if (isFragmentedTimeline) {
          await getRoomEvents(
            historyCount: historyCount,
            direction: direction,
          );
        } else {
          await room.requestHistory(
            historyCount: historyCount,
            direction: direction,
            onHistoryReceived: () {
              _collectHistoryUpdates = true;
            },
          );
        }
      }
    } finally {
      _collectHistoryUpdates = false;
      isRequestingHistory = false;
      onUpdate?.call();
    }
  }

  /// Request more previous events from the server. [historyCount] defines how much events should
  /// be received maximum. When the request is answered, [onHistoryReceived] will be triggered **before**
  /// the historical events will be published in the onEvent stream.
  /// Returns the actual count of received timeline events.
  Future<int> getRoomEvents(
      {int historyCount = Room.defaultHistoryCount,
      direction = Direction.b}) async {
    final resp = await room.client.getRoomEvents(
      room.id,
      direction == Direction.b ? chunk.prevBatch : chunk.nextBatch,
      direction,
      limit: historyCount,
      filter: jsonEncode(StateFilter(lazyLoadMembers: true).toJson()),
    );

    if (resp.end == null) {
      Logs().w('end parameter was not set in the response');
    }

    final newNextBatch = direction == Direction.b ? resp.start : resp.end;
    final newPrevBatch = direction == Direction.b ? resp.end : resp.start;

    final type = direction == Direction.b
        ? EventUpdateType.history
        : EventUpdateType.timeline;

    if ((resp.state?.length ?? 0) == 0 && resp.start != resp.end) {
      if (type == EventUpdateType.history) {
        Logs().w(
            '[nav] we can still request history prevBatch: $type $newPrevBatch');
      } else {
        Logs().w(
            '[nav] we can still request history nextBatch: $type $newNextBatch');
      }
    }

    final newEvents =
        resp.chunk.map((e) => Event.fromMatrixEvent(e, room)).toList();

    if (!allowNewEvent) {
      if (resp.start == resp.end) allowNewEvent = true;

      if (allowNewEvent) {
        Logs().d('We now allow sync update into the timeline.');
        allowNewEvent = true;
        newEvents.addAll(
            await room.client.database?.getEventList(room, onlySending: true) ??
                []);
      }
    }

    // Try to decrypt encrypted events but don't update the database.
    if (room.encrypted &&
        room.client.database != null &&
        room.client.encryptionEnabled) {
      for (var i = 0; i < newEvents.length; i++) {
        if (newEvents[i].type == EventTypes.Encrypted) {
          newEvents[i] = await room.client.encryption!
              .decryptRoomEvent(room.id, newEvents[i]);
        }
      }
    }

    // update chunk anchors
    if (type == EventUpdateType.history) {
      chunk.prevBatch = newPrevBatch ?? '';
      eventsList.addAll(newEvents);
    } else {
      chunk.nextBatch = newNextBatch ?? '';
      eventsList.insertAll(0, newEvents.reversed);
    }

    if (onUpdate != null) {
      onUpdate!();
    }
    return resp.chunk.length;
  }

  Timeline(
      {required this.room,
      this.onUpdate,
      this.onChange,
      this.onInsert,
      this.onRemove,
      this.onNewEvent,
      this.filter,
      required this.chunk}) {
    sub = room.client.onEvent.stream.listen(_handleEventUpdate);

    // If the timeline is limited we want to clear our events cache
    roomSub = room.client.onSync.stream
        .where((sync) => sync.rooms?.join?[room.id]?.timeline?.limited == true)
        .listen(_removeEventsNotInThisSync);

    sessionIdReceivedSub =
        room.onSessionKeyReceived.stream.listen(_sessionKeyReceived);

    // we want to populate our aggregated events
    for (final e in uevents) {
      addAggregatedEvent(e);
    }

    // we are using a fragmented timeline
    if (chunk.nextBatch != '') {
      allowNewEvent = false;
      isFragmentedTimeline = true;
    }

    eventsList = FilteredList(events, filter: filter ?? (_) => true);
  }

  /// Removes all entries from [events] which are not in this SyncUpdate.
  void _removeEventsNotInThisSync(SyncUpdate sync) {
    final newSyncEvents = sync.rooms?.join?[room.id]?.timeline?.events ?? [];
    final keepEventIds = newSyncEvents.map((e) => e.eventId);
    eventsList.removeWhere((e) => !keepEventIds.contains(e.eventId));
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
      for (var i = 0; i < uevents.length; i++) {
        if (uevents[i].type == EventTypes.Encrypted &&
            uevents[i].messageType == MessageTypes.BadEncrypted &&
            uevents[i].content['session_id'] == sessionId) {
          uevents[i] = await encryption.decryptRoomEvent(room.id, uevents[i],
              store: true);

          if (filter?.call(uevents[i]) ?? true) {
            final pos = events.indexOf(uevents[i]);
            onChange?.call(pos);
          }

          if (uevents[i].type != EventTypes.Encrypted) {
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
    for (final event in uevents) {
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
        uevents.firstWhereOrNull((event) => event.status.isSynced)?.eventId;
    if (eventId == null) return;
    return room.setReadMarker(eventId, mRead: eventId);
  }

  static int _findEvent(List<Event> list,
      {String? event_id, String? unsigned_txid}) {
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
    for (i = 0; i < list.length; i++) {
      final searchHaystack = <String>{list[i].eventId};

      final txnid = list[i].unsigned?['transaction_id'];
      if (txnid != null) {
        searchHaystack.add(txnid);
      }
      if (searchNeedle.intersection(searchHaystack).isNotEmpty) {
        break;
      }
    }
    return i;
  }

  static void _removeEventFromSet(Set<Event> eventSet, Event event) {
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
    final eventsSet = (aggregatedEvents[relationshipEventId] ??=
        <String, Set<Event>>{})[relationshipType] ??= <Event>{};
    // remove a potential old event
    _removeEventFromSet(eventsSet, event);
    // add the new one
    eventsSet.add(event);
    if (onChange != null) {
      final index = _findEvent(events, event_id: relationshipEventId);
      onChange?.call(index);
    }
  }

  void removeAggregatedEvent(Event event) {
    aggregatedEvents.remove(event.eventId);
    if (event.unsigned != null) {
      aggregatedEvents.remove(event.unsigned?['transaction_id']);
    }
    for (final types in aggregatedEvents.values) {
      for (final eventsSet in types.values) {
        _removeEventFromSet(eventsSet, event);
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

      if (eventUpdate.type == EventUpdateType.timeline) {
        onNewEvent?.call();
      }

      if (!allowNewEvent) return;

      final status = eventStatusFromInt(eventUpdate.content['status'] ??
          (eventUpdate.content['unsigned'] is Map<String, dynamic>
              ? eventUpdate.content['unsigned'][messageSendingStatusKey]
              : null) ??
          EventStatus.synced.intValue);

      if (status.isRemoved) {
        final i =
            _findEvent(uevents, event_id: eventUpdate.content['event_id']);
        if (i < uevents.length) {
          final event = uevents[i];
          removeAggregatedEvent(event);
          if (filter?.call(event) ?? true) {
            final pos = events.indexOf(event);
            events.removeAt(pos);
            onRemove?.call(pos);
          }
        }
      } else {
        final i = _findEvent(eventsList.unfiltered,
            event_id: eventUpdate.content['event_id'],
            unsigned_txid: eventUpdate.content['unsigned'] is Map
                ? eventUpdate.content['unsigned']['transaction_id']
                : null);

        if (i < uevents.length) {
          // if the old status is larger than the new one, we also want to preserve the old status
          final oldStatus = uevents[i].status;
          uevents[i] = Event.fromJson(
            eventUpdate.content,
            room,
          );
          // do we preserve the status? we should allow 0 -> -1 updates and status increases
          if ((latestEventStatus(status, oldStatus) == oldStatus) &&
              !(status.isError && oldStatus.isSending)) {
            uevents[i].status = oldStatus;
          }
          addAggregatedEvent(uevents[i]);

          if (filter?.call(uevents[i]) ?? true) {
            final pos = events.indexOf(uevents[i]);
            onChange?.call(pos);
          }
        } else {
          final newEvent = Event.fromJson(
            eventUpdate.content,
            room,
          );

          if (eventUpdate.type == EventUpdateType.history &&
              uevents.indexWhere(
                      (e) => e.eventId == eventUpdate.content['event_id']) !=
                  -1) return;
          var indexUnFiltered = uevents.length;
          if (eventUpdate.type == EventUpdateType.history) {
            eventsList.add(newEvent);
          } else {
            indexUnFiltered = uevents.firstIndexWhereNotError;
            uevents.insert(indexUnFiltered, newEvent);

            if (filter?.call(newEvent) ?? true) {
              final indexFiltered = events.firstIndexWhereNotError;
              events.insert(indexFiltered, newEvent);
              onInsert?.call(indexFiltered);
            }
          }

          addAggregatedEvent(newEvent);
        }
      }

      // Handle redaction events
      if (eventUpdate.content['type'] == EventTypes.Redaction) {
        final index =
            _findEvent(uevents, event_id: eventUpdate.content['redacts']);
        final filteredIndex =
            _findEvent(events, event_id: eventUpdate.content['redacts']);

        if (index < uevents.length) {
          removeAggregatedEvent(uevents[index]);

          // Is the redacted event a reaction? Then update the event this
          // belongs to:
          if (onChange != null) {
            final relationshipEventId = uevents[index].relationshipEventId;
            if (relationshipEventId != null) {
              onChange?.call(_findEvent(events, event_id: relationshipEventId));
              return;
            }
          }

          uevents[index].setRedactionEvent(Event.fromJson(
            eventUpdate.content,
            room,
          ));
          onChange?.call(filteredIndex);
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
