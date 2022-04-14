import '../../matrix.dart';

class TimelineChunk {
  int start; // pos of the first event in the database timeline
  int end; // pos of the last event in the database timeline

  String prevBatch; // pos of the first event of the database timeline chunk
  String nextBatch;

  String fragmentId;

  List<Event> events;
  List<String> eventIds = [];
  TimelineChunk(
      {required this.start,
      required this.end,
      required this.events,
      required this.prevBatch,
      required this.nextBatch,
      required this.fragmentId});
}
