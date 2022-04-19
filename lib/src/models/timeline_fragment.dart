import 'dart:math';

import '../../matrix.dart';
import 'timeline_chunk.dart';

class TimelineFragment {
  String fragmentId;
  Map<dynamic, dynamic> map = {};

  String get prevBatch => map['prev_batch'] ?? '';

  // wether this node is root
  bool get isRoot => fragmentId == '';

  // pos of the first event of the database timeline chunk
  set prevBatch(String value) => map['prev_batch'] = value;

  String get nextBatch => map['next_batch'] ?? '';
  set nextBatch(String value) => map['next_batch'] = value;

  List<String> get eventsId => map['events']?.cast<String>() ?? [];
  set eventsId(List<String> value) => map['events'] = value;

  String? get replacedBy => map['replaced_by'];

  void setReplacementFragmentID(String value) {
    map['replaced_by'] = value;
  }

  TimelineFragment(
      {required List<String> eventsId,
      required String prevBatch,
      required String nextBatch,
      required this.fragmentId}) {
    this.eventsId = eventsId;
    this.prevBatch = prevBatch;
    this.nextBatch = nextBatch;
  }

  TimelineChunk? getEventContext(String eventId, {required int limit}) {
    final itemPos = eventsId.indexWhere((item) => item.toString() == eventId);

    if (itemPos == -1) {
      Logs().w('Event not found');
      return null;
    }

    var start = itemPos - limit ~/ 2;
    if (start < 0) start = 0;
    final end = min(eventsId.length, start + limit);
    final chunk = TimelineChunk(
        start: start,
        end: end,
        events: [],
        prevBatch: prevBatch,
        nextBatch: nextBatch,
        fragmentId: fragmentId);

    chunk.eventIds = eventsId.getRange(start, end).toList();
    return chunk;
  }

  TimelineFragment.fromMap(Map? rawMap, {required this.fragmentId})
      : map = rawMap ?? {};

  /// Get the new eventIds to download
  List<String> getNewEvents(TimelineChunk chunk,
      {required Direction direction, int? limit}) {
    var end = chunk.end;
    var start = chunk.start;

    int reqStart;
    int reqEnd;

    List<String> newEventIds;
    if (direction == Direction.b) {
      reqStart = end;
      reqEnd = min(eventsId.length, reqStart + (limit ?? eventsId.length));
    } else {
      reqEnd = start;
      reqStart = max(0, start - (limit ?? eventsId.length));
    }

    newEventIds = eventsId.getRange(reqStart, reqEnd).toList();

    Logs().w(
        'len $reqStart -> $reqEnd : ${eventsId.length} : ${newEventIds.length}');

    if (direction == Direction.b) {
      end = reqEnd;

      chunk.eventIds = chunk.eventIds + newEventIds;
    } else {
      // save the new value
      start = reqStart;

      chunk.eventIds = newEventIds + chunk.eventIds;
    }

    // save the new values
    chunk.end = end;
    chunk.start = start;

    return newEventIds;
  }

  void addEvent(
      {required String eventId, required EventUpdateType eventUpdateType}) {
    if (eventUpdateType == EventUpdateType.history) {
      eventsId.add(eventId);
    } else {
      eventsId.insert(0, eventId);
    }
  }
}
