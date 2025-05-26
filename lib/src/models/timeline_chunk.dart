import 'package:matrix/matrix.dart';

class TimelineChunk {
  String prevBatch; // pos of the first event of the database timeline chunk
  String nextBatch;

  List<Event> events;
  TimelineChunk(
      {required this.events, this.prevBatch = '', this.nextBatch = ''});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TimelineChunk) return false;

    // Compare the lists of event ids regardless of order
    final thisEventIds = events.map((e) => e.eventId).toSet();
    final otherEventIds = other.events.map((e) => e.eventId).toSet();

    return thisEventIds.length == otherEventIds.length &&
        thisEventIds.containsAll(otherEventIds);
  }
}
