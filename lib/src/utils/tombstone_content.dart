class TombstoneContent {
  String body;
  String replacementRoom;

  TombstoneContent.fromJson(Map<String, dynamic> json)
      : body = json['body'],
        replacementRoom = json['replacement_room'];

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['body'] = body;
    data['replacement_room'] = replacementRoom;
    return data;
  }
}
