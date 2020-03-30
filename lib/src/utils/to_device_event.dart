class ToDeviceEvent {
  String sender;
  String type;
  Map<String, dynamic> content;

  ToDeviceEvent({this.sender, this.type, this.content});

  ToDeviceEvent.fromJson(Map<String, dynamic> json) {
    sender = json['sender'];
    type = json['type'];
    content = json['content'] != null
        ? Map<String, dynamic>.from(json['content'])
        : null;
  }

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
    final data = map;
    data['sender'] = sender;
    data['type'] = type;
    if (content != null) {
      data['content'] = content;
    }
    return data;
  }
}
