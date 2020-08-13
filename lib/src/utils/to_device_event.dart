import '../../matrix_api.dart';

class ToDeviceEvent extends BasicEventWithSender {
  Map<String, dynamic> encryptedContent;

  String get sender => senderId;
  set sender(String sender) => senderId = sender;

  ToDeviceEvent({
    String sender,
    String type,
    Map<String, dynamic> content,
    this.encryptedContent,
  }) {
    senderId = sender;
    this.type = type;
    this.content = content;
  }

  ToDeviceEvent.fromJson(Map<String, dynamic> json) {
    final event = BasicEventWithSender.fromJson(json);
    senderId = event.senderId;
    type = event.type;
    content = event.content;
  }
}

class ToDeviceEventDecryptionError extends ToDeviceEvent {
  Exception exception;
  StackTrace stackTrace;
  ToDeviceEventDecryptionError({
    ToDeviceEvent toDeviceEvent,
    this.exception,
    this.stackTrace,
  }) : super(
          sender: toDeviceEvent.senderId,
          content: toDeviceEvent.content,
          type: toDeviceEvent.type,
        );
}
