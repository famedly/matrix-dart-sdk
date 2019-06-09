import 'package:intl/intl.dart';

class ChatTime {
  DateTime dateTime = DateTime.now();

  ChatTime(num ts) {
    if (ts != null)
    dateTime = DateTime.fromMicrosecondsSinceEpoch(ts * 1000);
  }

  ChatTime.now() {
    dateTime = DateTime.now();
  }

  String toString() {
    DateTime now = DateTime.now();

    bool sameYear = now.year == dateTime.year;

    bool sameDay =
        sameYear && now.month == dateTime.month && now.day == dateTime.day;

    bool sameWeek = sameYear && !sameDay && now.millisecondsSinceEpoch - dateTime.millisecondsSinceEpoch < 1000*60*60*24*7;

    if (sameDay) {
      return toTimeString();
    } else if (sameWeek) {
      switch (dateTime.weekday) { // TODO: Needs localization
        case 1:
          return "Montag";
        case 2:
          return "Dienstag";
        case 3:
          return "Mittwoch";
        case 4:
          return "Donnerstag";
        case 5:
          return "Freitag";
        case 6:
          return "Samstag";
        case 7:
          return "Sonntag";
      }
    } else if (sameYear) {
      return DateFormat('dd.MM').format(dateTime);
    } else {
      return DateFormat('dd.MM.yyyy').format(dateTime);
    }
  }

  num toTimeStamp() {
    return dateTime.microsecondsSinceEpoch;
  }

  bool sameEnvironment(ChatTime prevTime) {
    return toTimeStamp() - prevTime.toTimeStamp() < 1000*60*5;
  }

  String toTimeString() {
    return DateFormat('HH:mm').format(dateTime);
  }

  String toEventTimeString() {
    DateTime now = DateTime.now();

    bool sameYear = now.year == dateTime.year;

    bool sameDay =
        sameYear && now.month == dateTime.month && now.day == dateTime.day;

    if (sameDay) return toTimeString();
    return "${toString()}, ${DateFormat('HH:mm').format(dateTime)}";
  }
}
