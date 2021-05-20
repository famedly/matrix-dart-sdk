class QueuedToDeviceEvent {
  final int id;
  final String type;
  final String txnId;
  final Map<String, dynamic> content;

  QueuedToDeviceEvent({this.id, this.type, this.txnId, this.content});

  factory QueuedToDeviceEvent.fromJson(Map<String, dynamic> json) =>
      QueuedToDeviceEvent(
        id: json['id'],
        type: json['type'],
        txnId: json['txn_id'],
        content: json['content'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'txn_id': txnId,
        'content': content,
      };
}
