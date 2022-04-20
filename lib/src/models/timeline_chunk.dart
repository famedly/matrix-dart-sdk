import '../../matrix.dart';

class TimelineChunk {
  int start; // pos of the first event in the database timeline
  late int end; // pos of the last event in the database timeline

  String prevBatch; // pos of the first event of the database timeline chunk
  String nextBatch;

  String fragmentId;

  List<Event> events;
  List<String> eventIds = [];
  TimelineChunk(
      {this.start = 0,
      int? end,
      required this.events,
      this.prevBatch = '',
      this.nextBatch = '',
      this.fragmentId = ''}) {
    this.end = end ?? events.length + start;
  }
}
