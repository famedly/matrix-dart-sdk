/*
 *   Famedly Matrix SDK
 *   Copyright (C) 2020, 2021 Famedly GmbH
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as
 *   published by the Free Software Foundation, either version 3 of the
 *   License, or (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:matrix/matrix.dart';

class ToDeviceEvent extends BasicEventWithSender {
  Map<String, dynamic>? encryptedContent;

  String get sender => senderId;
  set sender(String sender) => senderId = sender;

  ToDeviceEvent({
    required String sender,
    required super.type,
    required Map<String, dynamic> super.content,
    this.encryptedContent,
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
