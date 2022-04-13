import '../matrix.dart';

class TimelineChunck {
  int start; // pos of the first event in the database timeline
  int end; // pos of the last event in the database timeline
  List<Event> events;
  TimelineChunck(
      {required this.start, required this.end, required this.events});
}
