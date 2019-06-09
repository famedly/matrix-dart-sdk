import 'dart:convert';
import './User.dart';
import 'package:famedlysdk/src/utils/ChatTime.dart';
import 'package:famedlysdk/src/Client.dart';

class Event {
  final String id;
  final String roomID;
  final ChatTime time;
  final User sender;
  final User stateKey;
  final String environment;
  final String text;
  final String formattedText;
  final int status;
  final Map<String,dynamic> content;

  const Event(this.id, this.sender, this.time,{
    this.roomID,
    this.stateKey,
    this.text,
    this.formattedText,
    this.status = 2,
    this.environment = "timeline",
    this.content,
  });

  String getBody () => formattedText ?? text ?? "*** Unable to parse Content ***";

  EventTypes get type {
    switch (environment) {
      case "m.room.avatar": return EventTypes.RoomAvatar;
      case "m.room.name": return EventTypes.RoomName;
      case "m.room.topic": return EventTypes.RoomTopic;
      case "m.room.Aliases": return EventTypes.RoomAliases;
      case "m.room.canonical_alias": return EventTypes.RoomCanonicalAlias;
      case "m.room.create": return EventTypes.RoomCreate;
      case "m.room.join_rules": return EventTypes.RoomJoinRules;
      case "m.room.member": return EventTypes.RoomMember;
      case "m.room.power_levels": return EventTypes.RoomPowerLevels;
      case "m.room.message":
        switch(content["msgtype"] ?? "m.text") {
          case "m.text": return EventTypes.Text;
          case "m.notice": return EventTypes.Notice;
          case "m.emote": return EventTypes.Emote;
          case "m.image": return EventTypes.Image;
          case "m.video": return EventTypes.Video;
          case "m.audio": return EventTypes.Audio;
          case "m.file": return EventTypes.File;
          case "m.location": return EventTypes.Location;
        }
    }

  }

  static Event fromJson(Map<String, dynamic> jsonObj) {
    Map<String,dynamic> content;
    try {
      content = json.decode(jsonObj["content_json"]);
    } catch(e) {
      print("jsonObj decode of event content failed: ${e.toString()}");
      content = {};
    }
    return Event(
      jsonObj["id"],
      User.fromJson(jsonObj),
      ChatTime(jsonObj["origin_server_ts"]),
      stateKey: User(jsonObj["state_key"]),
      environment: jsonObj["type"],
      text: jsonObj["content_body"],
      status: jsonObj["status"],
      content: content,
    );
  }

  static Future<List<Event>> getEventList(Client matrix, String roomID) async{
    List<Map<String, dynamic>> eventRes = await matrix.store.db.rawQuery(
        "SELECT * " +
            " FROM Events events, Memberships memberships " +
            " WHERE events.chat_id=?" +
            " AND events.sender=memberships.matrix_id " +
            " GROUP BY events.id " +
            " ORDER BY origin_server_ts DESC",
        [roomID]);

    List<Event> eventList = [];

    for (num i = 0; i < eventRes.length; i++)
      eventList.add(Event.fromJson(eventRes[i]));
    return eventList;
  }

}

enum EventTypes {
  Text,
  Emote,
  Notice,
  Image,
  Video,
  Audio,
  File,
  Location,
  RoomAliases,
  RoomCanonicalAlias,
  RoomCreate,
  RoomJoinRules,
  RoomMember,
  RoomPowerLevels,
  RoomName,
  RoomTopic,
  RoomAvatar,
}

final Map<String,int> StatusTypes = {
  "ERROR": -1,
  "SENDING": 0,
  "SENT": 1,
  "RECEIVED": 2,
};