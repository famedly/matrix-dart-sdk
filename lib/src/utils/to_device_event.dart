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
    final Map<String, dynamic> data = Map<String, dynamic>();
    data['sender'] = this.sender;
    data['type'] = this.type;
    if (this.content != null) {
      data['content'] = this.content;
    }
    return data;
  }
}
