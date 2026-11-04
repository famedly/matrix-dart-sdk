// SPDX-FileCopyrightText: 2019-Present, 2020, 2021 Famedly GmbH
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import '../../matrix.dart';

class ToDeviceEvent extends BasicEventWithSender {
  Map<String, dynamic>? encryptedContent;

  /// The validated `sender_device_keys` of an olm encrypted event (MSC4147).
  DeviceKeys? senderDeviceKeys;

  String get sender => senderId;
  set sender(String sender) => senderId = sender;

  ToDeviceEvent({
    required String sender,
    required super.type,
    required Map<String, dynamic> super.content,
    this.encryptedContent,
    this.senderDeviceKeys,
  }) : super(senderId: sender);

  factory ToDeviceEvent.fromJson(Map<String, dynamic> json) {
    final event = BasicEventWithSender.fromJson(json);
    return ToDeviceEvent(
      sender: event.senderId,
      type: event.type,
      content: event.content,
    );
  }
}

class ToDeviceEventDecryptionError extends ToDeviceEvent {
  Exception exception;
  StackTrace? stackTrace;
  ToDeviceEventDecryptionError({
    required ToDeviceEvent toDeviceEvent,
    required this.exception,
    this.stackTrace,
  }) : super(
         sender: toDeviceEvent.senderId,
         content: toDeviceEvent.content,
         type: toDeviceEvent.type,
       );
}
